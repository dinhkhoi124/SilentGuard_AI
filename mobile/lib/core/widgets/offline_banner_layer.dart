import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/connectivity/connectivity_cubit.dart';

class OfflineBannerLayer extends StatefulWidget {
  const OfflineBannerLayer({super.key, required this.child});
  final Widget child;

  @override
  State<OfflineBannerLayer> createState() => _OfflineBannerLayerState();
}

class _OfflineBannerLayerState extends State<OfflineBannerLayer> {
  Timer? _dismissTimer;
  bool _wasOffline = false;
  bool _showSuccessBanner = false;
  bool _isGracePeriod = true;

  @override
  void initState() {
    super.initState();
    // Grace period on app startup to allow DNS resolution to complete.
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isGracePeriod = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _handleState(ConnectivityState state) {
    if (state is ConnectivityOffline) {
      _dismissTimer?.cancel();
      setState(() {
        _wasOffline = true;
        _showSuccessBanner = false;
      });
    } else if (state is ConnectivityOnline) {
      if (_wasOffline) {
        setState(() {
          _wasOffline = false;
          _showSuccessBanner = true;
        });
        _dismissTimer?.cancel();
        _dismissTimer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted) {
            setState(() {
              _showSuccessBanner = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectivityCubit, ConnectivityState>(
      listener: (context, state) => _handleState(state),
      child: Stack(
        children: [
          widget.child,
          BlocBuilder<ConnectivityCubit, ConnectivityState>(
            builder: (context, state) {
              final isOffline = state is ConnectivityOffline;
              final showBanner =
                  (isOffline && !_isGracePeriod) || _showSuccessBanner;

              return Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      );
                    },
                    child: showBanner
                        ? _BannerContent(
                            key: ValueKey(isOffline),
                            isOffline: isOffline,
                          )
                        : const SizedBox.shrink(key: ValueKey('empty')),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({super.key, required this.isOffline});
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final bgColor = isOffline ? Colors.amber.shade800 : Colors.green.shade600;
    final icon = isOffline ? Icons.wifi_off : Icons.wifi;
    final text = isOffline ? 'Không có kết nối mạng' : 'Đã kết nối lại';

    return Material(
      color: bgColor,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
