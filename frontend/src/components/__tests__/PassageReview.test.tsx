import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import type { JobPassage } from '../../api-types.gen'
import type { AssignPassagesRequest, AssignPassagesResponse } from '../../api'
import PassageReview from '../PassageReview'
import { unattributed } from '../../lib/passages'

const mockListStudents = vi.fn()
vi.mock('../../api', () => ({
  listStudents: (...args: unknown[]) => mockListStudents(...args),
}))

const mockGetToken = vi.fn()
vi.mock('@clerk/react', () => ({
  useAuth: () => ({ getToken: mockGetToken }),
}))

beforeEach(() => {
  vi.clearAllMocks()
  mockGetToken.mockResolvedValue('tok')
  mockListStudents.mockResolvedValue({ students: [
    { id: 21, classId: 3, name: 'Lévy', createdAt: '', aliases: [] },
    { id: 22, classId: 3, name: 'Eleonore', createdAt: '', aliases: [] },
  ] })
})

// Note 694's shape (#131): the spoken header comes back `none`, two blocks
// name nobody, and Lévy resolves. Two rows to show; the rest is filed or
// dropped. `none` is on the fixture even though assembly never puts one on
// the wire — a row for a header would be a bug worth pinning against.
const note694: JobPassage[] = [
  { kind: 'none', summary: 'Tuesday, period one.' },
  { kind: 'unknown', summary: 'She was helping the younger ones with their blocks.' },
  { kind: 'unknown', summary: "Polly wasn't speaking much today." },
  { kind: 'child', spokenLabels: ['Lévy'], student: 'Lévy', summary: 'Lévy finished the puzzle alone.' },
]

describe('unattributed', () => {
  it('keeps the passages that reached nobody, in order', () => {
    expect(unattributed(note694).map(p => p.summary)).toEqual([
      'She was helping the younger ones with their blocks.',
      "Polly wasn't speaking much today.",
    ])
  })

  // A child passage whose student the pipeline could not pin is as lost as an
  // unknown one, and reads the same to the teacher.
  it('counts a child passage with no student', () => {
    const rows = unattributed([{ kind: 'child', spokenLabels: ['Sam'], summary: 'Sam shared.' }])
    expect(rows).toHaveLength(1)
  })

  // A class-wide remark joins every note this recording made; it is not
  // something to file to one child.
  it('never lists a group passage', () => {
    expect(unattributed([{ kind: 'group', summary: 'Everyone worked hard.' }])).toEqual([])
  })
})

describe('PassageReview', () => {
  it('shows one row per passage that reached nobody', () => {
    render(<PassageReview passages={note694} />)
    const rows = screen.getAllByTestId('passage-review-row')
    expect(rows.map(r => r.textContent)).toEqual([
      'She was helping the younger ones with their blocks.',
      "Polly wasn't speaking much today.",
    ])
    expect(screen.queryByText(/Lévy/)).not.toBeInTheDocument()
    expect(screen.queryByText('Tuesday, period one.')).not.toBeInTheDocument()
  })

  it('renders nothing when every passage reached somebody', () => {
    const { container } = render(
      <PassageReview passages={[
        { kind: 'child', student: 'Alice', summary: 'Alice did great.' },
        { kind: 'group', summary: 'Everyone worked hard.' },
      ]} />,
    )
    expect(container).toBeEmptyDOMElement()
  })

  it('renders nothing for an empty array', () => {
    const { container } = render(<PassageReview passages={[]} />)
    expect(container).toBeEmptyDOMElement()
  })
})

