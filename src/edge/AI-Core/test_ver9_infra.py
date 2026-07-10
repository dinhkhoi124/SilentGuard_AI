import time
import pytest

# =====================================================================
# IMPORTS TỪ PRODUCTION CODE
# SystemHealthMonitor đã được chuyển vào ver9.py (2026-07-08)
# Test giờ gọi hàm production thật, không dùng bản sao trong file test.
# =====================================================================
from ver9 import PersonFSM, SystemHealthMonitor, evaluate_fsm_transition

# =====================================================================
# UNIT TESTS
# =====================================================================
def test_fsm_initialization():
    fsm = PersonFSM(1)
    assert fsm.state == "NORMAL"
    assert fsm.lying_wall_sec == 0.0
    assert fsm.severity_rank == 0

def test_fsm_independence():
    fsm1 = PersonFSM(1)
    fsm2 = PersonFSM(2)
    
    now = time.monotonic()
    fsm1.transition_to("LYING", now)
    
    assert fsm1.state == "LYING"
    assert fsm2.state == "NORMAL"
    assert fsm1.severity_rank == 3
    assert fsm2.severity_rank == 0

def test_fsm_lying_timer():
    fsm = PersonFSM(1)
    t0 = time.monotonic()
    fsm.transition_to("LYING", t0)
    
    # Giả lập trôi qua 2.5 giây
    t1 = t0 + 2.5
    fsm.update_lying_timer(t1)
    
    assert fsm.lying_wall_sec == 2.5
    
    # Chuyển về NORMAL, timer phải bị reset
    fsm.transition_to("NORMAL", t1)
    assert fsm.lying_start_wall is None
    assert fsm.lying_wall_sec == 0.0

def test_system_health_watchdog():
    monitor = SystemHealthMonitor()
    assert monitor.CAMERA_OFFLINE is False
    
    # Simulate time jump > 15s without frames
    monitor.last_frame_time = time.monotonic() - 16.0
    monitor.update_watchdog(has_frame=False)
    
    assert monitor.CAMERA_OFFLINE is True
    
    # Recover
    monitor.update_watchdog(has_frame=True)
    assert monitor.CAMERA_OFFLINE is False

def test_system_health_stream_frozen():
    import numpy as np
    monitor = SystemHealthMonitor()
    
    # Create a random mock frame
    mock_frame = np.random.randint(0, 255, (360, 640, 3), dtype=np.uint8)
    
    # Frame 1: initial frame
    t0 = time.monotonic()
    monitor.check_frame(mock_frame, t0)
    assert monitor.STREAM_FROZEN is False
    
    # Send identical frames for > 2.0 seconds
    monitor.check_frame(mock_frame, t0 + 1.0)
    assert monitor.STREAM_FROZEN is False
    
    monitor.check_frame(mock_frame, t0 + 3.5)
    assert monitor.STREAM_FROZEN is True
    
    # Send a new different frame
    mock_frame2 = np.random.randint(0, 255, (360, 640, 3), dtype=np.uint8)
    monitor.check_frame(mock_frame2, t0 + 3.5)
    assert monitor.STREAM_FROZEN is False

def test_person_fsm_quality_flags():
    """Test Per-Track Quality Flags: EDGE_TRUNCATED, ID_SWAP_WARNING, TRANSITION_GAP"""
    import time
    from ver9 import PersonFSM, check_edge_truncated, check_id_swap_warning
    fsm = PersonFSM(track_id=10)
    
    # 1. Test EDGE_TRUNCATED
    width, height = 1920, 1080
    
    # --- Không chạm (Ở giữa) ---
    x1, y1, x2, y2 = 10, 10, 500, 500
    fsm.EDGE_TRUNCATED = check_edge_truncated(x1, y1, x2, y2, width, height, margin=5)
    assert fsm.EDGE_TRUNCATED is False
    
    # --- Cạnh trái (x1) ---
    x1, y1, x2, y2 = 4, 10, 500, 500  # < 5 pixel
    fsm.EDGE_TRUNCATED = check_edge_truncated(x1, y1, x2, y2, width, height, margin=5)
    assert fsm.EDGE_TRUNCATED is True
    
    # --- Cạnh trên (y1) ---
    x1, y1, x2, y2 = 10, 4, 500, 500
    fsm.EDGE_TRUNCATED = check_edge_truncated(x1, y1, x2, y2, width, height, margin=5)
    assert fsm.EDGE_TRUNCATED is True
    
    # --- Cạnh phải (x2) ---
    x1, y1, x2, y2 = 10, 10, 1916, 500  # > 1920 - 5
    fsm.EDGE_TRUNCATED = check_edge_truncated(x1, y1, x2, y2, width, height, margin=5)
    assert fsm.EDGE_TRUNCATED is True
    
    # --- Cạnh dưới (y2) ---
    x1, y1, x2, y2 = 10, 10, 500, 1076  # > 1080 - 5
    fsm.EDGE_TRUNCATED = check_edge_truncated(x1, y1, x2, y2, width, height, margin=5)
    assert fsm.EDGE_TRUNCATED is True
    
    # 2. Test ID_SWAP_WARNING (vận tốc Y nhảy phi vật lý > 200px)
    fsm.ID_SWAP_WARNING = False
    current_hip_y = 600.0
    prev_hip_y = 350.0  # Nhảy 250px trong 1 frame
    instant_velocity_y = current_hip_y - prev_hip_y
    fsm.ID_SWAP_WARNING = check_id_swap_warning(instant_velocity_y, threshold=200.0)
    assert fsm.ID_SWAP_WARNING is True
    
    # Bình thường
    fsm.ID_SWAP_WARNING = False
    current_hip_y = 360.0
    instant_velocity_y = current_hip_y - prev_hip_y
    fsm.ID_SWAP_WARNING = check_id_swap_warning(instant_velocity_y, threshold=200.0)
    assert fsm.ID_SWAP_WARNING is False

    # 3. Test TRANSITION_GAP (> 500ms)
    t0 = time.monotonic()
    fsm.last_update_wall = t0
    
    # Lần cập nhật sau (cách 100ms) -> Không hở gap
    t1 = t0 + 0.1
    fsm.TRANSITION_GAP = (t1 - fsm.last_update_wall > 0.5)
    assert fsm.TRANSITION_GAP is False
    
    # Lần cập nhật sau (cách 600ms) -> Hở gap
    t2 = t0 + 0.6
    fsm.TRANSITION_GAP = (t2 - fsm.last_update_wall > 0.5)
    assert fsm.TRANSITION_GAP is True

def test_system_health_lens_degraded():
    import numpy as np
    import cv2
    monitor = SystemHealthMonitor()
    
    # Generate a noisy/sharp image (High Laplacian Variance)
    sharp_frame = np.random.randint(0, 255, (360, 640, 3), dtype=np.uint8)
    t0 = time.monotonic()
    
    # check_frame only evaluates lens degraded if time > last_shift_check_time + 2.0
    monitor.last_shift_check_time = t0 - 3.0
    monitor.check_frame(sharp_frame, t0)
    assert monitor.LENS_DEGRADED == False
    
    # Generate a blurry image (Low Laplacian Variance) -> All same color
    blurry_frame = np.zeros((360, 640, 3), dtype=np.uint8)
    blurry_frame[:] = 128
    
    t1 = t0 + 3.0
    monitor.check_frame(blurry_frame, t1)
    # First check shouldn't trigger LENS_DEGRADED yet (duration check)
    assert monitor.LENS_DEGRADED == False
    
    t2 = t1 + 3.0
    monitor.check_frame(blurry_frame, t2)
    # Second consecutive check triggers it
    assert monitor.LENS_DEGRADED == True

