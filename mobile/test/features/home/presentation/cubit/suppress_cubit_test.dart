// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/monitoring_suppress_service.dart';
import 'package:mobile/features/home/presentation/cubit/suppress_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SuppressCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    cubit = SuppressCubit(
      MonitoringSuppressService(sharedPreferences: prefs),
    );
  });

  tearDown(() => cubit.close());

  test('loads inactive state when no suppression exists', () async {
    await cubit.loadState('camera-a');

    expect(cubit.state, isA<SuppressInactive>());
  });

  test('pauses and resumes monitoring', () async {
    await cubit.pauseMonitoring('camera-a', 15);

    final active = cubit.state as SuppressActive;
    expect(active.cameraId, 'camera-a');
    expect(active.suppressedUntil.isAfter(DateTime.now().toUtc()), isTrue);

    await cubit.resumeMonitoring('camera-a');

    expect(cubit.state, isA<SuppressInactive>());
  });
}
