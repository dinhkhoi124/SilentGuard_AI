# SPEC.md — Đặc tả & Ma trận Truy vết (Traceability Matrix)
## Hệ thống Fall Detection AI — ver9.py

> Nguồn gốc: `ai_infrastructure_roadmap.md` (kiến trúc 3 tầng) + `vulnerability_analysis.md` (13 edge case).
> File này là **nguồn sự thật duy nhất** để đối chiếu báo cáo của agent. Mỗi khi agent báo cáo "đã xong", đối chiếu đúng dòng REQ-ID tương ứng — không chấp nhận mô tả bằng lời thay cho code/log.

### Quy tắc bắt buộc cho mọi REQ (đúc kết từ 8 vòng kiểm tra thực tế)
1. **Không tự ý thêm số liệu.** Mọi ngưỡng/hằng số phải trích dẫn đúng vị trí trong 2 tài liệu gốc, hoặc được đánh dấu `[GIẢ ĐỊNH MỚI — CẦN DUYỆT]` kèm lý do kỹ thuật.
2. **Test phải gọi hàm production thật.** Cấm viết lại (duplicate) logic if/else trong file test rồi tự assert trên bản sao — test đó luôn pass vô nghĩa.
3. **Log phải là log thật, đầy đủ tên test (`pytest -v`), không rút gọn.** Không chấp nhận "output ẩn bên dưới" hay tường thuật lại kết quả bằng lời.
4. **Mỗi thay đổi hành vi hệ thống phát sinh ngoài phạm vi yêu cầu ban đầu** (kiểu "tiện tay fix luôn...") phải được tách thành mục riêng, có diff riêng, có test riêng — không lồng ghép âm thầm vào báo cáo của yêu cầu khác.
5. **Thứ tự Bước phải tuần tự.** Không mở Bước N+1 khi Bước N chưa đủ 4 bằng chứng: code thật + diff/test thật + log pytest -v thật + xác nhận traceability vào bảng dưới đây.

---

## BẢNG TRẠNG THÁI TỔNG QUAN

| Bước | Nội dung | Trạng thái | Ghi chú |
|---|---|---|---|
| 1 | Per-Track FSM + Adaptive FPS cơ bản | ⚠️ Chưa audit riêng | Ẩn trong lõi trước khi phiên kiểm tra này bắt đầu |
| 2 | System Health Layer (4 Global Flags) | ✅ Duyệt | Xem REQ-013b-x |
| 3 | Per-Track Quality Flags (3 cờ) | ✅ Duyệt | Xem REQ-014, 015, 016 |
| 4 | Dead Reckoning (Kalman predict-only) | ✅ Duyệt | Xem REQ-017 → 020 |
| 5 | Adaptive Frame Skipping + Max Severity + Main Loop Integration | ✅ Duyệt | Xem REQ-001, REQ-021. 24/24 test PASS (2026-07-08). |
| — | Slow Slide Override (mục 6) | ✅ Duyệt | Implement trong evaluate_fsm_transition(), test_evaluate_fsm_slow_slide_override PASS. |

---

## TẦNG 1 — MODEL & COMPUTE

### [REQ-001] Adaptive Frame Skipping
- **Nội dung:** NORMAL → 10-15fps; SUSPECT/LYING → full 30fps. Quyết định dựa trên `worst_state` (Max Severity) của toàn bộ track đang active.
- **Nguồn:** `ai_infrastructure_roadmap.md` §1; `vulnerability_analysis.md` mục 9.
- **Trạng thái:** ✅ Duyệt (Bước 5 — 2026-07-08)
- **Implement:** `calculate_worst_state()` + `calculate_adaptive_skip_frames()` tách hàm riêng. `args.skip_frames` là tham số cấu hình. Hibernation dùng Motion Trigger với Masked Hysteresis (frame diff chỉ trên 70% dưới khung hình). `PersonFSM` OOP thay toàn bộ dict lỏng lẻo trong Main Loop.
- **Test:** `test_calculate_worst_state`, `test_calculate_adaptive_skip_frames_hibernation`, `test_calculate_adaptive_skip_frames_normal`, `test_calculate_adaptive_skip_frames_danger`, `test_integration_main_loop_hibernation` — **24/24 PASS** (pytest -v, 2026-07-08).

