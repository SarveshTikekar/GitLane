import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = Responsive.isCompact(context);
    final horizontalPadding = width < 360 ? 24.0 : 40.0;
    final iconContainerSize = compact ? 70.0 : 80.0;
    final iconSize = compact ? 32.0 : 36.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.maxContentWidth(width),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconContainerSize,
                height: iconContainerSize,
                decoration: BoxDecoration(
                  color: (iconColor ?? AppTheme.accentCyan).withValues(
                    alpha: 0.1,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (iconColor ?? AppTheme.accentCyan).withValues(
                      alpha: 0.3,
                    ),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: iconColor ?? AppTheme.accentCyan,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: compact ? 16 : 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: compact ? 13 : 14,
                  height: 1.5,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact inline empty state (for use inside cards/sections)
class EmptyStateInline extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color? color;

  const EmptyStateInline({
    super.key,
    required this.icon,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color ?? AppTheme.textMuted),
          const SizedBox(width: 8),
          Text(
            message,
            style: GoogleFonts.inter(
              color: color ?? AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
