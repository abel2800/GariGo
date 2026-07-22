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

/// Circular profile photo — tap opens a full-screen preview.
class GariProfileAvatar extends StatelessWidget {
  const GariProfileAvatar({
    super.key,
    this.imageUrl,
    required this.fallbackLetter,
    this.radius = 25,
    this.onTap,
  });

  final String? imageUrl;
  final String fallbackLetter;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImg = imageUrl != null && imageUrl!.isNotEmpty;
    final letter = fallbackLetter.trim().isNotEmpty
        ? fallbackLetter.trim()[0].toUpperCase()
        : '?';

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: GariColors.nightBlue,
      backgroundImage: hasImg ? NetworkImage(imageUrl!) : null,
      child: hasImg
          ? null
          : Text(
              letter,
              style: TextStyle(
                color: GariColors.amber400,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.7,
              ),
            ),
    );

    return GestureDetector(
      onTap: onTap ??
          (hasImg
              ? () => showGariPhotoPreview(context, imageUrl!)
              : null),
      child: avatar,
    );
  }
}

void showGariPhotoPreview(BuildContext context, String imageUrl) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.pop(ctx),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void showGariContactSheet(
  BuildContext context, {
  required String title,
  required String name,
  String? photoUrl,
  String? phone,
  String? subtitle,
  List<String> details = const [],
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: GariColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppText.headline(ctx)),
              const SizedBox(height: 16),
              GariProfileAvatar(
                imageUrl: photoUrl,
                fallbackLetter: name,
                radius: 44,
              ),
              const SizedBox(height: 12),
              Text(name, style: AppText.title(ctx)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle,
                    style: AppText.caption(ctx, color: GariColors.muted)),
              ],
              if (phone != null && phone.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(phone,
                    style: AppText.headline(ctx)
                        .copyWith(color: GariColors.amberDeep)),
              ],
              for (final d in details) ...[
                const SizedBox(height: 6),
                Text(d,
                    style: AppText.caption(ctx, color: GariColors.muted)),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Dark auth / landing billboard — curved sheet edge + route line.
class GariBillboardHero extends StatefulWidget {
  const GariBillboardHero({
    super.key,
    required this.isAm,
    required this.onLang,
    required this.brandLabel,
    required this.headline,
    this.height = 248,
    this.leading,
  });

  final bool isAm;
  final ValueChanged<bool> onLang;
  final String brandLabel;
  final InlineSpan headline;
  final double height;
  final Widget? leading;

  @override
  State<GariBillboardHero> createState() => _GariBillboardHeroState();
}

class _GariBillboardHeroState extends State<GariBillboardHero>
    with TickerProviderStateMixin {
  static const _ink = Color(0xFF0B0F1A);

  late final AnimationController _enter;
  late final AnimationController _route;
  late final Animation<double> _brandFade;
  late final Animation<Offset> _brandSlide;
  late final Animation<double> _headFade;
  late final Animation<Offset> _headSlide;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _route = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _brandFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _brandSlide = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    ));
    _headFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.28, 0.85, curve: Curves.easeOut),
    );
    _headSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.28, 0.9, curve: Curves.easeOutCubic),
    ));
    _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    _route.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: widget.height + top,
      width: double.infinity,
      child: ClipPath(
        clipper: const _BillboardSheetClipper(),
        child: ColoredBox(
          color: _ink,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _route,
                  builder: (_, __) => CustomPaint(
                    painter: _BillboardRoutePainter(progress: _route.value),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, top + 14, 16, 44),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeTransition(
                      opacity: _brandFade,
                      child: SlideTransition(
                        position: _brandSlide,
                        child: Row(
                          children: [
                            if (widget.leading != null) ...[
                              widget.leading!,
                              const SizedBox(width: 4),
                            ],
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: GariColors.amber,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'G',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Color(0xFF3D2606),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.brandLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFFBF3E4),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _LangToggle(
                              isAm: widget.isAm,
                              onLang: widget.onLang,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    FadeTransition(
                      opacity: _headFade,
                      child: SlideTransition(
                        position: _headSlide,
                        child: Text.rich(
                          widget.headline,
                          style: const TextStyle(
                            color: Color(0xFFFBF3E4),
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.isAm, required this.onLang});
  final bool isAm;
  final ValueChanged<bool> onLang;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF3E4).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip('EN', !isAm, () => onLang(false)),
          _chip('አማ', isAm, () => onLang(true)),
        ],
      ),
    );
  }

  Widget _chip(String t, bool on, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? GariColors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: on
                ? const Color(0xFF3D2606)
                : const Color(0xFFFBF3E4).withValues(alpha: 0.62),
          ),
        ),
      ),
    );
  }
}

/// Soft concave bottom — cream sheet reads as curling up under the billboard.
class _BillboardSheetClipper extends CustomClipper<Path> {
  const _BillboardSheetClipper();

  @override
  Path getClip(Size size) {
    final dip = (size.height * 0.18).clamp(36.0, 56.0);
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - dip * 0.25)
      ..cubicTo(
        size.width * 0.78,
        size.height - dip * 1.15,
        size.width * 0.22,
        size.height - dip * 1.15,
        0,
        size.height - dip * 0.25,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _BillboardRoutePainter extends CustomPainter {
  _BillboardRoutePainter({required this.progress});
  final double progress;

  Path _route(Size size) {
    final y = size.height * 0.55;
    return Path()
      ..moveTo(-10, y + 18)
      ..cubicTo(
        size.width * 0.2,
        y - 22,
        size.width * 0.38,
        y + 36,
        size.width * 0.58,
        y + 6,
      )
      ..cubicTo(
        size.width * 0.76,
        y - 24,
        size.width * 0.9,
        y + 20,
        size.width + 12,
        y - 10,
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _route(size);
    final line = Paint()
      ..color = const Color(0xFFFBF3E4).withValues(alpha: 0.22)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      const dash = 3.5;
      const gap = 6.0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), line);
        dist += dash + gap;
      }

      final t = progress % 1.0;
      final tan = metric.getTangentForOffset(metric.length * t);
      if (tan != null) {
        canvas.drawCircle(
          tan.position,
          3.6,
          Paint()..color = GariColors.amber,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BillboardRoutePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