### [REQ-002] Model Quantization — INT8 ưu tiên trước FP16
- **Nội dung:** Ưu tiên INT8 Quantization (OpenVINO POT/NNCF) trước khi hạ xuống FP16.
- **Nguồn:** `ai_infrastructure_roadmap.md` §1.
- **Trạng thái:** 🔲 Chưa audit.

### [REQ-002b] Quy tắc Load Tăng theo số Camera (FP32/FP16 + bỏ cổ chân)
- **Nội dung:** 1-2 camera → FP32, dùng đủ keypoint cổ tay/cổ chân. 3-5 camera → bắt buộc FP16, chỉ tính góc nghiêng theo Vai-Hông (bỏ cổ chân).
- **Nguồn:** `vulnerability_analysis.md` mục 3.
- **Trạng thái:** 🔲 Chưa audit.

### [REQ-003] Warm-start Tracking (Kalman prior cho YOLO/ByteTrack)
- **Nguồn:** `ai_infrastructure_roadmap.md` §1.
- **Trạng thái:** 🔲 Chưa audit.
- **Lưu ý:** Không nhầm với Kalman ở REQ-017 (Dead Reckoning) — đây là dùng Kalman làm "mồi" cho NMS, mục đích khác hoàn toàn.

### [REQ-004] Motion Trigger + Masked Hysteresis
- **Nội dung:** Không có chuyển động → YOLO ngủ đông. Dùng Masked Hysteresis (chỉ đánh thức nếu vùng chuyển động trùng tọa độ người lần cuối, hoặc vùng Giường/Ghế vẽ trước) để chống nhiễu bóng cây/xe.
- **Nguồn:** `ai_infrastructure_roadmap.md` §1; `vulnerability_analysis.md` mục 2.
- **Trạng thái:** ⚠️ Implement một phần (2026-07-08). Motion Trigger với Masked Hysteresis đã hoạt động trong Hibernation (rank=-1). Còn thiếu:
  - Ngưỡng cooldown 30-60s **chưa implement** — hiện chuyển Hibernation ngay khi `fsm_states` trống.
  - Masked Hysteresis chưa dùng vùng Giường/Ghế vẽ trước — chỉ dùng bottom 70% cố định (xem REQ-BACKLOG-001).

---

## TẦNG 2 — ĐẶC TRƯNG & TEMPORAL

### [REQ-005] EMA cho Velocity
- **Nguồn:** `ai_infrastructure_roadmap.md` §2. — 🔲 Chưa audit.

### [REQ-006] Đặc trưng Jerk (đạo hàm bậc 2)
- **Nguồn:** `ai_infrastructure_roadmap.md` §2. — 🔲 Chưa audit.

### [REQ-007] Sliding Window Statistics (Min/Max/Std, 10-20 frames)
- **Nguồn:** `ai_infrastructure_roadmap.md` §2. — 🔲 Chưa audit.

### [REQ-008] Aspect Ratio + Torso Angle
- **Nguồn:** `ai_infrastructure_roadmap.md` §2.
- **Trạng thái:** ✅ Duyệt (2026-07-08).
- **Implement:** `calculate_torso_angle(sh_x, sh_y, hip_x, hip_y)` — góc so với trục Y dọc.
  Convention: 0°=đứng, 45°=nghiêng, 90°=nằm. Guard dx=dy=0 → (90°, True).
  Guard dy<0 (hông trên vai) → clamp 90° + is_keypoint_unreliable=True — chính sách có chủ đích:
  dy<0 trong pipeline thực tế là lỗi keypoint >95%, để tràn lên 135–180° vi phạm GIGO.
  Caller gắn `fsm.low_confidence=True` khi cờ bật, ngăn escalate FALLING từ keypoint lỗi.
  Return type: `tuple[float, bool]` (angle, is_keypoint_unreliable). Tên tại caller: `is_angle_inverted`.
