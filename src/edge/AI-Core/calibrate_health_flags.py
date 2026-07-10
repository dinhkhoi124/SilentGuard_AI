"""
calibrate_health_flags.py — Công cụ hiệu chỉnh cho LENS_DEGRADED và CAMERA_SHIFTED
=============================================================================
Chạy với video file hoặc camera live, đo lường:
1. LENS_DEGRADED: Laplacian variance (đo lường độ nét/mờ toàn cục).
2. CAMERA_SHIFTED: Optical flow median shift (đo độ lệch pixel trung vị) 
   và tracked_points_count (số lượng feature track được).

Cách dùng:
  python calibrate_health_flags.py --source 0
"""

import cv2
import numpy as np
import argparse
import csv
import time
import sys
import os
from datetime import datetime

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

def parse_args():
    p = argparse.ArgumentParser(description="Health Flags Calibration Tool")
    p.add_argument("--source", default="0", help="Video source: file path or camera index")
    p.add_argument("--output-dir", default=".", help="Directory to save calibration logs")
    p.add_argument("--no-display", action="store_true", help="Run headless")
    return p.parse_args()

def main():
    args = parse_args()
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    os.makedirs(args.output_dir, exist_ok=True)

    try:
        idx = int(args.source)
        cap = cv2.VideoCapture(idx)
    except ValueError:
        cap = cv2.VideoCapture(args.source)
        
    if not cap.isOpened():
        print(f"{RED}[ERROR] Không mở được source: {args.source}{RESET}")
        sys.exit(1)

    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    
    csv_path = os.path.join(args.output_dir, f"health_calibration_log_{timestamp}.csv")
    csv_f = open(csv_path, "w", newline="", encoding="utf-8")
    writer = csv.writer(csv_f)
    writer.writerow([
        "frame", "elapsed_sec",
        "laplacian_var", "tracked_points_count", "median_shift"
    ])

    print(f"\n{CYAN}={'='*60}")
    print(f"  Health Flags Calibration Tool")
    print(f"{'='*60}{RESET}")
    print(f"  Source : {args.source}")
    print(f"  FPS    : {fps:.1f}")
    print(f"  Press Q to stop\n")

    frame_count = 0
    start_wall = time.time()
    
    acc_laplacian = []
    acc_shift = []
    acc_features = []

    baseline_gray = None
    baseline_features = None
    last_shift_check_time = 0

    try:
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            frame_count += 1
            wall_now = time.time()
            elapsed  = wall_now - start_wall
            
            gray_full = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            
            # --- 1. LENS_DEGRADED ---
            laplacian_var = cv2.Laplacian(gray_full, cv2.CV_64F).var()
            acc_laplacian.append(laplacian_var)

            # --- 2. CAMERA_SHIFTED ---
            median_shift = 0.0
            tracked_points_count = 0
            
            # Update optical flow base features explicitly every 2 seconds to match ver9.py logic
            if baseline_features is None or baseline_gray is None or (wall_now - last_shift_check_time > 2.0):
                last_shift_check_time = wall_now
                baseline_gray = gray_full.copy()
                baseline_features = cv2.goodFeaturesToTrack(
                    baseline_gray, maxCorners=100, qualityLevel=0.3,
                    minDistance=7, blockSize=7
                )
                if baseline_features is not None:
                    tracked_points_count = len(baseline_features)
            else:
                if baseline_features is not None and len(baseline_features) > 0:
                    p1, st, err = cv2.calcOpticalFlowPyrLK(
                        baseline_gray, gray_full, baseline_features, None
                    )
                    if p1 is not None and st is not None:
                        good_new = p1[st == 1]
                        good_old = baseline_features[st == 1]
                        tracked_points_count = len(good_new)
                        
                        if tracked_points_count > 10:
                            distances = np.linalg.norm(good_new - good_old, axis=1)
                            median_shift = float(np.median(distances))
                        else:
                            # Too few points (occlusion/massive blur) -> ignore shift calculation
                            median_shift = 0.0
            
            acc_shift.append(median_shift)
            acc_features.append(tracked_points_count)

            writer.writerow([
                frame_count, f"{elapsed:.3f}",
                f"{laplacian_var:.2f}", tracked_points_count, f"{median_shift:.2f}"
            ])

            if not args.no_display:
                hud = frame.copy()
                # Status texts
                cv2.putText(hud, f"Laplacian Var: {laplacian_var:.1f}", (10, 30), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
                cv2.putText(hud, f"Tracked Pts  : {tracked_points_count}", (10, 60), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
                cv2.putText(hud, f"Median Shift : {median_shift:.1f} px", (10, 90), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                cv2.putText(hud, f"T = {elapsed:.1f}s", (10, hud.shape[0] - 20), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (200, 200, 200), 1)

                # Draw points
                if 'good_new' in locals() and len(good_new) > 0:
                    for pt in good_new:
                        a, b = pt.ravel()
                        cv2.circle(hud, (int(a), int(b)), 3, (0, 255, 0), -1)

                cv2.imshow("Health Flags Calibration", hud)
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break

            if frame_count % int(fps * 2) == 0:
                print(f"  [T={elapsed:.1f}s] Laplacian={laplacian_var:.0f} | Pts={tracked_points_count} | Shift={median_shift:.1f}px")

    finally:
        cap.release()
        if not args.no_display:
            cv2.destroyAllWindows()
        csv_f.close()

    total = max(len(acc_laplacian), 1)
    
    # Calculate summaries
    lap_arr = np.array(acc_laplacian)
    shift_arr = np.array(acc_shift)
    feat_arr = np.array(acc_features)
    
    summary_text = f"""
{'='*60}
CALIBRATION SUMMARY — {timestamp}
Source: {args.source} | Frames: {frame_count} | Duration: {elapsed:.1f}s
{'='*60}

── LENS_DEGRADED (Laplacian Variance) ──
  Min    = {np.min(lap_arr):.1f}
  Median = {np.median(lap_arr):.1f}
  P05    = {np.percentile(lap_arr, 5):.1f}  (Giá trị đuôi thấp, cực kỳ quan trọng cho threshold)
  Max    = {np.max(lap_arr):.1f}

── CAMERA_SHIFTED (Optical Flow Median Shift & Feature Count) ──
  Median Shift  : Max = {np.max(shift_arr):.1f} px, Median = {np.median(shift_arr):.1f} px, P95 = {np.percentile(shift_arr, 95):.1f} px
  Tracked Pts   : Min = {np.min(feat_arr):.0f}, Median = {np.median(feat_arr):.0f}

CSV log saved: {csv_path}
{'='*60}
"""
    print(summary_text)
    
    summary_path = os.path.join(args.output_dir, f"health_summary_{timestamp}.txt")
    with open(summary_path, "w", encoding="utf-8") as f:
        f.write(summary_text)

if __name__ == "__main__":
    main()
