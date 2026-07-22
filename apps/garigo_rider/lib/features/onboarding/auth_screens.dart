import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gari_core/gari_core.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/providers.dart';
import '../../pick_upload.dart';

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
  final phoneFocus = FocusNode();
  String? err;
  bool loading = false;

  @override
  void dispose() {
    c.dispose();
    phoneFocus.dispose();
    super.dispose();
  }

  Future<void> go() async {
    final s = S.of(ref.read(authProvider).locale.languageCode == 'am');
    final e164 = PhoneUtils.normalize(c.text);
    if (e164 == null) {
      setState(() => err = s.invalidPhone);
      phoneFocus.requestFocus();
      return;
    }
    setState(() {
      loading = true;
      err = null;
    });
    try {
      await ref.read(apiProvider).requestOtp(e164);
      ref.read(pendingPhoneProvider.notifier).state = e164;
      if (mounted) context.go('/auth/otp');
    } catch (e) {
      if (mounted) setState(() => err = apiError(e));
    }
    if (mounted) setState(() => loading = false);
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
                          focusNode: phoneFocus,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(9),
                          ],
                          onChanged: (_) => setState(() => err = null),
                          onSubmitted: (_) {
                            if (ok) go();
                          },
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
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isAm
                                    ? 'ኢሜይል መግባት በቅርቡ'
                                    : 'Email sign-in coming soon — use phone for now',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SocialBtn(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Telebirr',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isAm
                                    ? 'Telebirr በቅርቡ'
                                    : 'Telebirr sign-in coming soon — use phone for now',
                              ),
                            ),
                          );
                        },
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
                    ref.read(pendingSignupProvider.notifier).state = null;
                    context.go('/auth/signup');
                  },
                  child: Text(
                    isAm ? 'አዲስ ነዎት? መለያ ፍጠር' : 'New rider? Create account',
                    style: AppText.label(context, color: GariColors.nightBlue)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.demoOtp,
                  textAlign: TextAlign.center,
                  style: AppText.caption(context, color: GariColors.amberDeep),
                ),
                const SizedBox(height: 6),
                Text(
                  isAm
                      ? 'ሹፌር መሆን ከፈለጉ የ Driver መተግበሪያን ይክፈቱ (ፖርት 5182)'
                      : 'Want to drive? Use the Driver app at http://localhost:5182',
                  textAlign: TextAlign.center,
                  style: AppText.caption(context, color: GariColors.muted),
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
    return GariBillboardHero(
      isAm: isAm,
      onLang: onLang,
      brandLabel: 'GariGo',
      headline: TextSpan(
        children: isAm
            ? const [
                TextSpan(text: 'አዲስ፣ '),
                TextSpan(
                  text: 'ጉዞዎ',
                  style: TextStyle(color: GariColors.amber),
                ),
                TextSpan(text: '\nደቂቃዎች ብቻ ነው።'),
              ]
            : const [
                TextSpan(text: 'Addis, '),
                TextSpan(
                  text: 'your ride',
                  style: TextStyle(color: GariColors.amber),
                ),
                TextSpan(text: '\nis minutes away.'),
              ],
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
      if (!mounted) return;

      final pending = ref.read(pendingSignupProvider);
      if (pending != null) {
        await ref.read(authProvider.notifier).completeRegistration(
              name: pending.name,
              password: pending.password,
              email: pending.email,
              photoBytes: pending.photoBytes,
              photoName: pending.photoName,
            );
        ref.read(pendingSignupProvider.notifier).state = null;
        if (mounted) context.go('/home');
        return;
      }

      final rider = ref.read(authProvider).rider;
      final needsProfile = rider != null &&
          !rider.isGuest &&
          !rider.profileComplete;
      context.go(needsProfile ? '/auth/register' : '/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiError(e).isNotEmpty
                  ? apiError(e)
                  : S
                      .of(ref.read(authProvider).locale.languageCode == 'am')
                      .invalidOtp,
            ),
          ),
        );
      }
    }
    if (mounted) setState(() => loading = false);
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
    try {
      final picked = await pickUpload(allowPdf: false);
      if (picked == null) return;
      setState(() {
        photoBytes = picked.bytes;
        photoName = picked.name;
        error = null;
      });
    } catch (e) {
      setState(() => error = apiError(e));
    }
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
            photoName: photoName ?? 'photo.jpg',
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
                ? 'ስም እና የይለፍ ቃል ያስፈልጋል · ፎቶ አማራጭ ነው'
                : 'Name and password are required · photo is optional',
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
            isAm ? 'ፎቶ ጨምር (አማራጭ)' : 'Tap to add photo (optional)',
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

