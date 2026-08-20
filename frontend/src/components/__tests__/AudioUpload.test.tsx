import { render, screen, waitFor, fireEvent } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'

const mockUploadAudio = vi.fn()
const mockGetGoogleToken = vi.fn()
const mockImportFromDrive = vi.fn()
const mockSubmitTextNotes = vi.fn()

vi.mock('../../api', () => ({
  uploadAudio: (...args: unknown[]) => mockUploadAudio(...args),
  getGoogleToken: (...args: unknown[]) => mockGetGoogleToken(...args),
  importFromDrive: (...args: unknown[]) => mockImportFromDrive(...args),
  submitTextNotes: (...args: unknown[]) => mockSubmitTextNotes(...args),
}))

vi.mock('@clerk/react', () => ({
  useAuth: () => ({ getToken: vi.fn().mockResolvedValue('tok') }),
}))

vi.mock('../../hooks/useDrivePicker', () => ({
  useDrivePicker: () => ({ openPicker: vi.fn().mockResolvedValue(null) }),
  AUDIO_MIME_TYPES: 'audio/mpeg',
}))

vi.mock('../../hooks/useMediaQuery', () => ({
  useMediaQuery: () => false, // desktop by default
}))

function fileDataTransfer(files: File[] = []) {
  return {
    types: ['Files'],
    files,
    items: files.map(() => ({ kind: 'file' })),
  }
}

