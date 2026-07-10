import argparse
import cv2
import numpy as np
import time
from ultralytics import YOLO
from ver9 import check_edge_truncated, CONFIDENCE_THRESHOLD

def analyze_video_velocity(video_path: str, model, min_track_age: int = 3):
    """
    Chạy YOLO pose tracker trên video và thu thập dữ liệu instant_velocity_y của tất cả các track.
    Trả về danh sách các giá trị vận tốc tuyệt đối (|v_y|) để phân tích ngưỡng.
    """
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"Error: Cannot open {video_path}")
        return []

    fps = cap.get(cv2.CAP_PROP_FPS)
    if fps == 0:
        fps = 30.0

    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    
    # ⚠️ Giá trị này phải khớp tay với MIN_VALID_KEYPOINTS trong ver9.py 
    # (hiện tại dòng ~1456) — không tự động đồng bộ, cần kiểm tra lại nếu 
    # ver9.py thay đổi.
    MIN_VALID_KEYPOINTS = 6  

    track_prev_hips = {}
    track_ages = {}
    velocities = []

    total_frames_est = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    print(f"Processing {video_path} (FPS: {fps:.1f}, Resolution: {width}x{height}, TotalFrames: {total_frames_est})...")
    frame_count = 0
    
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        frame_count += 1
        
        # Chạy tracker
        results = model.track(frame, persist=True, classes=[0], verbose=False)
        
        if results[0].boxes is not None and results[0].boxes.id is not None and results[0].keypoints is not None:
            track_ids = results[0].boxes.id.int().cpu().tolist()
            keypoints_all = results[0].keypoints.data.cpu().numpy()
            boxes_all = results[0].boxes.xyxy.cpu().numpy()
            
            for i, track_id in enumerate(track_ids):
                if track_id not in track_ages:
                    track_ages[track_id] = 0
                    track_prev_hips[track_id] = None
                
                track_ages[track_id] += 1
                
                keypoints = keypoints_all[i]
                x1, y1, x2, y2 = boxes_all[i]
                box_h = y2 - y1
                
                # ── GIGO FILTER 2: Keypoint quality ─────
                valid_kp_count = int(np.sum(keypoints[:, 2] > 0.3))
                if valid_kp_count < MIN_VALID_KEYPOINTS:
                    track_prev_hips[track_id] = None
                    continue
                
                # ── GIGO FILTER 3: Partial body (clip biên) ─────
                is_clipped = check_edge_truncated(x1, y1, x2, y2, width, height, margin=5)
                if is_clipped:
                    track_prev_hips[track_id] = None
                    continue

                # Tính Y hông (bắt chước ver9.py)
                conf_shoulders = (keypoints[5][2] + keypoints[6][2]) / 2
                conf_hips = (keypoints[11][2] + keypoints[12][2]) / 2
                if conf_shoulders >= CONFIDENCE_THRESHOLD and conf_hips >= CONFIDENCE_THRESHOLD:
                    current_hip_y = (keypoints[11][1] + keypoints[12][1]) / 2
                else:
                    current_hip_y = float(y1 + (box_h / 2))
                
                instant_velocity_y = 0.0
                if track_prev_hips[track_id] is not None:
                    instant_velocity_y = current_hip_y - track_prev_hips[track_id]
                
                # Bỏ qua các frame nhiễu lúc mới xuất hiện
                if track_ages[track_id] > min_track_age:
                    velocities.append(abs(instant_velocity_y))
                
                track_prev_hips[track_id] = current_hip_y

    cap.release()
    print(f"Finished {video_path}. Total frames: {frame_count}, Data points: {len(velocities)}")
    return velocities

def main():
    parser = argparse.ArgumentParser(description="Calibrate ID_SWAP_WARNING Threshold")
    parser.add_argument("--swap_video", type=str, required=True, help="Video mô phỏng ID Swap (Người đi ngang nhau)")
    parser.add_argument("--fall_video", type=str, required=True, help="Video mô phỏng ngã thật nhanh (Fast Fall)")
    parser.add_argument("--model", type=str, default="yolov8n-pose.pt", help="Path to YOLO model")
    args = parser.parse_args()

    print("Loading model...")
    model = YOLO(args.model)

    print("\n--- BƯỚC 1: Phân tích Video ID Swap (S1) ---")
    swap_vels = analyze_video_velocity(args.swap_video, model)
    
    print("\n--- BƯỚC 2: Phân tích Video Ngã Nhanh (S2) ---")
    fall_vels = analyze_video_velocity(args.fall_video, model)

    print("\n================ THỐNG KÊ KẾT QUẢ ===============")
    if swap_vels and fall_vels:
        max_swap = np.max(swap_vels)
        mean_swap = np.mean(swap_vels)
        
        max_fall = np.max(fall_vels)
        mean_fall = np.mean(fall_vels)
        
        print(f"FAST FALL (S2) - Max Y-Velocity: {max_fall:.1f} px/frame, Mean: {mean_fall:.1f}")
        print(f"ID SWAP (S1)   - Max Y-Velocity: {max_swap:.1f} px/frame, Mean: {mean_swap:.1f}")
        
        print("\n--- KHUYẾN NGHỊ THRESHOLD ---")
        if max_swap > max_fall:
            suggested = max_fall + (max_swap - max_fall) * 0.3 # Lấy điểm cắt an toàn
            print(f"Ngưỡng an toàn đề xuất để phân biệt: {suggested:.1f} px/frame")
            if suggested > 200.0:
                print(f"CẢNH BÁO: Ngưỡng 200.0 ASSUMED hiện tại đang RỦI RO (quá thấp, có thể chạm mức max_fall). Cần nâng lên {suggested:.1f}")
            else:
                print(f"Ngưỡng 200.0 ASSUMED hiện tại có vẻ an toàn, nhưng {suggested:.1f} sẽ tối ưu hơn.")
        else:
            print("CẢNH BÁO NGUY HIỂM: Max_fall lớn hơn Max_swap! Không thể dùng Y-Velocity làm tiêu chí duy nhất.")
            print("Đề xuất: Phải bổ sung X-Velocity hoặc Box_Width để phân biệt 2 kịch bản này.")
    else:
        print("Không đủ dữ liệu để phân tích. Hãy kiểm tra lại video.")

if __name__ == "__main__":
    main()