/// Full signup — same visual language as guest / phone login.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  List<int>? photoBytes;
  String? photoName;
  String? error;
  bool busy = false;
  bool obscurePass = true;
  bool obscureConfirm = true;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await pickUpload(allowPdf: false);
      if (picked == null) return;
      setState(() {
        photoBytes = picked.bytes;
        photoName = picked.name;
        error = null;
      });
    } catch (e) {
      setState(() => error = apiError(e));
    }
  }

  Future<void> _submit() async {
    final isAm = ref.read(authProvider).locale.languageCode == 'am';
    final e164 = PhoneUtils.normalize(phone.text);
    if (photoBytes == null || photoBytes!.isEmpty) {
      setState(() => error = isAm ? 'ፎቶ ያስፈልጋል' : 'Add a profile photo');
      return;
    }
    if (name.text.trim().length < 2) {
      setState(() => error = isAm ? 'ሙሉ ስም ያስገቡ' : 'Enter your full name');
      return;
    }
    if (e164 == null) {
      setState(() =>
          error = isAm ? 'ትክክለኛ ስልክ ያስገቡ' : 'Enter a valid Ethiopian phone');
      return;
    }
    if (password.text.length < 6) {
      setState(() => error = isAm
          ? 'የይለፍ ቃል ቢያንስ 6 ቁምፊ'
          : 'Password must be at least 6 characters');
      return;
    }
    if (password.text != confirm.text) {
      setState(
          () => error = isAm ? 'የይለፍ ቃሎች አይዛመዱም' : 'Passwords do not match');
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(apiProvider).requestOtp(e164);
      ref.read(pendingPhoneProvider.notifier).state = e164;
      ref.read(pendingSignupProvider.notifier).state = PendingSignup(
        name: name.text.trim(),
        password: password.text,
        email: email.text.trim().isEmpty ? null : email.text.trim(),
        photoBytes: photoBytes,
        photoName: photoName ?? 'photo.jpg',
      );
      if (mounted) context.go('/auth/otp');
    } catch (e) {
      setState(() => error = apiError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Widget _fieldLabel(BuildContext context, String text) {
    return Text(
      text.toUpperCase(),
      style: AppText.caption(context, color: GariColors.muted).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _authField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? trailing,
    List<TextInputFormatter>? formatters,
    bool hasError = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: hasError ? GariColors.crimson : GariColors.border,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              inputFormatters: formatters,
              onChanged: (_) => setState(() => error = null),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(
                  color: GariColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final phoneOk = phone.text.replaceAll(RegExp(r'\D'), '').length == 9;
    final canSubmit = !busy &&
        photoBytes != null &&
        name.text.trim().length >= 2 &&
        phoneOk &&
        password.text.length >= 6 &&
        confirm.text == password.text;

    return Scaffold(
      backgroundColor: GariColors.cream,
      body: Column(
        children: [
          _SignupHero(
            isAm: isAm,
            onBack: () => context.go('/auth/phone'),
            onLang: (am) async {
              await ref
                  .read(authProvider.notifier)
                  .setLocale(Locale(am ? 'am' : 'en'));
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
              children: [
                _fieldLabel(
                    context, isAm ? 'የመገለጫ ፎቶ' : 'Profile photo'),
                const SizedBox(height: 8),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: busy ? null : _pickPhoto,
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: photoBytes == null && error != null
                              ? GariColors.crimson
                              : GariColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: GariColors.creamDim,
                            backgroundImage: photoBytes != null
                                ? MemoryImage(
                                    Uint8List.fromList(photoBytes!))
                                : null,
                            child: photoBytes == null
                                ? const Icon(Icons.person_outline,
                                    color: GariColors.muted, size: 28)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  photoBytes == null
                                      ? (isAm
                                          ? 'ፎቶ ይምረጡ'
                                          : 'Add a clear photo')
                                      : (isAm
                                          ? 'ፎቶ ተመርጧል'
                                          : 'Photo selected'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                    color: GariColors.nightBlue,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  photoBytes == null
                                      ? (isAm
                                          ? 'አስፈላጊ · JPG ወይም PNG'
                                          : 'Required · JPG or PNG')
                                      : (photoName ?? 'photo.jpg'),
                                  style: AppText.caption(context,
                                      color: GariColors.muted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: GariColors.creamDim,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              photoBytes == null
                                  ? (isAm ? 'ምረጥ' : 'Choose')
                                  : (isAm ? 'ቀይር' : 'Change'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: GariColors.nightBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _fieldLabel(context, isAm ? 'ሙሉ ስም' : 'Full name'),
                const SizedBox(height: 8),
                _authField(
                  controller: name,
                  hint: 'Selam Abebe',
                ),
                const SizedBox(height: 16),
                _fieldLabel(context, isAm ? 'ስልክ ቁጥር' : 'Mobile number'),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: error != null && !phoneOk
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
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(9),
                          ],
                          onChanged: (_) => setState(() => error = null),
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
                const SizedBox(height: 16),
                _fieldLabel(
                    context, isAm ? 'ኢሜይል (አማራጭ)' : 'Email (optional)'),
                const SizedBox(height: 8),
                _authField(
                  controller: email,
                  hint: 'you@email.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _fieldLabel(context, isAm ? 'የይለፍ ቃል' : 'Password'),
                const SizedBox(height: 8),
                _authField(
                  controller: password,
                  hint: '••••••••',
                  obscure: obscurePass,
                  trailing: IconButton(
                    icon: Icon(
                      obscurePass
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: GariColors.muted,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => obscurePass = !obscurePass),
                  ),
                ),
                const SizedBox(height: 16),
                _fieldLabel(
                    context, isAm ? 'የይለፍ ቃል ድገም' : 'Confirm password'),
                const SizedBox(height: 8),
                _authField(
                  controller: confirm,
                  hint: '••••••••',
                  obscure: obscureConfirm,
                  trailing: IconButton(
                    icon: Icon(
                      obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: GariColors.muted,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: AppText.caption(context, color: GariColors.crimson),
                  ),
                ],
                const SizedBox(height: 22),
                GariPrimaryButton(
                  label: busy
                      ? '…'
                      : (isAm ? 'ቀጥል' : 'Continue'),
                  enabled: canSubmit,
                  loading: busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 14),
                Text(
                  isAm
                      ? 'ቀጣይ ደረጃ፡ OTP 123456 ያረጋግጡ'
                      : 'Next step: verify with OTP 123456',
                  textAlign: TextAlign.center,
                  style: AppText.caption(context, color: GariColors.muted),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/auth/phone'),
                  child: Text(
                    isAm ? 'አስቀድሞ መለያ አለዎት? ይግቡ' : 'Already have an account? Sign in',
                    style: AppText.label(context, color: GariColors.amberDeep),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignupHero extends StatelessWidget {
  const _SignupHero({
    required this.isAm,
    required this.onBack,
    required this.onLang,
  });
  final bool isAm;
  final VoidCallback onBack;
  final ValueChanged<bool> onLang;

  @override
  Widget build(BuildContext context) {
    return GariBillboardHero(
      isAm: isAm,
      onLang: onLang,
      brandLabel: 'GariGo',
      height: 220,
      leading: IconButton(
        onPressed: onBack,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      ),
      headline: TextSpan(
        children: isAm
            ? const [
                TextSpan(text: 'መለያ '),
                TextSpan(
                  text: 'ፍጠር',
                  style: TextStyle(color: GariColors.amber),
                ),
                TextSpan(text: '\nፎቶ፣ ስም እና ስልክ።'),
              ]
            : const [
                TextSpan(text: 'Create '),
                TextSpan(
                  text: 'your account',
                  style: TextStyle(color: GariColors.amber),
                ),
                TextSpan(text: '\nPhoto, name & phone.'),
              ],
      ),
    );
  }
}
