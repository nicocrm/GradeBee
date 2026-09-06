import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import type { JobPassage } from '../../api-types.gen'
import PassageReview from '../PassageReview'
import { unattributed } from '../../lib/passages'

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
