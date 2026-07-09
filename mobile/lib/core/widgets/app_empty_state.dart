import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class AppEmptyState extends StatefulWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.compact = false,
    this.animate = true,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final bool compact;
  final bool animate;

  @override
  State<AppEmptyState> createState() => _AppEmptyStateState();
}

class _AppEmptyStateState extends State<AppEmptyState>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late AnimationController _floatController;
  late Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // Entrance Animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    final entranceCurve = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(entranceCurve);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(entranceCurve);

    // Float Animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _floatAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, -0.05),
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0, -0.05),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
    ]).animate(_floatController);

    if (widget.animate) {
      _entranceController.forward();
      _floatController.repeat();
    } else {
      _entranceController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleStyle = widget.compact
        ? theme.textTheme.titleMedium
        : theme.textTheme.titleLarge;

    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: isDark ? theme.colorScheme.onSurfaceVariant : AppColors.mutedText,
      height: 1.4,
    );

    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : AppColors.darkText;

    final iconSize = widget.compact ? 32.0 : 42.0;
    final blobSize = widget.compact ? 72.0 : 96.0;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SlideTransition(
          position: _floatAnimation,
          child: Container(
            width: blobSize,
            height: blobSize,
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerHighest
                  : const Color(0xFFE8F0FE),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: iconSize,
                color: isDark ? theme.colorScheme.primary : AppColors.primary,
              ),
            ),
          ),
        ),
        SizedBox(height: widget.compact ? 16 : 24),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: titleStyle?.copyWith(
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 16.0 : 32.0,
          ),
          child: Text(
            widget.message,
            textAlign: TextAlign.center,
            style: bodyStyle,
          ),
        ),
        if (widget.primaryActionLabel != null &&
            widget.onPrimaryAction != null) ...[
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: widget.onPrimaryAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 24 : 32,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
              ),
              elevation: 0,
            ),
            child: Text(
              widget.primaryActionLabel!,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );

    if (widget.animate) {
      content = FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(position: _slideAnimation, child: content),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: content,
      ),
    );
  }
}
