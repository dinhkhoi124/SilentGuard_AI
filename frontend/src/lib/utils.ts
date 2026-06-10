/**
 * Shared confidence color utilities — single source of truth for ALL components.
 *
 * Semantic tiers:
 *
 *   ≥ 80%  (Cao)         → blue   — AI is reliably confident; treat as a real event
 *   40–79% (Trung bình)  → amber  — AI is uncertain; operator MUST review the clip
 *   < 40%  (Thấp)        → red    — Very low confidence; high false-positive risk
 *                                   Red is appropriate here because low AI confidence
 *                                   IS a warning state: the operator should dismiss
 *                                   carefully and the alert may be noise.
 *
 * Note: red is NOT used for high confidence (≥80%). High confidence is informational
 * (blue), not alarming on its own — the event type badges carry the urgency signal.
 */

export interface ConfidenceStyle {
  /** Tailwind text-* class */
  text: string;
  /** Tailwind bg-* class (for progress bars) */
  bg: string;
  /** Human-readable tier label */
  tier: "Cao" | "Trung bình" | "Thấp";
}

export function getConfidenceStyle(value: number): ConfidenceStyle {
  if (value >= 80)
    return { text: "text-blue-600", bg: "bg-blue-500", tier: "Cao" };
  if (value >= 40)
    return { text: "text-amber-600", bg: "bg-amber-400", tier: "Trung bình" };
  return { text: "text-red-500", bg: "bg-red-400", tier: "Thấp" };
}

/**
 * Full descriptive label for the Alert Detail panel.
 * Color comes from getConfidenceStyle — call both together, never separately.
 * e.g. "Cao · Fight pattern rõ"
 */
export function getConfidenceLabel(value: number, eventType: string): string {
  if (value >= 80) return `Cao · ${eventType} pattern rõ`;
  if (value >= 40) return "Trung bình · Operator cần xem clip";
  return "Thấp · Khả năng false positive cao";
}
