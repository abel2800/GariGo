import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../utils/money.dart';

export 'map_canvas.dart';

class GariPrimaryButton extends StatelessWidget {
  const GariPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !loading && onPressed != null;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: canTap ? onPressed : null,
        style: ElevatedButton.styleFrom(
          elevation: canTap ? 4 : 0,
          shadowColor: GariColors.amberGlow,
          backgroundColor: GariColors.amber,
          foregroundColor: GariColors.nightBlue,
          disabledBackgroundColor: GariColors.amber.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GariSpacing.radiusMd),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: GariColors.nightBlue,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: GariColors.nightBlue, size: 20),
                    const SizedBox(width: GariSpacing.sm),
                  ],
                  Text(
                    label,
                    style: AppText.headline(
                      context,
                      color: GariColors.nightBlue,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class GariSecondaryButton extends StatelessWidget {
  const GariSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: GariColors.nightBlue,
          side: const BorderSide(color: GariColors.nightBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GariSpacing.radiusMd),
          ),
        ),
        child: Text(label, style: AppText.headline(context)),
      ),
    );
  }
}

enum GariPillTone { online, offline, pending, approved, rejected, amber, navy }

class GariStatusPill extends StatelessWidget {
  const GariStatusPill({
    super.key,
    required this.label,
    this.tone = GariPillTone.navy,
  });

  final String label;
  final GariPillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      GariPillTone.online => (GariColors.emeraldSoft, GariColors.emerald),
      GariPillTone.offline => (GariColors.crimsonSoft, GariColors.crimson),
      GariPillTone.pending => (GariColors.amberGlow, GariColors.amberDeep),
      GariPillTone.approved => (GariColors.emeraldSoft, GariColors.emerald),
      GariPillTone.rejected => (GariColors.crimsonSoft, GariColors.crimson),
      GariPillTone.amber => (GariColors.amberGlow, GariColors.amberDeep),
      GariPillTone.navy => (GariColors.nightBlue, GariColors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GariSpacing.md,
        vertical: GariSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: AppText.caption(context, color: fg)),
    );
  }
}

class GariCard extends StatelessWidget {
  const GariCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.dark = false,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool dark;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(GariSpacing.lg),
      decoration: BoxDecoration(
        color: dark ? GariColors.surfaceDark : GariColors.surfaceLight,
        borderRadius: BorderRadius.circular(GariSpacing.radiusLg),
        border: Border.all(
          color: borderColor ?? (dark ? Colors.transparent : GariColors.border),
          width: borderColor != null ? 2 : 1.5,
        ),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: GariColors.nightBlue.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GariSpacing.radiusLg),
        child: content,
      ),
    );
  }
}

class GariTextField extends StatelessWidget {
  const GariTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.prefix,
    this.keyboardType,
    this.onChanged,
    this.inputFormatters,
    this.maxLength,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.obscureText = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final Widget? prefix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppText.label(context)),
          const SizedBox(height: GariSpacing.sm),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: autofocus,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          style: AppText.headline(context),
          cursorColor: GariColors.amber,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.body(context),
            prefixIcon: prefix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: GariSpacing.md),
                    child: prefix,
                  ),
            prefixIconConstraints: const BoxConstraints(),
            counterText: '',
            filled: true,
            fillColor: GariColors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: GariSpacing.lg,
              vertical: GariSpacing.lg,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GariSpacing.radiusMd),
              borderSide: BorderSide(
                color: errorText != null
                    ? GariColors.crimson
                    : GariColors.nightBlue.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GariSpacing.radiusMd),
              borderSide: BorderSide(
                color: errorText != null ? GariColors.crimson : GariColors.amber,
                width: 2,
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: GariSpacing.sm),
          Text(
            errorText!,
            style: AppText.caption(context, color: GariColors.crimson),
          ),
        ],
      ],
    );
  }
}

class PhonePrefixChip extends StatelessWidget {
  const PhonePrefixChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: GariSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: GariSpacing.md,
        vertical: GariSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: GariColors.nightBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(GariSpacing.radiusSm),
      ),
      child: Text('+251', style: AppText.headline(context)),
    );
  }
}

class BirrText extends StatelessWidget {
  const BirrText(this.amount, {super.key, this.size = 28, this.color});
  final num amount;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatBirr(amount),
      style: AppText.money(context, color: color, size: size),
    );
  }
}

class AnimatedFareCounter extends StatelessWidget {
  const AnimatedFareCounter({
    super.key,
    required this.amount,
    this.size = 22,
  });

  final int amount;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: amount.toDouble(), end: amount.toDouble()),
      duration: const Duration(milliseconds: 400),
      builder: (_, __, ___) => BirrText(
        amount,
        size: size,
        color: GariColors.nightBlue,
      ),
    );
  }
}

class GariEmptyState extends StatelessWidget {
  const GariEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.ctaLabel,
    this.onCta,
  });

  final IconData icon;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GariSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: GariColors.slate.withValues(alpha: 0.4)),
            const SizedBox(height: GariSpacing.lg),
            Text(message, textAlign: TextAlign.center, style: AppText.body(context)),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: GariSpacing.lg),
              TextButton(
                onPressed: onCta,
                child: Text(
                  ctaLabel!,
                  style: AppText.label(context, color: GariColors.amberDeep),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<T?> showGariSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(ctx).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: GariColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GariSpacing.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: GariSpacing.md),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: GariColors.nightBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Flexible(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                GariSpacing.lg,
                GariSpacing.lg,
                GariSpacing.lg,
                GariSpacing.lg + MediaQuery.of(ctx).padding.bottom,
              ),
              child: child,
            ),
          ),
        ],
      ),
    ),
  );
}