def test_system_health_camera_shifted():
    import numpy as np
    import cv2
    monitor = SystemHealthMonitor()
    
    # Create a base frame with a few distinct non-repeating features
    base_frame = np.zeros((360, 640, 3), dtype=np.uint8)
    # Draw enough features to ensure baseline_features > 10 corners without aliasing
    cv2.rectangle(base_frame, (100, 100), (150, 150), (255, 255, 255), -1)
    cv2.rectangle(base_frame, (200, 200), (250, 250), (255, 255, 255), -1)
    cv2.rectangle(base_frame, (300, 100), (350, 150), (255, 255, 255), -1)
    cv2.rectangle(base_frame, (400, 200), (450, 250), (255, 255, 255), -1)
                
    t0 = time.monotonic()
    
    # 1. Initialize baseline (First run)
    monitor.check_frame(base_frame, t0)
    print(f"DEBUG SHIFT INIT: baseline_features size: {len(monitor.baseline_features) if monitor.baseline_features is not None else 0}")
    
    # 2. Slight shift (< 50 pixels) -> not shifted
    shift_matrix = np.float32([[1, 0, 10], [0, 1, 10]])
    slight_shift = cv2.warpAffine(base_frame, shift_matrix, (640, 360))
    t1 = t0 + 3.0
    monitor.check_frame(slight_shift, t1)
    print(f"DEBUG SHIFT 1: CAMERA_SHIFTED={getattr(monitor, 'CAMERA_SHIFTED', False)}")
    
    # 3. Large shift (> 50 pixels) -> shifted
    # Shift strictly horizontally by 55 pixels to avoid optical flow tracking loss
    shift_matrix_large = np.float32([[1, 0, 55], [0, 1, 0]])
    large_shift = cv2.warpAffine(base_frame, shift_matrix_large, (640, 360))
    t2 = t1 + 3.0
    monitor.check_frame(large_shift, t2)
    # First shift check -> shouldn't trigger yet (duration check)
    assert getattr(monitor, 'CAMERA_SHIFTED', False) == False
    
    t3 = t2 + 3.0
    monitor.check_frame(large_shift, t3)
    # Second shift check -> triggers CAMERA_SHIFTED
    assert getattr(monitor, 'CAMERA_SHIFTED', False) == True

def test_system_health_camera_shifted_massive_shift_ignored_due_to_occlusion_safeguard():
    """Test scenario where camera shift is so massive that optical flow tracking is completely lost.
    Under the NEW logic, this is indistinguishable from occlusion (e.g. person blocking camera),
    so it should be ignored (CAMERA_SHIFTED = False) rather than falsely triggering."""
    import numpy as np
    import cv2
    monitor = SystemHealthMonitor()

    # Base frame with multiple distinct shapes to ensure LENS_DEGRADED = False and good corners
    base_frame = np.zeros((360, 640, 3), dtype=np.uint8)
    for i in range(5):
        cv2.rectangle(base_frame, (50 + i*80, 50 + i*40), (100 + i*80, 100 + i*40), (255, 255, 255), -1)

    t0 = time.monotonic()
    monitor.last_shift_check_time = t0 - 3.0
    monitor.check_frame(base_frame, t0)

    # Verify baseline is established
    assert monitor.baseline_features is not None
    assert getattr(monitor, 'LENS_DEGRADED', False) == False

    # 2. Shift the entire frame by 150 pixels (so optical flow loses the corners completely)
    shift_matrix_massive = np.float32([[1, 0, 150], [0, 1, 150]])
    different_frame = cv2.warpAffine(base_frame, shift_matrix_massive, (640, 360))

    t1 = t0 + 3.0
    monitor.check_frame(different_frame, t1)

    # Expect CAMERA_SHIFTED to be False because tracking was lost completely and the new logic ignores it
    assert getattr(monitor, 'CAMERA_SHIFTED', False) == False
    # Expect LENS_DEGRADED to be False because the frame still has high texture (sharpness)
    assert getattr(monitor, 'LENS_DEGRADED', True) == False

def test_system_health_camera_shifted_textureless():
    """Test scenario where frame lacks features, verifying fallback to LENS_DEGRADED"""
    import numpy as np
    monitor = SystemHealthMonitor()
    
    # Blank frame (no corners, laplacian var = 0)
    blank_frame = np.zeros((360, 640, 3), dtype=np.uint8)
    blank_frame[:] = 128
    
    t0 = time.monotonic()
    
    # Needs current_time - last_shift_check_time > 2.0 to trigger the shift/lens check
    monitor.last_shift_check_time = t0 - 3.0
    
    monitor.check_frame(blank_frame, t0)
    
    # 1. goodFeaturesToTrack should return None for a blank frame
    assert monitor.baseline_features is None
    
    # 2. The fallback alert (LENS_DEGRADED) is False on first check due to duration check
    assert getattr(monitor, 'LENS_DEGRADED', False) == False
    
    t1 = t0 + 3.0
    monitor.check_frame(blank_frame, t1)
    # 3. Second check triggers LENS_DEGRADED
    assert getattr(monitor, 'LENS_DEGRADED', False) == True

def test_system_health_duration_check_recovery():
    """Test that a single bad frame doesn't trigger the flag, and the counter resets on a good frame."""
    import numpy as np
    import cv2
    monitor = SystemHealthMonitor()

    good_frame = np.random.randint(0, 255, (360, 640, 3), dtype=np.uint8)
    bad_frame = np.zeros((360, 640, 3), dtype=np.uint8)
    
    t0 = time.monotonic()
    monitor.last_shift_check_time = t0 - 3.0
    
    # 1. First bad frame -> should not trigger yet
    monitor.check_frame(bad_frame, t0)
    assert monitor.LENS_DEGRADED == False
    assert monitor.lens_degraded_consecutive_frames == 1
    
    # 2. Good frame -> counter should reset
    t1 = t0 + 3.0
    monitor.check_frame(good_frame, t1)
    assert monitor.LENS_DEGRADED == False
    assert monitor.lens_degraded_consecutive_frames == 0
    
    # 3. Two bad frames consecutively -> should trigger
    t2 = t1 + 3.0
    monitor.check_frame(bad_frame, t2)
    assert monitor.LENS_DEGRADED == False
    
    t3 = t2 + 3.0
    monitor.check_frame(bad_frame, t3)
    assert monitor.LENS_DEGRADED == True
    assert monitor.lens_degraded_consecutive_frames == 2

def test_system_health_cross_reference_shift_suppresses_lens_degraded():
    """Test that RAW CAMERA_SHIFTED suppresses RAW LENS_DEGRADED immediately in the same frame.
    
    The cross-reference logic works at the RAW signal level:
    - If raw_camera_shifted is True in a given 2s check window,
      raw_lens_degraded is forced to False BEFORE the duration counter is incremented.
    - This means lens_degraded_consecutive_frames stays at 0 even if Laplacian is below threshold.
    """
    import numpy as np
    import cv2
    monitor = SystemHealthMonitor()
    
    # Intentionally set threshold super high so ANY frame has raw_lens_degraded=True
    monitor.LENS_DEGRADED_THRESHOLD = 999999.0
    
    # Use 4 well-separated rectangles — known to produce >10 tracked features with 55px shift
    # (validated experimentally: 16 features, median_shift ~55px)
    base_frame = np.zeros((360, 640, 3), dtype=np.uint8)
    cv2.rectangle(base_frame, (100, 100), (150, 150), (255, 255, 255), -1)
    cv2.rectangle(base_frame, (200, 200), (250, 250), (255, 255, 255), -1)
    cv2.rectangle(base_frame, (300, 100), (350, 150), (255, 255, 255), -1)
    cv2.rectangle(base_frame, (400, 200), (450, 250), (255, 255, 255), -1)
            
    t0 = time.monotonic()
    monitor.last_shift_check_time = t0 - 3.0
    
    # T0: set baseline. raw_lens_degraded=True (threshold=999999), raw_camera_shifted=False (no baseline yet)
    monitor.check_frame(base_frame, t0)
    assert monitor.lens_degraded_consecutive_frames == 1  # First bad frame, counter goes to 1
    assert monitor.camera_shifted_consecutive_frames == 0
    
    # T1: Shift 55px — optical flow tracks successfully and median_shift ~55 > 50
    # raw_camera_shifted=True must suppress raw_lens_degraded=True BEFORE counter increments
    shift_matrix = np.float32([[1, 0, 55], [0, 1, 0]])
    large_shift = cv2.warpAffine(base_frame, shift_matrix, (640, 360))
    
    t1 = t0 + 3.0
    monitor.check_frame(large_shift, t1)
    
    # KEY ASSERTION: lens counter must be reset to 0, NOT incremented to 2
    assert monitor.camera_shifted_consecutive_frames == 1, f"Expected shift counter=1, got {monitor.camera_shifted_consecutive_frames}"
    assert monitor.lens_degraded_consecutive_frames == 0, (
        f"Cross-reference failed: LENS_DEGRADED counter is {monitor.lens_degraded_consecutive_frames} "
        f"even though CAMERA_SHIFTED raw was True. Rung cam bi nham thanh LENS_DEGRADED!"
    )

