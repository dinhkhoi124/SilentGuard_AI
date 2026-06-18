// lib/features/home/data/mock_events.dart

import 'package:mobile/features/home/domain/entities/camera_event.dart';

enum MockEventFeedbackStatus {
  unreviewed,
  submitting,
  acknowledged,
  dismissed,
  uncertain,
  failed,
}

const List<CameraEvent> mockCameraEvents = [
  CameraEvent(
    id: 'e1',
    time: '09:35 AM',
    title: 'Nghi ngờ té ngã',
    description: 'Chưa phát hiện đứng dậy sau 20 giây',
    level: EventLevel.high,
    type: EventType.fall,
  ),
  CameraEvent(
    id: 'e2',
    time: '08:12 AM',
    title: 'Nằm bất động',
    description: 'Đang gửi phản hồi để xem trạng thái loading',
    level: EventLevel.medium,
    type: EventType.still,
  ),
  CameraEvent(
    id: 'e3',
    time: '07:45 AM',
    title: 'Đã xác nhận té ngã thật',
    description: 'Người dùng xác nhận đây là cảnh báo đúng',
    level: EventLevel.high,
    type: EventType.fall,
  ),
  CameraEvent(
    id: 'e4',
    time: '07:30 AM',
    title: 'Camera hoạt động trở lại',
    description: 'Mất kết nối 2 phút',
    level: EventLevel.info,
    type: EventType.reconnect,
  ),
  CameraEvent(
    id: 'e5',
    time: 'Hôm qua',
    title: 'Cảnh báo nhầm',
    description: 'Người trong khung hình chỉ cúi xuống nhặt đồ',
    level: EventLevel.medium,
    type: EventType.fall,
  ),
  CameraEvent(
    id: 'e6',
    time: 'Hôm qua',
    title: 'Chưa thể xác định',
    description: 'Vùng nhìn bị che khuất nên cần xem lại',
    level: EventLevel.medium,
    type: EventType.still,
  ),
  CameraEvent(
    id: 'e7',
    time: 'Thứ 2',
    title: 'Chưa đồng bộ phản hồi',
    description: 'Mô phỏng gửi thất bại để test nút thử lại',
    level: EventLevel.high,
    type: EventType.fall,
  ),
];

const Map<String, MockEventFeedbackStatus> mockEventFeedbackStatuses = {
  'e1': MockEventFeedbackStatus.unreviewed,
  'e2': MockEventFeedbackStatus.submitting,
  'e3': MockEventFeedbackStatus.acknowledged,
  'e4': MockEventFeedbackStatus.unreviewed,
  'e5': MockEventFeedbackStatus.dismissed,
  'e6': MockEventFeedbackStatus.uncertain,
  'e7': MockEventFeedbackStatus.failed,
};
