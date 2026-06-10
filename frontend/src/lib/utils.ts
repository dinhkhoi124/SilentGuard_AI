/**
 * Shared confidence color utilities.
 *
 * Semantic standard (used consistently across ALL components):
 *   ≥ 80%  → blue   — AI is highly confident
 *   40–79% → amber  — AI is uncertain; operator must review carefully
 *   < 40%  → gray   — Very low confidence; likely false positive
 *
 * High confidence = reliable AI signal → blue (not red).
 * Red is reserved for danger/error states, NOT for confidence scores.
 */

export interface ConfidenceStyle {
  /** Tailwind text-* class */
  text: string
  /** Tailwind bg-* class (for progress bars) */
  bg: string
  /** Human-readable tier label */
  tier: 'Cao' | 'Trung bình' | 'Thấp'
}

export function getConfidenceStyle(value: number): ConfidenceStyle {
  if (value >= 80) return { text: 'text-blue-600',  bg: 'bg-blue-500',  tier: 'Cao' }
  if (value >= 40) return { text: 'text-amber-600', bg: 'bg-amber-400', tier: 'Trung bình' }
  return               { text: 'text-gray-400',  bg: 'bg-gray-400',  tier: 'Thấp' }
}

/**
 * Returns a full descriptive label for use in Alert Detail panel.
 * e.g. "Cao · Fight pattern rõ"
 */
export function getConfidenceLabel(value: number, eventType: string): string {
  if (value >= 80) return `Cao · ${eventType} pattern rõ`
  if (value >= 40) return 'Trung bình · Operator cần xem clip'
  return 'Thấp · Khả năng false positive cao'
}
