// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/monitoring_suppress_service.dart';
import 'package:mobile/features/home/presentation/cubit/suppress_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late SuppressCubit cubit;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    cubit = SuppressCubit(
      MonitoringSuppressService(sharedPreferences: SharedPreferencesAsync()),
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