- **Ngưỡng hệ thống:** < 30° → is_standing; > 60° (ANGLE_THRESHOLD) → escalate FALLING.
- **Confidence fallback:** caller chỉ gọi hàm này khi conf >= 0.3. Không đủ conf → fallback aspect_ratio tại call site.
- **Test (7 cases):** standing, lying_horizontal, 45_degrees, leaning_left, degenerate_same_point,
  low_confidence_fallback, **inverted_hip_above_shoulder** — **7/7 PASS** (pytest -v, 2026-07-08).

---

## TẦNG 3 — HẠ TẦNG & LUỒNG DỮ LIỆU

### [REQ-009] Async Pipeline (Threads/Processes tách biệt qua Queues)
- **Nguồn:** `ai_infrastructure_roadmap.md` §3. — 🔲 Chưa audit.

### [REQ-010] RTMP Main Stream (không dùng HLS)
- **Nguồn:** `ai_infrastructure_roadmap.md` §3. — 🔲 Chưa audit.

### [REQ-011] SSOT Lying Timer (FSM giữ đồng hồ, Backend chỉ đọc `duration_sec`)
- **Nguồn:** `ai_infrastructure_roadmap.md` §3; `vulnerability_analysis.md` mục 6 (đoạn IMPORTANT), mục 12.3 (Fixed Timestep).
- **Trạng thái:** ✅ Duyệt (kiểm chứng qua Bước 4 — `test_fixed_timestep_lying_timer`).
- **Test:** `test_fixed_timestep_lying_timer` — PASS. Xác nhận `lying_wall_sec` tính đúng theo `time.time()`, không lệ thuộc số frame.

### [REQ-012] Silent Re-check + Per-User Profile (chống "Tôi Ổn" ép buộc)
- **Nội dung:** Bấm Hủy → Backend âm thầm hẹn giờ vài phút sau kiểm tra lại Heartbeat. Nếu vẫn LYING → ghi đè lệnh Hủy + gọi cấp cứu. Đối chiếu Per-User Profile để không báo giả người liệt giường.
- **Nguồn:** `ai_infrastructure_roadmap.md` §3; `vulnerability_analysis.md` mục 5.
- **Trạng thái:** 🔲 Chưa audit (thuộc phạm vi Backend, chưa chạm tới trong các bước ver9.py hiện tại).
- **Lưu ý bổ sung:** `vulnerability_analysis.md` mục 5 còn yêu cầu Fail-safe Default: chưa vẽ Safe Zone → mặc định 100% khung hình là Sàn nhà. Cần audit riêng khi làm tới phần Safe Zone.

---

## SYSTEM HEALTH LAYER (Global Flags) — Bước 2/3, đã duyệt

### [REQ-013a] CAMERA_OFFLINE (Watchdog)
- **Nội dung:** >15s không có frame → cờ `CAMERA_OFFLINE`. Lưu Last-Known-State. Auto-reconnect Exponential Backoff. Khi khôi phục, bắt buộc kiểm tra lại Camera Shift trước khi tin Safe Zone cũ.
- **Nguồn:** `vulnerability_analysis.md` mục 13.1.
- **Trạng thái:** ✅ Duyệt.
- **Test:** `test_system_health_watchdog` — PASS.
- **Còn thiếu:** Chưa thấy bằng chứng "Bảo vệ Kép" (bắt buộc check Camera Shift ngay sau khi reconnect) được implement — cần audit riêng.

