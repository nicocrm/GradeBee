import type { JobPassage } from '../api-types.gen'
import { unattributed } from '../lib/passages'

interface PassageReviewProps {
  passages: JobPassage[]
}

/**
 * Lists what a done recording said that no note holds, so the teacher can see
 * it rather than lose it. Read-only for now: filing a row to a child is #134.
 *
 * Takes a passage array and nothing else. It knows nothing about jobs, so a
 * later inbox can feed it rows from a table instead of the card.
 */
export default function PassageReview({ passages }: PassageReviewProps) {
  const rows = unattributed(passages)
  if (rows.length === 0) return null

  return (
    <div className="passage-review" data-testid="passage-review">
      <p className="passage-review-prompt">Not filed to anyone:</p>
      <ul className="passage-review-list">
        {rows.map((p, i) => (
          <li key={i} className="passage-review-row" data-testid="passage-review-row">
            {p.summary}
          </li>
        ))}
      </ul>
    </div>
  )
}
