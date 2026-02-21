import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? accentBorder; // left-side status stripe color (optional)
  final bool gradientBorder; // use cyan→purple gradient border

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 12.0,
    this.opacity = 0.04,
    this.borderRadius = 12.0,
    this.padding,
    this.margin,
    this.accentBorder,
    this.gradientBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surface
                .withValues(alpha: 0.8 + opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: gradientBorder
                ? null
                : Border.all(
                    color: Theme.of(context).colorScheme.outline,
                    width: 1.0),
          ),
          child: accentBorder != null
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: accentBorder,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(borderRadius),
                            bottomLeft: Radius.circular(borderRadius),
                          ),
                        ),
                      ),
                      Expanded(child: child),
                    ],
                  ),
                )
              : child,
        ),
      ),
    );

    if (gradientBorder) {
      card = Container(
        decoration: BoxDecoration(
          gradient: AppTheme.cardBorderGradient,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: const EdgeInsets.all(1),
        child: card,
      );
    }

    return Container(margin: margin, child: card);
  }
}

/// Shimmer placeholder card — use during loading
class ShimmerCard extends StatelessWidget {
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerCard({
    super.key,
    this.height = 100,
    this.borderRadius = 12,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}