### [REQ-013b-1] CAMERA_SHIFTED — Textureless Fallback
- **Nội dung:** Khi ảnh trơn không có góc cạnh (`goodFeaturesToTrack` trả `None`), phải có cơ chế fallback (không được im lặng bỏ qua).
- **Nguồn:** `vulnerability_analysis.md` mục 13.2 + lỗ hổng phát hiện thêm trong quá trình audit (không có trong tài liệu gốc, nhưng là hệ quả logic bắt buộc).
- **Trạng thái:** ✅ Duyệt.
- **Test:** `test_system_health_camera_shifted_textureless` — PASS. Xác nhận `LENS_DEGRADED=True` khi ảnh trơn (Laplacian var thấp) bắt được case này.

### [REQ-013b-2] CAMERA_SHIFTED — Large-Displacement Tracking Loss (texture cao)
- **Nội dung:** Dịch chuyển đột ngột lớn dù ảnh vẫn sắc nét (khác REQ-013b-1) → `tracking_lost=True` → `CAMERA_SHIFTED=True`, đồng thời `LENS_DEGRADED=False`.
- **Nguồn:** `vulnerability_analysis.md` mục 13.2 (kịch bản chính: "ai đó đụng trúng camera").
- **Trạng thái:** ✅ Duyệt.
- **Test:** `test_system_health_camera_shifted_massive_high_texture` — PASS (dịch 150px bằng `cv2.warpAffine` trên frame nhiều hình chữ nhật).
- **Backlog nhẹ (không chặn):** Mới test dịch chéo (X+Y đồng thời 150px). Nên bổ sung test dịch 1 trục (chỉ ngang hoặc chỉ dọc) khi có thời gian.

### [REQ-013c] LENS_DEGRADED (Laplacian Variance)
- **Ngưỡng:** `laplacian_var < 50.0`, kiểm tra mỗi 2 giây.
- **Nguồn:** `vulnerability_analysis.md` mục 13.3.
- **Trạng thái:** ✅ Duyệt. **Test:** `test_system_health_lens_degraded` — PASS.

### [REQ-013d] STREAM_FROZEN
- **Ngưỡng test dùng:** giống hệt nhau >5s (`frozen_timeout=5.0`) — *lưu ý: tài liệu gốc không ghi số giây cụ thể cho ngưỡng này, 5.0s là giá trị agent tự chọn, chưa từng được duyệt tường minh.*
- **Nguồn:** `vulnerability_analysis.md` mục 11.2.
- **Trạng thái:** ✅ Duyệt về mặt cơ chế. ⚠️ **Cần duyệt riêng ngưỡng 5.0s** — chưa từng được hỏi thẳng.
- **Trạng thái cấu trúc (Đã xử lý 2026-07-08):**
  `SystemHealthMonitor` (bao gồm toàn bộ logic STREAM_FROZEN, CAMERA_OFFLINE, LENS_DEGRADED, CAMERA_SHIFTED) ĐÃ ĐƯỢC DI CHUYỂN vào `ver9.py` và được file test `test_ver9_infra.py` import trực tiếp. Các test REQ-013a/b/c/d đang chạy trên code production thật, tuân thủ đúng Quy tắc #2 của SPEC.md ("Test phải gọi hàm production thật").
- **Quy tắc nghiệp vụ bắt buộc đi kèm:** Nếu đang `LYING` mà `STREAM_FROZEN` xảy ra →
  **KHÔNG** tạm dừng Lying Timer (thà báo giả còn hơn bỏ lọt). Chưa audit việc này có thực sự
  được code hay chưa — `update_lying_timer()` được gọi ở đâu trong main loop?