// Filing rows to a child (#134). The component knows nothing about jobs: it
// gets rows, a class id and a callback, and the callback gets a body.
describe('PassageReview filing', () => {
  // The recording's class-wide remark, on the card but never a row: it rides
  // along on every assignment, as it joins every note the pipeline makes.
  const withGroup: JobPassage[] = [...note694, { kind: 'group', summary: 'Everyone worked hard.' }]
  const filed: AssignPassagesResponse = { noteId: 60, studentId: 22, name: 'Eleonore', className: 'Tuesday', appended: false }

  // A job done before the field existed, or nothing pinned: nothing to file
  // to, so the rows are read-only and no roster is fetched.
  it('shows no controls without a class', () => {
    render(<PassageReview passages={note694} onAssign={vi.fn()} />)
    expect(screen.getAllByTestId('passage-review-row')).toHaveLength(2)
    expect(screen.queryByTestId('passage-review-check')).not.toBeInTheDocument()
    expect(screen.queryByTestId('passage-review-student')).not.toBeInTheDocument()
    expect(mockListStudents).not.toHaveBeenCalled()
  })

  // The pick is the confirm: choosing a child sends the ticked rows at once.
  it('lists the pinned class, and assigns the ticked rows plus the group passage on the pick', async () => {
    const user = userEvent.setup()
    const onAssign = vi.fn().mockResolvedValue(filed)
    render(<PassageReview passages={withGroup} classId={3} onAssign={onAssign} />)

    await waitFor(() => {
      expect(screen.getByRole('option', { name: 'Eleonore' })).toBeInTheDocument()
    })
    expect(mockListStudents).toHaveBeenCalledWith(3, expect.anything())

    const picker = screen.getByTestId('passage-review-student')
    expect(picker).toBeDisabled()

    await user.click(screen.getAllByTestId('passage-review-check')[0])
    expect(picker).toBeEnabled()
    await user.selectOptions(picker, '22')

    expect(onAssign).toHaveBeenCalledWith({
      classId: 3,
      studentId: 22,
      passages: [
        { kind: 'unknown', summary: 'She was helping the younger ones with their blocks.' },
        { kind: 'group', summary: 'Everyone worked hard.' },
      ],
    } satisfies AssignPassagesRequest)

    // The filed row is marked and can no longer be ticked; the other stays open.
    await waitFor(() => {
      expect(screen.getByTestId('passage-review-filed')).toHaveTextContent('Assigned to Eleonore')
    })
    const checks = screen.getAllByTestId('passage-review-check')
    expect(checks[0]).toBeDisabled()
    expect(checks[1]).toBeEnabled()
    expect(checks[1]).not.toBeChecked()
  })

  // Two ticked rows go in transcript order whatever order they were ticked
  // in, and both are marked filed to the same child.
  it('files several rows as one call, in transcript order', async () => {
    const user = userEvent.setup()
    const onAssign = vi.fn().mockResolvedValue(filed)
    render(<PassageReview passages={note694} classId={3} onAssign={onAssign} />)
    await waitFor(() => expect(screen.getByRole('option', { name: 'Eleonore' })).toBeInTheDocument())

    const checks = screen.getAllByTestId('passage-review-check')
    await user.click(checks[1])
    await user.click(checks[0])
    await user.selectOptions(screen.getByTestId('passage-review-student'), '22')

    expect(onAssign.mock.calls[0][0].passages.map((p: { summary: string }) => p.summary)).toEqual([
      'She was helping the younger ones with their blocks.',
      "Polly wasn't speaking much today.",
    ])
    await waitFor(() => expect(screen.getAllByTestId('passage-review-filed')).toHaveLength(2))
    // Every row assigned: nothing left to pick, so the picker goes.
    expect(screen.queryByTestId('passage-review-student')).not.toBeInTheDocument()
  })

  // A failed call leaves the row ticked and says why; the teacher tries again.
  it('keeps a failed row selectable and shows the error', async () => {
    const user = userEvent.setup()
    const onAssign = vi.fn().mockRejectedValue(new Error('Already filing this recording, try again.'))
    render(<PassageReview passages={note694} classId={3} onAssign={onAssign} />)
    await waitFor(() => expect(screen.getByRole('option', { name: 'Eleonore' })).toBeInTheDocument())

    await user.click(screen.getAllByTestId('passage-review-check')[0])
    await user.selectOptions(screen.getByTestId('passage-review-student'), '22')

    await waitFor(() => {
      expect(screen.getByTestId('passage-review-error')).toHaveTextContent('Already filing this recording, try again.')
    })
    expect(screen.queryByTestId('passage-review-filed')).not.toBeInTheDocument()
    expect(screen.getAllByTestId('passage-review-check')[0]).toBeChecked()
    expect(screen.getAllByTestId('passage-review-check')[0]).toBeEnabled()
    // The picker is back on its prompt, ready for the next pick.
    expect(screen.getByTestId('passage-review-student')).toBeEnabled()
    expect(screen.getByTestId('passage-review-student')).toHaveValue('')
  })

  // A pinned card that named nobody shows the class picker and these controls
  // together. Picking another class must swap the roster: a child of the old
  // class sent with the new class id is a 404.
  it('swaps the roster when the class changes', async () => {
    const user = userEvent.setup()
    mockListStudents.mockImplementation(async (classId: number) => ({
      students: classId === 3
        ? [{ id: 22, classId: 3, name: 'Eleonore', createdAt: '', aliases: [] }]
        : [{ id: 31, classId: 4, name: 'Ombeline', createdAt: '', aliases: [] }],
    }))
    const { rerender } = render(<PassageReview passages={note694} classId={3} onAssign={vi.fn()} />)
    await waitFor(() => expect(screen.getByRole('option', { name: 'Eleonore' })).toBeInTheDocument())
    await user.click(screen.getAllByTestId('passage-review-check')[0])
    expect(screen.getByTestId('passage-review-student')).toBeEnabled()

    rerender(<PassageReview passages={note694} classId={4} onAssign={vi.fn()} />)
    expect(screen.queryByRole('option', { name: 'Eleonore' })).not.toBeInTheDocument()
    // Nothing to pick from until the new roster lands, tick or no tick.
    expect(screen.getByTestId('passage-review-student')).toBeDisabled()
    await waitFor(() => expect(screen.getByRole('option', { name: 'Ombeline' })).toBeInTheDocument())
    expect(screen.getByTestId('passage-review-student')).toBeEnabled()
    expect(mockListStudents).toHaveBeenLastCalledWith(4, expect.anything())
  })

  // A class pick replaces the rows, and pass 2 is non-deterministic: a tick
  // on the old list must not carry over to whatever text sits at that index
  // now. The same rows coming back from the poll keep their ticks.
  it('starts over when the rows change, and keeps its ticks when they do not', async () => {
    const user = userEvent.setup()
    const { rerender } = render(<PassageReview passages={note694} classId={3} onAssign={vi.fn()} />)
    await waitFor(() => expect(screen.getByRole('option', { name: 'Eleonore' })).toBeInTheDocument())
    await user.click(screen.getAllByTestId('passage-review-check')[0])

    rerender(<PassageReview passages={[...note694]} classId={3} onAssign={vi.fn()} />)
    expect(screen.getAllByTestId('passage-review-check')[0]).toBeChecked()

    rerender(<PassageReview passages={[
      { kind: 'unknown', summary: 'Someone tidied up without being asked.' },
      { kind: 'unknown', summary: "Polly wasn't speaking much today." },
    ]} classId={3} onAssign={vi.fn()} />)
    for (const check of screen.getAllByTestId('passage-review-check')) {
      expect(check).not.toBeChecked()
    }
  })
})
