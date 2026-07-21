part of 'main.dart';

class _Lang extends ConsumerWidget {
  const _Lang();
  @override
  Widget build(BuildContext context, WidgetRef ref) => const _DriverLogin();
}

class _Phone extends ConsumerWidget {
  const _Phone();
  @override
  Widget build(BuildContext context, WidgetRef ref) => const _DriverLogin();
}

/// New driver sign-up — phone + OTP, then KYC onboarding.
class _DriverApply extends ConsumerStatefulWidget {
  const _DriverApply();
  @override
  ConsumerState<_DriverApply> createState() => _DriverApplyState();
}

class _DriverApplyState extends ConsumerState<_DriverApply> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final otp = TextEditingController(text: '123456');
  bool otpSent = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    otp.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final e164 = PhoneUtils.normalize(phone.text.trim());
    if (e164 == null) {
      setState(() => error = 'Enter a valid Ethiopian phone (9xxxxxxxx)');
      return;
    }
    if (name.text.trim().length < 2) {
      setState(() => error = 'Enter your full name');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(apiProvider).requestOtp(e164);
      setState(() {
        otpSent = true;
        busy = false;
      });
    } catch (e) {
      setState(() {
        busy = false;
        error = drvErr(e);
      });
    }
  }

  Future<void> _createAccount() async {
    final e164 = PhoneUtils.normalize(phone.text.trim());
    if (e164 == null) {
      setState(() => error = 'Enter a valid Ethiopian phone (9xxxxxxxx)');
      return;
    }
    if (otp.text.trim().length < 4) {
      setState(() => error = 'Enter the OTP code');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      ref.read(phoneProvider.notifier).state = e164;
      final d = await ref.read(authProvider.notifier).login(
            e164,
            otp.text.trim(),
            name: name.text.trim(),
            requestOtpFirst: false,
          );
      if (!mounted) return;
      switch (d.approvalStatus) {
        case ApprovalStatus.none:
          context.go('/onboarding/vehicle');
        case ApprovalStatus.pending:
        case ApprovalStatus.rejected:
          context.go('/onboarding/status');
        case ApprovalStatus.approved:
          context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = drvErr(e);
        });
      }
      return;
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    return Scaffold(
      backgroundColor: GariColors.nightBlue,
      appBar: AppBar(
        backgroundColor: GariColors.nightBlue,
        foregroundColor: Colors.white,
        title: Text(isAm ? 'እንደ ሹፌር መመዝገብ' : 'Driver sign up'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Text(
            isAm ? 'መለያ ፍጠር' : 'Create your driver account',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAm
                ? 'ከዚያ መኪና፣ ሰነዶች እና KYC ይቀጥላል — አስተዳዳሪ ያፀድቃል።'
                : 'Next you will add vehicle photos & documents. Admin must approve before you go online.',
            style: const TextStyle(
              color: GariColors.muted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          _darkField(
            controller: name,
            icon: Icons.person_outline,
            hint: isAm ? 'ሙሉ ስም' : 'Full name',
            onChanged: (_) => setState(() => error = null),
          ),
          const SizedBox(height: 14),
          _darkField(
            controller: phone,
            icon: Icons.phone_outlined,
            hint: isAm ? 'ስልክ (9xxxxxxxx)' : 'Phone (9xxxxxxxx)',
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() => error = null),
          ),
          if (otpSent) ...[
            const SizedBox(height: 14),
            _darkField(
              controller: otp,
              icon: Icons.lock_outline,
              hint: isAm ? 'OTP ኮድ' : 'OTP code',
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() => error = null),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
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
            height: 54,
            child: ElevatedButton(
              onPressed: busy
                  ? null
                  : (otpSent ? _createAccount : _sendOtp),
              style: ElevatedButton.styleFrom(
                backgroundColor: GariColors.amber,
                foregroundColor: const Color(0xFF1A1408),
                elevation: 4,
                shadowColor: GariColors.amberGlow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF1A1408),
                      ),
                    )
                  : Text(
                      otpSent
                          ? (isAm ? 'መለያ ፍጠር እና ቀጥል' : 'Create account & continue')
                          : (isAm ? 'OTP ላክ' : 'Send OTP'),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/'),
            child: Text(
              isAm ? 'ወደ መግቢያ ተመለስ' : 'Back to sign in',
              style: const TextStyle(
                color: GariColors.amber400,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAm ? 'ሙከራ OTP: 123456' : 'Demo OTP: 123456',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _darkField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: GariColors.amber,
        decoration: InputDecoration(
          icon: Icon(icon, color: const Color(0xFF5A6172), size: 20),
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF5A6172),
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

class _DriverLogin extends ConsumerStatefulWidget {
  const _DriverLogin();
  @override
  ConsumerState<_DriverLogin> createState() => _DriverLoginState();
}

class _DriverLoginState extends ConsumerState<_DriverLogin> {
  final id = TextEditingController(text: '911000009');
  final pin = TextEditingController(text: '123456');
  bool busy = false;
  bool obscure = true;
  String? error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final prefs = ref.read(prefsProvider);
      if (!prefs.containsKey('locale')) {
        await ref.read(authProvider.notifier).setLocale(const Locale('en'));
      }
    });
  }

  @override
  void dispose() {
    id.dispose();
    pin.dispose();
    super.dispose();
  }

  String? _resolvePhone() {
    final raw = id.text.trim();
    final normalized = PhoneUtils.normalize(raw);
    if (normalized != null) return normalized;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 9) {
      return PhoneUtils.normalize(digits.substring(digits.length - 9));
    }
    return null;
  }

  Future<void> _goOnline() async {
    final phone = _resolvePhone();
    final code = pin.text.trim();
    if (phone == null) {
      setState(() => error = 'Enter a valid Ethiopian phone (9xxxxxxxx)');
      return;
    }
    if (code.length < 4) {
      setState(() => error = 'Enter your PIN / OTP');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      ref.read(phoneProvider.notifier).state = phone;
      final d = await ref.read(authProvider.notifier).login(phone, code);
      if (!mounted) return;
      switch (d.approvalStatus) {
        case ApprovalStatus.none:
          context.go('/onboarding/vehicle');
        case ApprovalStatus.pending:
        case ApprovalStatus.rejected:
          context.go('/onboarding/status');
        case ApprovalStatus.approved:
          context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = drvErr(e);
        });
      }
      return;
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _applyToDrive() {
    return Future(() => context.go('/auth/apply'));
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);

    return Scaffold(
      backgroundColor: GariColors.nightBlue,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(26, 8, 26, 80),
              children: [
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
                      child: const Text(
                        'G',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                          color: Color(0xFF1A1408),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'GariGo Driver',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: GariColors.emeraldSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: GariColors.emerald.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: GariColors.emerald,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            s.liveInAddis,
                            style: const TextStyle(
                              color: GariColors.emerald,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    _earnMini('1,240 Br', isAm ? 'ሳምንታዊ አማካይ' : 'avg. weekly earnings'),
                    const SizedBox(width: 10),
                    _earnMini('4.8★', isAm ? 'አማካይ ደረጃ' : 'driver rating avg'),
                  ],
                ),
                const SizedBox(height: 30),
                Text(
                  s.readyToEarn,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.signInDriverId,
                  style: const TextStyle(
                    color: GariColors.muted,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 26),
                _darkField(
                  controller: id,
                  icon: Icons.badge_outlined,
                  hint: s.driverIdOrPhone,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() => error = null),
                ),
                const SizedBox(height: 14),
                _darkField(
                  controller: pin,
                  icon: Icons.lock_outline,
                  hint: s.pinHint,
                  obscure: obscure,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() => error = null),
                  suffix: IconButton(
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF5A6172),
                      size: 18,
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: const TextStyle(
                      color: GariColors.crimson,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: busy ? null : _goOnline,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GariColors.amber,
                      foregroundColor: const Color(0xFF1A1408),
                      elevation: 4,
                      shadowColor: GariColors.amberGlow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF1A1408),
                            ),
                          )
                        : Text(
                            s.goOnline,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: busy ? null : _applyToDrive,
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5A6172),
                        ),
                        children: [
                          TextSpan(text: '${s.newDriver} '),
                          TextSpan(
                            text: s.applyToDrive,
                            style: const TextStyle(
                              color: GariColors.amber400,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '${s.demoOtp} · existing approved: 911000009',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _langChip('EN', !isAm, () async {
                      await ref
                          .read(authProvider.notifier)
                          .setLocale(const Locale('en'));
                    }),
                    const SizedBox(width: 8),
                    _langChip('አማ', isAm, () async {
                      await ref
                          .read(authProvider.notifier)
                          .setLocale(const Locale('am'));
                    }),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 26,
              right: 26,
              bottom: 26,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _vchip(Icons.airport_shuttle_outlined, 'Bajaj'),
                  _dot(),
                  _vchip(Icons.two_wheeler_outlined, 'Moto'),
                  _dot(),
                  _vchip(Icons.directions_car_outlined, 'Car'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _earnMini(String n, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                n,
                style: const TextStyle(
                  color: GariColors.amber400,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l,
                style: const TextStyle(
                  color: GariColors.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _darkField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: GariColors.amber400, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              onChanged: onChanged,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: GariColors.amber,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFF5A6172),
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (suffix != null) suffix,
        ],
      ),
    );
  }

  Widget _langChip(String t, bool on, VoidCallback tap) => GestureDetector(
        onTap: tap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? GariColors.amber : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: on
                  ? GariColors.amber
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            t,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: on ? const Color(0xFF1A1408) : const Color(0xFFB9C0D1),
            ),
          ),
        ),
      );

  Widget _vchip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF5A6172)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5A6172),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Text('·', style: TextStyle(color: Color(0xFF333C50))),
      );
}