### [REQ-014] EDGE_TRUNCATED
- **Ngưỡng:** Ngưỡng thực tế trong code là 5px (x1<5, y1<5, x2>width-5, y2>height-5), KHÁC với giá trị 0px từng được ghi trong SPEC.md gốc (nguồn vulnerability_analysis.md mục 7). Sai lệch này CHƯA được giải quyết, giữ nguyên 5px theo yêu cầu không tự đổi ngưỡng production, chờ quyết định chính thức của chủ dự án.
- **Nguồn:** `vulnerability_analysis.md` mục 7.
- **Trạng thái:** ✅ ĐÃ TRIỂN KHAI. 
  - **Code:** Tính toán thật qua hàm helper `check_edge_truncated()` và gọi trực tiếp trong main loop.
  - **Xóa an toàn cache:** Track chạm biên trước khi mất hình sẽ bị xóa ngay lập tức khỏi `track_lost_cache`, ngăn chặn hoàn toàn việc bị bốc lên thành SUSPECT giả.
- **Test:** `test_person_fsm_quality_flags` — PASS, sử dụng hàm production thay vì gán thủ công.

### [REQ-015] ID_SWAP_WARNING
- **Ngưỡng:** Y-velocity > 200px trong 1 frame (33ms) → phi vật lý. LƯU Ý: Đây là số ASSUMED placeholder, cần đo đạc lại bằng script calibration.
- **Nguồn:** `vulnerability_analysis.md` mục 8 — **đã xác minh nguyên văn với người dùng, khớp tài liệu gốc.**
- **Trạng thái:** ✅ ĐÃ TRIỂN KHAI (9/7/2026).
  - **Code:** Tính toán qua hàm helper `check_id_swap_warning()`. Tích lũy bằng counter `id_swap_frames`. Nếu đạt ≥3 frame liên tiếp (N=3), bật cờ `low_confidence = True` để chặn escalation.
- **Test:** `test_id_swap_accumulates_and_triggers_low_confidence` (PASS), `test_id_swap_counter_resets_on_edge_clip` (PASS).

### [REQ-016] TRANSITION_GAP
- **Ngưỡng:** timestamp gap > 500ms (>15 frame ở 30fps).
- **Nguồn:** `vulnerability_analysis.md` mục 10.
- **Trạng thái:** ✅ ĐÃ TRIỂN KHAI (9/7/2026). Bao gồm 2 chốt chặn độc lập bảo vệ FSM:
  - **Chốt 1 (Global Gap):** Phát hiện luồng/mạng bị treo >500ms ở cấp độ vật lý (`cap.read()`). Bật cờ cho mọi track đang active. Miễn nhiễm và an toàn với Adaptive Skip & Hibernation.
  - **Chốt 2 (Per-track Gap):** Phát hiện YOLO miss/bị che khuất. Đo thời gian lưu trú trong `track_lost_cache` >500ms khi track được Re-ID thành công.
- **Hành vi bắt buộc đi kèm:** Log tách biệt "Data Quality Event" khác "AI Decision Event" (Đã hoàn thiện chung với REQ-020).

### [REQ-Flag-Class] Phân tầng Global Flags vs Per-Track Flags
- **Nguồn:** `vulnerability_analysis.md` mục 13 (hộp TIP).
- **Trạng thái:** ✅ Ngầm tuân thủ qua kiến trúc `SystemHealthMonitor` (global) tách biệt `PersonFSM` (per-track) — nhưng chưa có xác nhận tường minh bằng văn bản từ agent.

---

## DEAD RECKONING — Bước 4, đã duyệt

### [REQ-017] Kalman predict-only khi mất frame
- **Nội dung:** `fsm.kf.predict()` liên tục trong lúc Gap, gắn cờ `low_confidence=True`. Cấm hệ thống tự phán quyết ngã chỉ dựa trên dữ liệu ngoại suy này.
- **Nguồn:** `vulnerability_analysis.md` mục 12.1.
- **Trạng thái:** ❌ HỦY BỎ — Kiến trúc lỗi thời.
  - **Lý do 1 (Xung đột an toàn):** Rủi ro tọa độ trôi dạt (Drifting) khi nội suy mù sẽ phá hỏng mốc tọa độ của `OCCLUSION_SUSPECT` (REQ-023) và sinh ra False Positive cho cờ `is_on_floor`.
  - **Lý do 2 (Kế thừa kiến trúc):** Mục tiêu gốc "Lấp khoảng trống rớt mạng để nuôi model LightGBM" đã được giải quyết triệt để và an toàn hơn. Xem REQ-016 (TRANSITION_GAP, ép SUSPECT bằng quy tắc hình học thay vì ép điểm LightGBM) và REQ-023 (OCCLUSION_SUSPECT) — cả 2 đạt mục tiêu fail-safe tương đương mà không cần nạp dữ liệu ngoại suy ảo vào hệ thống.

