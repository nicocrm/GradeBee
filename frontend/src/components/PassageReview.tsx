import { useEffect, useState } from 'react'
import { useAuth } from '@clerk/react'
import { listStudents } from '../api'
import type { AssignPassagesRequest, AssignPassagesResponse, StudentItem } from '../api'
import type { JobPassage } from '../api-types.gen'
import { PassageGroup } from '../api-types.gen'
import { isUnattributed } from '../lib/passages'

interface PassageReviewProps {
  passages: JobPassage[]
  /**
   * The class in force on the card, whose roster the picker offers. Absent on
   * a job done before the field existed, or when nothing was pinned: the rows
   * then stay read-only. A class pick brings it with the assemble response.
   */
  classId?: number
  /** Files the body and resolves to the note link made. Rejects to show its message. */
  onAssign?: (body: AssignPassagesRequest) => Promise<AssignPassagesResponse>
}

/**
 * Lists what a done recording said that no note holds, and lets the teacher
 * assign rows to a child of the pinned class (#134): tick rows, pick a child,
 * and the pick is the confirm — one call, one note; repeat for the next
 * child. No separate button: a wrong pick is undone from the row (#138), so
 * the extra click bought nothing. Group passages on the card ride along on
 * every assignment, as they join every note the pipeline makes.
 *
 * Takes a passage array and a callback. It knows nothing about jobs, so a
 * later inbox can feed it rows from a table instead of the card.
 *
 * Selection and assigned marks are keyed on the row's position and text, not
 * its position alone: a class pick replaces the rows, and pass 2 is
 * non-deterministic, so an index into the old list would point at other
 * text. The poll brings the same rows back under the same keys, so a tick
 * survives it; a pick's new rows match nothing, so the review starts over.
 * Nothing is stored anywhere but here: a refresh ends the review, by design.
 */
export default function PassageReview({ passages, classId, onAssign }: PassageReviewProps) {
  const { getToken } = useAuth()
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [filed, setFiled] = useState<Map<string, string>>(new Map())
  // The roster remembers which class it belongs to, and counts only while
  // that is the class on the card. A class pick replaces the class (a pinned
  // card that named nobody shows the class picker and these controls
  // together), and a child of the old class sent with the new class id is a
  // 404 the teacher cannot read.
  const [roster, setRoster] = useState<{ classId: number; students: StudentItem[] } | null>(null)
  // The child an assignment is in flight to, so the select shows who while
  // it runs, and goes back to the prompt when it is done.
  const [assigning, setAssigning] = useState('')
  const [error, setError] = useState<string | null>(null)

  const canFile = classId !== undefined && onAssign !== undefined
  const students = roster !== null && roster.classId === classId ? roster.students : null
  const busy = assigning !== ''

  useEffect(() => {
    if (classId === undefined) return
    let live = true
    listStudents(classId, getToken)
      .then(({ students }) => {
        if (!live) return
        setRoster({ classId, students })
        // A roster that failed to load for the previous class said so here;
        // this one loaded, and the line must not outlive the failure.
        setError(null)
      })
      .catch((err: unknown) => {
        if (live) setError(err instanceof Error ? err.message : 'Could not load the class')
      })
    return () => { live = false }
  }, [classId, getToken])

  const rows = passages
    .map((p, i) => ({ p, key: `${i}:${p.summary}` }))
    .filter(({ p }) => isUnattributed(p))
  if (rows.length === 0) return null

  const open = rows.filter(r => !filed.has(r.key))
  const chosen = open.filter(r => selected.has(r.key))

  function toggle(key: string) {
    setSelected(prev => {
      const next = new Set(prev)
      if (next.has(key)) next.delete(key)
      else next.add(key)
      return next
    })
  }

  async function assignTo(studentId: string) {
    if (!canFile || chosen.length === 0 || studentId === '') return
    // The ticked rows in transcript order, then every group passage on the
    // card. The server orders group text last whatever order it arrives in.
    const body: AssignPassagesRequest = {
      classId,
      studentId: Number(studentId),
      passages: [
        ...chosen.map(r => ({ kind: r.p.kind, summary: r.p.summary })),
        ...passages.filter(p => p.kind === PassageGroup).map(p => ({ kind: p.kind, summary: p.summary })),
      ],
    }
    setAssigning(studentId)
    setError(null)
    try {
      const link = await onAssign(body)
      setFiled(prev => new Map([...prev, ...chosen.map(r => [r.key, link.name] as const)]))
      setSelected(new Set())
    } catch (err) {
      // The rows stay ticked: the teacher's next move is to pick again.
      setError(err instanceof Error ? err.message : 'Could not assign the passage')
    } finally {
      setAssigning('')
    }
  }

  const prompt = students === null ? 'Loading the class…'
    : chosen.length === 0 ? 'Tick a row, then pick a child'
      : chosen.length === 1 ? 'Assign this row to…'
        : `Assign ${chosen.length} rows to…`

  return (
    <div className="passage-review" data-testid="passage-review">
      <p className="passage-review-prompt">Not assigned to anyone:</p>
      <ul className="passage-review-list">
        {rows.map(({ p, key }) => {
          const to = filed.get(key)
          return (
            <li key={key} className={`passage-review-row${to ? ' passage-review-row-filed' : ''}`} data-testid="passage-review-row">
              {canFile ? (
                <label className="passage-review-pick">
                  <input
                    type="checkbox"
                    checked={selected.has(key)}
                    disabled={busy || to !== undefined}
                    onChange={() => toggle(key)}
                    data-testid="passage-review-check"
                  />
                  <span className="passage-review-text">{p.summary}</span>
                </label>
              ) : (
                <span className="passage-review-text">{p.summary}</span>
              )}
              {to && <span className="passage-review-filed" data-testid="passage-review-filed">Assigned to {to}</span>}
            </li>
          )
        })}
      </ul>
      {canFile && open.length > 0 && (
        <div className="passage-review-controls">
          <select
            className="passage-review-student"
            value={assigning}
            onChange={e => assignTo(e.target.value)}
            disabled={busy || students === null || chosen.length === 0}
            aria-label="Assign the ticked rows to"
            data-testid="passage-review-student"
          >
            <option value="">{busy ? 'Assigning…' : prompt}</option>
            {students?.map(s => (
              <option key={s.id} value={s.id}>{s.name}</option>
            ))}
          </select>
        </div>
      )}
      {error && <p className="passage-review-error" data-testid="passage-review-error">{error}</p>}
    </div>
  )
}