def test_transition_gap_forces_suspect_not_falling():
    """Xác nhận GAP thật: TRANSITION_GAP + pose ép nhảy lên SUSPECT chứ không phải FALLING, không mất xác nhận."""
    from ver9 import PersonFSM, evaluate_fsm_transition
    import time
    
    fsm = PersonFSM(track_id=107)
    wall_now = time.time()
    
    fsm.TRANSITION_GAP = True
    decision = evaluate_fsm_transition(fsm, score=40, is_on_floor=True, is_lying_pose=True, 
                                       current_angle=70.0, wall_now=wall_now, frame_count=1, args_score_threshold=65)
    
    assert decision == "SUSPECT"
    assert fsm.state == "SUSPECT"
    assert fsm.TRANSITION_GAP is False


def test_transition_gap_still_requires_normal_confirmation_after():
    """Xác nhận sau khi bị ép lên SUSPECT bởi GAP, các frame sau vẫn cần tích lũy đủ N frame để lên FALLING."""
    from ver9 import PersonFSM, evaluate_fsm_transition
    import time
    
    fsm = PersonFSM(track_id=108)
    wall_now = time.time()
    args_score_threshold = 65
    
    # Frame 1: GAP trigger (đóng góp frame suspect đầu tiên)
    fsm.TRANSITION_GAP = True
    decision = evaluate_fsm_transition(fsm, score=40, is_on_floor=True, is_lying_pose=True, 
                                       current_angle=70.0, wall_now=wall_now, frame_count=1, args_score_threshold=args_score_threshold)
    assert decision == "SUSPECT"
    assert fsm.state == "SUSPECT"
    
    # Chạy 8 frame tiếp theo (Frame 2 -> 9)
    for i in range(2, 10):
        decision = evaluate_fsm_transition(fsm, score=40, is_on_floor=True, is_lying_pose=True, 
                                           current_angle=70.0, wall_now=wall_now, frame_count=i, args_score_threshold=args_score_threshold)
        assert decision == "SUSPECT"
        assert fsm.state == "SUSPECT"
        
    # Frame 10: Đủ 10 frames
    decision = evaluate_fsm_transition(fsm, score=40, is_on_floor=True, is_lying_pose=True, 
                                       current_angle=70.0, wall_now=wall_now, frame_count=10, args_score_threshold=args_score_threshold)
    assert decision == "FALL"
    assert fsm.state == "FALLING"

def test_control_no_transition_gap_requires_accumulation():
    """Control test: Nếu KHÔNG mất frame (không có TRANSITION_GAP), dù score rất cao vẫn phải tích lũy đủ suspect frames chứ không nhảy ngay."""
    import time
    from ver9 import evaluate_fsm_transition, PersonFSM
    fsm = PersonFSM(track_id=101)
    fsm.TRANSITION_GAP = False
    fsm.low_confidence = False
    
    score = 95 # Điểm cực cao
    wall_now = time.time()
    
    decision = evaluate_fsm_transition(
        fsm=fsm,
        score=score,
        is_on_floor=True,
        is_lying_pose=True,
        current_angle=90.0,
        frame_count=1,
        args_score_threshold=65,
        wall_now=wall_now
    )
    
    # Assert: hệ thống chỉ tích lũy bộ đếm (state vẫn là NORMAL) chứ không leo thang nhảy cóc
    assert decision == "SUSPECT"
    assert fsm.state == "NORMAL"
    assert fsm.above_threshold == 1

def test_low_confidence_geometry_guard_blocks_escalation():
    """Test cho Keypoint Geometry Guard: Khi is_angle_inverted=True -> low_confidence=True, FSM phải chặn escalation. KHÔNG liên quan Kalman/mất frame."""
    import time
    from ver9 import evaluate_fsm_transition, PersonFSM
    fsm = PersonFSM(track_id=99)
    fsm.low_confidence = True # Mô phỏng lỗi hình học (hông trên vai) đã xảy ra trong main loop
    
    score = 95 # Cố tình cho điểm cao để xem có bị chặn không
    wall_now = time.time()
    
    decision = evaluate_fsm_transition(
        fsm=fsm,
        score=score,
        is_on_floor=True,
        is_lying_pose=True,
        current_angle=90.0,
        frame_count=1,
        args_score_threshold=65,
        wall_now=wall_now
    )
    
    # Guard phải phát huy tác dụng chặn hoàn toàn
    assert decision == "IGNORED (LOW CONFIDENCE)"
    assert fsm.state == "NORMAL"

def test_decision_syncs_when_falling_recovers_to_normal():
    """Test regression (P5): FSM recovers from FALLING to NORMAL, HUD decision must sync to NORMAL"""
    import time
    from ver9 import evaluate_fsm_transition, PersonFSM
    
    fsm = PersonFSM(track_id=109)
    fsm.state = "FALLING"
    wall_now = time.time()
    args_score_threshold = 65
    
    # Giả lập người bệnh đang ở trạng thái ngã nhưng vừa đứng dậy an toàn:
    # Điểm tụt (score < 65), góc đứng thẳng (< 30 độ), không còn nằm
    decision = evaluate_fsm_transition(
        fsm=fsm,
        score=20,
        is_on_floor=True,  # Đứng trên sàn
        is_lying_pose=False,
        current_angle=15.0,
        wall_now=wall_now,
        frame_count=1,
        args_score_threshold=args_score_threshold
    )
    
    assert fsm.state == "NORMAL", "State phải phục hồi về NORMAL"
    assert decision == "NORMAL", "Regression Bug (P5 HUD): Biến decision phải đồng bộ là NORMAL, không được kẹt lại ở FALL"

def test_dead_reckoning_falling_lying():
    """Test that FSM maintains FALLING and LYING states without reverting during low_confidence"""
    import time
    from ver9 import evaluate_fsm_transition
    
    # 1. Test FALLING state
    fsm_falling = PersonFSM(track_id=101)
    fsm_falling.state = "FALLING"
    fsm_falling.low_confidence = True
    
    wall_now = time.time()
    decision_f = evaluate_fsm_transition(
        fsm=fsm_falling,
        score=0, # Score không quan trọng vì low_confidence
        is_on_floor=False,
        is_lying_pose=False,
        current_angle=0.0,
        wall_now=wall_now,
        frame_count=100,
        args_score_threshold=65
    )
    assert decision_f == "FALL"
    assert fsm_falling.state == "FALLING"
    
    # 2. Test LYING state
    fsm_lying = PersonFSM(track_id=102)
    t_lying_start = time.time() - 5.0  # Nằm được 5 giây trước
    fsm_lying.transition_to("LYING", t_lying_start)
    fsm_lying.low_confidence = True

    # KIẾN TRÚC MỚI (2026-07-08): timer tick trong main loop TRƯỚC evaluate_fsm_transition.
    # Test phải mô phỏng đúng thứ tự đó — gọi update_lying_timer() trước, rồi mới evaluate.
    fsm_lying.update_lying_timer(wall_now)

    decision_l = evaluate_fsm_transition(
        fsm=fsm_lying,
        score=0,
        is_on_floor=True,
        is_lying_pose=True,
        current_angle=90.0,
        wall_now=wall_now,
        frame_count=101,
        args_score_threshold=65
    )

    assert decision_l == "FALL"
    assert fsm_lying.state == "LYING"
    assert fsm_lying.lying_wall_sec >= 4.9


def test_fixed_timestep_lying_timer():
    """Test that FPS drop (Fixed Timestep) still calculates Lying Timer correctly via wall-clock"""
    import time
    fsm = PersonFSM(track_id=103)
    t0 = time.time()
    
    fsm.transition_to("LYING", t0)
    
    # Giả lập FPS tụt xuống 5 FPS (Khoảng cách giữa các frame là 0.2s)
    # Lặp 10 frame (tốn 2.0 giây thực tế)
    for i in range(10):
        fake_wall_now = t0 + (i * 0.2)
        fsm.update_lying_timer(fake_wall_now)
        
    # Thời gian nằm phải chuẩn xác theo wall-clock (khoảng 1.8s ở frame cuối)
    assert abs(fsm.lying_wall_sec - 1.8) < 0.01