### [REQ-017b] Keypoint Geometry Guard
- **Nội dung:** Khi `calculate_torso_angle()` phát hiện hông nằm trên vai (`is_angle_inverted=True`), dấu hiệu lỗi bắt keypoint của YOLO, FSM được gắn `low_confidence=True`. Chặn escalation NORMAL→SUSPECT/FALLING và ép decision='IGNORED (LOW CONFIDENCE)'. Áp dụng độc lập với `TRANSITION_GAP`.
- **Nguồn:** Code thực tế `ver9.py`.
- **Trạng thái:** ✅ ĐÃ TRIỂN KHAI (9/7/2026). Đã vá lỗi **CRITICAL STICKY BUG**: trước đây `low_confidence` bị kẹt `True` vĩnh viễn sau 1 frame lộn ngược. Hiện tại đã được reset `False` ở đầu mỗi vòng lặp `per-frame`.
- **Test:** `test_low_confidence_geometry_guard_blocks_escalation` (PASS), `test_low_confidence_is_reset_per_frame` (PASS).

### [REQ-018] Cấm Linear Interpolation cho luồng AI (chỉ được dùng cho Render)
- **Nguồn:** `vulnerability_analysis.md` mục 12.2.
- **Trạng thái:** ✅ Duyệt theo lời xác nhận của agent ("không tồn tại interpolation nào trong ver9.py, chỉ Kalman"). ⚠️ **Chưa tự kiểm tra bằng cách đọc code render thực tế** — nên grep `interp` trong toàn bộ codebase một lần cho chắc, vì đây là quy tắc "cấm tuyệt đối", rủi ro cao nếu sai.

### [REQ-019] Fixed Timestep (Wall-clock cho Lying Timer)
- **Nguồn:** `vulnerability_analysis.md` mục 12.3.
- **Trạng thái:** ✅ Duyệt. **Test:** `test_fixed_timestep_lying_timer` — PASS (giả lập FPS tụt 5fps/rớt frame, `lying_wall_sec` vẫn đúng theo wall-clock, sai số <0.01s).

### [REQ-020] Xử lý "STANDING→LYING ngay sau Gap" — ép SUSPECT
- **Nội dung:** Khi Gap kết thúc (`low_confidence` trở lại `False`) mà phát hiện đổi tư thế đứng→nằm, phải ép state lên SUSPECT (không được tự tin theo điểm LightGBM, cũng không được im lặng bỏ qua).
- **Nguồn:** `vulnerability_analysis.md` mục 10.
- **Trạng thái:** ✅ ĐÃ SỬA (9/7/2026). Đã hoàn trả thiết kế: ép `SUSPECT` thay vì nhảy thẳng `FALLING`, không bypass xác nhận N-frame (để lại cho FSM tự tích lũy qua Nhánh 2/3), có log Data Quality Event riêng. Đã xử lý bug kẹt trạng thái ZOMBIE của OCCLUSION_SUSPECT (REQ-023) nhờ mở rộng vùng check thành `state in ("NORMAL", "SUSPECT")`.

---

## ⚠️ CHƯA XÁC NHẬN — CẦN HỎI TRƯỚC KHI NGHIỆM THU TỔNG THỂ

