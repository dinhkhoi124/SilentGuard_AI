// lib/features/home/data/mock_devices.dart

import 'package:mobile/features/home/domain/entities/camera_device.dart';

const List<CameraDevice> mockCameraDevices = [
  CameraDevice(
    id: '1',
    name: 'CAMERA PHÒNG KHÁCH',
    location: 'Phòng khách',
    status: 'Đang trực tuyến',
    isArmed: true,
    accessories: ['Đèn 1', 'Đèn 2', 'Ổ cắm'],
    accessoryStates: [true, true, false],
  ),
  CameraDevice(
    id: '2',
    name: 'CAMERA PHÒNG NGỦ',
    location: 'Phòng ngủ',
    status: 'Đang trực tuyến',
    isArmed: true,
    accessories: ['Đèn 1', 'Quạt'],
    accessoryStates: [false, true],
  ),
  CameraDevice(
    id: '3',
    name: 'CAMERA CỬA TRƯỚC',
    location: 'Lối vào',
    status: 'Ngoại tuyến',
    isArmed: false,
    accessories: ['Đèn sân'],
    accessoryStates: [false],
  ),
  CameraDevice(
    id: '4',
    name: 'CAMERA NHÀ BẾP',
    location: 'Nhà bếp',
    status: 'Đang trực tuyến',
    isArmed: true,
    accessories: ['Đèn bếp', 'Lò vi sóng'],
    accessoryStates: [true, false],
  ),
];
