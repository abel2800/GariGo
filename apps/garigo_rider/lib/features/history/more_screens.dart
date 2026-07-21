import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gari_core/gari_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../shared/providers/providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final historyAsync = ref.watch(tripHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(S.of(isAm).activity)),
      body: historyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: GariColors.amber),
        ),
        error: (e, _) => Center(child: Text(apiError(e))),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(isAm ? 'ጉዞ የለም' : 'No trips yet'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(GariSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: GariSpacing.sm),
            itemBuilder: (_, i) {
              final t = items[i];
              return GariCard(
                onTap: () => context.push('/history/${t.id}/receipt'),
                child: Row(
                  children: [
                    Icon(t.category.icon, color: GariColors.amberDeep),
                    const SizedBox(width: GariSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.route, style: AppText.headline(context)),
                          Text(
                            DateFormat('MMM d · HH:mm').format(t.completedAt),
                            style: AppText.caption(context),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatBirr(t.fare),
                            style: AppText.headline(context)),
                        if (t.rating != null)
                          Text('★ ${t.rating}',
                              style: AppText.caption(context)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    return Scaffold(
      appBar: AppBar(title: Text(isAm ? 'ደረሰኝ' : 'Receipt')),
      body: ListView(
        padding: const EdgeInsets.all(GariSpacing.xl),
        children: [
          GariCard(
            child: Column(
              children: [
                Text('Trip #$id', style: AppText.title(context)),
                const Divider(),
                _r(context, 'Base', '40 Br'),
                _r(context, 'Distance', '30 Br'),
                _r(context, 'Time', '15 Br'),
                _r(context, 'Total', '85 Br'),
              ],
            ),
          ),
          const SizedBox(height: GariSpacing.lg),
          GariSecondaryButton(
            label: isAm ? 'ችግር ሪፖርት' : 'Report an issue',
            onPressed: () => context.push('/support'),
          ),
          const SizedBox(height: GariSpacing.sm),
          GariSecondaryButton(
            label: isAm ? 'የጠፋ ነገር' : 'Lost something?',
            onPressed: () => context.push('/support'),
          ),
        ],
      ),
    );
  }

  Widget _r(BuildContext c, String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: AppText.body(c)),
            Text(v, style: AppText.headline(c)),
          ],
        ),
      );
}

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final api = ref.watch(apiProvider);
    final cardsAsync = ref.watch(savedCardsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(S.of(isAm).wallet)),
      body: ListView(
        padding: const EdgeInsets.all(GariSpacing.xl),
        children: [
          Text(isAm ? 'ቀሪ ሂሳብ' : 'Balance', style: AppText.caption(context)),
          BirrText(api.wallet, size: 40, color: GariColors.nightBlue),
          const SizedBox(height: GariSpacing.lg),
          GariPrimaryButton(
            label: isAm ? 'ሙላ' : 'Top Up',
            onPressed: () => showGariSheet(
              context: context,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isAm ? 'መጠን' : 'Amount', style: AppText.title(context)),
                  Wrap(
                    spacing: 8,
                    children: [50, 100, 200, 500]
                        .map((n) => ActionChip(
                              label: Text('$n Br'),
                              onPressed: () => Navigator.pop(context),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: GariSpacing.lg),
                  GariPrimaryButton(
                    label: 'Telebirr',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: GariSpacing.xl),
          Row(
            children: [
              Text(
                isAm ? 'የባንክ ካርዶች' : 'Bank cards',
                style: AppText.headline(context),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await context.push('/wallet/cards/add');
                  ref.invalidate(savedCardsProvider);
                },
                child: Text(
                  isAm ? 'ጨምር' : 'Add',
                  style: AppText.label(context, color: GariColors.amberDeep),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          cardsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: GariColors.amber),
              ),
            ),
            error: (e, _) => Text(apiError(e)),
            data: (cards) {
              if (cards.isEmpty) {
                return GariCard(
                  onTap: () async {
                    await context.push('/wallet/cards/add');
                    ref.invalidate(savedCardsProvider);
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.add_card, color: GariColors.amberDeep),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isAm
                              ? 'Visa / Mastercard ጨምር'
                              : 'Add a Visa or Mastercard',
                          style: AppText.headline(context),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: cards
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GariCard(
                          child: Row(
                            children: [
                              Icon(
                                Icons.credit_card,
                                color: GariColors.nightBlue,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.label,
                                        style: AppText.headline(context)),
                                    Text(
                                      '${c.holderName} · ${c.expiryLabel}',
                                      style: AppText.caption(context),
                                    ),
                                  ],
                                ),
                              ),
                              if (c.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: GariColors.emeraldSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isAm ? 'ነባሪ' : 'Default',
                                    style: const TextStyle(
                                      color: GariColors.emerald,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: GariColors.crimson),
                                onPressed: () async {
                                  await ref.read(apiProvider).deleteCard(c.id);
                                  ref.invalidate(savedCardsProvider);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: GariSpacing.xl),
          ...api.txns().map((t) => ListTile(
                leading: Icon(
                  t.isCredit ? Icons.add_circle : Icons.remove_circle,
                  color: t.isCredit ? GariColors.emerald : GariColors.crimson,
                ),
                title: Text(t.label, style: AppText.headline(context)),
                subtitle: Text(DateFormat.MMMd().format(t.at)),
                trailing: Text(
                  '${t.isCredit ? '+' : '−'}${formatBirr(t.amount)}',
                  style: AppText.headline(context,
                      color: t.isCredit
                          ? GariColors.emerald
                          : GariColors.crimson),
                ),
              )),
        ],
      ),
    );
  }
}

class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({super.key});
  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  final number = TextEditingController();
  final holder = TextEditingController();
  final expiry = TextEditingController();
  final cvc = TextEditingController();
  bool saveCard = true;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    for (final c in [number, holder, expiry]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    number.dispose();
    holder.dispose();
    expiry.dispose();
    cvc.dispose();
    super.dispose();
  }

  String get _digits => number.text.replaceAll(RegExp(r'\D'), '');

  String get _displayNumber {
    final d = _digits;
    if (d.isEmpty) return '•••• •••• •••• ••••';
    final buf = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(i < d.length ? d[i] : '•');
    }
    return buf.toString();
  }

  String get _displayExpiry {
    final e = expiry.text.replaceAll(RegExp(r'\D'), '');
    if (e.isEmpty) return 'MM/YY';
    if (e.length <= 2) return e.padRight(2, '•');
    return '${e.substring(0, 2)}/${e.substring(2).padRight(2, '•')}';
  }

  String get _brand {
    if (_digits.startsWith('4')) return 'VISA';
    if (RegExp(r'^5[1-5]').hasMatch(_digits) ||
        RegExp(r'^2[2-7]').hasMatch(_digits)) {
      return 'MASTERCARD';
    }
    if (RegExp(r'^3[47]').hasMatch(_digits)) return 'AMEX';
    return 'CARD';
  }

  Future<void> _save() async {
    if (!saveCard) {
      setState(() => error = 'Turn on Save Card to store this card');
      return;
    }
    final digits = _digits;
    if (digits.length < 13) {
      setState(() => error = 'Enter a valid card number');
      return;
    }
    final exp = expiry.text.replaceAll(RegExp(r'\D'), '');
    if (exp.length < 4) {
      setState(() => error = 'Use MM/YY expiry');
      return;
    }
    if (holder.text.trim().length < 2) {
      setState(() => error = 'Enter the name on the card');
      return;
    }
    if (cvc.text.trim().length < 3) {
      setState(() => error = 'Enter CVC');
      return;
    }
    final month = int.tryParse(exp.substring(0, 2)) ?? 0;
    final year = int.tryParse(exp.substring(2)) ?? 0;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final token = await ref.read(apiProvider).getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Please sign in again to save a card');
      }
      ref.read(apiProvider).client.setToken(token);
      await ref.read(apiProvider).addCard(
            number: digits,
            expMonth: month,
            expYear: year,
            cvc: cvc.text.trim(),
            holderName: holder.text.trim(),
            setDefault: saveCard,
          );
      ref.invalidate(savedCardsProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => error = apiError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  InputDecoration _pill(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFFB0B0B0),
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF3F3F3),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: GariColors.amber, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final name = holder.text.trim().isEmpty
        ? 'CARDHOLDER NAME'
        : holder.text.trim().toUpperCase();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: const CircleBorder(
                side: BorderSide(color: Color(0xFFE8E8E8)),
              ),
            ),
            icon: const Icon(Icons.chevron_left, color: GariColors.slate),
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          isAm ? 'ክፍያ' : 'Payment',
          style: const TextStyle(
            color: GariColors.nightBlue,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        children: [
          // Amber payment-card preview (local colors only — not app theme)
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFC94A),
                  GariColors.amber,
                  Color(0xFFE8960E),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: GariColors.amber.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -40,
                  right: -30,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isAm ? 'የካርድ አይነት' : 'CARD TYPE',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const Spacer(),
                          _CardBrandMark(brand: _brand),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const _ChipIcon(),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _displayNumber,
                              style: const TextStyle(
                                color: GariColors.nightBlue,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          Text(
                            'VALID THRU  ›  ${_displayExpiry}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            isAm ? 'የካርድ ዝርዝር' : 'Card Details',
            style: const TextStyle(
              color: GariColors.nightBlue,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: holder,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: GariColors.nightBlue,
              fontWeight: FontWeight.w600,
            ),
            decoration: _pill(isAm ? 'ስም' : 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: number,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: GariColors.nightBlue,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
              _CardNumberFormatter(),
            ],
            decoration: _pill(isAm ? 'የካርድ ቁጥር' : 'Card number'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: expiry,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: GariColors.nightBlue,
                    fontWeight: FontWeight.w600,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                    _ExpiryFormatter(),
                  ],
                  decoration: _pill('MM/YY'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: cvc,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  style: const TextStyle(
                    color: GariColors.nightBlue,
                    fontWeight: FontWeight.w600,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: _pill('CVC'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                isAm ? 'ካርድ አስቀምጥ' : 'Save Card',
                style: const TextStyle(
                  color: GariColors.nightBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Switch.adaptive(
                value: saveCard,
                activeThumbColor: Colors.white,
                activeTrackColor: GariColors.amber,
                onChanged: (v) => setState(() => saveCard = v),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: const TextStyle(
                color: GariColors.crimson,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: busy ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: GariColors.amber,
                foregroundColor: GariColors.nightBlue,
                disabledBackgroundColor:
                    GariColors.amber.withValues(alpha: 0.5),
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: GariColors.nightBlue,
                      ),
                    )
                  : Text(
                      isAm ? 'ካርድ አስቀምጥ' : 'Payment',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipIcon extends StatelessWidget {
  const _ChipIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8C878), Color(0xFFC9A227), Color(0xFFB8860B)],
        ),
        border: Border.all(color: const Color(0xFF9A7209), width: 0.8),
      ),
      child: CustomPaint(painter: _ChipPainter()),
    );
  }
}

class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF8B6914).withValues(alpha: 0.45)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final midY = size.height / 2;
    final midX = size.width / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), p);
    canvas.drawLine(Offset(midX, 0), Offset(midX, size.height), p);
    canvas.drawLine(Offset(0, midY * 0.5), Offset(midX * 0.55, midY * 0.5), p);
    canvas.drawLine(
        Offset(midX * 1.45, midY * 1.5), Offset(size.width, midY * 1.5), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardBrandMark extends StatelessWidget {
  const _CardBrandMark({required this.brand});
  final String brand;

  @override
  Widget build(BuildContext context) {
    if (brand == 'VISA') {
      return const Text(
        'VISA',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 18,
          letterSpacing: 1.5,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    // Mastercard-style overlapping circles (also default)
    return SizedBox(
      width: 44,
      height: 28,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEB001B),
              ),
            ),
          ),
          Positioned(
            right: 0,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF79E1B).withValues(alpha: 0.92),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    var out = digits;
    if (digits.length > 2) {
      out = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}

class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    return Scaffold(
      appBar: AppBar(title: Text(isAm ? 'የተቀመጡ ቦታዎች' : 'Saved places')),
      body: ListView(
        padding: const EdgeInsets.all(GariSpacing.lg),
        children: [
          GariCard(
            child: ListTile(
              leading: const Icon(Icons.home),
              title: Text(isAm ? 'ቤት' : 'Home'),
              subtitle: Text(isAm ? 'ያዘጋጁ' : 'Tap to set'),
            ),
          ),
          const SizedBox(height: GariSpacing.sm),
          GariCard(
            child: ListTile(
              leading: const Icon(Icons.work),
              title: Text(isAm ? 'ሥራ' : 'Work'),
              subtitle: Text('Bole · Edna Mall'),
            ),
          ),
          const SizedBox(height: GariSpacing.lg),
          GariPrimaryButton(
            label: isAm ? 'ቦታ ጨምር' : 'Add place',
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    return Scaffold(
      appBar: AppBar(title: Text(isAm ? 'ታማኝ ግንኙነቶች' : 'Trusted contacts')),
      body: ListView(
        padding: const EdgeInsets.all(GariSpacing.lg),
        children: [
          GariCard(
            child: SwitchListTile(
              title: Text('Meron · +251911222333'),
              subtitle: Text(isAm ? 'ራስ-ሰር አጋራ' : 'Auto-share trip status'),
              value: true,
              activeThumbColor: GariColors.emerald,
              onChanged: (_) {},
            ),
          ),
          const SizedBox(height: GariSpacing.lg),
          GariPrimaryButton(
            label: isAm ? 'ግንኙነት ጨምር' : 'Add contact',
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class SafetyScreen extends ConsumerWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    return Scaffold(
      appBar: AppBar(title: Text(isAm ? 'ደህንነት' : 'Safety Center')),
      body: ListView(
        padding: const EdgeInsets.all(GariSpacing.lg),
        children: [
          _block(context, 'PIN verification',
              'Show your 4-digit code before entering — prevents wrong-bajaj pickups.'),
          _block(context, 'Trip sharing',
              'Trusted contacts get a live link automatically if enabled.'),
          _block(context, 'SOS',
              'One tap alerts GariGo command center and shares GPS.'),
          GariPrimaryButton(
            label: isAm ? 'ታማኝ ግንኙነቶች' : 'Trusted contacts',
            onPressed: () => context.push('/safety/contacts'),
          ),
        ],
      ),
    );
  }

  Widget _block(BuildContext c, String t, String b) => Padding(
        padding: const EdgeInsets.only(bottom: GariSpacing.md),
        child: GariCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: AppText.headline(c)),
              const SizedBox(height: 6),
              Text(b, style: AppText.body(c)),
            ],
          ),
        ),
      );
}

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    return Scaffold(
      appBar: AppBar(title: Text(S.of(isAm).support)),
      body: ListView(
        children: [
          ExpansionTile(
            title: Text(isAm ? 'PIN ምንድን ነው?' : 'What is the PIN?'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                    isAm
                        ? 'ከመግባትዎ በፊት ለሹፌሩ የሚያሳዩት 4 አሃዝ ኮድ ነው።'
                        : 'A 4-digit code you show the driver before boarding.',
                    style: AppText.body(context)),
              ),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.chat),
            title: Text(isAm ? 'ከድጋፍ ጋር ተወያዩ' : 'Chat with Support'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: Text(isAm ? 'የጠፋ ነገር ሪፖርት' : 'Report lost item'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isAm = auth.locale.languageCode == 'am';
    final s = S.of(isAm);
    final r = auth.rider;

    Widget row(IconData i, String t, VoidCallback on) => Padding(
          padding: const EdgeInsets.only(bottom: GariSpacing.sm),
          child: GariCard(
            onTap: on,
            child: Row(
              children: [
                Icon(i, color: GariColors.slate),
                const SizedBox(width: GariSpacing.md),
                Expanded(child: Text(t, style: AppText.headline(context))),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(s.profile)),
      body: ListView(
        padding: const EdgeInsets.all(GariSpacing.lg),
        children: [
          GariCard(
            dark: true,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: GariColors.amber,
                  child: Text((r?.name ?? 'G').characters.first,
                      style: AppText.title(context, color: GariColors.nightBlue)),
                ),
                const SizedBox(width: GariSpacing.lg),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r?.name ?? 'Rider',
                        style: AppText.title(context, color: GariColors.white)),
                    Text(r?.phone ?? '',
                        style: AppText.caption(context,
                            color: GariColors.white.withValues(alpha: 0.6))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: GariSpacing.lg),
          row(Icons.place, isAm ? 'ቦታዎች' : 'Saved places',
              () => context.push('/places')),
          row(Icons.shield, isAm ? 'ደህንነት' : 'Safety',
              () => context.push('/safety')),
          row(Icons.people, isAm ? 'ግንኙነቶች' : 'Trusted contacts',
              () => context.push('/safety/contacts')),
          row(Icons.card_giftcard, isAm ? 'ጋብዝ' : 'Refer a friend',
              () => context.push('/referral')),
          row(Icons.help, s.support, () => context.push('/support')),
          row(Icons.language, isAm ? 'ቋንቋ' : 'Language', () async {
            await ref.read(authProvider.notifier).setLocale(
                isAm ? const Locale('en') : const Locale('am'));
          }),
          GariCard(
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/');
            },
            child: Text(s.logout,
                style: AppText.headline(context, color: GariColors.crimson)),
          ),
        ],
      ),
    );
  }
}

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    const code = 'SELAM50';
    return Scaffold(
      appBar: AppBar(title: Text(isAm ? 'ጓደኛ ጋብዝ' : 'Refer a friend')),
      body: Padding(
        padding: const EdgeInsets.all(GariSpacing.xl),
        child: Column(
          children: [
            GariCard(
              dark: true,
              child: Column(
                children: [
                  Text(code,
                      style: AppText.display(context, color: GariColors.amber)),
                  Text(
                    isAm
                        ? 'ሁለታችሁም 50 ብር ቅናሽ'
                        : 'You both get 50 birr off your next ride',
                    style: AppText.body(context,
                        color: GariColors.white.withValues(alpha: 0.7)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: GariSpacing.xl),
            GariPrimaryButton(
              label: isAm ? 'ቅዳ' : 'Copy',
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: code));
              },
            ),
            const SizedBox(height: GariSpacing.md),
            GariSecondaryButton(
              label: 'Share',
              onPressed: () => Share.share('Ride with GariGo — code $code'),
            ),
          ],
        ),
      ),
    );
  }
}