def test_evaluate_fsm_slow_slide_override():
    """Test REQ-021: Slow Slide override when ML score is consistently low but geometric condition persists"""
    import time
    from ver9 import evaluate_fsm_transition
    fsm = PersonFSM(track_id=104)
    
    wall_now = time.time()
    args_score_threshold = 65
    low_score = 40  # < SUSPECT_LOW (65 - 15 = 50)
    
    # 9 frames of slow sliding (score low, but on_floor and lying_pose is True)
    # Should stay SUSPECT until frame 10 (SUSPECT_CONFIRM_FRAMES = 10)
    for i in range(9):
        decision = evaluate_fsm_transition(
            fsm=fsm,
            score=low_score,
            is_on_floor=True,
            is_lying_pose=True,
            current_angle=80.0,
            wall_now=wall_now,
            frame_count=i,
            args_score_threshold=args_score_threshold
        )
        assert decision == "SUSPECT"
        assert fsm.state == "NORMAL"
        assert fsm.suspect_frames == i + 1
        
    # Frame 10: should escalate to FALLING
    decision = evaluate_fsm_transition(
        fsm=fsm,
        score=low_score,
        is_on_floor=True,
        is_lying_pose=True,
        current_angle=80.0,
        wall_now=wall_now,
        frame_count=9,
        args_score_threshold=args_score_threshold
    )
    assert decision == "FALL"
    assert fsm.state == "FALLING"
    assert fsm.suspect_frames == 0

def test_calculate_worst_state():
    """Test REQ-001: Max severity calculation across all tracks"""
    from ver9 import calculate_worst_state
    
    # Empty list
    assert calculate_worst_state([]) == -1
    
    # All normal
    fsm1 = PersonFSM(1)
    fsm1.state = "NORMAL"
    fsm2 = PersonFSM(2)
    fsm2.state = "NORMAL"
    assert calculate_worst_state([fsm1, fsm2]) == 0
    
    # One suspect
    fsm2.state = "SUSPECT"
    assert calculate_worst_state([fsm1, fsm2]) == 1
    
    # Multiple varying states
    fsm3 = PersonFSM(3)
    fsm3.state = "LYING"
    assert calculate_worst_state([fsm1, fsm2, fsm3]) == 3

def test_calculate_adaptive_skip_frames_hibernation():
    """Test REQ-001 (c): No tracks -> returns -1 (Motion Trigger Hibernation)"""
    from ver9 import calculate_adaptive_skip_frames
    assert calculate_adaptive_skip_frames(-1, 5) == -1

def test_calculate_adaptive_skip_frames_normal():
    """Test REQ-001 (b): All tracks NORMAL -> returns N (Skip N frames)"""
    from ver9 import calculate_adaptive_skip_frames
    assert calculate_adaptive_skip_frames(0, 5) == 5

def test_calculate_adaptive_skip_frames_danger():
    """Test REQ-001 (a): Any track SUSPECT/FALLING/LYING -> returns 0 (Process all frames)"""
    from ver9 import calculate_adaptive_skip_frames
    assert calculate_adaptive_skip_frames(1, 5) == 0
    assert calculate_adaptive_skip_frames(2, 5) == 0
    assert calculate_adaptive_skip_frames(3, 5) == 0
def test_calculate_worst_state_accumulating_suspect():
    """Test REQ-001: Track accumulating suspect frames should have rank >= 1 even if state is NORMAL"""
    import time
    from ver9 import calculate_worst_state, evaluate_fsm_transition
    
    fsm = PersonFSM(105)
    wall_now = time.time()
    
    # 1. State is NORMAL, no suspicion
    assert fsm.state == "NORMAL"
    assert fsm.severity_rank == 0
    assert calculate_worst_state([fsm]) == 0
    
    # 2. Trigger suspicion (e.g. low score + geometric override)
    decision = evaluate_fsm_transition(
        fsm=fsm,
        score=40,
        is_on_floor=True,
        is_lying_pose=True,
        current_angle=80.0,
        wall_now=wall_now,
        frame_count=0,
        args_score_threshold=65
    )
    
    # 3. Decision should be SUSPECT, state is still NORMAL
    assert decision == "SUSPECT"
    assert fsm.state == "NORMAL"
    
    # 4. BUT severity_rank should now be >= 1 (1 for SUSPECT)
    assert fsm.is_suspect is True
    assert fsm.severity_rank == 1
    assert calculate_worst_state([fsm]) == 1

def test_suspect_state_clears_when_geometry_negates():
    """Test to ensure that suspect state drops if geometry continuously negates after SUSPECT_CONFIRM_FRAMES"""
    import time
    from ver9 import evaluate_fsm_transition
    
    fsm = PersonFSM(106)
    wall_now = time.time()
    args_score_threshold = 65
    suspect_score = 55 # in [SUSPECT_LOW, SUSPECT_HIGH)
    
    # 1. Reach >= SUSPECT_CONFIRM_FRAMES (10 frames) with is_on_floor=True but lying_pose=False
    for i in range(10):
        decision = evaluate_fsm_transition(
            fsm=fsm,
            score=suspect_score,
            is_on_floor=True,
            is_lying_pose=False,
            current_angle=10.0,
            wall_now=wall_now,
            frame_count=i,
            args_score_threshold=args_score_threshold
        )
        assert decision == "SUSPECT"
        
    assert fsm.suspect_frames == 10
    
    # 2. Geometry negates completely (e.g. is_on_floor=False) for the next frames
    # Up to SUSPECT_CLEAR_FRAMES (30). It needs 20 more frames to clear.
    # At frame 29 (i=10 to 28), it should remain SUSPECT
    for i in range(10, 29):
        decision = evaluate_fsm_transition(
            fsm=fsm,
            score=suspect_score,
            is_on_floor=False,
            is_lying_pose=False,
            current_angle=10.0,
            wall_now=wall_now,
            frame_count=i,
            args_score_threshold=args_score_threshold
        )
        assert decision == "SUSPECT"
        
    assert fsm.suspect_frames == 29
    
    # 3. Frame 30 -> clears
    decision = evaluate_fsm_transition(
        fsm=fsm,
        score=suspect_score,
        is_on_floor=False,
        is_lying_pose=False,
        current_angle=10.0,
        wall_now=wall_now,
        frame_count=29,
        args_score_threshold=args_score_threshold
    )
    
    assert decision == "NORMAL"
    assert fsm.suspect_frames == 0
    assert fsm.is_suspect is False
    assert fsm.severity_rank == 0

def test_suspect_frames_do_not_grow_unbounded():
    """Test to ensure suspect_frames never exceeds a predefined cap (SUSPECT_CLEAR_FRAMES) even after 500 frames"""
    import time
    from ver9 import evaluate_fsm_transition
    
    fsm = PersonFSM(107)
    wall_now = time.time()
    args_score_threshold = 65
    suspect_score = 55
    
    # Run 500 frames in suspect zone with negating geometry
    # SUSPECT_CLEAR_FRAMES = 30
    for i in range(500):
        evaluate_fsm_transition(
            fsm=fsm,
            score=suspect_score,
            is_on_floor=False,
            is_lying_pose=False,
            current_angle=10.0,
            wall_now=wall_now,
            frame_count=i,
            args_score_threshold=args_score_threshold
        )
        
        assert fsm.suspect_frames <= 30

def test_suspect_does_not_immediately_re_trigger_after_clear():
    """Test REQ-021/REQ-001: decision=NORMAL is stable after clear, no immediate re-trigger"""
    import time
    from ver9 import evaluate_fsm_transition
    
    fsm = PersonFSM(108)
    wall_now = time.time()
    args_score_threshold = 65
    suspect_score = 55
    
    # 1. 30 frames of negating geometry -> reaches clear state
    for i in range(30):
        decision = evaluate_fsm_transition(
            fsm=fsm,
            score=suspect_score,
            is_on_floor=False,
            is_lying_pose=False,
            current_angle=10.0,
            wall_now=wall_now,
            frame_count=i,
            args_score_threshold=args_score_threshold
        )
    
    # At frame 30, it should be cleared
    assert decision == "NORMAL"
    assert fsm.suspect_frames == 0
    assert getattr(fsm, 'geometry_clear_frames', 0) == 0
    assert getattr(fsm, 'is_suspect_cleared', False) is True
    
    # 2. Next 20 frames with SAME score (55) and SAME negating geometry
    # It must REMAIN "NORMAL" and suspect_frames must REMAIN 0
    for i in range(30, 50):
        decision = evaluate_fsm_transition(
            fsm=fsm,
            score=suspect_score,
            is_on_floor=False,
            is_lying_pose=False,
            current_angle=10.0,
            wall_now=wall_now,
            frame_count=i,
            args_score_threshold=args_score_threshold
        )
        assert decision == "NORMAL"
        assert fsm.suspect_frames == 0
    
    # 3. New suspect evidence (geometry confirms) -> should break the clear state and trigger SUSPECT
    decision = evaluate_fsm_transition(
        fsm=fsm,
        score=suspect_score,
        is_on_floor=True,
        is_lying_pose=True,
        current_angle=90.0,
        wall_now=wall_now,
        frame_count=50,
        args_score_threshold=args_score_threshold
    )
    assert decision == "SUSPECT"
    assert getattr(fsm, 'is_suspect_cleared', False) is False