describe('AudioUpload', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    // jsdom doesn't implement scrollIntoView
    Element.prototype.scrollIntoView = vi.fn()
  })

  it('renders drop zone in idle state', async () => {
    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)
    expect(screen.getByTestId('drop-zone')).toBeInTheDocument()
    expect(screen.getByText('Add Notes')).toBeInTheDocument()
  })

  it('rejects files over 25MB', async () => {
    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    const bigFile = new File(['x'.repeat(100)], 'big.mp3', { type: 'audio/mpeg' })
    Object.defineProperty(bigFile, 'size', { value: 26 * 1024 * 1024 })

    const input = screen.getByTestId('file-input') as HTMLInputElement
    await userEvent.upload(input, bigFile)

    await waitFor(() => {
      expect(screen.getByTestId('upload-error')).toHaveTextContent(/too large/)
    })
  })

  it('shows success toast after upload completes', async () => {
    mockUploadAudio.mockResolvedValue({ uploadId: 1, fileName: 'test.mp3' })

    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    const file = new File(['audio'], 'test.mp3', { type: 'audio/mpeg' })
    const input = screen.getByTestId('file-input') as HTMLInputElement
    await userEvent.upload(input, file)

    await waitFor(() => {
      expect(screen.getByTestId('upload-success')).toHaveTextContent(/Processing in background/)
    })
    expect(mockUploadAudio).toHaveBeenCalled()
    // Should return to drop zone (idle state) while toast is visible
    expect(screen.getByTestId('drop-zone')).toBeInTheDocument()
  })

  it('shows error state on API failure', async () => {
    mockUploadAudio.mockRejectedValue(new Error('Network error'))

    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    const file = new File(['audio'], 'test.mp3', { type: 'audio/mpeg' })
    const input = screen.getByTestId('file-input') as HTMLInputElement
    await userEvent.upload(input, file)

    await waitFor(() => {
      expect(screen.getByTestId('upload-error')).toHaveTextContent('Network error')
    })
  })

  it('does not call transcribe or extract after upload', async () => {
    mockUploadAudio.mockResolvedValue({ uploadId: 1, fileName: 'test.mp3' })

    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    const file = new File(['audio'], 'test.mp3', { type: 'audio/mpeg' })
    const input = screen.getByTestId('file-input') as HTMLInputElement
    await userEvent.upload(input, file)

    await waitFor(() => {
      expect(screen.getByTestId('upload-success')).toBeInTheDocument()
    })
    // These should not exist as API functions anymore
    expect(mockUploadAudio).toHaveBeenCalledTimes(1)
  })

  it('opens a Paste Text modal instead of an inline paste row', async () => {
    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    expect(screen.queryByTestId('paste-area')).not.toBeInTheDocument()
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()

    await userEvent.click(screen.getByTestId('paste-text-btn'))

    const dialog = await screen.findByRole('dialog')
    expect(dialog).toHaveAttribute('aria-modal', 'true')
    expect(screen.getByRole('heading', { name: 'Paste Text' })).toBeInTheDocument()
    expect(screen.getByTestId('paste-textarea')).toBeInTheDocument()
    expect(screen.getByTestId('paste-submit-btn')).toBeDisabled()
    expect(screen.queryByTestId('paste-area')).not.toBeInTheDocument()
  })

  it('closes the Paste Text modal on Escape and returns focus to Paste Text', async () => {
    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    await userEvent.click(screen.getByTestId('paste-text-btn'))
    await screen.findByRole('dialog')
    await userEvent.keyboard('{Escape}')

    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    })
    expect(screen.getByTestId('paste-text-btn')).toHaveFocus()
  })

  it('closes the Paste Text modal via × and returns focus to Paste Text', async () => {
    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    await userEvent.click(screen.getByTestId('paste-text-btn'))
    await screen.findByRole('dialog')
    await userEvent.click(screen.getByRole('button', { name: 'Close' }))

    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    })
    expect(screen.getByTestId('paste-text-btn')).toHaveFocus()
  })

  it('does not dismiss the Paste Text modal on overlay click', async () => {
    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    await userEvent.click(screen.getByTestId('paste-text-btn'))
    await screen.findByRole('dialog')
    fireEvent.click(screen.getByTestId('paste-text-overlay'))

    expect(screen.getByRole('dialog')).toBeInTheDocument()
  })

  it('keeps the draft when the Paste Text modal is dismissed', async () => {
    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    await userEvent.click(screen.getByTestId('paste-text-btn'))
    fireEvent.change(screen.getByTestId('paste-textarea'), { target: { value: 'Draft notes' } })
    await userEvent.keyboard('{Escape}')
    await waitFor(() => {
      expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    })

    await userEvent.click(screen.getByTestId('paste-text-btn'))
    expect(screen.getByTestId('paste-textarea')).toHaveValue('Draft notes')
  })

  it('clears the draft after a successful paste submit', async () => {
    mockSubmitTextNotes.mockResolvedValue({ uploadId: 1, fileName: 'pasted-text' })

    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    await userEvent.click(screen.getByTestId('paste-text-btn'))
    fireEvent.change(screen.getByTestId('paste-textarea'), {
      target: { value: 'Alice did great today' },
    })
    await userEvent.click(screen.getByTestId('paste-submit-btn'))

    await waitFor(() => {
      expect(screen.getByTestId('upload-success')).toBeInTheDocument()
    })
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()

    await userEvent.click(screen.getByTestId('paste-text-btn'))
    expect(screen.getByTestId('paste-textarea')).toHaveValue('')
  })

  it('submits pasted text and shows success', async () => {
    mockSubmitTextNotes.mockResolvedValue({ uploadId: 1, fileName: 'pasted-text' })

    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    await userEvent.click(screen.getByTestId('paste-text-btn'))
    fireEvent.change(screen.getByTestId('paste-textarea'), {
      target: { value: 'Alice did great today' },
    })

    expect(screen.getByTestId('paste-submit-btn')).not.toBeDisabled()
    await userEvent.click(screen.getByTestId('paste-submit-btn'))

    await waitFor(() => {
      expect(screen.getByTestId('upload-success')).toHaveTextContent(/Processing in background/)
    })
    expect(mockSubmitTextNotes).toHaveBeenCalledTimes(1)
    expect(mockSubmitTextNotes.mock.calls[0][0]).toBe('Alice did great today')
  })

  it('shows error when paste submission fails', async () => {
    mockSubmitTextNotes.mockRejectedValue(new Error('Extraction failed'))

    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    await userEvent.click(screen.getByTestId('paste-text-btn'))
    fireEvent.change(screen.getByTestId('paste-textarea'), { target: { value: 'Some notes' } })
    await userEvent.click(screen.getByTestId('paste-submit-btn'))

    await waitFor(() => {
      expect(screen.getByTestId('upload-error')).toHaveTextContent('Extraction failed')
    })
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(screen.queryByTestId('paste-textarea')).not.toBeInTheDocument()

    await userEvent.click(screen.getByTestId('paste-text-btn'))
    expect(screen.getByTestId('paste-textarea')).toHaveValue('Some notes')
  })

  it('focuses paste textarea when Paste Text is clicked', async () => {
    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    await userEvent.click(screen.getByTestId('paste-text-btn'))

    await waitFor(() => {
      expect(screen.getByTestId('paste-textarea')).toBeInTheDocument()
    })
    await waitFor(() => {
      expect(document.activeElement).toBe(screen.getByTestId('paste-textarea'))
    })
  })

  it('uploads multiple files sequentially and shows success count', async () => {
    mockUploadAudio.mockResolvedValue({ uploadId: 1 })

    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    const file1 = new File(['audio'], 'a.mp3', { type: 'audio/mpeg' })
    const file2 = new File(['audio'], 'b.mp3', { type: 'audio/mpeg' })
    const input = screen.getByTestId('file-input') as HTMLInputElement
    await userEvent.upload(input, [file1, file2])

    await waitFor(() => {
      expect(screen.getByTestId('upload-success')).toHaveTextContent('2 files uploaded')
    })
    expect(mockUploadAudio).toHaveBeenCalledTimes(2)
  })

  it('shows partial failure summary when some files fail', async () => {
    mockUploadAudio
      .mockResolvedValueOnce({ uploadId: 1 })
      .mockRejectedValueOnce(new Error('Server error'))

    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    const file1 = new File(['audio'], 'ok.mp3', { type: 'audio/mpeg' })
    const file2 = new File(['audio'], 'fail.mp3', { type: 'audio/mpeg' })
    const input = screen.getByTestId('file-input') as HTMLInputElement
    await userEvent.upload(input, [file1, file2])

    await waitFor(() => {
      const errorEl = screen.getByTestId('upload-error')
      expect(errorEl).toHaveTextContent('1 file uploaded')
      expect(errorEl).toHaveTextContent('fail.mp3')
    })
    expect(mockUploadAudio).toHaveBeenCalledTimes(2)
  })

  it('rejects all files when any file exceeds 25MB', async () => {
    const { default: AudioUpload } = await import('../AudioUpload')
    render(<AudioUpload />)

    const okFile = new File(['audio'], 'ok.mp3', { type: 'audio/mpeg' })
    const bigFile = new File(['x'.repeat(100)], 'big.mp3', { type: 'audio/mpeg' })
    Object.defineProperty(bigFile, 'size', { value: 26 * 1024 * 1024 })

    const input = screen.getByTestId('file-input') as HTMLInputElement
    await userEvent.upload(input, [okFile, bigFile])

    await waitFor(() => {
      expect(screen.getByTestId('upload-error')).toHaveTextContent(
        /too large|exceed the 25 MB limit/,
      )
    })
    expect(mockUploadAudio).not.toHaveBeenCalled()
  })

  describe('viewport file drop', () => {
    it('shows a drop overlay when a file is dragged over the page', async () => {
      const { default: AudioUpload } = await import('../AudioUpload')
      render(<AudioUpload />)

      fireEvent.dragEnter(window, { dataTransfer: fileDataTransfer() })

      expect(screen.getByTestId('drop-overlay')).toHaveTextContent('Drop audio to upload')
    })

    it('uploads dropped files through the existing file path', async () => {
      mockUploadAudio.mockResolvedValue({ uploadId: 1, fileName: 'drop.mp3' })

      const { default: AudioUpload } = await import('../AudioUpload')
      render(<AudioUpload />)

      const file = new File(['audio'], 'drop.mp3', { type: 'audio/mpeg' })
      fireEvent.drop(window, { dataTransfer: fileDataTransfer([file]) })

      await waitFor(() => {
        expect(mockUploadAudio).toHaveBeenCalledTimes(1)
      })
      expect(mockUploadAudio.mock.calls[0][0]).toBe(file)
      expect(screen.queryByTestId('drop-overlay')).not.toBeInTheDocument()
    })

    it('hides the overlay when the drag leaves the window', async () => {
      const { default: AudioUpload } = await import('../AudioUpload')
      render(<AudioUpload />)

      fireEvent.dragEnter(window, { dataTransfer: fileDataTransfer() })
      expect(screen.getByTestId('drop-overlay')).toBeInTheDocument()

      fireEvent.dragLeave(window, { dataTransfer: fileDataTransfer() })
      await waitFor(() => {
        expect(screen.queryByTestId('drop-overlay')).not.toBeInTheDocument()
      })
    })

    it('does not flicker the overlay on nested dragenter/dragleave', async () => {
      const { default: AudioUpload } = await import('../AudioUpload')
      render(<AudioUpload />)

      fireEvent.dragEnter(window, { dataTransfer: fileDataTransfer() })
      expect(screen.getByTestId('drop-overlay')).toBeInTheDocument()

      // Real nested move: leave then enter in the same frame
      fireEvent.dragLeave(window, { dataTransfer: fileDataTransfer() })
      fireEvent.dragEnter(window, { dataTransfer: fileDataTransfer() })
      expect(screen.getByTestId('drop-overlay')).toBeInTheDocument()

      await new Promise<void>(resolve => requestAnimationFrame(() => resolve()))
      expect(screen.getByTestId('drop-overlay')).toBeInTheDocument()

      fireEvent.dragLeave(window, { dataTransfer: fileDataTransfer() })
      await waitFor(() => {
        expect(screen.queryByTestId('drop-overlay')).not.toBeInTheDocument()
      })
    })

    it('does not show the overlay or take a drop while the Paste Text modal is open', async () => {
      mockUploadAudio.mockResolvedValue({ uploadId: 1, fileName: 'test.mp3' })

      const { default: AudioUpload } = await import('../AudioUpload')
      render(<AudioUpload />)

      await userEvent.click(screen.getByTestId('paste-text-btn'))
      await screen.findByRole('dialog')

      fireEvent.dragEnter(window, { dataTransfer: fileDataTransfer() })
      expect(screen.queryByTestId('drop-overlay')).not.toBeInTheDocument()

      const file = new File(['audio'], 'test.mp3', { type: 'audio/mpeg' })
      fireEvent.drop(window, { dataTransfer: fileDataTransfer([file]) })

      expect(mockUploadAudio).not.toHaveBeenCalled()
      expect(screen.getByRole('dialog')).toBeInTheDocument()
    })

    it('does not show the overlay or take a drop while uploading', async () => {
      let resolveUpload: (value: unknown) => void = () => {}
      mockUploadAudio.mockReturnValue(
        new Promise(resolve => {
          resolveUpload = resolve
        }),
      )

      const { default: AudioUpload } = await import('../AudioUpload')
      render(<AudioUpload />)

      const file = new File(['audio'], 'uploading.mp3', { type: 'audio/mpeg' })
      const input = screen.getByTestId('file-input') as HTMLInputElement
      await userEvent.upload(input, file)
      await waitFor(() => expect(screen.getByTestId('upload-progress')).toBeInTheDocument())

      fireEvent.dragEnter(window, { dataTransfer: fileDataTransfer() })
      expect(screen.queryByTestId('drop-overlay')).not.toBeInTheDocument()

      const dropped = new File(['audio'], 'dropped.mp3', { type: 'audio/mpeg' })
      fireEvent.drop(window, { dataTransfer: fileDataTransfer([dropped]) })
      expect(mockUploadAudio).toHaveBeenCalledTimes(1)

      resolveUpload({ uploadId: 1, fileName: 'uploading.mp3' })
    })

    it('surfaces the existing size error after an oversized drop', async () => {
      const { default: AudioUpload } = await import('../AudioUpload')
      render(<AudioUpload />)

      const bigFile = new File(['x'.repeat(100)], 'big.mp3', { type: 'audio/mpeg' })
      Object.defineProperty(bigFile, 'size', { value: 26 * 1024 * 1024 })

      fireEvent.drop(window, { dataTransfer: fileDataTransfer([bigFile]) })

      await waitFor(() => {
        expect(screen.getByTestId('upload-error')).toHaveTextContent(/too large/)
      })
      expect(mockUploadAudio).not.toHaveBeenCalled()
      expect(screen.queryByTestId('drop-overlay')).not.toBeInTheDocument()
    })

    it('stops handling file drags after unmount (Notes tab left)', async () => {
      mockUploadAudio.mockResolvedValue({ uploadId: 1 })

      const { default: AudioUpload } = await import('../AudioUpload')
      const { unmount } = render(<AudioUpload />)

      fireEvent.dragEnter(window, { dataTransfer: fileDataTransfer() })
      expect(screen.getByTestId('drop-overlay')).toBeInTheDocument()

      unmount()

      fireEvent.dragEnter(window, { dataTransfer: fileDataTransfer() })
      expect(screen.queryByTestId('drop-overlay')).not.toBeInTheDocument()

      const file = new File(['audio'], 'after-unmount.mp3', { type: 'audio/mpeg' })
      fireEvent.drop(window, { dataTransfer: fileDataTransfer([file]) })
      expect(mockUploadAudio).not.toHaveBeenCalled()
    })
  })

  describe('recording', () => {
    class FakeMediaRecorder {
      static isTypeSupported = vi.fn(() => true)
      state: 'inactive' | 'recording' = 'inactive'
      mimeType: string
      ondataavailable: ((e: { data: Blob }) => void) | null = null
      onstop: (() => void) | null = null
      constructor(_stream: MediaStream, options?: { mimeType?: string }) {
        this.mimeType = options?.mimeType ?? ''
      }
      start() {
        this.state = 'recording'
      }
      stop() {
        this.state = 'inactive'
        this.ondataavailable?.({
          data: new Blob(['chunk'], { type: this.mimeType || 'audio/webm' }),
        })
        this.onstop?.()
      }
    }

    const stopTrack = vi.fn()
    const fakeStream = { getTracks: () => [{ stop: stopTrack }] } as unknown as MediaStream
    const getUserMedia = vi.fn()

    beforeEach(() => {
      stopTrack.mockClear()
      getUserMedia.mockReset().mockResolvedValue(fakeStream)
      vi.stubGlobal('MediaRecorder', FakeMediaRecorder as unknown as typeof MediaRecorder)
      Object.defineProperty(navigator, 'mediaDevices', {
        value: { getUserMedia },
        configurable: true,
      })
      Object.defineProperty(window, 'isSecureContext', { value: true, configurable: true })
    })

    afterEach(() => {
      vi.unstubAllGlobals()
    })

    it('shows a permission-denied error when the mic is blocked', async () => {
      const err = new Error('denied')
      err.name = 'NotAllowedError'
      getUserMedia.mockRejectedValue(err)

      const { default: AudioUpload } = await import('../AudioUpload')
      render(<AudioUpload />)

      await userEvent.click(screen.getByTestId('record-btn'))

      await waitFor(() => {
        expect(screen.getByTestId('upload-error')).toHaveTextContent(/blocked/)
      })
    })

    it('records, stops, confirms, and uploads the resulting file', async () => {
      mockUploadAudio.mockResolvedValue({ uploadId: 1, fileName: 'recording.webm' })

      const { default: AudioUpload } = await import('../AudioUpload')
      render(<AudioUpload />)

      await userEvent.click(screen.getByTestId('record-btn'))
      await waitFor(() => expect(screen.getByTestId('recording-panel')).toBeInTheDocument())

      await userEvent.click(screen.getByTestId('record-stop-btn'))
      await waitFor(() => expect(screen.getByTestId('recorded-panel')).toBeInTheDocument())

      await userEvent.click(screen.getByTestId('record-upload-btn'))

      await waitFor(() => {
        expect(mockUploadAudio).toHaveBeenCalledTimes(1)
      })
      const uploadedFile = mockUploadAudio.mock.calls[0][0] as File
      expect(uploadedFile.name).toMatch(/^recording-/)
    })

    it('discards the recording without uploading', async () => {
      const { default: AudioUpload } = await import('../AudioUpload')
      render(<AudioUpload />)

      await userEvent.click(screen.getByTestId('record-btn'))
      await waitFor(() => expect(screen.getByTestId('recording-panel')).toBeInTheDocument())

      await userEvent.click(screen.getByTestId('record-stop-btn'))
      await waitFor(() => expect(screen.getByTestId('recorded-panel')).toBeInTheDocument())

      await userEvent.click(screen.getByTestId('record-discard-btn'))

      expect(screen.getByTestId('drop-zone')).toBeInTheDocument()
      expect(mockUploadAudio).not.toHaveBeenCalled()
    })

    it('stops mic tracks when unmounted mid-recording', async () => {
      const { default: AudioUpload } = await import('../AudioUpload')
      const { unmount } = render(<AudioUpload />)

      await userEvent.click(screen.getByTestId('record-btn'))
      await waitFor(() => expect(screen.getByTestId('recording-panel')).toBeInTheDocument())

      unmount()

      expect(stopTrack).toHaveBeenCalled()
    })

    it('does not show the overlay or take a drop while recording', async () => {
      mockUploadAudio.mockResolvedValue({ uploadId: 1 })

      const { default: AudioUpload } = await import('../AudioUpload')
      render(<AudioUpload />)

      await userEvent.click(screen.getByTestId('record-btn'))
      await waitFor(() => expect(screen.getByTestId('recording-panel')).toBeInTheDocument())

      fireEvent.dragEnter(window, { dataTransfer: fileDataTransfer() })
      expect(screen.queryByTestId('drop-overlay')).not.toBeInTheDocument()

      const file = new File(['audio'], 'test.mp3', { type: 'audio/mpeg' })
      fireEvent.drop(window, { dataTransfer: fileDataTransfer([file]) })
      expect(mockUploadAudio).not.toHaveBeenCalled()
    })

    it('does not show the overlay or take a drop while reviewing a recording', async () => {
      mockUploadAudio.mockResolvedValue({ uploadId: 1 })

      const { default: AudioUpload } = await import('../AudioUpload')
      render(<AudioUpload />)

      await userEvent.click(screen.getByTestId('record-btn'))
      await waitFor(() => expect(screen.getByTestId('recording-panel')).toBeInTheDocument())
      await userEvent.click(screen.getByTestId('record-stop-btn'))
      await waitFor(() => expect(screen.getByTestId('recorded-panel')).toBeInTheDocument())

      fireEvent.dragEnter(window, { dataTransfer: fileDataTransfer() })
      expect(screen.queryByTestId('drop-overlay')).not.toBeInTheDocument()

      const file = new File(['audio'], 'test.mp3', { type: 'audio/mpeg' })
      fireEvent.drop(window, { dataTransfer: fileDataTransfer([file]) })
      expect(mockUploadAudio).not.toHaveBeenCalled()
    })
  })
})