### [REQ-021] Slow Slide Override (Nghịch lý Động lực học — vế 1)
- **Nội dung:** Dù vận tốc ngã chậm khiến LightGBM chấm điểm thấp, FSM vẫn phải tự quét hình học (Aspect ratio nằm + Danger Zone) qua từng frame để **ghi đè xác nhận ngã độc lập với điểm ML**.
- **Nguồn:** `vulnerability_analysis.md` mục 6, chiến lược khắc phục #1.
- **Trạng thái:** ✅ Duyệt (2026-07-08).
- **Implement:** Nhánh `else` (score < SUSPECT_LOW) trong `evaluate_fsm_transition()` có đường hình học độc lập: nếu `geometry_confirms` (is_on_floor AND is_lying_pose OR angle > ANGLE_THRESHOLD) đủ N=SUSPECT_CONFIRM_FRAMES thì escalate FALLING bất kể điểm ML. Bổ sung `is_suspect_cleared` + `geometry_clear_frames` tránh vòng lặp reset vô hạn. Nhánh score thấp-hình học chớp nhoáng có Delay Reset có chủ đích (xem docstring trong code).
- **Test:** `test_evaluate_fsm_slow_slide_override` — **PASS**. Mô phỏng score=40 (<SUSPECT_LOW=50) liên tục, is_on_floor=True + is_lying_pose=True suốt N frame → escalate FALLING.

### [REQ-022] Fast Flop Safe Zone Override (Nghịch lý Động lực học — vế 2)
- **Nội dung:** Dù AI chấm 99% ngã, nếu đích đến là Safe Zone (Giường) → dập tắt báo động.
- **Nguồn:** `vulnerability_analysis.md` mục 6, chiến lược khắc phục #2.
- **Trạng thái:** 🔲 Chưa audit — phụ thuộc vào việc Safe Zone đã được vẽ/lưu trữ ở đâu (Backend hay AI Server), chưa chạm tới trong các bước hiện tại.

### [REQ-023] Occlusion — Timeout Trigger & CAMERA_OCCLUDED (Global + Per-track)
- **Nội dung:** Kết hợp phát hiện che khuất ở 2 cấp độ:
  - **Per-track (OCCLUSION_SUSPECT):** Track biến mất GIỮA khung hình (không chạm biên `EDGE_MARGIN=30`) → vượt quá `OCCLUSION_TIMEOUT=4s` → ép trạng thái FSM thành `SUSPECT`.
  - **Global (CAMERA_OCCLUDED):** Gồm 2 tín hiệu kết hợp bằng OR để định hình trạng thái che camera toàn cục (và làm cross-reference ức chế `LENS_DEGRADED`/`STREAM_FROZEN`):
    - **Tín hiệu 1:** Có track chiếm `Area Ratio > 0.95` (`OCCLUSION_AREA_THRESHOLD`).
    - **Tín hiệu 2:** Phòng trống (`person_count == 0`) kéo dài `> 5s` VÀ track cuối cùng trước khi mất có kích thước rất lớn (`last_known_max_ar >= 0.50`).
- **Nguồn:** `vulnerability_analysis.md` mục 1, dữ liệu thực nghiệm K1-K4 Calibration (2026-07-09).
- **Trạng thái:** ✅ Duyệt hoàn tất (Đã có test đối chứng).
  - ⚠️ **BUG ĐÃ PHÁT HIỆN & SỬA (9/7/2026):** Trước đây, track được ép sang SUSPECT bởi OCCLUSION_SUSPECT khi tái xuất hiện (re-identified) sẽ bị "kẹt zombie" vĩnh viễn — do evaluate_fsm_transition() chỉ xử lý state=="NORMAL", bỏ qua hoàn toàn track có state=="SUSPECT", khiến track không bao giờ tự leo lên FALLING dù có ngã thật sau khi tái xuất hiện. Đã sửa cùng lúc với REQ-020 bằng cách mở rộng điều kiện thành `state in ("NORMAL", "SUSPECT")`. Xem chi tiết REQ-020.