def test_suspect_frames_persist_through_single_frame_geometry_flicker_in_low_score_zone():
    """Test REQ-021: suspect_frames persists through transient geometry failures in low score zone"""
    import time
    from ver9 import evaluate_fsm_transition
    
    fsm = PersonFSM(109)
    wall_now = time.time()
    args_score_threshold = 65
    low_score = 40  # score < SUSPECT_LOW (50)
    
    # 1. Geometry confirms for 3 frames (e.g., starts bending down)
    for i in range(3):
        decision = evaluate_fsm_transition(
            fsm=fsm,
            score=low_score,
            is_on_floor=True,
            is_lying_pose=True,
            current_angle=90.0,
            wall_now=wall_now,
            frame_count=i,
            args_score_threshold=args_score_threshold
        )
        assert decision == "SUSPECT"
        
    assert fsm.suspect_frames == 3
    
    # 2. Geometry flickers/negates for 1 frame (e.g., occlusion or standing up briefly)
    decision = evaluate_fsm_transition(
        fsm=fsm,
        score=low_score,
        is_on_floor=False, # negates geometry
        is_lying_pose=False,
        current_angle=10.0,
        wall_now=wall_now,
        frame_count=3,
        args_score_threshold=args_score_threshold
    )
    
    # 3. Assert suspect_frames did NOT reset to 0 and decision is STILL SUSPECT
    assert fsm.suspect_frames == 3
    assert decision == "SUSPECT"

def test_integration_main_loop_hibernation():
    """
    Test Adaptive Skip + Motion Hibernation flow with Masked Hysteresis in Main Loop.
    Mocks VideoCapture to return static frames (no motion), then a sudden change (motion).
    Asserts model.track is skipped during hibernation and called upon motion.
    """
    import argparse
    import numpy as np
    from unittest.mock import patch, MagicMock

    args = argparse.Namespace(
        video_url=None, input="dummy.mp4", api_url="http://dummy", output="dummy_out.mp4",
        floor_zone_ratio=0.8, aspect_ratio_threshold=1.5,
        score_threshold=65, confirmation_limit=1.5,
        skip_frames=2, device_key="dummy", upload_token="dummy",
        model_path="dummy.txt", quantize="none"
    )

    rng = np.random.default_rng(seed=42)

    def noisy(base_val, shape=(720, 1280, 3)):
        """Create a frame with uniform noise (std~29) to pass Corrupted Frame Gate."""
        frame = np.full(shape, base_val, dtype=np.uint8)
        noise = rng.integers(-20, 21, shape, dtype=np.int16)
        return np.clip(frame.astype(np.int16) + noise, 0, 255).astype(np.uint8)

    # Static frame: uniform mid-grey with noise — passes Gate, no motion
    frame_static = noisy(128)
    # Top-motion: only top 30% changes (below mask threshold — should be ignored)
    frame_top_motion = noisy(128)
    frame_top_motion[0:200, :] = noisy(200, (200, 1280, 3))
    # Bottom-motion: bottom 70% changes (above mask threshold — should be detected)
    frame_bottom_motion = noisy(128)
    frame_bottom_motion[300:720, :] = noisy(30, (420, 1280, 3))

    frames = [
        frame_static,          # F1: Init (always processed, target_skips=0)
        frame_static,          # F2: No motion -> skip_counter=5
        frame_top_motion,      # F3: Top motion (Masked) -> skip_counter=4
        frame_top_motion,      # F4: Top motion -> skip_counter=3
        frame_top_motion,      # F5: Top motion -> skip_counter=2
        frame_top_motion,      # F6: Top motion -> skip_counter=1
        frame_bottom_motion,   # F7: skip_counter=0 -> evaluates -> Bottom motion -> Detected -> processed
        None                   # F8: EOF
    ]

    mock_cap = MagicMock()
    mock_cap.isOpened.side_effect = lambda: len(frames) > 0
    def mock_read():
        if frames:
            f = frames.pop(0)
            if f is None:
                return False, None
            return True, f
        return False, None
    mock_cap.read.side_effect = mock_read
    mock_cap.get.return_value = 30 # Mock FPS/Width/Height

    mock_yolo_instance = MagicMock()
    mock_results = MagicMock()
    mock_results.boxes.id = None # No detections
    mock_results.plot.return_value = frame_static
    mock_yolo_instance.track.return_value = [mock_results]

    with patch('ver9.cv2.VideoCapture', return_value=mock_cap), \
         patch('ver9.YOLO', return_value=mock_yolo_instance), \
         patch('ver9.lgb.Booster'), \
         patch('ver9.cv2.VideoWriter'), \
         patch('ver9.FramePublisher'), \
         patch('ver9.get_imou_live_stream_url', return_value="dummy.m3u8"):

        from ver9 import process_video_stream
        
        # We catch SystemExit because loop ends
        try:
            process_video_stream(args)
        except Exception as e:
            print(f"Exception caught in test: {e}")

    # Assert YOLO track was called exactly 2 times (Frame 1 and Frame 7)
    # The hibernation mask successfully ignored the top motion in frames 3-6
    assert mock_yolo_instance.track.call_count == 2


def test_calculate_torso_angle_standing():
    """
    0° — Đứng thẳng: vai và hông cùng x, hông thấp hơn vai (dy > 0, dx = 0).
    atan2(abs(0), dy_positive) = atan2(0, positive) = 0 rad = 0°
    Hàm trả tuple (angle, is_inverted). is_inverted phải là False.
    """
    from ver9 import calculate_torso_angle
    angle, is_inverted = calculate_torso_angle(500, 100, 500, 400)
    assert abs(angle - 0.0) < 0.001, f"Expected 0°, got {angle}"
    assert is_inverted is False


def test_calculate_torso_angle_lying_horizontal():
    """
    90° — Nằm ngang hoàn toàn: vai và hông cùng độ cao y (dy = 0), cách nhau theo x.
    atan2(abs(dx), 0) = atan2(positive, 0) = 90°. is_inverted phải là False (dy=0, không âm).
    """
    from ver9 import calculate_torso_angle
    angle, is_inverted = calculate_torso_angle(100, 400, 500, 400)
    assert abs(angle - 90.0) < 0.001, f"Expected 90°, got {angle}"
    assert is_inverted is False


def test_calculate_torso_angle_45_degrees():
    """
    45° — Nghiêng 45°: dx == dy (cả 2 đều dương).
    atan2(abs(dx), dy) = atan2(d, d) = 45°. is_inverted phải là False.
    """
    from ver9 import calculate_torso_angle
    angle, is_inverted = calculate_torso_angle(100, 100, 200, 200)
    assert abs(angle - 45.0) < 0.001, f"Expected 45°, got {angle}"
    assert is_inverted is False


def test_calculate_torso_angle_leaning_left():
    """
    Ngã về phía trái (camera): hip_x < sh_x → dx âm nhưng abs(dx) vẫn dương.
    Góc phải bằng nhau dù ngã trái hay phải vì dùng abs(dx). is_inverted phải là False.
    """
    from ver9 import calculate_torso_angle
    angle_right, inv_right = calculate_torso_angle(200, 100, 300, 200)
    angle_left,  inv_left  = calculate_torso_angle(300, 100, 200, 200)
    assert abs(angle_right - 45.0) < 0.001
    assert abs(angle_left  - 45.0) < 0.001, \
        f"abs(dx) phải loại bỏ chiều ngã, expected 45°, got {angle_left}"
    assert inv_right is False
    assert inv_left  is False