class _Otp extends ConsumerStatefulWidget {
  const _Otp();
  @override
  ConsumerState<_Otp> createState() => _OtpState();
}

class _OtpState extends ConsumerState<_Otp> {
  final boxes = List.generate(6, (_) => TextEditingController());
  @override
  void dispose() {
    for (final b in boxes) {
      b.dispose();
    }
    super.dispose();
  }

  Future<void> go() async {
    final code = boxes.map((e) => e.text).join();
    if (code.length < 6) return;
    final d = await ref
        .read(authProvider.notifier)
        .login(ref.read(phoneProvider), code);
    if (!mounted) return;
    switch (d.approvalStatus) {
      case ApprovalStatus.none:
        context.go('/onboarding/vehicle');
      case ApprovalStatus.pending:
      case ApprovalStatus.rejected:
        context.go('/onboarding/status');
      case ApprovalStatus.approved:
        context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GariColors.nightBlue,
      appBar: AppBar(
        backgroundColor: GariColors.nightBlue,
        foregroundColor: Colors.white,
        title: const Text('OTP'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                6,
                (i) => SizedBox(
                  width: 44,
                  child: TextField(
                    controller: boxes[i],
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty && i < 5) {
                        FocusScope.of(context).nextFocus();
                      }
                      if (boxes.every((e) => e.text.isNotEmpty)) go();
                    },
                  ),
                ),
              ),
            ),
            const Spacer(),
            Text(
              S.of(ref.watch(authProvider).locale.languageCode == 'am').demoOtp,
              style: AppText.caption(context, color: GariColors.amber400),
            ),
          ],
        ),
      ),
    );
  }
}

class _Vehicle extends ConsumerStatefulWidget {
  const _Vehicle();
  @override
  ConsumerState<_Vehicle> createState() => _VehicleState();
}

