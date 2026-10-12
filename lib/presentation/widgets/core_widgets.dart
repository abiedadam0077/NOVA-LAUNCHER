import 'package:flutter/material.dart';

import '../../core/colors.dart';
import '../../core/motion.dart';

/// Glassmorphism card — restrained and performance-safe.
class NovaGlassCard extends StatelessWidget {
  const NovaGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: novaGlass(),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class NovaGradientButton extends StatelessWidget {
  const NovaGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 52,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: 1,
      duration: NovaMotion.fast,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onPressed : null,
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: enabled ? NovaColors.playGradient : null,
              color: enabled ? null : NovaColors.surfaceLight,
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: NovaColors.electricBlue.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: NovaColors.bgDeep, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: NovaColors.bgDeep,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NovaOutlineButton extends StatelessWidget {
  const NovaOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? NovaColors.danger : NovaColors.electricBlue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.5)),
            color: color.withOpacity(0.08),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: NovaColors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- states

class NovaLoading extends StatelessWidget {
  const NovaLoading({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          if (label != null) ...[
            const SizedBox(height: 12),
            Text(label!, style: const TextStyle(color: NovaColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class NovaEmpty extends StatelessWidget {
  const NovaEmpty({super.key, required this.message, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: NovaColors.textSecondary.withOpacity(0.6)),
          const SizedBox(height: 10),
          Text(message,
              style: const TextStyle(color: NovaColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class NovaError extends StatelessWidget {
  const NovaError({super.key, required this.message, this.onRetry, this.details});
  final String message;
  final VoidCallback? onRetry;
  final String? details;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: NovaColors.danger, size: 40),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: NovaColors.textPrimary)),
            if (details != null) ...[
              const SizedBox(height: 8),
              Text(details!,
                  style: const TextStyle(
                      color: NovaColors.textSecondary, fontSize: 12)),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              NovaOutlineButton(
                label: '↻',
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