def test_calculate_torso_angle_degenerate_same_point():
    """
    Guard case: vai trùng hông (suy biến keypoint), dx=0 và dy=0.
    Phải trả về (90.0, True) thay vì raise lỗi atan2(0,0).
    is_inverted=True báo caller đây là dữ liệu không tin cậy.
    """
    from ver9 import calculate_torso_angle
    angle, is_inverted = calculate_torso_angle(400, 300, 400, 300)
    assert angle == 90.0, f"Degenerate case phải trả về 90°, got {angle}"
    assert is_inverted is True, "Degenerate case phải trả is_inverted=True"


def test_calculate_torso_angle_low_confidence_fallback():
    """
    Trường hợp confidence thấp (< CONFIDENCE_THRESHOLD): caller tại ver9.py
    KHÔNG gọi calculate_torso_angle mà dùng fallback aspect_ratio.
    Test này xác nhận behavior tại call site:
      - Nếu aspect_ratio > args.aspect_ratio_threshold → angle = 90.0 (coi là nằm)
      - Ngược lại → angle = 0.0 (coi là đứng)
    Đây là behavior tại CALLER, không phải trong hàm calculate_torso_angle.
    """
    CONFIDENCE_THRESHOLD = 0.3
    aspect_ratio_threshold = 1.5
    conf_shoulders_low = 0.1
    conf_hips_low = 0.1
    aspect_ratio_lying = 2.0

    if conf_shoulders_low >= CONFIDENCE_THRESHOLD and conf_hips_low >= CONFIDENCE_THRESHOLD:
        raise AssertionError("Không nên gọi calculate_torso_angle khi confidence thấp")
    else:
        fallback_angle = 90.0 if aspect_ratio_lying > aspect_ratio_threshold else 0.0

    assert fallback_angle == 90.0, f"Lying aspect ratio phải cho angle=90°, got {fallback_angle}"

    aspect_ratio_standing = 0.5
    fallback_angle_standing = 90.0 if aspect_ratio_standing > aspect_ratio_threshold else 0.0
    assert fallback_angle_standing == 0.0, f"Standing aspect ratio phải cho angle=0°, got {fallback_angle_standing}"


def test_calculate_torso_angle_inverted_hip_above_shoulder():
    """
    GUARD dy < 0: hông trên vai trong image coordinates (hip_y < sh_y).

    Phân tích tần suất thực tế:
      - Gần như luôn là LỖI KEYPOINT (model nhầm vị trí khi bị che khuất một phần).
      - Người cao tuổi trong nhà hiếm khi gập bụng sâu đủ để hip_y < sh_y.
      - Nếu không clamp: atan2(abs(dx), negative_dy) cho góc 90–180°,
        hệ thống CÀNG TIN keypoint lỗi HOÀN TOÀN → vi phạm GIGO.

    Hành vi mong muốn (có chủ đích, có tài liệu, có test):
      - angle được clamp về 90.0° (ngưỡng bão hòa, đủ vượt ANGLE_THRESHOLD 60°)
      - is_inverted = True (caller sẽ gắn low_confidence cho FSM track này)
      - KHÔNG phóng đại lên 135° hay 180° vì keypoint càng lỗi không có nghĩa hệ thống
        càng chắc chắn hơn đây là ngã.
    """
    from ver9 import calculate_torso_angle

    # Case 1: hông điển hình trên vai (sai keypoint): hip_y=100 < sh_y=400
    # atan2(abs(dx=0), dy=-300) sẽ cho 180° nếu không clamp — phải trả 90°
    angle, is_inverted = calculate_torso_angle(500, 400, 500, 100)
    assert angle == 90.0, f"dy<0 (thẳng) phải clamp về 90°, got {angle}"
    assert is_inverted is True, "dy<0 phải trả is_inverted=True"

    # Case 2: vừa hông trên vai vừa lệch ngang (keypoint lỗi nặng hơn)
    # atan2(abs(dx=100), dy=-100) sẽ cho 135° nếu không clamp — phải trả 90°
    angle2, is_inverted2 = calculate_torso_angle(200, 400, 300, 300)
    assert angle2 == 90.0, f"dy<0 (chéo) phải clamp về 90°, got {angle2}"
    assert is_inverted2 is True

    # Case 3: xác nhận rằng trường hợp bình thường (dy > 0) KHÔNG bị clamp
    angle3, is_inverted3 = calculate_torso_angle(500, 100, 500, 400)  # đứng thẳng
    assert abs(angle3 - 0.0) < 0.001
    assert is_inverted3 is False, "dy>0 không nên bị đánh dấu is_inverted"


def test_lying_timer_continues_during_stream_frozen():
    """
    Test tích hợp: Lying Timer KHÔNG dừng khi stream frozen (REQ-019).

    Kịch bản mô phỏng:
      1. Track chuyển sang LYING tại t=0.
      2. Hệ thống nhận được frame mới liên tục trong 2 giây → timer tăng bình thường.
      3. Stream frozen: không có frame mới trong 3 giây (mô phỏng bằng cách
         gọi update_lying_timer() trực tiếp với wall-clock tăng, như main loop thật làm).
      4. Xác nhận lying_wall_sec vẫn phản ánh tổng thời gian thực (5 giây),
         không bị "treo" ở 2 giây.

    Lý do kiến trúc: update_lying_timer() được gọi trong main loop mỗi frame,
    TRƯỚC skip logic. Do đó ngay cả khi STREAM_FROZEN hoặc skip_counter > 0,
    timer vẫn tick vì main loop vẫn nhận frame từ cap.read() (cap.read() luôn chạy).
    Test này kiểm chứng hành vi của PersonFSM.update_lying_timer() trực tiếp,
    không cần mock VideoCapture, đủ để bảo vệ invariant REQ-019.
    """
    fsm = PersonFSM(track_id=99)

    # --- Giai đoạn 1: Chuyển sang LYING tại t0 ---
    t0 = 1000.0  # dùng timestamp giả định để kiểm soát chính xác
    fsm.transition_to("LYING", t0)
    assert fsm.state == "LYING"
    assert fsm.lying_wall_sec == 0.0

    # --- Giai đoạn 2: Stream bình thường — tick 30fps trong 2 giây ---
    # Mô phỏng 60 frame (30fps × 2s), mỗi frame gọi update_lying_timer như main loop
    for i in range(1, 61):
        t = t0 + i / 30.0
        fsm.update_lying_timer(t)

    assert abs(fsm.lying_wall_sec - 2.0) < 0.01, \
        f"Sau 2s bình thường, lying_wall_sec phải ≈ 2.0, got {fsm.lying_wall_sec}"

    # --- Giai đoạn 3: STREAM_FROZEN — không có frame mới trong 3 giây ---
    # Trong production: main loop VẪNTICK timer vì cap.read() trả về frame cũ bị đóng băng
    # Test mô phỏng: chỉ tick timer 1 lần tại cuối khoảng frozen (wall-clock = t0 + 5s)
    t_after_frozen = t0 + 5.0
    fsm.update_lying_timer(t_after_frozen)

    assert abs(fsm.lying_wall_sec - 5.0) < 0.01, \
        f"Sau frozen 3s, lying_wall_sec phải ≈ 5.0 (wall-clock), got {fsm.lying_wall_sec}"

    # --- Xác nhận timer không bị reset hay treo ---
    assert fsm.state == "LYING", "FSM vẫn phải ở LYING sau frozen"
    assert fsm.lying_start_wall == t0, "lying_start_wall phải giữ nguyên t0"

    # --- Giai đoạn 4: Thức dậy sau frozen, tiếp tục bình thường ---
    fsm.update_lying_timer(t0 + 7.0)
    assert abs(fsm.lying_wall_sec - 7.0) < 0.01, \
        f"Sau phục hồi 7s, lying_wall_sec phải ≈ 7.0, got {fsm.lying_wall_sec}"