class _VehicleState extends ConsumerState<_Vehicle> {
  VehicleCategory? sel;
  bool isOwner = true;
  bool busy = false;
  String? error;
  final scroll = ScrollController();
  final plate = TextEditingController();
  final make = TextEditingController();
  final model = TextEditingController();
  final color = TextEditingController();
  final name = TextEditingController();
  final tin = TextEditingController();
  final business = TextEditingController();
  final license = TextEditingController();
  final nationalId = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final d = ref.read(authProvider).driver;
      setState(() {
        sel = d?.vehicleCategory ?? VehicleCategory.car;
        if (d?.name != null && d!.name!.trim().isNotEmpty) {
          name.text = d.name!;
        }
      });
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    plate.dispose();
    make.dispose();
    model.dispose();
    color.dispose();
    name.dispose();
    tin.dispose();
    business.dispose();
    license.dispose();
    nationalId.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (sel == null) {
      setState(() => error = 'Select a vehicle type at the top (Bajaj / Moto / Car)');
      if (scroll.hasClients) {
        scroll.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
      return;
    }
    if (plate.text.trim().length < 3) {
      setState(() => error = 'Plate number required');
      return;
    }
    if (name.text.trim().length < 2) {
      setState(() => error = 'Your full name is required');
      return;
    }
    if (tin.text.trim().isEmpty) {
      setState(() => error = 'TIN number required');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(apiProvider).saveVehicleDetails(
            category: sel!,
            plate: plate.text.trim(),
            make: make.text.trim().isEmpty ? null : make.text.trim(),
            model: model.text.trim().isEmpty ? null : model.text.trim(),
            color: color.text.trim().isEmpty ? null : color.text.trim(),
            isOwner: isOwner,
            name: name.text.trim(),
            tin: tin.text.trim(),
            businessReg:
                business.text.trim().isEmpty ? null : business.text.trim(),
            licenseNumber:
                license.text.trim().isEmpty ? null : license.text.trim(),
            nationalId:
                nationalId.text.trim().isEmpty ? null : nationalId.text.trim(),
          );
      final d = ref.read(apiProvider).driver;
      if (d != null) {
        ref.read(authProvider.notifier).upd(d);
      }
      if (!mounted) return;
      context.go('/onboarding/docs');
    } catch (e) {
      if (mounted) setState(() => error = drvErr(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply to drive')),
      body: ListView(
        controller: scroll,
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Vehicle type *',
            style: AppText.headline(context),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap one — required before you can continue',
            style: AppText.caption(
              context,
              color: sel == null ? GariColors.crimson : GariColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          ...VehicleCategory.values.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GariCard(
                  borderColor: sel == c
                      ? GariColors.amber
                      : (sel == null ? GariColors.crimson.withValues(alpha: 0.35) : null),
                  onTap: () => setState(() {
                    sel = c;
                    error = null;
                  }),
                  child: Row(children: [
                    Icon(c.icon,
                        color: sel == c
                            ? GariColors.amberDeep
                            : GariColors.slate),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('${c.labelEn} · ${c.labelAm}',
                          style: AppText.headline(context)),
                    ),
                    if (sel == c)
                      const Icon(Icons.check_circle, color: GariColors.emerald),
                  ]),
                ),
              )),
          const SizedBox(height: 8),
          GariTextField(controller: name, label: 'Full name', hint: 'Abebe Kebede'),
          const SizedBox(height: 12),
          GariTextField(controller: plate, label: 'Plate number', hint: 'AA-3-12345'),
          const SizedBox(height: 12),
          GariTextField(controller: make, label: 'Make', hint: 'Toyota'),
          const SizedBox(height: 12),
          GariTextField(controller: model, label: 'Model', hint: 'Corolla'),
          const SizedBox(height: 12),
          GariTextField(controller: color, label: 'Color', hint: 'White'),
          const SizedBox(height: 12),
          GariTextField(controller: license, label: 'Licence number'),
          const SizedBox(height: 12),
          GariTextField(controller: nationalId, label: 'National ID number'),
          const SizedBox(height: 12),
          GariTextField(controller: tin, label: 'TIN number'),
          const SizedBox(height: 12),
          GariTextField(
              controller: business, label: 'Business registration no.'),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('I own this vehicle',
                style: AppText.headline(context)),
            subtitle: const Text(
              'If off, you must upload an owner authorization letter',
            ),
            value: isOwner,
            activeThumbColor: Colors.white,
            activeTrackColor: GariColors.amber,
            onChanged: (v) => setState(() => isOwner = v),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!,
                style: const TextStyle(
                    color: GariColors.crimson, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          GariPrimaryButton(
            label: busy ? '…' : 'Continue to documents',
            enabled: !busy,
            loading: busy,
            onPressed: _continue,
          ),
          if (sel != null) ...[
            const SizedBox(height: 8),
            Text(
              'Selected: ${sel!.labelEn}',
              textAlign: TextAlign.center,
              style: AppText.caption(context, color: GariColors.emerald),
            ),
          ],
        ],
      ),
    );
  }
}

class _Docs extends ConsumerStatefulWidget {
  const _Docs();
  @override
  ConsumerState<_Docs> createState() => _DocsState();
}

