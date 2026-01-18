import 'package:flutter/material.dart';

import '../controllers/theme_controller.dart';

/// Content types for the snackbar
enum ContentType {
  success,
  failure,
  warning,
  help,
}

/// Modern custom snackbar that matches the app's design system
SnackBar customSnack(String title, String message, ContentType contentType) {
  return SnackBar(
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    padding: EdgeInsets.zero,
    duration: const Duration(seconds: 4),
    content: _CustomSnackbarContent(
      title: title,
      message: message,
      contentType: contentType,
    ),
  );
}

/// Shows snackbar in the center of the screen
void showSnack(SnackBar banner, BuildContext context) {
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => _CenteredSnackbar(
      snackBar: banner,
      onDismiss: () => overlayEntry.remove(),
    ),
  );

  overlay.insert(overlayEntry);
}

/// Simplified helper to show snackbar directly
void showCustomSnack(
  BuildContext context, {
  required String title,
  required String message,
  required ContentType type,
}) {
  showSnack(customSnack(title, message, type), context);
}

class _CenteredSnackbar extends StatefulWidget {
  final SnackBar snackBar;
  final VoidCallback onDismiss;

  const _CenteredSnackbar({
    required this.snackBar,
    required this.onDismiss,
  });

  @override
  State<_CenteredSnackbar> createState() => _CenteredSnackbarState();
}

class _CenteredSnackbarState extends State<_CenteredSnackbar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Auto dismiss after duration
    Future.delayed(widget.snackBar.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _dismiss,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black.withValues(alpha: 0.1),
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: GestureDetector(
                  onTap: () {}, // Prevent tap from dismissing when tapping content
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: widget.snackBar.content,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomSnackbarContent extends StatelessWidget {
  final String title;
  final String message;
  final ContentType contentType;

  const _CustomSnackbarContent({
    required this.title,
    required this.message,
    required this.contentType,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: config.color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: config.color.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: config.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              config.icon,
              color: config.color,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : const Color(0xFF64748B),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Color accent bar
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: config.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  _SnackbarConfig _getConfig() {
    switch (contentType) {
      case ContentType.success:
        return _SnackbarConfig(
          color: const Color(0xFF22C55E), // Green
          icon: Icons.check_circle_rounded,
        );
      case ContentType.failure:
        return _SnackbarConfig(
          color: const Color(0xFFEF4444), // Red
          icon: Icons.error_rounded,
        );
      case ContentType.warning:
        return _SnackbarConfig(
          color: const Color(0xFFF59E0B), // Amber
          icon: Icons.warning_rounded,
        );
      case ContentType.help:
        return _SnackbarConfig(
          color: AppTheme.accentColor, // App accent color
          icon: Icons.info_rounded,
        );
    }
  }
}

class _SnackbarConfig {
  final Color color;
  final IconData icon;

  _SnackbarConfig({
    required this.color,
    required this.icon,
  });
}