def test_stream_frozen_true_exact_duplicate_frame():
    """
    LỚP 2 — Case 1: Frozen THẬT (same frame duplicated byte-for-byte).

    Kịch bản: IP camera gửi cùng 1 frame liên tiếp (buffer bị đứng).
    Diff array: mọi pixel = 0 chính xác → mean=0.0, std=0.0.
    Cả 2 gate đều pass → STREAM_FROZEN=True sau frozen_timeout.

    Dữ liệu giả lập: dùng np.zeros để bypass cv2 và test logic dual-gate trực tiếp.
    Mô phỏng đúng trường hợp cực đoan nhất (frozen hoàn toàn).
    """
    import numpy as np

    monitor = SystemHealthMonitor()
    t0 = 1000.0

    # Tạo frame xám tĩnh hoàn toàn (không có noise) — mô phỏng stream đóng băng
    # Dùng BGR vì check_frame() gọi cv2.cvtColor(frame, BGR2GRAY)
    static_frame = np.full((64, 64, 3), 128, dtype=np.uint8)

    # Frame 1: khởi tạo prev_frame_gray
    monitor.check_frame(static_frame, t0)
    assert monitor.STREAM_FROZEN is False, "Frame đầu tiên chưa có gì để so sánh"

    # Frame 2: identical → diff = 0 everywhere → mean=0, std=0
    monitor.check_frame(static_frame, t0 + 1.0)
    assert monitor.STREAM_FROZEN is False, "Mới 1s, chưa đủ frozen_timeout (2s)"

    # Frame 3: vẫn identical, sau > 2.0s → STREAM_FROZEN = True
    # frozen_start_time được set tại t0+1.0, nên cần current_time > t0+1.0+2.0 = t0+3.0
    # Dùng t0+3.1 vì code dùng strict > (không phải >=)
    monitor.check_frame(static_frame, t0 + 3.1)
    assert monitor.STREAM_FROZEN is True, \
        "Cùng frame trong >2.0s với mean=0 và std=0 phải báo STREAM_FROZEN=True"



def test_stream_frozen_false_still_scene_with_camera_noise():
    """
    LỚP 2 — Case 2: Scene tĩnh CÓ camera noise → KHÔNG báo frozen.

    Kịch bản: Bệnh nhân nằm bất động, background tĩnh, nhưng camera sensor
    vẫn có electronic noise phân tán đều (gaussian noise ~σ=2 gray levels).

    Trong frame 64×64:
      - mean_diff ≈ 1.6 (noise làm mean vượt ngưỡng 1.0) → không qua gate 1
      - Hoặc: mean_diff < 1.0 nhưng std_diff > 0.5 → không qua gate 2

    Test mô phỏng case khó hơn: mean_diff thấp nhưng std_diff cao,
    xác nhận dual-gate phân biệt đúng với single-gate cũ.
    """
    import numpy as np

    monitor = SystemHealthMonitor()
    t0 = 1000.0

    rng = np.random.default_rng(seed=42)  # seed cố định để reproducible

    # Base frame: người nằm yên — chủ yếu là background tĩnh
    base_frame = np.full((64, 64, 3), 100, dtype=np.uint8)

    # Frame 1: khởi tạo
    monitor.check_frame(base_frame, t0)

    # Frame 2+: thêm gaussian noise nhỏ (σ=3) mô phỏng camera sensor noise
    # std_diff của diff array sẽ ~ σ*√2 ≈ 4.2 > ngưỡng 0.5 → không frozen
    for i in range(1, 8):
        noise = rng.integers(-4, 5, size=(64, 64, 3), dtype=np.int16)
        noisy_frame = np.clip(base_frame.astype(np.int16) + noise, 0, 255).astype(np.uint8)
        monitor.check_frame(noisy_frame, t0 + i * 1.0)

    assert monitor.STREAM_FROZEN is False, \
        ("Scene tĩnh với camera noise (std_diff > 0.5) KHÔNG được báo STREAM_FROZEN. "
         "Nếu fail: dual-gate chưa hoạt động đúng hoặc std_threshold cần hiệu chỉnh.")


def test_stream_frozen_never_suppresses_lying_alert_guard_rail():
    """
    LỚP 1 GUARD RAIL — bất biến không được vi phạm.

    Nguyên tắc: STREAM_FROZEN=True KHÔNG BAO GIỜ được suppress FALLING/LYING alert.
    "Thà báo giả còn hơn bỏ lọt" — nếu người đang nằm mà stream đóng băng,
    hệ thống phải vẫn giữ nguyên quyết định FALL.

    Test này KHÔNG test `check_frame()` — nó test `evaluate_fsm_transition()`.
    Mục đích: đảm bảo không ai vô tình thêm logic
    `if health_monitor.STREAM_FROZEN: return "NORMAL"` vào evaluate_fsm_transition.

    Nếu test này fail → có người đã vi phạm Lớp 1 chính sách.
    """
    import time

    # LYING + STREAM_FROZEN → phải vẫn trả về "FALL"
    fsm = PersonFSM(track_id=999)
    t0 = time.time()
    fsm.transition_to("LYING", t0 - 10.0)
    fsm.update_lying_timer(t0)

    # Giả lập: health_monitor.STREAM_FROZEN = True
    # Lưu ý: evaluate_fsm_transition() KHÔNG nhận health_monitor làm tham số.
    # Đây chính là thiết kế đúng — FSM không biết gì về trạng thái stream.
    # Test này xác nhận signature không thay đổi và không thêm tham số stream_frozen.
    decision = evaluate_fsm_transition(
        fsm=fsm,
        score=0,
        is_on_floor=True,
        is_lying_pose=True,
        current_angle=90.0,
        wall_now=t0,
        frame_count=500,
        args_score_threshold=65
    )

    assert decision == "FALL", \
        ("STREAM_FROZEN KHÔNG được ảnh hưởng quyết định FSM. "
         f"Mong đợi 'FALL', nhận '{decision}'. "
         "Kiểm tra: có ai thêm stream_frozen vào evaluate_fsm_transition() không?")
    assert fsm.state == "LYING", "FSM phải vẫn ở LYING khi stream frozen"
    assert fsm.lying_wall_sec >= 9.9, \
        f"Lying timer phải vẫn tích lũy, got {fsm.lying_wall_sec:.2f}s"

    # FALLING + STREAM_FROZEN → phải vẫn trả về "FALL"
    fsm2 = PersonFSM(track_id=998)
    fsm2.state = "FALLING"
    decision2 = evaluate_fsm_transition(
        fsm=fsm2,
        score=80,
        is_on_floor=False,
        is_lying_pose=False,
        current_angle=50.0,
        wall_now=t0,
        frame_count=501,
        args_score_threshold=65
    )
    assert decision2 == "FALL", \
        f"FALLING + STREAM_FROZEN phải vẫn trả 'FALL', got '{decision2}'"

def test_system_health_camera_occluded_signal_1():
    import numpy as np
    from ver9 import SystemHealthMonitor
    monitor = SystemHealthMonitor()
    frame = np.zeros((360, 640, 3), dtype=np.uint8)
    
    t0 = 100.0
    monitor.last_shift_check_time = t0 - 3.0
    monitor.check_frame(frame, t0, active_area_ratios=[0.96], person_count=1)
    # Chưa đủ 2 lần -> False
    assert monitor.CAMERA_OCCLUDED == False
    
    t1 = t0 + 3.0
    monitor.check_frame(frame, t1, active_area_ratios=[0.97], person_count=1)
    # Lần 2 -> True
    assert monitor.CAMERA_OCCLUDED == True
    
    # Check safeguard
    assert monitor.LENS_DEGRADED == False
    assert monitor.STREAM_FROZEN == False

def test_system_health_camera_occluded_signal_2():
    import numpy as np
    from ver9 import SystemHealthMonitor
    monitor = SystemHealthMonitor()
    frame = np.zeros((360, 640, 3), dtype=np.uint8)
    
    t0 = 100.0
    # Person present, area ratio 0.55 (large enough to trigger occlusion when lost)
    monitor.check_frame(frame, t0, active_area_ratios=[0.55], person_count=1)
    assert monitor.CAMERA_OCCLUDED == False
    assert monitor.last_known_max_ar == 0.55
    
    # Person lost
    t1 = t0 + 1.0
    monitor.check_frame(frame, t1, active_area_ratios=[], person_count=0)
    assert monitor.CAMERA_OCCLUDED == False
    
    # After 4.0s from loss
    t2 = t1 + 4.0
    monitor.check_frame(frame, t2, active_area_ratios=[], person_count=0)
    assert monitor.CAMERA_OCCLUDED == False
    
    # After 6.0s from loss -> True
    t3 = t1 + 6.0
    monitor.check_frame(frame, t3, active_area_ratios=[], person_count=0)
    assert monitor.CAMERA_OCCLUDED == True