class _DocsState extends ConsumerState<_Docs> {
  String? uploading;
  String? error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(apiProvider).syncDocsFromServer();
      if (mounted) setState(() {});
    });
  }

  Future<void> _pick(DocumentType type) async {
    setState(() {
      uploading = type.apiKey;
      error = null;
    });
    try {
      final picked = await pickUpload(allowPdf: true);
      if (picked == null) {
        setState(() => uploading = null);
        return;
      }
      await ref.read(apiProvider).uploadDoc(type, picked.bytes, picked.name);
      final d = ref.read(apiProvider).driver;
      if (d != null) ref.read(authProvider.notifier).upd(d);
      setState(() {});
    } catch (e) {
      setState(() => error = drvErr(e));
    }
    if (mounted) setState(() => uploading = null);
  }

  bool _isPdf(String? url) =>
      (url ?? '').toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final docs = api.docs.values.toList();
    final rejected =
        docs.where((d) => d.status == DocumentStatus.rejected).toList();
    final approval = api.driver?.approvalStatus;
    final reviewFlow = approval == ApprovalStatus.rejected ||
        approval == ApprovalStatus.pending ||
        docs.any((d) =>
            d.status == DocumentStatus.verified ||
            d.status == DocumentStatus.rejected);
    final done = docs.where((d) => d.status != DocumentStatus.empty).length;
    final apiBase = GariConfig.apiBaseUrl;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          rejected.isNotEmpty
              ? 'Fix documents (${rejected.length} to replace)'
              : 'KYC docs $done/${docs.length}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            rejected.isNotEmpty
                ? 'Only re-upload the declined documents. Verified ones stay as they are.'
                : 'Images (JPG, PNG, WEBP, HEIC, …) or PDF — max 12 MB each',
            style: AppText.caption(context, color: GariColors.muted),
          ),
          const SizedBox(height: 12),
          ...docs.map((d) {
            final ok = d.status != DocumentStatus.empty;
            final busy = uploading == d.type.apiKey;
            final pdf = _isPdf(d.url);
            final isRejected = d.status == DocumentStatus.rejected;
            final isVerified = d.status == DocumentStatus.verified;
            final canReplace = !isVerified;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GariCard(
                onTap: busy || !canReplace ? null : () => _pick(d.type),
                child: Row(
                  children: [
                    if (ok && d.url != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: pdf
                            ? Container(
                                width: 48,
                                height: 48,
                                color: GariColors.creamDim,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.picture_as_pdf,
                                  color: GariColors.crimson,
                                ),
                              )
                            : Image.network(
                                '$apiBase${d.url}',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  isRejected
                                      ? Icons.error
                                      : Icons.check_circle,
                                  color: isRejected
                                      ? GariColors.crimson
                                      : GariColors.emerald,
                                ),
                              ),
                      )
                    else
                      Icon(
                        ok ? Icons.check_circle : Icons.upload_file,
                        color: ok ? GariColors.emerald : GariColors.amberDeep,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.nameEn, style: AppText.headline(context)),
                          Text(
                            busy
                                ? 'Uploading…'
                                : isRejected
                                    ? 'Declined: ${d.rejectionReason ?? 'Please re-upload'}'
                                    : isVerified
                                        ? 'Verified — no action needed'
                                        : ok
                                            ? (pdf
                                                ? 'PDF uploaded — tap to replace'
                                                : 'Uploaded — tap to replace')
                                            : 'Tap to upload image or PDF',
                            style: AppText.caption(
                              context,
                              color: isRejected ? GariColors.crimson : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (busy)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            );
          }),
          if (error != null)
            Text(error!,
                style: const TextStyle(
                    color: GariColors.crimson, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          GariPrimaryButton(
            label: reviewFlow ? 'Back to status' : 'Continue',
            enabled: rejected.isEmpty &&
                (reviewFlow || (done == docs.length && docs.isNotEmpty)),
            onPressed: () {
              if (reviewFlow) {
                context.go('/onboarding/status');
              } else {
                context.go('/onboarding/selfie');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Selfie extends ConsumerStatefulWidget {
  const _Selfie();
  @override
  ConsumerState<_Selfie> createState() => _SelfieState();
}

class _SelfieState extends ConsumerState<_Selfie> {
  bool busy = false;
  String? error;

  Future<void> _capture() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final picked = await pickUpload(allowPdf: false);
      if (picked == null) {
        setState(() => busy = false);
        return;
      }
      await ref
          .read(apiProvider)
          .uploadDoc(DocumentType.selfie, picked.bytes, picked.name);
      if (mounted) context.go('/onboarding/payout');
    } catch (e) {
      setState(() => error = drvErr(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final has = ref.watch(apiProvider).docs[DocumentType.selfie]?.url != null;
    return Scaffold(
      backgroundColor: GariColors.nightBlue,
      appBar: AppBar(title: const Text('Driver photo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, size: 120, color: GariColors.amber),
              const SizedBox(height: 16),
              Text(
                'Clear face photo for KYC verification',
                textAlign: TextAlign.center,
                style: AppText.body(context, color: Colors.white70),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: GariColors.crimson)),
              ],
              const SizedBox(height: 24),
              GariPrimaryButton(
                label: busy
                    ? '…'
                    : has
                        ? 'Photo saved — continue'
                        : 'Upload photo',
                enabled: !busy,
                loading: busy,
                onPressed: has
                    ? () => context.go('/onboarding/payout')
                    : _capture,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Payout extends ConsumerWidget {
  const _Payout();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payout')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ...PayoutMethodType.values.map((t) => GariCard(
                onTap: () async {
                  await ref
                      .read(apiProvider)
                      .setPayout(t, '0911000000');
                  if (context.mounted) context.go('/onboarding/training');
                },
                child: Text(
                    PayoutMethod(type: t, details: '').label,
                    style: AppText.headline(context)),
              )),
        ],
      ),
    );
  }
}

class _Train extends ConsumerStatefulWidget {
  const _Train();
  @override
  ConsumerState<_Train> createState() => _TrainState();
}

class _TrainState extends ConsumerState<_Train> {
  int q = 0;
  int score = 0;
  final qs = [
    ('PIN before boarding?', ['Yes', 'No'], 0),
    ('Commission shown as?', ['Hidden', 'Gross/%/net'], 1),
    ('SOS goes to?', ['Nowhere', 'Command center'], 1),
    ('Cash debt?', ['Ignored', 'Accrues'], 1),
    ('Late?', ['Ignore', 'Send ETA'], 1),
  ];

  @override
  Widget build(BuildContext context) {
    final cur = qs[q];
    return Scaffold(
      appBar: AppBar(title: Text('Quiz ${q + 1}/5')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(cur.$1, style: AppText.title(context)),
          ...List.generate(cur.$2.length, (i) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GariCard(
                  onTap: () async {
                    if (i == cur.$3) score++;
                    if (q < 4) {
                      setState(() => q++);
                    } else {
                      if (score >= 4) {
                        try {
                          await ref.read(apiProvider).submitApproval(
                                name: ref.read(authProvider).driver?.name ??
                                    'Driver',
                              );
                          ref.read(authProvider.notifier).upd(
                                ref.read(apiProvider).driver!,
                              );
                          if (context.mounted) {
                            context.go('/onboarding/status');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(drvErr(e))),
                            );
                          }
                        }
                      } else {
                        setState(() {
                          q = 0;
                          score = 0;
                        });
                      }
                    }
                  },
                  child: Text(cur.$2[i]),
                ),
              )),
        ],
      ),
    );
  }
}

class _Status extends ConsumerWidget {
  const _Status();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(authProvider).driver;
    final st = driver?.approvalStatus;
    final reasons = driver?.rejectionReasons ?? const <String>[];
    final isRejected = st == ApprovalStatus.rejected;
    return Scaffold(
      appBar: AppBar(title: const Text('Status')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                st == ApprovalStatus.approved
                    ? Icons.check_circle
                    : isRejected
                        ? Icons.error_outline
                        : Icons.hourglass_top,
                size: 80,
                color: st == ApprovalStatus.approved
                    ? GariColors.emerald
                    : isRejected
                        ? GariColors.crimson
                        : GariColors.amber,
              ),
              Text(
                st == ApprovalStatus.approved
                    ? "You're ready!"
                    : isRejected
                        ? 'Document update needed'
                        : 'Under review (24–48h)',
                style: AppText.title(context),
                textAlign: TextAlign.center,
              ),
              if (isRejected && reasons.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...reasons.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      r,
                      textAlign: TextAlign.center,
                      style: AppText.body(context, color: GariColors.crimson),
                    ),
                  ),
                ),
              ],
              if (isRejected) ...[
                const SizedBox(height: 16),
                GariPrimaryButton(
                  label: 'Re-upload declined documents',
                  onPressed: () async {
                    await ref.read(apiProvider).syncDocsFromServer();
                    if (context.mounted) context.go('/onboarding/docs');
                  },
                ),
              ],
              if (st != ApprovalStatus.approved)
                TextButton(
                  onPressed: () async {
                    await ref.read(apiProvider).restore();
                    final d = ref.read(apiProvider).driver;
                    if (d != null) ref.read(authProvider.notifier).upd(d);
                  },
                  child: const Text('Refresh status'),
                ),
              if (st == ApprovalStatus.approved)
                GariPrimaryButton(
                  label: 'Dashboard',
                  onPressed: () => context.go('/dashboard'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final s = S.of(Localizations.localeOf(context).languageCode == 'am');
    return Scaffold(
      backgroundColor: GariColors.cream,
      body: shell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xEBFBF7EF),
          border: Border(top: BorderSide(color: GariColors.border)),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedIndex: shell.currentIndex,
          onDestinationSelected: shell.goBranch,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: _navIcon(Icons.home_rounded),
              label: s.home,
            ),
            NavigationDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: _navIcon(Icons.account_balance_wallet),
              label: s.earnings,
            ),
            NavigationDestination(
              icon: const Icon(Icons.show_chart_outlined),
              selectedIcon: _navIcon(Icons.show_chart),
              label: s.trips,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: _navIcon(Icons.person),
              label: s.profile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon) => Container(
        width: 44,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: GariColors.nightBlue,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: GariColors.amber400, size: 19),
      );
}