- **Tổng kết các ngưỡng (Chốt từ số liệu thực nghiệm):**
  - `OCCLUSION_TIMEOUT`: **4.0s** (Dựa trên K1: ca núp sau vật cản lâu nhất 6.47s).
  - `TTL_NORMAL` (Track Cache): **7.0s** (Nâng từ 5.0s để tạo buffer xử lý `OCCLUSION_TIMEOUT`).
  - `OCCLUSION_AREA_THRESHOLD`: **0.95** (Dựa trên K3 đứng sát max 0.915, K4 che thật min 0.981).
  - `EMPTY_FRAME_DURATION_THRESHOLD`: **5.0s** (Dựa trên K4 mất track 13.85s).
  - `last_known_max_ar threshold`: **0.50** (Ngưỡng an toàn phân biệt K2 đi ngang cực sát max 0.333 và K4 bịt thật min 0.981).
---

## TECHNICAL BACKLOG — Nợ kỹ thuật đã ghi nhận

### [REQ-BACKLOG-001] Tham số hóa Motion Mask Ratio
- **Nội dung:** `mask_y_start = int(h * 0.3)` hiện hardcode trong nhánh Hibernation của Main Loop. Cần tham số hóa thành `--motion-mask-ratio` (float, default `0.3`), hoặc tự suy ra từ `floor_zone_ratio`.
- **Lý do chưa làm ngay:** Giá trị 0.3 hợp lý cho phần lớn deployment camera trần nhà nhìn xuống. Không ảnh hưởng an toàn — chỉ ảnh hưởng hiệu năng CPU khi môi trường có nhiều nhiễu ánh sáng/cây cối.
- **Ưu tiên:** THẤP.
- **Vị trí code:** `ver9.py` — Hibernation block, có TODO comment `# TODO: parameterize via args.motion_mask_ratio`.
- **Ghi nhận:** 2026-07-08.

---

## LỊCH SỬ CÁC LẦN PHÁT HIỆN SỐ LIỆU/HÀNH VI TỰ Ý THÊM (chưa xin phép)

| Lần | Nội dung | Agent xử lý | Kết quả |
|---|---|---|---|
| 1 | `EDGE_TRUNCATED` margin = 5px thay vì 0 | Yêu cầu giải trình → agent tự sửa về 0 | ✅ Đã fix |
| 2 | ID_SWAP mock 250px | Hóa ra chỉ là giá trị test, ngưỡng thật 200px khớp tài liệu (đã tự xác minh) | ✅ Không phải lỗi |
| 3 | Optical Flow "fix logic tiện tay" khi mất dấu hoàn toàn | Yêu cầu tách diff + test riêng | ✅ Đã tách & verify |
| 4 | Test `low_confidence` duplicate logic thay vì gọi hàm thật | Yêu cầu refactor `evaluate_fsm_transition()` | ✅ Đã refactor |
| 5 | STREAM_FROZEN timeout = 5.0s | **Chưa hỏi** — tài liệu gốc không ghi số cụ thể | ⚠️ Cần duyệt riêng (xem REQ-013d) |

---

## QUY TRÌNH SỬ DỤNG FILE NÀY CHO CÁC BƯỚC TIẾP THEO

Mỗi khi agent báo cáo hoàn thành 1 REQ:
1. Đối chiếu đúng dòng REQ-ID — không chấp nhận báo cáo không map được vào bảng này.
2. Bắt buộc có: (a) source code thật, (b) log `pytest -v` đầy đủ tên test, (c) xác nhận test gọi hàm production chứ không duplicate logic.
3. Cập nhật cột Trạng thái trong bảng, chuyển 🔲 → ✅ hoặc giữ ⚠️ nếu còn thiếu sót.
4. Không mở bước kế tiếp khi còn REQ nào của bước hiện tại ở trạng thái 🔲/⚠️ mà thuộc phạm vi bắt buộc của bước đó.
