"""
calibrate_thresholds.py — Công cụ đo ngưỡng từ video thật
===========================================================
Chạy với video file hoặc camera live, xuất CSV và summary
để hiệu chỉnh các ngưỡng hiện đang là giả định lý thuyết.

Ngưỡng cần hiệu chỉnh:
  REQ-BACKLOG-001: motion_mask_ratio (hiện 0.3)
  REQ-BACKLOG-002: frozen_timeout (hiện 5.0s),
                   FROZEN_MEAN_THRESHOLD (1.0),
                   FROZEN_STD_THRESHOLD (0.5)
  REQ-023 (chưa impl): occlusion_cooldown, disappear_timeout

Cách dùng:
  python calibrate_thresholds.py --source VIDEO_FILE_OR_CAMERA_INDEX
  python calibrate_thresholds.py --source 0                 # webcam
  python calibrate_thresholds.py --source clip_nga.mp4     # video file
  python calibrate_thresholds.py --source rtsp://...       # IP cam

Output:
  calibration_log_YYYYMMDD_HHMMSS.csv  — log từng frame
  calibration_summary_YYYYMMDD_HHMMSS.txt — thống kê tổng hợp
"""

import cv2
import numpy as np
import argparse
import csv
import time
import sys
import os
from datetime import datetime
from pathlib import Path

# ───────────────────────────────────────────────────────────────
# ANSI colors (tắt trên Windows nếu cần)
# ───────────────────────────────────────────────────────────────
try:
    import colorama
    colorama.init()
    GREEN  = "\033[92m"
    YELLOW = "\033[93m"
    RED    = "\033[91m"
    CYAN   = "\033[96m"
    RESET  = "\033[0m"
except ImportError:
    GREEN = YELLOW = RED = CYAN = RESET = ""


# ───────────────────────────────────────────────────────────────
# THRESHOLDS ĐANG LÀ GIẢ ĐỊNH — giá trị để so sánh với dữ liệu thật
# ───────────────────────────────────────────────────────────────
ASSUMED = {
    "motion_mask_ratio":    0.30,   # REQ-BACKLOG-001
    "frozen_timeout_sec":   5.0,    # REQ-BACKLOG-002
    "frozen_mean_thresh":   1.0,    # REQ-BACKLOG-002
    "frozen_std_thresh":    0.5,    # REQ-BACKLOG-002
    "motion_pixel_thresh":  500,    # main loop motion detection
    "motion_absdiff_gate":  25,     # cv2.threshold level
}


def parse_args():
    p = argparse.ArgumentParser(description="SilentGuard Threshold Calibration Tool")
    p.add_argument("--source", default="0",
                   help="Video source: file path, camera index (0), or RTSP URL")
    p.add_argument("--mask-ratio", type=float, default=ASSUMED["motion_mask_ratio"],
                   help=f"Motion mask ratio to test (default: {ASSUMED['motion_mask_ratio']})")
    p.add_argument("--epsilon", type=float, default=0.05,
                   help="Epsilon threshold for true frozen detection (default: 0.05)")
    p.add_argument("--duration", type=int, default=0,
                   help="Max seconds to run (0 = unlimited, press Q to stop)")
    p.add_argument("--output-dir", default=".",
                   help="Directory to save calibration logs")
    p.add_argument("--no-display", action="store_true",
                   help="Run headless (no cv2.imshow), useful for remote sessions")
    return p.parse_args()


def open_source(source: str):
    """Mở video source, thử convert sang int nếu là camera index."""
    try:
        idx = int(source)
        cap = cv2.VideoCapture(idx)
    except ValueError:
        cap = cv2.VideoCapture(source)
    if not cap.isOpened():
        print(f"{RED}[ERROR] Không mở được source: {source}{RESET}")
        sys.exit(1)
    return cap