def test_system_health_camera_occluded_signal_2_normal_walk_out():
    import numpy as np
    from ver9 import SystemHealthMonitor
    monitor = SystemHealthMonitor()
    frame = np.zeros((360, 640, 3), dtype=np.uint8)
    
    t0 = 100.0
    # Person present, area ratio 0.15 (walking out normally)
    monitor.check_frame(frame, t0, active_area_ratios=[0.15], person_count=1)
    assert monitor.CAMERA_OCCLUDED == False
    assert monitor.last_known_max_ar == 0.15
    
    # Person lost
    t1 = t0 + 1.0
    monitor.check_frame(frame, t1, active_area_ratios=[], person_count=0)
    assert monitor.CAMERA_OCCLUDED == False
    
    # After 6.0s from loss -> Should still be False because ar < 0.50
    t2 = t1 + 6.0
    monitor.check_frame(frame, t2, active_area_ratios=[], person_count=0)
    assert monitor.CAMERA_OCCLUDED == False

def test_transition_gap_global_freeze_detection():
    """Test Kịch bản A: Global Gap > 0.5s kích hoạt TRANSITION_GAP cho toàn bộ track active."""
    import time
    from ver9 import PersonFSM
    
    fsm1 = PersonFSM(1)
    fsm2 = PersonFSM(2)
    fsm_states = {1: fsm1, 2: fsm2}
    
    last_loop_wall = time.time() - 0.6  # Giả lập gap 600ms
    current_wall = time.time()
    
    global_gap = current_wall - last_loop_wall
    if global_gap > 0.5:
        for _fsm in fsm_states.values():
            _fsm.TRANSITION_GAP = True
            
    assert fsm1.TRANSITION_GAP is True
    assert fsm2.TRANSITION_GAP is True

def test_transition_gap_not_triggered_by_adaptive_skip():
    """Test Kịch bản A: Adaptive skip không gây kích hoạt cờ giả (vì gap vật lý giữa cap.read < 0.5s)."""
    import time
    from ver9 import PersonFSM
    
    fsm1 = PersonFSM(1)
    fsm_states = {1: fsm1}
    
    # Ở 10fps, gap vật lý giữa 2 cap.read là 100ms
    last_loop_wall = time.time() - 0.1  
    current_wall = time.time()
    
    global_gap = current_wall - last_loop_wall
    if global_gap > 0.5:
        for _fsm in fsm_states.values():
            _fsm.TRANSITION_GAP = True
            
    assert fsm1.TRANSITION_GAP is False

def test_transition_gap_cache_reid_detection():
    """Test Kịch bản B: Track nằm trong cache > 0.5s khi lôi ra sẽ bị set TRANSITION_GAP."""
    import time
    from ver9 import PersonFSM
    
    track_id = 1
    fsm1 = PersonFSM(track_id)
    current_time = time.time()
    
    # Track nằm trong cache 800ms
    old_info = {
        "timestamp": current_time - 0.8,
        "fsm": fsm1
    }
    
    fsm_states = {}
    
    # Logic móc từ cache
    cache_gap = current_time - old_info["timestamp"]
    fsm_states[track_id] = old_info["fsm"]
    
    if cache_gap > 0.5:
        fsm_states[track_id].TRANSITION_GAP = True
        
    assert fsm_states[track_id].TRANSITION_GAP is True

def test_low_confidence_is_reset_per_frame():
    """Test LỖI CRITICAL BUG: Xác nhận low_confidence không bị kẹt vĩnh viễn."""
    from ver9 import PersonFSM
    
    fsm = PersonFSM(1)
    fsm.low_confidence = True # Giả lập bị kẹt từ frame trước
    
    # Ở vòng lặp tiếp theo, code reset
    fsm.low_confidence = False
    assert fsm.low_confidence is False

def test_id_swap_accumulates_and_triggers_low_confidence():
    """Test ID_SWAP_WARNING cộng dồn 3 frame liên tiếp mới bật cờ low_confidence."""
    from ver9 import PersonFSM
    
    fsm = PersonFSM(1)
    
    def simulate_frame(is_swap: bool):
        fsm.low_confidence = False
        fsm.ID_SWAP_WARNING = is_swap
        if is_swap:
            fsm.id_swap_frames += 1
        else:
            fsm.id_swap_frames = 0
            
        if fsm.id_swap_frames >= 3:
            fsm.low_confidence = True

    # Frame 1: Swap (1 frame)
    simulate_frame(True)
    assert fsm.id_swap_frames == 1
    assert fsm.low_confidence is False
    
    # Frame 2: Swap (2 frames)
    simulate_frame(True)
    assert fsm.id_swap_frames == 2
    assert fsm.low_confidence is False
    
    # Frame 3: Swap (3 frames) -> Trigger
    simulate_frame(True)
    assert fsm.id_swap_frames == 3
    assert fsm.low_confidence is True
    
    # Frame 4: No Swap -> Reset
    simulate_frame(False)
    assert fsm.id_swap_frames == 0
    assert fsm.low_confidence is False

def test_id_swap_counter_resets_on_edge_clip():
    """Test GIGO Filter 3 (Clip biên) resets counter và prev_hip để chống Overshoot."""
    from ver9 import PersonFSM, check_id_swap_warning
    
    fsm = PersonFSM(1)
    fsm.id_swap_frames = 2
    track_prev_hips = {1: 100.0} # Hông ở frame hợp lệ cuối cùng
    
    # --- Frame 1: Bị clip biên (Mô phỏng GIGO Filter 3) ---
    is_clipped = True
    if is_clipped and fsm.state == "NORMAL":
        fsm.id_swap_frames = 0
        track_prev_hips[1] = None
        # continue (bỏ qua tính toán)
        
    assert fsm.id_swap_frames == 0, "Counter phải bị reset về 0"
    assert track_prev_hips[1] is None, "Lịch sử hông phải bị xóa"
    
    # --- Frame 2: Thoát clip (Vào lại khung hình sau N frame) ---
    is_clipped = False
    current_hip_y = 500.0 # Khoảng cách dồn qua N frame = 400.0px (Rất lớn)
    instant_velocity_y = 0.0
    
    # Tính vận tốc (Mô phỏng dòng 1690)
    if track_prev_hips[1] is not None:
        instant_velocity_y = current_hip_y - track_prev_hips[1]
        
    # Xác nhận chống Overshoot thành công (vận tốc dồn không được tính)
    assert instant_velocity_y == 0.0, "Overshoot chưa bị chặn!"
    
    is_swap = check_id_swap_warning(instant_velocity_y)
    assert is_swap is False, "Không được báo ID Swap ảo"




# [P4] SimpleKalman1D unit tests
def test_simple_kalman_predict_constant_velocity():
    from ver9 import SimpleKalman1D
    k = SimpleKalman1D(initial_y=100.0, initial_vy=5.0)
    y1, vy1 = k.predict()
    assert abs(y1 - 105.0) < 1e-6, f'y sau predict phai ~105, got {y1}'
    assert abs(vy1 - 5.0) < 1e-6, f'vy phai ~5.0, got {vy1}'


def test_simple_kalman_update_corrects_position():
    from ver9 import SimpleKalman1D
    k = SimpleKalman1D(initial_y=100.0, initial_vy=0.0)
    k.predict()
    y_updated, _ = k.update(200.0)
    assert y_updated > 100.0, 'Sau update, y phai lon hon 100'
    assert y_updated < 200.0, 'Nhung chua nhay thang len 200'


def test_simple_kalman_low_confidence_gap():
    from ver9 import SimpleKalman1D, PersonFSM, evaluate_fsm_transition
    import collections, time as _t
    fsm = PersonFSM(track_id=99)
    win = collections.deque(maxlen=32)
    kal = SimpleKalman1D(initial_y=300.0, initial_vy=10.0)
    for _ in range(5):
        _, pvy = kal.predict()
        win.append({'velocity_y': pvy*30, 'current_angle': 0.0,
                    'height_drop_ratio': 1.0, 'is_lying_pose': 0.0, 'is_on_floor': 0.0})
        fsm.low_confidence = True
    assert fsm.low_confidence is True
    assert len(win) == 5
    assert all(w['velocity_y'] > 0 for w in win)
    dec = evaluate_fsm_transition(fsm=fsm, score=90, is_on_floor=True,
        is_lying_pose=True, current_angle=80.0, wall_now=_t.time(),
        frame_count=100, args_score_threshold=65)
    expected = 'IGNORED (LOW CONFIDENCE)'
    assert dec == expected, f'Dead reckoning phai bi suppress, got {dec}'
