"""
calibrate_occlusion.py — Công cụ hiệu chỉnh cho OCCLUSION_SUSPECT & CAMERA_OCCLUDED
======================================================================================
Ghi đo liên tục từng frame:
  - BBox Area Ratio của từng track_id (BBox Width*Height / Frame Width*Height)
  - Số người detect được trong frame (person_count)
  - Tọa độ cuối cùng trước khi track mất (để xác nhận "không nằm ở biên")
  - Sliding window (1.5s) của Area Ratio từng track, phục vụ phân tích xu hướng
    "tăng dần" ngay trước khi track biến mất

Chạy 4 kịch bản TÁCH BIỆT, mỗi lần 1 kịch bản:
  BỘ 1 — Per-track (OCCLUSION_SUSPECT):
    K1: Nấp sau vật cản ở GIỮA phòng
  BỘ 2 — Global (CAMERA_OCCLUDED):
    K2: Đi bộ bình thường / đi sát qua (baseline)
    K3: Đứng sát camera nhưng KHÔNG che ống kính (control case)
    K4: Bịt camera thật (áo/tay che ống kính > 10s)

Cách dùng:
  python calibrate_occlusion.py --source 0 --scenario K1
  python calibrate_occlusion.py --source 0 --scenario K2
  python calibrate_occlusion.py --source 0 --scenario K3
  python calibrate_occlusion.py --source 0 --scenario K4
"""

import cv2
import numpy as np
import argparse
import csv
import time
import sys
import os
import math
from collections import deque
from datetime import datetime

try:
    from ultralytics import YOLO
except ImportError:
    print("[ERROR] ultralytics không được cài. Chạy: pip install ultralytics")
    sys.exit(1)

try:
    import colorama
    colorama.init()
    GREEN  = "\033[92m"
    YELLOW = "\033[93m"
    RED    = "\033[91m"
    CYAN   = "\033[96m"
    BLUE   = "\033[94m"
    RESET  = "\033[0m"
except ImportError:
    GREEN = YELLOW = RED = CYAN = BLUE = RESET = ""

SCENARIOS = {
    "K1": "Bộ 1 — Nấp sau vật cản giữa phòng (Per-track OCCLUSION_SUSPECT)",
    "K2": "Bộ 2 — Đi bộ bình thường / đi sát qua (Baseline)",
    "K3": "Bộ 2 — Đứng sát camera NHƯNG không che ống kính (Control Case)",
    "K4": "Bộ 2 — Bịt camera thật bằng áo/tay (True Positive)",
}

# Sliding window: giữ Area Ratio 1.5 giây gần nhất (mặc định 30fps * 1.5 = 45 frame)
SLIDING_WINDOW_SIZE = 45

# EDGE_MARGIN: sử dụng margin 30px (đủ rộng để phân biệt "người thoát ra khỏi biên khung hình"
# vs. "người mất dấu ở giữa khung hình do bị vật cản che").
# Lực chọn: 5px (gía trị cũ) quá khít khiến BBox chạm biên do góc đặt camera
# hoặc tư thế người vẫn bị đánh nhầm là near_edge=True.
EDGE_MARGIN = 30

def parse_args():
    p = argparse.ArgumentParser(description="Occlusion Calibration Tool")
    p.add_argument("--source", default="0", help="Nguồn video: file hoặc camera index")
    p.add_argument("--scenario", required=True, choices=list(SCENARIOS.keys()),
                   help="Kịch bản: K1 (nấp sau vật cản) | K2 (baseline) | K3 (control) | K4 (bịt camera)")
    p.add_argument("--output-dir", default=".", help="Thư mục lưu log CSV")
    p.add_argument("--model", default="yolov8n-pose.pt", help="Đường dẫn tới YOLO model")
    p.add_argument("--no-display", action="store_true", help="Chạy không hiển thị cửa sổ")
    p.add_argument("--fps-hint", type=float, default=0.0,
                   help="FPS gợi ý cho sliding window nếu không đọc được từ source")
    return p.parse_args()

def area_ratio(x1, y1, x2, y2, fw, fh):
    """Tính tỉ lệ diện tích BBox / toàn khung hình."""
    return ((x2 - x1) * (y2 - y1)) / (fw * fh)