def setup_csv(output_dir: str, timestamp: str):
    """Tạo CSV writer và trả về (file_handle, writer, filepath)."""
    filepath = os.path.join(output_dir, f"calibration_log_{timestamp}.csv")
    f = open(filepath, "w", newline="", encoding="utf-8")
    writer = csv.writer(f)
    writer.writerow([
        "frame", "wall_time", "elapsed_sec",
        # --- STREAM FROZEN metrics ---
        "mean_diff_full", "std_diff_full",
        "mean_diff_masked_bottom70", "std_diff_masked_bottom70",
        "is_frozen_single_gate",      # mean < 1.0 only
        "is_frozen_dual_gate",        # mean < 1.0 AND std < 0.5
        # --- MOTION metrics ---
        "motion_score_full",          # entire frame
        "motion_score_masked",        # bottom (1-mask_ratio) of frame
        "motion_score_top_only",      # top mask_ratio (noise source)
        "motion_detected_full",
        "motion_detected_masked",
        # --- FRAME INFO ---
        "frame_h", "frame_w",
        "mask_y_start",
    ])
    return f, writer, filepath


def main():
    args = parse_args()
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # Validate output dir
    os.makedirs(args.output_dir, exist_ok=True)

    cap = open_source(args.source)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    is_file = total_frames > 0

    print(f"\n{CYAN}{'='*60}")
    print(f"  SilentGuard Calibration Tool")
    print(f"{'='*60}{RESET}")
    print(f"  Source      : {args.source}")
    print(f"  FPS         : {fps:.1f}")
    print(f"  Total frames: {total_frames if is_file else 'live'}")
    print(f"  Mask ratio  : {args.mask_ratio} (top {int(args.mask_ratio*100)}% ignored)")
    print(f"  Output dir  : {args.output_dir}")
    print(f"  Press Q to stop\n")

    print(f"{YELLOW}Assumed thresholds being tested:{RESET}")
    for k, v in ASSUMED.items():
        print(f"  {k:30s} = {v}")
    print()

    csv_f, csv_writer, csv_path = setup_csv(args.output_dir, timestamp)

    # State
    prev_small_gray = None
    prev_masked_gray = None
    frame_count = 0
    start_wall = time.time()

    # Accumulators for summary
    acc_mean_diff    = []
    acc_std_diff     = []
    acc_motion_full  = []
    acc_motion_masked= []
    acc_motion_top   = []
    frozen_single_hits = 0
    frozen_dual_hits   = 0
    max_mean_diff    = 0.0
    max_std_diff     = 0.0

    current_consecutive_epsilon_frames = 0
    max_consecutive_epsilon_frames = 0
    epsilon_start_time = None
    max_consecutive_epsilon_duration = 0.0

    try:
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            frame_count += 1
            wall_now = time.time()
            elapsed  = wall_now - start_wall

            if args.duration > 0 and elapsed > args.duration:
                break

            h, w = frame.shape[:2]
            mask_y_start = int(h * args.mask_ratio)

            gray_full = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            gray_blurred = cv2.GaussianBlur(gray_full, (21, 21), 0)

            # Resize nhỏ cho frozen detection (như production)
            small = cv2.resize(gray_blurred, (64, 64))

            # ── STREAM FROZEN metrics ──────────────────────────────
            mean_diff_full   = 0.0
            std_diff_full    = 0.0
            mean_diff_masked = 0.0
            std_diff_masked  = 0.0

            if prev_small_gray is not None:
                diff_full = cv2.absdiff(small, prev_small_gray)
                mean_diff_full = float(np.mean(diff_full))
                std_diff_full  = float(np.std(diff_full))

                # Masked version (bottom 70%)
                mask_start_64 = int(64 * args.mask_ratio)
                diff_masked = diff_full[mask_start_64:, :]
                mean_diff_masked = float(np.mean(diff_masked))
                std_diff_masked  = float(np.std(diff_masked))

                max_mean_diff = max(max_mean_diff, mean_diff_full)
                max_std_diff  = max(max_std_diff, std_diff_full)

            acc_mean_diff.append(mean_diff_full)
            acc_std_diff.append(std_diff_full)

            is_frozen_single = mean_diff_full < ASSUMED["frozen_mean_thresh"]
            is_frozen_dual   = (mean_diff_full < ASSUMED["frozen_mean_thresh"] and
                                std_diff_full  < ASSUMED["frozen_std_thresh"])
            if is_frozen_single: frozen_single_hits += 1
            if is_frozen_dual:   frozen_dual_hits   += 1

            is_epsilon_frozen = (mean_diff_full < args.epsilon) and (std_diff_full < args.epsilon)
            if is_epsilon_frozen:
                current_consecutive_epsilon_frames += 1
                if epsilon_start_time is None:
                    epsilon_start_time = wall_now
                current_duration = wall_now - epsilon_start_time
                if current_consecutive_epsilon_frames > max_consecutive_epsilon_frames:
                    max_consecutive_epsilon_frames = current_consecutive_epsilon_frames
                if current_duration > max_consecutive_epsilon_duration:
                    max_consecutive_epsilon_duration = current_duration
            else:
                current_consecutive_epsilon_frames = 0
                epsilon_start_time = None

            prev_small_gray = small

            # ── MOTION metrics ─────────────────────────────────────
            motion_score_full   = 0
            motion_score_masked = 0
            motion_score_top    = 0

            if prev_masked_gray is not None:
                delta_full   = cv2.absdiff(prev_masked_gray, gray_blurred)
                thr_full     = cv2.threshold(delta_full, ASSUMED["motion_absdiff_gate"],
                                             255, cv2.THRESH_BINARY)[1]
                motion_score_full   = cv2.countNonZero(thr_full)
                motion_score_masked = cv2.countNonZero(thr_full[mask_y_start:, :])
                motion_score_top    = cv2.countNonZero(thr_full[:mask_y_start, :])

            acc_motion_full.append(motion_score_full)
            acc_motion_masked.append(motion_score_masked)
            acc_motion_top.append(motion_score_top)

            mot_detected_full   = motion_score_full   > ASSUMED["motion_pixel_thresh"]
            mot_detected_masked = motion_score_masked > ASSUMED["motion_pixel_thresh"]

            prev_masked_gray = gray_blurred.copy()

            # ── CSV row ────────────────────────────────────────────
            csv_writer.writerow([
                frame_count, f"{wall_now:.3f}", f"{elapsed:.3f}",
                f"{mean_diff_full:.4f}", f"{std_diff_full:.4f}",
                f"{mean_diff_masked:.4f}", f"{std_diff_masked:.4f}",
                int(is_frozen_single), int(is_frozen_dual),
                motion_score_full, motion_score_masked, motion_score_top,
                int(mot_detected_full), int(mot_detected_masked),
                h, w, mask_y_start,
            ])

            # ── Live HUD (nếu hiển thị) ────────────────────────────
            if not args.no_display:
                hud = frame.copy()
                # Vẽ mask line
                cv2.line(hud, (0, mask_y_start), (w, mask_y_start), (0, 255, 255), 1)
                cv2.putText(hud, f"MASK {int(args.mask_ratio*100)}%",
                            (5, mask_y_start - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 255, 255), 1)

                # Frozen indicators
                frozen_color = (0, 0, 255) if is_frozen_dual else (0, 255, 0)
                cv2.putText(hud, f"mean_diff={mean_diff_full:.2f}  std={std_diff_full:.2f}",
                            (5, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.45, frozen_color, 1)
                cv2.putText(hud, f"frozen_single={is_frozen_single}  dual={is_frozen_dual}",
                            (5, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.45, frozen_color, 1)

                # Motion indicators
                mot_color = (0, 255, 0) if mot_detected_masked else (128, 128, 128)
                cv2.putText(hud, f"motion_masked={motion_score_masked}  full={motion_score_full}",
                            (5, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.45, mot_color, 1)
                cv2.putText(hud, f"motion_top_noise={motion_score_top}",
                            (5, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 128, 0), 1)

                cv2.putText(hud, f"frame={frame_count}  t={elapsed:.1f}s",
                            (5, h - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (200, 200, 200), 1)

                cv2.imshow("Calibration — press Q to stop", hud)
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break

            # Console progress every 5s
            if frame_count % int(fps * 5) == 0:
                pct = (frame_count / total_frames * 100) if is_file and total_frames > 0 else 0
                pct_str = f"{pct:.0f}%" if is_file else "live"
                print(f"  [{pct_str}] frame={frame_count} t={elapsed:.0f}s "
                      f"| mean={mean_diff_full:.3f} std={std_diff_full:.3f} "
                      f"| motion_masked={motion_score_masked}")

    finally:
        cap.release()
        if not args.no_display:
            cv2.destroyAllWindows()
        csv_f.close()

    # ── SUMMARY ───────────────────────────────────────────────
    total = max(len(acc_mean_diff), 1)

    def pct(n): return n / total * 100

    summary_lines = [
        "=" * 60,
        f"CALIBRATION SUMMARY — {timestamp}",
        f"Source: {args.source}",
        f"Frames analyzed: {frame_count}",
        f"Duration: {elapsed:.1f}s",
        "=" * 60,
        "",
        "── STREAM FROZEN (mean + std của diff 64×64) ──",
        f"  mean_diff:  min={min(acc_mean_diff):.4f}  max={max(acc_mean_diff):.4f}  "
        f"median={float(np.median(acc_mean_diff)):.4f}  "
        f"p95={float(np.percentile(acc_mean_diff, 95)):.4f}",
        f"  std_diff:   min={min(acc_std_diff):.4f}  max={max(acc_std_diff):.4f}  "
        f"median={float(np.median(acc_std_diff)):.4f}  "
        f"p95={float(np.percentile(acc_std_diff, 95)):.4f}",
        "",
        f"  [ASSUMED] frozen_mean_thresh = {ASSUMED['frozen_mean_thresh']}",
        f"  [ASSUMED] frozen_std_thresh  = {ASSUMED['frozen_std_thresh']}",
        f"  Frames where single-gate fires: {frozen_single_hits} ({pct(frozen_single_hits):.1f}%)",
        f"  Frames where dual-gate fires:   {frozen_dual_hits} ({pct(frozen_dual_hits):.1f}%)",
        f"  → Gap (single-only false positives): "
        f"{frozen_single_hits - frozen_dual_hits} ({pct(frozen_single_hits - frozen_dual_hits):.1f}%)",
        "",
        "── MOTION DETECTION ──",
        f"  motion_score_full:   median={float(np.median(acc_motion_full)):.0f}  "
        f"p95={float(np.percentile(acc_motion_full, 95)):.0f}",
        f"  motion_score_masked: median={float(np.median(acc_motion_masked)):.0f}  "
        f"p95={float(np.percentile(acc_motion_masked, 95)):.0f}",
        f"  motion_score_top:    median={float(np.median(acc_motion_top)):.0f}  "
        f"p95={float(np.percentile(acc_motion_top, 95)):.0f}",
        f"  [ASSUMED] motion_pixel_thresh = {ASSUMED['motion_pixel_thresh']}",
        f"  [ASSUMED] motion_mask_ratio   = {args.mask_ratio}",
        f"  Frames w/ motion (full):   {sum(1 for x in acc_motion_full if x > ASSUMED['motion_pixel_thresh'])} "
        f"({pct(sum(1 for x in acc_motion_full if x > ASSUMED['motion_pixel_thresh'])):.1f}%)",
        f"  Frames w/ motion (masked): {sum(1 for x in acc_motion_masked if x > ASSUMED['motion_pixel_thresh'])} "
        f"({pct(sum(1 for x in acc_motion_masked if x > ASSUMED['motion_pixel_thresh'])):.1f}%)",
        "",
        "── HIỆU CHỈNH ĐỀ XUẤT ──",
        f"  Dữ liệu thực nghiệm (epsilon={args.epsilon}):",
        f"  → Chuỗi tĩnh tuyệt đối dài nhất: {max_consecutive_epsilon_frames} frames ({max_consecutive_epsilon_duration:.2f} giây)",
        "",
        "  Nhìn vào phân bố ở đuôi thấp nhất (min) của mean_diff và std_diff, KHÔNG dùng p95.",
        "  → Đặt FROZEN_MEAN_THRESHOLD = epsilon (ví dụ 0.05 hoặc min quan sát được)",
        "  → Đặt FROZEN_STD_THRESHOLD = epsilon (ví dụ 0.05 hoặc min quan sát được)",
        "  → Đặt frozen_timeout = max_consecutive_epsilon_duration + buffer (vd: +2.0s)",
        "",
        "  Nhìn vào motion_score_top (nhiễu bóng cây/quạt):",
        "  → Nếu motion_score_top > motion_pixel_thresh thường xuyên → tăng mask_ratio",
        "",
        f"CSV log: {csv_path}",
        "=" * 60,
    ]

    summary_text = "\n".join(summary_lines)
    print("\n" + summary_text)

    summary_path = os.path.join(args.output_dir, f"calibration_summary_{timestamp}.txt")
    with open(summary_path, "w", encoding="utf-8") as sf:
        sf.write(summary_text)
    print(f"\n{GREEN}Summary saved: {summary_path}{RESET}")
    print(f"{GREEN}CSV log saved: {csv_path}{RESET}\n")


if __name__ == "__main__":
    main()