class _Dash extends ConsumerStatefulWidget {
  const _Dash();
  @override
  ConsumerState<_Dash> createState() => _DashState();
}

class _DashState extends ConsumerState<_Dash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radar;

  @override
  void initState() {
    super.initState();
    _radar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _radar.dispose();
    super.dispose();
  }

  Future<void> _toggleOnline() async {
    final d = ref.read(authProvider).driver!;
    final online = d.onlineStatus == OnlineStatus.online;
    try {
      await ref.read(apiProvider).setOnline(!online);
      ref.read(authProvider.notifier).upd(ref.read(apiProvider).driver!);
      if (!online) _listenOffers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(drvErr(e))),
        );
      }
    }
  }

  void _listenOffers() {
    final socket = ref.read(apiProvider).client.socket;
    socket?.off('ride_request');
    socket?.on('ride_request', (data) {
      if (!mounted) return;
      final m = Map<String, dynamic>.from(data as Map);
      ref.read(offerProvider.notifier).state = TripOffer(
        id: m['tripId'].toString(),
        pickupLandmark: m['pickupLandmark']?.toString() ?? 'Pickup',
        pickupDistanceKm: (m['pickupDistanceKm'] as num?)?.toDouble() ?? 0.5,
        destinationArea: m['destinationArea']?.toString() ?? 'Drop-off',
        estimatedFare: (m['estimatedFare'] as num?)?.round() ?? 0,
        estimatedDurationMin: (m['estimatedDurationMin'] as num?)?.round() ?? 15,
        acceptWindowSec: (m['acceptWindowSec'] as num?)?.round() ?? 14,
        riderPin: m['riderPin']?.toString() ?? '0000',
      );
      showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (_) => const _OfferSheet(),
      );
    });
  }

  void _demoOffer() {
    // Kept only as a manual refresh tip — real offers come via socket.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stay online — trip offers arrive from the API when a rider requests.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(authProvider).driver!;
    final online = d.onlineStatus == OnlineStatus.online;
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);

    return Scaffold(
      backgroundColor: GariColors.nightBlue,
      body: Stack(
        children: [
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: online
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                  : const ColorFilter.matrix(<double>[
                      0.4, 0.4, 0.4, 0, 0,
                      0.4, 0.4, 0.4, 0, 0,
                      0.4, 0.4, 0.4, 0, 0,
                      0, 0, 0, 0.85, 0,
                    ]),
              child: const GariMapCanvas(
                mode: GariMapMode.day,
                center: GariMapDefaults.addis,
                zoom: 13.2,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: GariColors.nightBlue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'G',
                      style: AppText.headline(
                        context,
                        color: GariColors.amber400,
                      ),
                    ),
                  ),
                  if (online) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: GariColors.emeraldSoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: GariColors.emerald.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: GariColors.emerald,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: GariColors.emerald.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              s.youreOnline,
                              style: const TextStyle(
                                color: GariColors.emerald,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  const SizedBox(width: 10),
                  _glassIcon(Icons.notifications_none_rounded),
                ],
              ),
            ),
          ),
          if (!online)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _toggleOnline,
                    child: Container(
                      width: 180,
                      height: 180,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 2,
                        ),
                      ),
                      child: Container(
                        width: 148,
                        height: 148,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.power_settings_new_rounded,
                              color: Colors.white.withValues(alpha: 0.35),
                              size: 30,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s.youreOffline,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              s.tapToGoOnline,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    isAm
                        ? 'ኦንላይን ሆነው በአቅራቢያዎ ጉዞ ጥያቄዎችን ይቀበሉ።'
                        : 'Go online to start receiving trip requests near you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          if (online) ...[
            Center(
              child: AnimatedBuilder(
                animation: _radar,
                builder: (_, __) {
                  return SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ...List.generate(3, (i) {
                          final t = (_radar.value + i / 3) % 1.0;
                          final size = 20 + t * 200;
                          return Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: GariColors.amber
                                    .withValues(alpha: (1 - t) * 0.45),
                                width: 1.5,
                              ),
                            ),
                          );
                        }),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: GariColors.amber,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    GariColors.amber.withValues(alpha: 0.35),
                                blurRadius: 8,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                decoration: const BoxDecoration(
                  color: GariColors.cream,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 24,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.searchingTrips,
                        style: AppText.headline(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.stayBusyAreas,
                        style: AppText.caption(context, color: GariColors.muted),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _onlineStat('890 Br', isAm ? 'ዛሬ' : 'TODAY'),
                          const SizedBox(width: 8),
                          _onlineStat('2h 14m', isAm ? 'ኦንላይን' : 'ONLINE'),
                          const SizedBox(width: 8),
                          _onlineStat('12', isAm ? 'ጉዞ' : 'TRIPS'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _toggleOnline,
                              child: Text(
                                isAm ? 'ኦፍላይን ሂድ' : 'Go offline',
                                style: const TextStyle(
                                  color: GariColors.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              onPressed: _demoOffer,
                              child: Text(
                                isAm ? 'ጥያቄዎችን አድስ' : 'Waiting for offers…',
                                style: const TextStyle(
                                  color: GariColors.amberDeep,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                ),
              ),
            ),
          ],
          if (!online)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    _statPill('890 Br', isAm ? 'ዛሬ' : 'Today'),
                    const SizedBox(width: 8),
                    _statPill('12', isAm ? 'ጉዞ' : 'Trips'),
                    const SizedBox(width: 8),
                    _statPill('4.9★', isAm ? 'ደረጃ' : 'Rating'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _glassIcon(IconData icon) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Icon(icon, color: const Color(0xFFEDEFF5), size: 20),
      );

  Widget _statPill(String n, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Text(
                n,
                style: const TextStyle(
                  color: GariColors.amber400,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _onlineStat(String n, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GariColors.border, width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                n,
                style: const TextStyle(
                  color: GariColors.nightBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l,
                style: const TextStyle(
                  color: GariColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      );
}

class _OfferSheet extends ConsumerStatefulWidget {
  const _OfferSheet();
  @override
  ConsumerState<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends ConsumerState<_OfferSheet> {
  late int left;
  late int total;
  Timer? t;

  @override
  void initState() {
    super.initState();
    total = ref.read(offerProvider)?.acceptWindowSec ?? 14;
    left = total;
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (left <= 1) {
        decline();
        return;
      }
      setState(() => left--);
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  void decline() async {
    t?.cancel();
    final o = ref.read(offerProvider);
    if (o != null) {
      try {
        await ref.read(apiProvider).client.declineTrip(o.id);
      } catch (_) {}
    }
    ref.read(offerProvider.notifier).state = null;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final o = ref.watch(offerProvider);
    if (o == null) return const SizedBox.shrink();
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    final progress = left / total;
    final distM = (o.pickupDistanceKm * 1000).round();

    return Container(
      decoration: const BoxDecoration(
        color: GariColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 5,
                        backgroundColor: GariColors.border,
                        color: GariColors.amber,
                      ),
                      Text(
                        left.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: GariColors.nightBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.newTripRequest,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: GariColors.nightBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$distM m away · Bajaj',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: GariColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GariColors.border, width: 1.5),
              ),
              child: Row(
                children: [
                  Text(
                    '${o.estimatedFare} Br',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: GariColors.nightBlue,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAEEDA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAm ? 'ግምት ክፍያ' : 'Est. fare',
                      style: const TextStyle(
                        color: Color(0xFF854F0B),
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GariColors.border, width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: GariColors.nightBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 24,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: const Color(0xFFDCD5C4),
                          ),
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: GariColors.amber,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${isAm ? 'መውሰጃ' : 'Pickup'} · ${o.pickupLandmark}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: GariColors.nightBlue,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '${isAm ? 'ማውረጃ' : 'Drop-off'} · ${o.destinationArea}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: GariColors.nightBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: GariColors.creamDim, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        isAm ? 'ርቀት ' : 'Distance ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: GariColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '6.4 km',
                        style: const TextStyle(
                          fontSize: 12,
                          color: GariColors.nightBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        isAm ? 'ጊዜ ' : 'Est. time ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: GariColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${o.estimatedDurationMin} min',
                        style: const TextStyle(
                          fontSize: 12,
                          color: GariColors.nightBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: decline,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border:
                            Border.all(color: GariColors.border, width: 1.5),
                      ),
                      child: Text(
                        s.decline,
                        style: const TextStyle(
                          color: GariColors.crimson,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () async {
                      t?.cancel();
                      try {
                        await ref.read(apiProvider).client.acceptTrip(o.id);
                        ref.read(apiProvider).client.joinTrip(o.id);
                        ref.read(activeTripProvider.notifier).state = ActiveTrip(
                          id: o.id,
                          riderName: o.riderName,
                          pickupLandmark: o.pickupLandmark,
                          destinationLandmark: o.destinationArea,
                          estimatedFare: o.estimatedFare,
                          riderPin: o.riderPin,
                        );
                        ref.read(offerProvider.notifier).state = null;
                        if (context.mounted) {
                          Navigator.pop(context);
                          context.go('/trip/${o.id}/pickup');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(drvErr(e))),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: GariColors.emerald,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: GariColors.emerald.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Text(
                        s.acceptTrip,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pickup extends ConsumerStatefulWidget {
  const _Pickup({required this.id});
  final String id;
  @override
  ConsumerState<_Pickup> createState() => _PickupState();
}

class _PickupState extends ConsumerState<_Pickup> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(activeTripProvider);
    final s = S.of(ref.watch(authProvider).locale.languageCode == 'am');
    final name = trip?.riderName ?? 'Selam A.';
    final initial = name.isNotEmpty ? name[0] : 'S';

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: GariMapCanvas(
              mode: GariMapMode.day,
              showRoute: true,
              center: GariMapDefaults.addis,
              zoom: 13.5,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _mapChip(
                    child: const Icon(
                      Icons.chevron_left,
                      color: Color(0xFFEDEFF5),
                    ),
                    onTap: () => context.go('/dashboard'),
                  ),
                  const Spacer(),
                  _mapChip(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: const Text(
                      '6.4 km · 18 min',
                      style: TextStyle(
                        color: Color(0xFFEDEFF5),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 70,
            left: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                decoration: BoxDecoration(
                  color: GariColors.nightBlue.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.turn_right, color: GariColors.amber400, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Head north on Bole Rd',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'then turn right onto Cameroon St',
                            style: TextStyle(
                              color: GariColors.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              decoration: const BoxDecoration(
                color: GariColors.cream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: GariColors.nightBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: GariColors.amber400,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: GariColors.nightBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.star,
                                    size: 12,
                                    color: GariColors.amber,
                                  ),
                                  const Text(
                                    ' 4.9',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: GariColors.nightBlue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Picking up · 2 min away',
                                style: AppText.caption(
                                  context,
                                  color: GariColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: GariColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.phone,
                            color: GariColors.nightBlue,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final max = constraints.maxWidth - 64;
                        return GestureDetector(
                          onHorizontalDragUpdate: (d) {
                            setState(() {
                              _drag = (_drag + d.delta.dx).clamp(0, max);
                            });
                          },
                          onHorizontalDragEnd: (_) async {
                            if (_drag > max * 0.65) {
                              try {
                                await ref
                                    .read(apiProvider)
                                    .client
                                    .arriveTrip(widget.id);
                                if (context.mounted) {
                                  context.go('/trip/${widget.id}/pin');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(drvErr(e))),
                                  );
                                }
                              }
                            } else {
                              setState(() => _drag = 0);
                            }
                          },
                          onTap: () async {
                            try {
                              await ref
                                  .read(apiProvider)
                                  .client
                                  .arriveTrip(widget.id);
                              if (context.mounted) {
                                context.go('/trip/${widget.id}/pin');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(drvErr(e))),
                                );
                              }
                            }
                          },
                          child: Container(
                            height: 64,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: GariColors.nightBlue,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  s.swipeArrived,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Transform.translate(
                                    offset: Offset(_drag, 0),
                                    child: Container(
                                      width: 52,
                                      height: 52,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: GariColors.amber,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.chevron_right,
                                        color: Color(0xFF1A1408),
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapChip({required Widget child, VoidCallback? onTap, EdgeInsets? padding}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: child,
      ),
    );
  }
}

class _Pin extends ConsumerStatefulWidget {
  const _Pin({required this.id});
  final String id;
  @override
  ConsumerState<_Pin> createState() => _PinState();
}

class _PinState extends ConsumerState<_Pin> {
  final c = TextEditingController();
  String? err;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(activeTripProvider);
    final s = S.of(ref.watch(authProvider).locale.languageCode == 'am');
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(
        backgroundColor: GariColors.cream,
        title: Text(s.askPin),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              trip?.riderName ?? '',
              style: AppText.title(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Demo PIN: ${trip?.riderPin ?? '4821'}',
              style: AppText.caption(context, color: GariColors.muted),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: c,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: AppText.display(context),
              decoration: InputDecoration(
                hintText: '••••',
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: GariColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: GariColors.border),
                ),
              ),
              onChanged: (_) => setState(() => err = null),
            ),
            if (err != null) ...[
              const SizedBox(height: 8),
              Text(err!, style: const TextStyle(color: GariColors.crimson)),
            ],
            const Spacer(),
            GariPrimaryButton(
              label: s.startTrip,
              enabled: c.text.length == 4,
              onPressed: () async {
                try {
                  await ref
                      .read(apiProvider)
                      .client
                      .verifyTripPin(widget.id, c.text);
                  if (context.mounted) {
                    context.go('/trip/${widget.id}/active');
                  }
                } catch (e) {
                  setState(() => err = drvErr(e));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Active extends ConsumerStatefulWidget {
  const _Active({required this.id});
  final String id;
  @override
  ConsumerState<_Active> createState() => _ActiveState();
}

class _ActiveState extends ConsumerState<_Active> {
  int fare = 42;
  Timer? t;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(
      const Duration(seconds: 2),
      (_) => setState(() => fare++),
    );
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(activeTripProvider);
    final s = S.of(ref.watch(authProvider).locale.languageCode == 'am');
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: GariMapCanvas(
              mode: GariMapMode.day,
              showRoute: true,
              center: GariMapDefaults.addis,
              zoom: 13.5,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: GariColors.nightBlue.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments, color: GariColors.amber400),
                    const SizedBox(width: 10),
                    Text(
                      'Live fare',
                      style: AppText.caption(context, color: GariColors.muted),
                    ),
                    const Spacer(),
                    BirrText(fare, size: 22, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
              decoration: const BoxDecoration(
                color: GariColors.cream,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trip?.destinationLandmark ?? '',
                      style: AppText.headline(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dropping off ${trip?.riderName ?? ''}',
                      style: AppText.caption(context, color: GariColors.muted),
                    ),
                    const SizedBox(height: 16),
                    GariPrimaryButton(
                      label: s.endTrip,
                      onPressed: () async {
                        t?.cancel();
                        try {
                          await ref
                              .read(apiProvider)
                              .client
                              .completeTrip(widget.id);
                          final fb = FareBreakdown.fromGross(fare, 15);
                          ref.read(lastFareProvider.notifier).state = fb;
                          await ref.read(apiProvider).refreshEarnings();
                          if (context.mounted) {
                            context.go('/trip/${widget.id}/done');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(drvErr(e))),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Done extends ConsumerWidget {
  const _Done({required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(lastFareProvider);
    return Scaffold(
      backgroundColor: GariColors.cream,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: GariColors.emerald),
            const SizedBox(height: 16),
            Text('Trip completed', style: AppText.title(context)),
            const SizedBox(height: 20),
            if (f != null) ...[
              _fareRow('Gross', formatBirr(f.gross)),
              _fareRow(
                'Commission ${f.commissionPercent}%',
                '−${formatBirr(f.commissionAmount)}',
              ),
              _fareRow('Net', formatBirr(f.net), bold: true),
              const SizedBox(height: 24),
            ],
            GariPrimaryButton(
              label: 'Dashboard',
              onPressed: () {
                ref.read(activeTripProvider.notifier).state = null;
                context.go('/dashboard');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _fareRow(String l, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(
              l,
              style: TextStyle(
                color: bold ? GariColors.nightBlue : GariColors.muted,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              v,
              style: TextStyle(
                color: bold ? GariColors.emerald : GariColors.nightBlue,
                fontWeight: FontWeight.w800,
                fontSize: bold ? 18 : 14,
              ),
            ),
          ],
        ),
      );
}

class _Dispute extends ConsumerWidget {
  const _Dispute({required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(title: const Text('Fare dispute')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: GariPrimaryButton(
          label: 'Submit',
          onPressed: () => context.pop(),
        ),
      ),
    );
  }
}

class _Earn extends ConsumerWidget {
  const _Earn();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    return Scaffold(
      backgroundColor: GariColors.cream,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: GariColors.nightBlue,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 16,
              20,
              26,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.earnings,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _earnTab(isAm ? 'ዛሬ' : 'Today', true),
                      _earnTab(isAm ? 'ሳምንት' : 'This week', false),
                      _earnTab(isAm ? 'ወር' : 'This month', false),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '890 Br',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  isAm ? '12 ጉዞ · 2ሰ 14ደ ኦንላይን' : '12 trips · 2h 14m online',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Row(
                  children: [
                    _earnCard(
                      Icons.layers_outlined,
                      '74 Br',
                      isAm ? 'አማካይ ጉዞ' : 'Avg. per trip',
                    ),
                    const SizedBox(width: 10),
                    _earnCard(
                      Icons.schedule,
                      '11 min',
                      isAm ? 'አማካይ ጥበቃ' : 'Avg. wait',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: GariColors.nightBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GariColors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: GariColors.amber400,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.availableCashOut,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              isAm
                                  ? '640 ብር · ወዲያውኑ ቴሌብር'
                                  : '640 Br · instant to Telebirr',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/earnings/cashout'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: GariColors.amber,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            s.cashOut,
                            style: const TextStyle(
                              color: Color(0xFF1A1408),
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isAm ? 'የዛሬ ጉዞዎች' : "Today's trips",
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: GariColors.muted,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                _txRow('Bole → Megenagna', '9:12 AM · 18 min', '+62 Br'),
                _txRow('CMC → Summit', '8:34 AM · 24 min', '+78 Br'),
                _txRow('Gerji → Edna Mall', '7:58 AM · 15 min', '+55 Br',
                    last: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _earnTab(String t, bool on) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? GariColors.amber : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            t,
            style: TextStyle(
              color: on ? const Color(0xFF1A1408) : GariColors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      );

  Widget _earnCard(IconData icon, String n, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GariColors.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: GariColors.amber, size: 18),
              const SizedBox(height: 8),
              Text(
                n,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: GariColors.nightBlue,
                ),
              ),
              Text(
                l,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: GariColors.muted,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _txRow(String t, String sub, String amt, {bool last = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: GariColors.creamDim)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: GariColors.cream,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.directions_car_filled_outlined,
                size: 18,
                color: GariColors.nightBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: GariColors.nightBlue,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                      color: GariColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              amt,
              style: const TextStyle(
                color: GariColors.emerald,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
}

class _Cash extends ConsumerWidget {
  const _Cash();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(
        backgroundColor: GariColors.cream,
        title: const Text('Cash out'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          BirrText(api.balance, size: 36, color: GariColors.nightBlue),
          if (api.debt > 0) ...[
            const SizedBox(height: 12),
            GariCard(
              child: Text(
                'Cash-trip debt ${formatBirr(api.debt)}',
                style: AppText.label(context, color: GariColors.crimson),
              ),
            ),
          ],
          const SizedBox(height: 20),
          GariPrimaryButton(
            label: 'Instant to Telebirr (2% fee)',
            onPressed: () async {
              try {
                await ref.read(apiProvider).client.payoutInstant(
                      amount: api.balance,
                      method: 'telebirr',
                    );
                await api.refreshEarnings();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cash out submitted')),
                  );
                  context.pop();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(drvErr(e))),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Trips extends ConsumerWidget {
  const _Trips();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    final trips = const [
      ('Bole → Megenagna', '9:12 AM · 6.4 km', '62 Br', '★ 5.0', ['Bajaj', 'Cash']),
      ('CMC → Summit', '8:34 AM · 8.1 km', '78 Br', '★ 4.0', ['Car', 'Wallet']),
      ('Gerji → Edna Mall', '7:58 AM · 5.2 km', '55 Br', '★ 5.0', ['Moto', 'Wallet']),
      ('Sarbet → Meskel Sq', '7:20 AM · 3.8 km', '40 Br', '★ 5.0', ['Bajaj', 'Cash']),
    ];

    return Scaffold(
      backgroundColor: GariColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Text(
                s.tripHistory,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: GariColors.nightBlue,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _chip(isAm ? 'ዛሬ' : 'Today', true),
                  const SizedBox(width: 8),
                  _chip(isAm ? 'ሳምንት' : 'This week', false),
                  const SizedBox(width: 8),
                  _chip(isAm ? 'ሁሉም' : 'All time', false),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: trips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final t = trips[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: GariColors.border, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.$1,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: GariColors.nightBlue,
                                    ),
                                  ),
                                  Text(
                                    t.$2,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11.5,
                                      color: GariColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  t.$3,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: GariColors.nightBlue,
                                  ),
                                ),
                                Text(
                                  t.$4,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    color: GariColors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: t.$5
                              .map(
                                (tag) => Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: GariColors.cream,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: GariColors.muted,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String t, bool on) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? GariColors.nightBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: on ? GariColors.nightBlue : GariColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          t,
          style: TextStyle(
            color: on ? GariColors.amber400 : GariColors.nightBlue,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      );
}

class _Prof extends ConsumerWidget {
  const _Prof();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(authProvider).driver!;
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    final name = d.name ?? 'Dawit Tesfaye';
    final initial = name.isNotEmpty ? name[0] : 'D';

    return Scaffold(
      backgroundColor: GariColors.cream,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            color: GariColors.nightBlue,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 20,
              20,
              24,
            ),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GariColors.amber.withValues(alpha: 0.15),
                    border: Border.all(color: GariColors.amber, width: 2),
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: GariColors.amber400,
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name.length < 3 ? 'Dawit Tesfaye' : name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, size: 12, color: GariColors.amber),
                    Text(
                      ' ${d.rating.toStringAsFixed(1)} · ${d.totalTrips} trips',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _badge(isAm ? 'KYC ተረጋግጧል' : 'KYC verified'),
                    const SizedBox(width: 8),
                    _badge(isAm ? 'ከፍተኛ ደረጃ' : 'Top rated'),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section(isAm ? 'ተሽከርካሪ' : 'Vehicle'),
                _profRow(
                  Icons.directions_car_filled_outlined,
                  '${d.vehicleCategory?.labelEn ?? 'Bajaj'} · ${d.vehicleColor ?? 'White'} · ${d.plate ?? 'AA-3241'}',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: GariColors.muted,
                    size: 18,
                  ),
                  onTap: () {},
                ),
                _section(isAm ? 'ሰነዶች' : 'Documents'),
                _profRow(
                  Icons.description_outlined,
                  isAm ? 'የመንጃ ፈቃድ' : 'Driving license',
                  trailing: _status(isAm ? 'ተረጋግጧል' : 'Verified', true),
                  onTap: () => context.push('/documents'),
                ),
                _profRow(
                  Icons.description_outlined,
                  isAm ? 'ኢንሹራንስ' : 'Vehicle insurance',
                  trailing: _status(isAm ? 'በመጠባበቅ' : 'Pending', false),
                  onTap: () => context.push('/documents'),
                ),
                _section(isAm ? 'መለያ' : 'Account'),
                _profRow(
                  Icons.account_balance_wallet_outlined,
                  isAm ? 'የክፍያ ዘዴ' : 'Payout method',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: GariColors.muted,
                    size: 18,
                  ),
                  onTap: () => context.push('/earnings/cashout'),
                ),
                _profRow(
                  Icons.notifications_none,
                  isAm ? 'ማሳወቂያዎች' : 'Notifications',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: GariColors.muted,
                    size: 18,
                  ),
                  onTap: () {},
                ),
                _profRow(
                  Icons.help_outline,
                  isAm ? 'እገዛ እና ድጋፍ' : 'Help and support',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: GariColors.muted,
                    size: 18,
                  ),
                  onTap: () => context.push('/support'),
                ),
                const SizedBox(height: 12),
                GariCard(
                  onTap: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/');
                  },
                  child: Text(
                    s.logout,
                    style: AppText.headline(context, color: GariColors.crimson),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: GariColors.emeraldSoft,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: GariColors.emerald.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 12, color: GariColors.emerald),
            const SizedBox(width: 5),
            Text(
              t,
              style: const TextStyle(
                color: GariColors.emerald,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(
          t.toUpperCase(),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: GariColors.muted,
            letterSpacing: 0.3,
          ),
        ),
      );

  Widget _profRow(
    IconData icon,
    String title, {
    required Widget trailing,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: GariColors.border, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(icon, color: GariColors.nightBlue, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: GariColors.nightBlue,
                      ),
                    ),
                  ),
                  trailing,
                ],
              ),
            ),
          ),
        ),
      );

  Widget _status(String t, bool ok) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: ok ? const Color(0xFFEAF3DE) : const Color(0xFFFAEEDA),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          t,
          style: TextStyle(
            color: ok ? const Color(0xFF3B6D11) : const Color(0xFF854F0B),
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      );
}

class _Quest extends ConsumerWidget {
  const _Quest();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(title: const Text('Incentives')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: GariCard(child: Text('13/20 trips before 6pm · +150 Br')),
      ),
    );
  }
}

class _DocCenter extends ConsumerWidget {
  const _DocCenter();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(title: const Text('Documents')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: GariCard(child: Text('License · expiring in 12 days')),
      ),
    );
  }
}

class _Support extends ConsumerWidget {
  const _Support();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(title: Text(S.of(false).support)),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: GariCard(
          dark: true,
          child: Text(
            'SOS → Command Center + GPS share',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _Ref extends ConsumerWidget {
  const _Ref();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(title: const Text('Refer')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'DAWIT200',
              style: AppText.display(context, color: GariColors.amberDeep),
            ),
            GariPrimaryButton(
              label: 'Share',
              onPressed: () => Share.share('Join GariGo Driver DAWIT200'),
            ),
          ],
        ),
      ),
    );
  }
}
