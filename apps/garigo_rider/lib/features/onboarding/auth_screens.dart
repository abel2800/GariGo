import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gari_core/gari_core.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/providers/providers.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ensure a locale exists so redirects treat the user as ready to auth.
    final prefs = ref.watch(prefsProvider);
    if (!prefs.containsKey('locale')) {
      Future.microtask(
        () => ref.read(authProvider.notifier).setLocale(const Locale('en')),
      );
    }
    return const PhoneScreen(showHero: true);
  }
}

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key, this.showHero = true});
  final bool showHero;
  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final c = TextEditingController();
  String? err;
  bool loading = false;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> go() async {
    final s = S.of(ref.read(authProvider).locale.languageCode == 'am');
    final e164 = PhoneUtils.normalize(c.text);
    if (e164 == null) {
      setState(() => err = s.invalidPhone);
      return;
    }
    setState(() {
      loading = true;
      err = null;
    });
    await ref.read(apiProvider).requestOtp(e164);
    ref.read(pendingPhoneProvider.notifier).state = e164;
    if (mounted) context.go('/auth/otp');
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    final ok = c.text.replaceAll(RegExp(r'\D'), '').length == 9;

    return Scaffold(
      backgroundColor: GariColors.cream,
      body: Column(
        children: [
          if (widget.showHero)
            _RiderHero(
              isAm: isAm,
              onLang: (am) async {
                await ref
                    .read(authProvider.notifier)
                    .setLocale(Locale(am ? 'am' : 'en'));
              },
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
              children: [
                Text(
                  s.mobileNumber.toUpperCase(),
                  style: AppText.caption(context, color: GariColors.muted)
                      .copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: err != null
                          ? GariColors.crimson
                          : GariColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('🇪🇹  +251',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14.5)),
                      Container(
                        width: 1.5,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: GariColors.border,
                      ),
                      Expanded(
                        child: TextField(
                          controller: c,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(9),
                          ],
                          onChanged: (_) => setState(() => err = null),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '9 12 345 678',
                            hintStyle: TextStyle(
                              color: GariColors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(err!,
                      style: AppText.caption(context,
                          color: GariColors.crimson)),
                ],
                const SizedBox(height: 18),
                GariPrimaryButton(
                  label: s.continueLabel,
                  enabled: ok,
                  loading: loading,
                  onPressed: go,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(child: Divider(color: GariColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        isAm ? 'ወይም' : 'or continue with',
                        style: AppText.caption(context,
                            color: GariColors.muted),
                      ),
                    ),
                    const Expanded(child: Divider(color: GariColors.border)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SocialBtn(
                        icon: Icons.mail_outline,
                        label: isAm ? 'ኢሜይል' : 'Email',
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SocialBtn(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Telebirr',
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: GariColors.muted,
                      height: 1.6,
                    ),
                    children: [
                      TextSpan(text: s.termsPrefix),
                      TextSpan(
                        text: s.termsLink,
                        style: const TextStyle(
                          color: GariColors.nightBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(text: s.termsAnd),
                      TextSpan(
                        text: s.privacyLink,
                        style: const TextStyle(
                          color: GariColors.nightBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).guest();
                    if (context.mounted) context.go('/home');
                  },
                  child: Text(
                    s.guestContinue,
                    style: AppText.label(context, color: GariColors.amberDeep),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isAm
                              ? 'ስልክዎን ያስገቡ፣ OTP 123456፣ ከዚያ መመዝገብ ይቀጥላሉ'
                              : 'Enter your phone, use OTP 123456, then complete name, photo & password',
                        ),
                      ),
                    );
                    // Focus phone field by staying on this screen
                  },
                  child: Text(
                    isAm ? 'አዲስ ነዎት? መለያ ፍጠር' : 'New rider? Create account',
                    style: AppText.label(context, color: GariColors.nightBlue),
                  ),
                ),
                Text(
                  s.demoOtp,
                  textAlign: TextAlign.center,
                  style: AppText.caption(context, color: GariColors.amberDeep),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RiderHero extends StatelessWidget {
  const _RiderHero({required this.isAm, required this.onLang});
  final bool isAm;
  final ValueChanged<bool> onLang;

  @override
  Widget build(BuildContext context) {
    final s = S.of(isAm);
    return Container(
      height: 270,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [GariColors.nightBlue, GariColors.navy800],
        ),
      ),
      child: Stack(
        children: [
          CustomPaint(size: Size.infinite, painter: _RoadPainter()),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 18, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _langChip('EN', !isAm, () => onLang(false)),
                          _langChip('አማ', isAm, () => onLang(true)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GariColors.amber,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Text('G',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 19,
                                color: Color(0xFF1A1408))),
                      ),
                      const SizedBox(width: 10),
                      Text(s.appName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const Spacer(),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.28,
                      ),
                      children: isAm
                          ? [
                              const TextSpan(text: 'አዲስ፣ '),
                              TextSpan(
                                  text: 'ጉዞዎ',
                                  style: TextStyle(color: GariColors.amber400)),
                              const TextSpan(text: '\nበ2 ደቂቃ ውስጥ ነው።'),
                            ]
                          : [
                              const TextSpan(text: 'Addis, '),
                              TextSpan(
                                  text: 'your ride',
                                  style: TextStyle(color: GariColors.amber400)),
                              const TextSpan(text: '\nis 2 minutes away.'),
                            ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _langChip(String t, bool on, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? GariColors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(t,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: on ? const Color(0xFF1A1408) : const Color(0xFFB9C0D1),
            )),
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  const _SocialBtn(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GariColors.border, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: GariColors.nightBlue),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(-20, 60), Offset(size.width + 20, 120), p);
    canvas.drawLine(Offset(-20, 180), Offset(size.width + 20, 100), p);
    canvas.drawLine(Offset(90, -20), Offset(150, size.height + 20), p);
    canvas.drawLine(Offset(280, -20), Offset(230, size.height + 20), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final boxes = List.generate(6, (_) => TextEditingController());
  final focus = List.generate(6, (_) => FocusNode());
  bool loading = false;

  @override
  void dispose() {
    for (final x in boxes) {
      x.dispose();
    }
    for (final f in focus) {
      f.dispose();
    }
    super.dispose();
  }

  String get code => boxes.map((e) => e.text).join();

  Future<void> verify() async {
    if (code.length < 6 || loading) return;
    setState(() => loading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .login(ref.read(pendingPhoneProvider), code);
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(S
                  .of(ref.read(authProvider).locale.languageCode == 'am')
                  .invalidOtp)),
        );
      }
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/auth/phone')),
        title: Text(s.enterOtp),
      ),
      body: Padding(
        padding: const EdgeInsets.all(GariSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.enterOtp, style: AppText.display(context)),
            const SizedBox(height: 6),
            Text(ref.watch(pendingPhoneProvider),
                style: AppText.body(context, color: GariColors.muted)),
            const SizedBox(height: GariSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                return SizedBox(
                  width: 46,
                  child: TextField(
                    controller: boxes[i],
                    focusNode: focus[i],
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    keyboardType: TextInputType.number,
                    style: AppText.title(context),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) {
                      if (v.isNotEmpty && i < 5) focus[i + 1].requestFocus();
                      if (code.length == 6) verify();
                    },
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: GariColors.border, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: GariColors.amber, width: 1.5),
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: CircularProgressIndicator(color: GariColors.amber)),
              ),
            const Spacer(),
            Text(s.demoOtp,
                style: AppText.caption(context, color: GariColors.muted)),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  List<int>? photoBytes;
  String? photoName;
  String? error;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      photoBytes = bytes;
      photoName = file.name;
    });
  }

  Future<void> _submit() async {
    if (name.text.trim().length < 2) {
      setState(() => error = 'Enter your full name');
      return;
    }
    if (password.text.length < 6) {
      setState(() => error = 'Password must be at least 6 characters');
      return;
    }
    if (password.text != confirm.text) {
      setState(() => error = 'Passwords do not match');
      return;
    }
    if (photoBytes == null) {
      setState(() => error = 'Add a profile photo');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(authProvider.notifier).completeRegistration(
            name: name.text.trim(),
            password: password.text,
            email: email.text.trim().isEmpty ? null : email.text.trim(),
            photoBytes: photoBytes,
          );
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => error = apiError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(
        backgroundColor: GariColors.cream,
        title: Text(isAm ? 'መመዝገብ' : 'Create your profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            isAm
                ? 'ስም፣ ፎቶ እና የይለፍ ቃል ያስፈልጋል'
                : 'Name, photo and password are required to ride',
            style: AppText.caption(context, color: GariColors.muted),
          ),
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: GariColors.creamDim,
                backgroundImage: photoBytes != null
                    ? MemoryImage(Uint8List.fromList(photoBytes!))
                    : null,
                child: photoBytes == null
                    ? const Icon(Icons.add_a_photo,
                        color: GariColors.amberDeep, size: 32)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAm ? 'ፎቶ ጨምር' : 'Tap to add photo',
            textAlign: TextAlign.center,
            style: AppText.caption(context, color: GariColors.amberDeep),
          ),
          const SizedBox(height: 20),
          GariTextField(
            controller: name,
            label: isAm ? 'ሙሉ ስም' : 'Full name',
            hint: 'Selam Abebe',
          ),
          const SizedBox(height: 12),
          GariTextField(
            controller: email,
            label: isAm ? 'ኢሜይል (አማራጭ)' : 'Email (optional)',
            hint: 'you@email.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          GariTextField(
            controller: password,
            label: isAm ? 'የይለፍ ቃል' : 'Password',
            hint: '••••••',
            obscureText: true,
          ),
          const SizedBox(height: 12),
          GariTextField(
            controller: confirm,
            label: isAm ? 'የይለፍ ቃል ድገም' : 'Confirm password',
            hint: '••••••',
            obscureText: true,
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!,
                style: const TextStyle(
                    color: GariColors.crimson, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 24),
          GariPrimaryButton(
            label: busy ? '…' : (isAm ? 'መመዝገብ ጨርስ' : 'Finish registration'),
            enabled: !busy,
            loading: busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