def trend_slope(values):
    """
    Tính độ dốc (trend) của dãy giá trị bằng hồi quy tuyến tính đơn giản.
    Dương → đang tăng (tiến sát camera). Âm → đang giảm (đi ra xa).
    """
    if len(values) < 2:
        return 0.0
    n = len(values)
    xs = list(range(n))
    mean_x = sum(xs) / n
    mean_y = sum(values) / n
    num = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, values))
    den = sum((x - mean_x) ** 2 for x in xs)
    return num / den if den > 0 else 0.0

def main():
    args = parse_args()
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    os.makedirs(args.output_dir, exist_ok=True)

    scenario_label = SCENARIOS[args.scenario]

    print(f"\n{CYAN}{'='*66}")
    print(f"  Occlusion Calibration Tool  |  {args.scenario}: {scenario_label}")
    print(f"{'='*66}{RESET}")

    # --- Load YOLO model ---
    model_path = args.model
    if not os.path.exists(model_path):
        # thử tìm ở thư mục cha
        parent_candidate = os.path.join(os.path.dirname(__file__), "..", "..", "yolov8n-pose.pt")
        if os.path.exists(parent_candidate):
            model_path = os.path.abspath(parent_candidate)
        else:
            project_candidate = os.path.join(
                os.path.dirname(__file__), "..", "..", "..", "..", "yolov8n-pose.pt"
            )
            if os.path.exists(project_candidate):
                model_path = os.path.abspath(project_candidate)
    print(f"📦 Loading YOLO model: {model_path}")
    try:
        model = YOLO(model_path)
    except Exception as e:
        print(f"{RED}[ERROR] Không load được model: {e}{RESET}")
        sys.exit(1)

    # --- Mở video source ---
    try:
        src = int(args.source)
    except ValueError:
        src = args.source

    cap = cv2.VideoCapture(src)
    if not cap.isOpened():
        print(f"{RED}[ERROR] Không mở được source: {args.source}{RESET}")
        sys.exit(1)

    raw_fps = cap.get(cv2.CAP_PROP_FPS)
    fps = raw_fps if raw_fps > 1 else (args.fps_hint if args.fps_hint > 0 else 30.0)
    width  = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))  or 640
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)) or 360
    frame_area = width * height

    # Sliding window size ≈ 1.5 giây
    win_size = max(10, int(fps * 1.5))
    print(f"  Source : {args.source}  |  {width}x{height} @ {fps:.1f}fps")
    print(f"  Sliding window size: {win_size} frames (~1.5s)")
    print(f"  Press Q to stop\n")

    # --- CSV log ---
    csv_path = os.path.join(args.output_dir, f"occlusion_calibration_{args.scenario}_{timestamp}.csv")
    csv_f = open(csv_path, "w", newline="", encoding="utf-8")
    writer = csv.writer(csv_f)
    writer.writerow([
        "frame", "elapsed_sec", "scenario",
        "person_count",
        "track_id", "x1", "y1", "x2", "y2",
        "area_ratio", "area_trend_slope", "area_window_variance",
        "last_x_before_lost", "last_y_before_lost",
        "is_near_edge",        # True nếu bbox chạm biên (sẽ bị loại trong OCCLUSION_SUSPECT)
        "empty_frame_streak_sec",  # Bao nhiêu giây liên tiếp không có người (Tín hiệu 2)
        "note"
    ])

    # --- State tracking ---
    # track_id → deque of (elapsed, area_ratio)
    area_history: dict[int, deque] = {}
    # track_id → last seen bbox & time
    last_seen: dict[int, dict] = {}
    # Ghi lại sự kiện mất track đặc biệt (track disappears mid-frame)
    track_loss_events = []
    # Tín hiệu 2: đếm số giây liên tiếp không có người được detect (Signal 2)
    empty_frame_start: float | None = None  # Wall-time khi bắt đầu streak empty

    frame_count = 0
    start_wall = time.time()
    prev_track_ids: set = set()

    # Tích lũy cho summary
    all_area_ratios = []
    all_person_counts = []
    max_empty_streak_sec = 0.0     # streak dài nhất của Tín hiệu 2

    try:
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            elapsed = time.time() - start_wall
            frame_count += 1

            # --- YOLO inference ---
            results = model.track(frame, persist=True, conf=0.3, iou=0.5,
                                  tracker="bytetrack.yaml", verbose=False)

            annotated = frame.copy()
            current_track_ids: set = set()
            person_count = 0

            if (results[0].boxes is not None
                    and results[0].boxes.id is not None):
                track_ids_list = results[0].boxes.id.int().cpu().tolist()
                boxes_all = results[0].boxes.xyxy.cpu().numpy()

                for i, tid in enumerate(track_ids_list):
                    x1, y1, x2, y2 = boxes_all[i]
                    ar = area_ratio(x1, y1, x2, y2, width, height)
                    person_count += 1
                    current_track_ids.add(tid)

                    # Sliding window
                    if tid not in area_history:
                        area_history[tid] = deque(maxlen=win_size)
                    area_history[tid].append(ar)

                    # Tính trend và variance dựa trên toàn bộ cửa sổ hiện có
                    window_vals = list(area_history[tid])
                    slope = trend_slope(window_vals)
                    ar_variance = float(np.var(window_vals)) if len(window_vals) > 1 else 0.0

                    # Kiểm tra cạnh biên
                    near_edge = (x1 <= EDGE_MARGIN or y1 <= EDGE_MARGIN
                                 or x2 >= width - EDGE_MARGIN
                                 or y2 >= height - EDGE_MARGIN)

                    last_seen[tid] = {
                        "elapsed": elapsed,
                        "bbox": (x1, y1, x2, y2),
                        "ar": ar,
                        "slope": slope,
                        "variance": ar_variance,
                        "near_edge": near_edge,
                    }
                    all_area_ratios.append(ar)

                    # Ghi CSV
                    writer.writerow([
                        frame_count, f"{elapsed:.3f}", args.scenario,
                        person_count,
                        tid, f"{x1:.1f}", f"{y1:.1f}", f"{x2:.1f}", f"{y2:.1f}",
                        f"{ar:.4f}", f"{slope:.6f}", f"{ar_variance:.6f}",
                        "", "",    # last_x/y — chỉ ghi khi mất track
                        int(near_edge), "0.00", ""
                    ])

                    # HUD
                    col = (0, 255, 255) if ar < 0.5 else ((0, 165, 255) if ar < 0.85 else (0, 0, 255))
                    cv2.rectangle(annotated, (int(x1), int(y1)), (int(x2), int(y2)), col, 2)
                    cv2.putText(annotated,
                                f"ID{tid} AR:{ar:.2f} S:{slope:+.4f} V:{ar_variance:.4f}",
                                (int(x1), int(y1) - 8),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.5, col, 1)

            # Nếu không detect được ai
            empty_streak_sec = 0.0
            if person_count == 0:
                if empty_frame_start is None:
                    empty_frame_start = elapsed
                empty_streak_sec = elapsed - empty_frame_start
                max_empty_streak_sec = max(max_empty_streak_sec, empty_streak_sec)
            else:
                empty_frame_start = None  # reset khi có lại người

            if person_count == 0:
                writer.writerow([
                    frame_count, f"{elapsed:.3f}", args.scenario,
                    0, "", "", "", "", "", "", "", "", "", "", "",
                    f"{empty_streak_sec:.2f}", ""
                ])

            all_person_counts.append(person_count)

            # --- Phát hiện track mất ---
            just_lost = prev_track_ids - current_track_ids
            for lost_tid in just_lost:
                if lost_tid in last_seen:
                    info = last_seen[lost_tid]
                    lx1, ly1, lx2, ly2 = info["bbox"]
                    last_cx = (lx1 + lx2) / 2
                    last_cy = (ly1 + ly2) / 2
                    near_edge = info["near_edge"]

                    # Xu hướng ngay trước khi mất
                    history_vals = list(area_history.get(lost_tid, []))
                    slope_at_loss = trend_slope(history_vals)
                    approaching = slope_at_loss > 0.001  # đang tiến sát camera

                    note = (
                        "APPROACHING_THEN_LOST" if approaching
                        else ("EDGE_EXIT" if near_edge else "DISAPPEARED_MID_FRAME")
                    )

                    track_loss_events.append({
                        "track_id": lost_tid,
                        "elapsed_lost": elapsed,
                        "last_cx": last_cx,
                        "last_cy": last_cy,
                        "last_ar": info["ar"],
                        "slope_at_loss": slope_at_loss,
                        "near_edge": near_edge,
                        "approaching": approaching,
                        "note": note,
                    })

                    # Ghi sự kiện mất track vào CSV
                    writer.writerow([
                        frame_count, f"{elapsed:.3f}", args.scenario,
                        person_count,
                        f"LOST:{lost_tid}", "", "", "", "",
                        f"{info['ar']:.4f}", f"{slope_at_loss:.6f}",
                        f"{last_cx:.1f}", f"{last_cy:.1f}",
                        int(near_edge), note
                    ])

                    color_note = RED if (approaching and not near_edge) else YELLOW
                    print(f"  {color_note}⚠ Track {lost_tid} MẤT @ {elapsed:.1f}s | "
                          f"AR={info['ar']:.3f} | slope={slope_at_loss:+.5f} | "
                          f"near_edge={near_edge} | {note}{RESET}")

            prev_track_ids = current_track_ids

            # --- HUD overlay ---
            cv2.putText(annotated, f"S:{args.scenario} | {scenario_label[:30]}",
                        (10, 24), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (200, 200, 200), 1)
            cv2.putText(annotated, f"Persons: {person_count}",
                        (10, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 255, 0) if person_count > 0 else (0, 0, 255), 2)
            cv2.putText(annotated, f"t={elapsed:.1f}s  frame={frame_count}",
                        (10, 76), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (180, 180, 180), 1)

            if not args.no_display:
                cv2.imshow(f"Occlusion Calibration — {args.scenario}", annotated)
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    print(f"\n{YELLOW}[USER] Dừng sớm theo yêu cầu.{RESET}")
                    break

    finally:
        cap.release()
        if not args.no_display:
            cv2.destroyAllWindows()
        csv_f.close()

    # ===================== SUMMARY =====================
    duration = time.time() - start_wall
    print(f"\n{CYAN}{'='*66}")
    print(f"  CALIBRATION SUMMARY — {timestamp}")
    print(f"  Scenario : {args.scenario} — {scenario_label}")
    print(f"  Frames   : {frame_count}  |  Duration: {duration:.1f}s")
    print(f"{'='*66}{RESET}")

    if all_area_ratios:
        arr = np.array(all_area_ratios)
        print(f"\n── BBox Area Ratio (khi track CÒN tồn tại) ──")
        print(f"  Min    = {arr.min():.4f}  ({arr.min()*100:.1f}% khung hình)")
        print(f"  P05    = {np.percentile(arr, 5):.4f}")
        print(f"  Median = {np.median(arr):.4f}")
        print(f"  P95    = {np.percentile(arr, 95):.4f}")
        print(f"  Max    = {arr.max():.4f}  ({arr.max()*100:.1f}% khung hình)")

    if all_person_counts:
        pc_arr = np.array(all_person_counts)
        print(f"\n── Số người detect được / frame ──")
        print(f"  Min    = {pc_arr.min()}")
        print(f"  Median = {np.median(pc_arr):.1f}")
        print(f"  Max    = {pc_arr.max()}")
        n_zero = int((pc_arr == 0).sum())
        pct_zero = n_zero / len(pc_arr) * 100
        print(f"  Frame với 0 người: {n_zero} ({pct_zero:.1f}%)")

    if track_loss_events:
        print(f"\n── Sự kiện mất track ──")
        for ev in track_loss_events:
            tag = f"{RED}[APPROACHING_THEN_LOST]{RESET}" if ev["approaching"] and not ev["near_edge"] else ""
            print(f"  Track {ev['track_id']} @ t={ev['elapsed_lost']:.1f}s | "
                  f"AR_last={ev['last_ar']:.3f} | slope={ev['slope_at_loss']:+.5f} | "
                  f"near_edge={ev['near_edge']} | {ev['note']} {tag}")
    else:
        print(f"\n── Sự kiện mất track: không có ──")

    print(f"\n── Tín hiệu 2: Empty Frame Streak (person_count=0 liên tiếp) ──")
    print(f"  Max streak  = {max_empty_streak_sec:.2f}s")
    if max_empty_streak_sec > 3.0:
        print(f"  {RED}⚠ Streak > 3s — Ứng viên CAMERA_OCCLUDED Signal 2{RESET}")

    print(f"\n  CSV log saved: {csv_path}")
    print(f"{'='*66}{RESET}\n")

if __name__ == "__main__":
    main()
