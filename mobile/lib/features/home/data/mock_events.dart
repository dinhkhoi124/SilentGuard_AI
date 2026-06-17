// lib/features/home/data/mock_events.dart

import 'package:mobile/features/home/domain/entities/camera_event.dart';

const List<CameraEvent> mockCameraEvents = [
  CameraEvent(
    id: 'e1',
    time: '09:35 AM',
    title: 'Nghi ngờ té ngã',
    description: 'Chưa phát hiện đứng dậy',
    level: EventLevel.high,
    type: EventType.fall,
  ),
  CameraEvent(
    id: 'e2',
    time: '08:12 AM',
    title: 'Nằm bất động',
    description: 'Nằm 45 giây, sau đó đã di chuyển',
    level: EventLevel.medium,
    type: EventType.still,
  ),
  CameraEvent(
    id: 'e3',
    time: '07:45 AM',
    title: 'Hoạt động bình thường',
    description: 'Di chuyển trong khu vực',
    level: EventLevel.normal,
    type: EventType.normal,
  ),
  CameraEvent(
    id: 'e4',
    time: '07:30 AM',
    title: 'Camera hoạt động trở lại',
    description: 'Mất kết nối 2 phút',
    level: EventLevel.info,
    type: EventType.reconnect,
  ),
];
