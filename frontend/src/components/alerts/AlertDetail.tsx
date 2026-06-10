'use client'

import React, { useState } from 'react'
import { CheckCircle, Clock, Shield, CheckSquare } from 'lucide-react'
import type { Alert, Role } from '@/lib/types'

interface AlertDetailProps {
  alert: Alert
  onConfirm: (note: string) => void
  onReject: (note: string) => void
  onEscalate: (note: string) => void
  userRole: Role
}

// ─── Timeline ────────────────────────────────────────────────────────────────

const timelineSteps = [
  'AI detect',
  'Anonymize',
  'Operator review',
  'Confirm / Reject',
  'Driver notified',
]

function getActiveStep(status: string): number {
  if (status === 'pending') return 2       // "Operator review"
  if (status === 'confirmed' || status === 'rejected') return 3  // "Confirm/Reject"
  return 4
}

function Timeline({ status }: { status: string }) {
  const activeStep = getActiveStep(status)

  return (
    <div className="w-full bg-white border border-gray-200 rounded-xl px-6 py-4 mb-6">
      <div className="flex items-center justify-between">
        {timelineSteps.map((step, idx) => {
          const isDone = idx < activeStep
          const isCurrent = idx === activeStep
          const isFuture = idx > activeStep

          return (
            <React.Fragment key={step}>
              {/* Step */}
              <div className="flex flex-col items-center gap-1 flex-shrink-0">
                <div
                  className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold border-2 transition-all ${
                    isDone
                      ? 'bg-green-500 border-green-500 text-white'
                      : isCurrent
                      ? 'bg-blue-500 border-blue-500 text-white'
                      : 'bg-gray-100 border-gray-200 text-gray-400'
                  }`}
                >
                  {isDone ? (
                    <CheckCircle size={16} />
                  ) : isCurrent ? (
                    <div className="w-2.5 h-2.5 bg-white rounded-full animate-pulse" />
                  ) : (
                    <span className="text-xs">{idx + 1}</span>
                  )}
                </div>
                <span
                  className={`text-xs text-center max-w-[70px] leading-tight ${
                    isDone
                      ? 'text-green-600 font-medium'
                      : isCurrent
                      ? 'text-blue-600 font-semibold'
                      : 'text-gray-400'
                  }`}
                >
                  {step}
                </span>
              </div>

              {/* Connector */}
              {idx < timelineSteps.length - 1 && (
                <div
                  className={`flex-1 h-0.5 mx-2 rounded ${
                    idx < activeStep ? 'bg-green-400' : 'bg-gray-200'
                  }`}
                />
              )}
            </React.Fragment>
          )
        })}
      </div>
    </div>
  )
}

// ─── Skeleton Stick Figures ───────────────────────────────────────────────────

function SkeletonFigure({ x, animation }: { x: number; animation: string }) {
  return (
    <g className={animation}>
      {/* Head */}
      <circle cx={x} cy={30} r={9} fill="none" stroke="#22d3ee" strokeWidth="2.5" />
      {/* Body */}
      <line x1={x} y1={39} x2={x} y2={75} stroke="#22d3ee" strokeWidth="2.5" strokeLinecap="round" />
      {/* Left arm */}
      <line x1={x} y1={50} x2={x - 18} y2={63} stroke="#22d3ee" strokeWidth="2.5" strokeLinecap="round" />
      {/* Right arm */}
      <line x1={x} y1={50} x2={x + 18} y2={63} stroke="#22d3ee" strokeWidth="2.5" strokeLinecap="round" />
      {/* Left leg */}
      <line x1={x} y1={75} x2={x - 14} y2={98} stroke="#22d3ee" strokeWidth="2.5" strokeLinecap="round" />
      {/* Right leg */}
      <line x1={x} y1={75} x2={x + 14} y2={98} stroke="#22d3ee" strokeWidth="2.5" strokeLinecap="round" />
    </g>
  )
}

function SkeletonVisualization({ eventType }: { eventType: string }) {
  return (
    <div className="absolute inset-0 flex flex-col items-center justify-center">
      <svg
        width="200"
        height="120"
        viewBox="0 0 200 120"
        className="overflow-visible"
      >
        <style>{`
          @keyframes sway1 { 0%,100%{transform:translateX(-3px) rotate(-5deg)} 50%{transform:translateX(3px) rotate(5deg)} }
          @keyframes sway2 { 0%,100%{transform:translateX(3px) rotate(4deg)} 50%{transform:translateX(-3px) rotate(-4deg)} }
          .anim1 { animation: sway1 2s ease-in-out infinite; transform-origin: 60px 60px; }
          .anim2 { animation: sway2 2.3s ease-in-out infinite; transform-origin: 130px 60px; }
        `}</style>

        {/* Floor line */}
        <line x1={20} y1={108} x2={180} y2={108} stroke="#374151" strokeWidth="1.5" strokeDasharray="4 3" opacity={0.4} />

        {eventType === 'Fight' ? (
          <>
            {/* Two figures facing each other, leaning in */}
            <SkeletonFigure x={62} animation="anim1" />
            <SkeletonFigure x={138} animation="anim2" />
            {/* Impact lines between them */}
            <line x1={88} y1={52} x2={112} y2={52} stroke="#ef4444" strokeWidth="1.5" strokeDasharray="3 2" opacity={0.7} />
            <line x1={90} y1={57} x2={110} y2={47} stroke="#ef4444" strokeWidth="1.5" opacity={0.5} />
          </>
        ) : (
          <>
            {/* One figure standing, one on the floor */}
            <SkeletonFigure x={70} animation="anim1" />
            {/* Fallen figure (rotated 90deg) */}
            <g transform="translate(140, 85) rotate(-85)" className="anim2">
              <circle cx={0} cy={0} r={9} fill="none" stroke="#22d3ee" strokeWidth="2.5" />
              <line x1={0} y1={9} x2={0} y2={45} stroke="#22d3ee" strokeWidth="2.5" strokeLinecap="round" />
              <line x1={0} y1={22} x2={-18} y2={32} stroke="#22d3ee" strokeWidth="2.5" strokeLinecap="round" />
              <line x1={0} y1={22} x2={18} y2={32} stroke="#22d3ee" strokeWidth="2.5" strokeLinecap="round" />
              <line x1={0} y1={45} x2={-14} y2={58} stroke="#22d3ee" strokeWidth="2.5" strokeLinecap="round" />
              <line x1={0} y1={45} x2={14} y2={58} stroke="#22d3ee" strokeWidth="2.5" strokeLinecap="round" />
            </g>
          </>
        )}

        {/* Bounding boxes */}
        <rect x={38} y={16} width={48} height={90} rx={4}
          fill="none" stroke="#22d3ee" strokeWidth="1" strokeDasharray="3 2" opacity={0.35} />
        <rect x={110} y={16} width={62} height={90} rx={4}
          fill="none" stroke="#22d3ee" strokeWidth="1" strokeDasharray="3 2" opacity={0.35} />
      </svg>

      {/* Scan line */}
      <div className="absolute inset-x-0 top-0 h-full overflow-hidden pointer-events-none rounded-lg">
        <div
          className="absolute inset-x-0 h-px bg-cyan-400/50"
          style={{ animation: 'scanline 3s linear infinite' }}
        />
      </div>
      <style>{`
        @keyframes scanline { 0%{top:5%} 100%{top:95%} }
      `}</style>
    </div>
  )
}

// ─── Confidence Label ─────────────────────────────────────────────────────────

function confidenceLabel(value: number, type: string): { text: string; color: string } {
  if (value >= 80) return { text: `Cao · ${type} pattern rõ`, color: 'text-green-600' }
  if (value >= 40) return { text: 'Trung bình · Operator cần xem clip', color: 'text-amber-600' }
  return { text: 'Thấp · Khả năng false positive cao', color: 'text-red-600' }
}

// ─── Main Component ───────────────────────────────────────────────────────────

export default function AlertDetail({
  alert,
  onConfirm,
  onReject,
  onEscalate,
  userRole,
}: AlertDetailProps) {
  const [note, setNote] = useState(alert.reviewNote ?? '')
  const canReview =
    alert.status === 'pending' && (userRole === 'admin' || userRole === 'operator')

  const conf = confidenceLabel(alert.confidence, alert.eventType)
  const mttdOk = alert.mttd <= 30

  return (
    <div className="space-y-6">
      {/* Timeline */}
      <Timeline status={alert.status} />

      {/* 2-column content */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* ── LEFT: Video Panel ── */}
        <div className="space-y-4">
          {/* Video Box */}
          <div className="relative aspect-video bg-black rounded-lg overflow-hidden">
            <SkeletonVisualization eventType={alert.eventType} />

            {/* Clip label */}
            <div className="absolute bottom-8 left-0 right-0 flex justify-center">
              <span className="text-white text-xs bg-black/60 px-3 py-1 rounded-full">
                Clip 8 giây · đã ẩn danh
              </span>
            </div>

            {/* Privacy badge */}
            <div className="absolute bottom-2 left-2">
              <span className="bg-green-500/80 text-white text-xs px-2 py-1 rounded flex items-center gap-1">
                <Shield size={11} />
                privacy layer active
              </span>
            </div>
          </div>

          {/* 2 Mini Info Cards */}
          <div className="grid grid-cols-2 gap-3">
            <div className="bg-gray-50 rounded-lg p-3">
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
                Hành động AI phát hiện
              </p>
              <p className="text-sm text-gray-800">{alert.description}</p>
            </div>
            <div className="bg-gray-50 rounded-lg p-3">
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
                Vị trí trên xe
              </p>
              <p className="text-sm text-gray-800">{alert.camera} · Khu vực giữa xe</p>
            </div>
          </div>

          {/* Privacy note */}
          <div className="flex items-start gap-2 text-xs text-gray-400">
            <CheckSquare size={13} className="mt-0.5 flex-shrink-0 text-gray-400" />
            <span>Clip gốc không được lưu. Chỉ hiển thị skeleton visualization.</span>
          </div>
        </div>

        {/* ── RIGHT: Info & Actions ── */}
        <div className="space-y-4">
          {/* Confidence */}
          <div className="bg-white border border-gray-200 rounded-xl p-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-gray-500 mb-1">
              Confidence AI
            </p>
            <p className="text-4xl font-bold text-blue-600 leading-none mb-1">
              {alert.confidence}%
            </p>
            <p className={`text-sm font-medium ${conf.color}`}>{conf.text}</p>
          </div>

          {/* Bus & Route */}
          <div className="bg-white border border-gray-200 rounded-xl p-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-gray-500 mb-2">
              Xe & Tuyến
            </p>
            <p className="font-semibold text-gray-900">{alert.busId}</p>
            <p className="text-sm text-gray-500">{alert.route} · Đang chạy</p>
          </div>

          {/* MTTD */}
          <div className="bg-white border border-gray-200 rounded-xl p-4">
            <p className="text-xs font-semibold uppercase tracking-wide text-gray-500 mb-2">
              MTTD
            </p>
            <p className="text-2xl font-bold text-gray-900 mb-1">{alert.mttd}s</p>
            {mttdOk ? (
              <p className="text-sm text-green-600 flex items-center gap-1">
                <CheckCircle size={14} />
                Trong ngưỡng &lt; 30s
              </p>
            ) : (
              <p className="text-sm text-red-500 flex items-center gap-1">
                <Clock size={14} />
                Vượt ngưỡng 30s
              </p>
            )}
          </div>

          {/* Operator Review Actions */}
          {canReview && (
            <div className="bg-white border border-gray-200 rounded-xl p-4 space-y-3">
              <p className="text-xs font-semibold uppercase tracking-wide text-gray-500">
                Quyết định Operator
              </p>

              {/* Confirm + Reject */}
              <div className="flex gap-2">
                <button
                  onClick={() => onConfirm(note)}
                  className="flex-1 py-2.5 bg-green-500 hover:bg-green-600 text-white text-sm font-semibold rounded-lg transition-colors"
                >
                  ✓ Confirm
                </button>
                <button
                  onClick={() => onReject(note)}
                  className="flex-1 py-2.5 border-2 border-red-400 hover:bg-red-50 text-red-600 text-sm font-semibold rounded-lg transition-colors"
                >
                  ✗ Reject
                </button>
              </div>

              {/* Escalate */}
              <button
                onClick={() => onEscalate(note)}
                className="w-full py-2.5 border-2 border-amber-400 hover:bg-amber-50 text-amber-600 text-sm font-semibold rounded-lg transition-colors"
              >
                ↑ Escalate
              </button>

              {/* Note */}
              <textarea
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder="Ghi chú (tùy chọn)..."
                rows={3}
                className="w-full border border-gray-200 rounded-lg p-3 text-sm text-gray-700 placeholder-gray-400 resize-none focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
          )}

          {/* Review Info (for confirmed/rejected) */}
          {alert.status !== 'pending' && (
            <div className="bg-white border border-gray-200 rounded-xl p-4">
              <p className="text-xs font-semibold uppercase tracking-wide text-gray-500 mb-3">
                Thông tin duyệt
              </p>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-500">Trạng thái</span>
                  <span
                    className={`font-semibold ${
                      alert.status === 'confirmed' ? 'text-green-600' : 'text-gray-500'
                    }`}
                  >
                    {alert.status === 'confirmed' ? '✓ Confirmed' : '✗ Rejected'}
                  </span>
                </div>
                {alert.reviewedBy && (
                  <div className="flex justify-between">
                    <span className="text-gray-500">Operator</span>
                    <span className="font-medium text-gray-700">{alert.reviewedBy}</span>
                  </div>
                )}
                {alert.reviewedAt && (
                  <div className="flex justify-between">
                    <span className="text-gray-500">Lúc</span>
                    <span className="font-medium text-gray-700">{alert.reviewedAt}</span>
                  </div>
                )}
                {alert.reviewNote && (
                  <div className="mt-2 p-2 bg-gray-50 rounded-lg">
                    <p className="text-xs text-gray-500 mb-0.5">Ghi chú</p>
                    <p className="text-gray-700">{alert.reviewNote}</p>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
