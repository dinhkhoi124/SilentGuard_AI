import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/services/connectivity_service.dart';

abstract class ConnectivityState {
  const ConnectivityState();
}

class ConnectivityOnline extends ConnectivityState {
  const ConnectivityOnline();
}

class ConnectivityOffline extends ConnectivityState {
  const ConnectivityOffline();
}

class ConnectivityCubit extends Cubit<ConnectivityState>
    with WidgetsBindingObserver {
  ConnectivityCubit(this._connectivityService)
    : super(const ConnectivityOnline()) {
    WidgetsBinding.instance.addObserver(this);
    _subscription = _connectivityService.onConnectivityChanged.listen((
      isOnline,
    ) {
      if (isOnline) {
        _connectivityCheckGeneration++;
        emit(const ConnectivityOnline());
      } else {
        unawaited(_checkInitialState(verifyOffline: true));
      }
    });
  }

  final ConnectivityService _connectivityService;
  StreamSubscription<bool>? _subscription;
  int _connectivityCheckGeneration = 0;

  Future<void> _checkInitialState({bool verifyOffline = false}) async {
    final generation = ++_connectivityCheckGeneration;
    final isOnline = await _connectivityService.isConnected;
    if (isClosed || generation != _connectivityCheckGeneration) return;

    if (isOnline) {
      emit(const ConnectivityOnline());
      return;
    }

    if (verifyOffline) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (isClosed || generation != _connectivityCheckGeneration) return;

      final isStillOffline = !await _connectivityService.isConnected;
      if (isClosed || generation != _connectivityCheckGeneration) return;

      if (!isStillOffline) {
        emit(const ConnectivityOnline());
        return;
      }
    }

    if (!isClosed && generation == _connectivityCheckGeneration) {
      emit(const ConnectivityOffline());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[ConnectivityCubit] didChangeAppLifecycleState: $state');
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkInitialState(verifyOffline: true));
    }
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    return super.close();
  }
}
