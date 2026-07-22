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
      backgroundColor: GariColors.cream,
      appBar: AppBar(
        backgroundColor: GariColors.cream,
        foregroundColor: GariColors.nightBlue,
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
            style: AppText.title(context),
          ),
          const SizedBox(height: 8),
          Text(
            isAm
                ? 'ከዚያ መኪና፣ ሰነዶች እና KYC ይቀጥላል — አስተዳዳሪ ያፀድቃል።'
                : 'Next you will add vehicle photos & documents. Admin must approve before you go online.',
            style: AppText.caption(context, color: GariColors.muted),
          ),
          const SizedBox(height: 28),
          _lightField(
            controller: name,
            icon: Icons.person_outline,
            hint: isAm ? 'ሙሉ ስም' : 'Full name',
            onChanged: (_) => setState(() => error = null),
          ),
          const SizedBox(height: 14),
          _lightField(
            controller: phone,
            icon: Icons.phone_outlined,
            hint: isAm ? 'ስልክ (9xxxxxxxx)' : 'Phone (9xxxxxxxx)',
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() => error = null),
          ),
          if (otpSent) ...[
            const SizedBox(height: 14),
            _lightField(
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
              style: AppText.caption(context, color: GariColors.crimson),
            ),
          ],
          const SizedBox(height: 20),
          GariPrimaryButton(
            label: busy
                ? '…'
                : otpSent
                    ? (isAm ? 'መለያ ፍጠር እና ቀጥል' : 'Create account & continue')
                    : (isAm ? 'OTP ላክ' : 'Send OTP'),
            enabled: !busy,
            loading: busy,
            onPressed: otpSent ? _createAccount : _sendOtp,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/'),
            child: Text(
              isAm ? 'አስቀድሞ መለያ አለዎት? ይግቡ' : 'Already a driver? Sign in',
              style: AppText.label(context, color: GariColors.amberDeep),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAm ? 'OTP 123456' : 'Demo OTP 123456',
            textAlign: TextAlign.center,
            style: AppText.caption(context, color: GariColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _lightField({
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: GariColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: GariColors.muted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              onChanged: onChanged,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: GariColors.nightBlue,
              ),
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
          if (suffix != null) suffix,
        ],
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
      backgroundColor: GariColors.cream,
      body: Column(
        children: [
          _DriverAuthHero(
            isAm: isAm,
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
                Text(
                  (isAm ? 'ስልክ ወይም መለያ' : 'Phone or driver ID').toUpperCase(),
                  style: AppText.caption(context, color: GariColors.muted)
                      .copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                _authField(
                  controller: id,
                  hint: s.driverIdOrPhone,
                  keyboardType: TextInputType.phone,
                  prefix: Icons.badge_outlined,
                  onChanged: (_) => setState(() => error = null),
                ),
                const SizedBox(height: 16),
                Text(
                  s.pinHint.toUpperCase(),
                  style: AppText.caption(context, color: GariColors.muted)
                      .copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                _authField(
                  controller: pin,
                  hint: '••••••',
                  obscure: obscure,
                  keyboardType: TextInputType.number,
                  prefix: Icons.lock_outline,
                  onChanged: (_) => setState(() => error = null),
                  suffix: IconButton(
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: GariColors.muted,
                      size: 18,
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: AppText.caption(context, color: GariColors.crimson),
                  ),
                ],
                const SizedBox(height: 18),
                GariPrimaryButton(
                  label: s.goOnline,
                  enabled: !busy,
                  loading: busy,
                  onPressed: _goOnline,
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: busy ? null : _applyToDrive,
                  child: Text.rich(
                    TextSpan(
                      style: AppText.caption(context, color: GariColors.muted),
                      children: [
                        TextSpan(text: '${s.newDriver} '),
                        TextSpan(
                          text: s.applyToDrive,
                          style: const TextStyle(
                            color: GariColors.nightBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${s.demoOtp}',
                  textAlign: TextAlign.center,
                  style: AppText.caption(context, color: GariColors.amberDeep),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider(color: GariColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        isAm ? 'ተሽከርካሪዎች' : 'Vehicle types',
                        style: AppText.caption(context, color: GariColors.muted),
                      ),
                    ),
                    const Expanded(child: Divider(color: GariColors.border)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _vchip(Icons.airport_shuttle_outlined, 'Bajaj'),
                    _dot(),
                    _vchip(Icons.two_wheeler_outlined, 'Moto'),
                    _dot(),
                    _vchip(Icons.directions_car_outlined, 'Car'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _authField({
    required TextEditingController controller,
    required String hint,
    required IconData prefix,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: GariColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(prefix, color: GariColors.muted, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              onChanged: onChanged,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: GariColors.nightBlue,
              ),
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
          if (suffix != null) suffix,
        ],
      ),
    );
  }

  Widget _vchip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: GariColors.muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: GariColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Text('·', style: TextStyle(color: GariColors.border)),
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
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(
        backgroundColor: GariColors.cream,
        foregroundColor: GariColors.nightBlue,
        title: const Text('OTP'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              isAm ? 'ኮድ ያስገቡ' : 'Enter verification code',
              style: AppText.title(context),
            ),
            const SizedBox(height: 20),
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
                      color: GariColors.nightBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: GariColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: GariColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: GariColors.amber, width: 1.5),
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
              S.of(isAm).demoOtp,
              style: AppText.caption(context, color: GariColors.amberDeep),
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
      backgroundColor: GariColors.cream,
      appBar: AppBar(
        backgroundColor: GariColors.cream,
        foregroundColor: GariColors.nightBlue,
        title: const Text('Driver photo'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: GariColors.border, width: 1.5),
                ),
                child: const Icon(Icons.person,
                    size: 64, color: GariColors.amberDeep),
              ),
              const SizedBox(height: 16),
              Text(
                'Clear face photo for KYC verification',
                textAlign: TextAlign.center,
                style: AppText.body(context, color: GariColors.muted),
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
  int todayBr = 0;
  int todayTrips = 0;
  bool _listening = false;
  Timer? _offerPoll;

  @override
  void initState() {
    super.initState();
    _radar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadToday();
      final online =
          ref.read(authProvider).driver?.onlineStatus == OnlineStatus.online;
      if (online) {
        _listenOffers(force: true);
        _startOfferPoll();
      }
    });
  }

  Future<void> _loadToday() async {
    try {
      final bundle = await ref.read(apiProvider).earningsBundle();
      final today = Map<String, dynamic>.from(bundle['today'] as Map? ?? {});
      if (!mounted) return;
      setState(() {
        todayBr = (today['gross'] as num?)?.round() ?? 0;
        todayTrips = (today['trips'] as num?)?.round() ?? 0;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _offerPoll?.cancel();
    OfferRing.stop();
    _radar.dispose();
    super.dispose();
  }

  Future<void> _toggleOnline() async {
    final d = ref.read(authProvider).driver!;
    final online = d.onlineStatus == OnlineStatus.online;
    try {
      await ref.read(apiProvider).setOnline(!online);
      ref.read(authProvider.notifier).upd(ref.read(apiProvider).driver!);
      if (!online) {
        _listenOffers(force: true);
        _startOfferPoll();
      } else {
        _offerPoll?.cancel();
        _offerPoll = null;
        OfferRing.stop();
        final socket = ref.read(apiProvider).client.socket;
        socket?.off('ride_request');
        _listening = false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(drvErr(e))),
        );
      }
    }
  }

  void _startOfferPoll() {
    _offerPoll?.cancel();
    _offerPoll = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      if (ref.read(offerProvider) != null) return;
      final online =
          ref.read(authProvider).driver?.onlineStatus == OnlineStatus.online;
      if (!online) return;
      try {
        final m = await ref.read(apiProvider).client.driverPendingOffer();
        if (m != null && mounted && ref.read(offerProvider) == null) {
          _presentOffer(m);
        }
      } catch (_) {}
    });
  }

  void _presentOffer(Map<String, dynamic> m) {
    if (ref.read(offerProvider) != null) return;
    if (ref.read(apiProvider).prefs.getBool('offer_ring') ?? true) {
      OfferRing.start();
    }
    ref.read(offerProvider.notifier).state = TripOffer(
      id: m['tripId'].toString(),
      pickupLandmark: m['pickupLandmark']?.toString() ?? 'Pickup',
      pickupDistanceKm: (m['pickupDistanceKm'] as num?)?.toDouble() ?? 0.5,
      destinationArea: m['destinationArea']?.toString() ?? 'Drop-off',
      estimatedFare: (m['estimatedFare'] as num?)?.round() ?? 0,
      estimatedDurationMin: (m['estimatedDurationMin'] as num?)?.round() ?? 15,
      acceptWindowSec: (m['acceptWindowSec'] as num?)?.round() ?? 20,
      riderPin: m['riderPin']?.toString() ?? '0000',
      category: m['category']?.toString(),
      tripDistanceKm: (m['tripDistanceKm'] as num?)?.toDouble(),
      paymentMethod: m['paymentMethod']?.toString(),
      riderName: m['riderName']?.toString(),
      riderPhotoUrl: m['riderPhotoUrl']?.toString(),
      riderRating: (m['riderRating'] as num?)?.toDouble(),
    );
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const _OfferSheet(),
    ).whenComplete(OfferRing.stop);
  }

  void _listenOffers({bool force = false}) {
    if (_listening && !force) return;
    _listening = true;
    final socket = ref.read(apiProvider).client.socket;
    socket?.off('ride_request');
    socket?.on('ride_request', (data) {
      if (!mounted) return;
      final m = Map<String, dynamic>.from(data as Map);
      _presentOffer(m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(authProvider).driver!;
    final online = d.onlineStatus == OnlineStatus.online;
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);

    return Scaffold(
      backgroundColor: GariColors.cream,
      body: Stack(
        children: [
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: online
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                  : const ColorFilter.matrix(<double>[
                      0.55, 0.55, 0.55, 0, 0,
                      0.55, 0.55, 0.55, 0, 0,
                      0.55, 0.55, 0.55, 0, 0,
                      0, 0, 0, 0.9, 0,
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: GariColors.border, width: 1.5),
                    ),
                    child: Text(
                      'G',
                      style: AppText.headline(context, color: GariColors.amberDeep),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Material(
                      color: online
                          ? GariColors.emeraldSoft
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: _toggleOnline,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: online
                                  ? GariColors.emerald.withValues(alpha: 0.4)
                                  : GariColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: online
                                      ? GariColors.emerald
                                      : GariColors.muted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  online ? s.youreOnline : s.youreOffline,
                                  style: TextStyle(
                                    color: online
                                        ? GariColors.emerald
                                        : GariColors.nightBlue,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Switch.adaptive(
                                value: online,
                                activeTrackColor: GariColors.emerald,
                                onChanged: (_) => _toggleOnline(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => context.push('/profile/settings'),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: GariColors.border, width: 1.5),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: GariColors.nightBlue, size: 20),
                    ),
                  ),
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
                      width: 168,
                      height: 168,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: GariColors.border, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: GariColors.nightBlue.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: GariColors.amber,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.power_settings_new_rounded,
                              color: Color(0xFF1A1408),
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.youreOffline,
                            style: const TextStyle(
                              color: GariColors.nightBlue,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            s.tapToGoOnline,
                            style: AppText.caption(context, color: GariColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      isAm
                          ? 'ኦንላይን ሆነው በአቅራቢያዎ ጉዞ ጥያቄዎችን ይቀበሉ።'
                          : 'Go online to start receiving trip requests near you.',
                      textAlign: TextAlign.center,
                      style: AppText.caption(context, color: GariColors.muted),
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
                          decoration: const BoxDecoration(
                            color: GariColors.amber,
                            shape: BoxShape.circle,
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
                      color: Color(0x28000000),
                      blurRadius: 24,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.searchingTrips, style: AppText.headline(context)),
                    const SizedBox(height: 4),
                    Text(
                      s.stayBusyAreas,
                      style: AppText.caption(context, color: GariColors.muted),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _onlineStat('$todayBr Br', isAm ? 'ዛሬ' : 'TODAY'),
                        const SizedBox(width: 8),
                        _onlineStat(
                          '${(d.matchRadiusKm * 1000).round()} m',
                          isAm ? 'ራዲየስ' : 'RADIUS',
                        ),
                        const SizedBox(width: 8),
                        _onlineStat('$todayTrips', isAm ? 'ጉዞ' : 'TRIPS'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GariPrimaryButton(
                      label: isAm ? 'ኦፍላይን ሂድ' : 'Go offline',
                      onPressed: _toggleOnline,
                    ),
                    TextButton(
                      onPressed: () => context.push('/profile/settings'),
                      child: Text(
                        isAm ? 'ራዲየስ ቀይር' : 'Job radius',
                        style: const TextStyle(
                          color: GariColors.amberDeep,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GariPrimaryButton(
                      label: isAm ? 'ኦንላይን ሂድ' : 'Go online',
                      onPressed: _toggleOnline,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _statPill('$todayBr Br', isAm ? 'ዛሬ' : 'Today'),
                        const SizedBox(width: 8),
                        _statPill('$todayTrips', isAm ? 'ጉዞ' : 'Trips'),
                        const SizedBox(width: 8),
                        _statPill(
                          '${d.rating.toStringAsFixed(1)}★',
                          isAm ? 'ደረጃ' : 'Rating',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statPill(String n, String l) => Expanded(
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
                l.toUpperCase(),
                style: const TextStyle(
                  color: GariColors.muted,
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

class _DriverAuthHero extends StatelessWidget {
  const _DriverAuthHero({
    required this.isAm,
    required this.onLang,
  });
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
                  text: 'ኦንላይን ሂድ',
                  style: TextStyle(color: GariColors.amber),
                ),
                TextSpan(text: '\nገቢ ማግኘት ይጀምሩ።'),
              ]
            : const [
                TextSpan(text: 'Addis, '),
                TextSpan(
                  text: 'go online',
                  style: TextStyle(color: GariColors.amber),
                ),
                TextSpan(text: '\nand start earning.'),
              ],
      ),
    );
  }
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
    OfferRing.stop();
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
                        '$distM m away · ${(o.category ?? ref.watch(authProvider).driver?.vehicleCategory?.name ?? 'ride').toUpperCase()}',
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GariColors.border, width: 1.5),
              ),
              child: Row(
                children: [
                  GariProfileAvatar(
                    imageUrl: () {
                      final u = GariConfig.mediaUrl(o.riderPhotoUrl);
                      return u.isEmpty ? null : u;
                    }(),
                    fallbackLetter: o.riderName ?? 'R',
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.riderName ?? (isAm ? 'ተሳፋሪ' : 'Rider'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: GariColors.nightBlue,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAm
                              ? 'ስልክ ከተቀበሉ በኋላ ይታያል'
                              : 'Phone shown after you accept',
                          style: AppText.caption(context,
                              color: GariColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (o.riderRating != null)
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: GariColors.amber),
                        Text(
                          ' ${o.riderRating!.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: GariColors.nightBlue,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
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
                        '${(o.tripDistanceKm ?? o.pickupDistanceKm).toStringAsFixed(1)} km',
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
                      OfferRing.stop();
                      try {
                        final res =
                            await ref.read(apiProvider).client.acceptTrip(o.id);
                        ref.read(apiProvider).client.joinTrip(o.id);
                        final rider = Map<String, dynamic>.from(
                            res['rider'] as Map? ?? {});
                        ref.read(activeTripProvider.notifier).state = ActiveTrip(
                          id: o.id,
                          riderName: rider['name']?.toString() ??
                              o.riderName ??
                              'Rider',
                          pickupLandmark: o.pickupLandmark,
                          destinationLandmark: o.destinationArea,
                          estimatedFare: o.estimatedFare,
                          riderPin: o.riderPin,
                          riderPhotoUrl: rider['photoUrl']?.toString() ??
                              o.riderPhotoUrl,
                          riderPhone: rider['phone']?.toString(),
                          riderRating: (rider['rating'] as num?)?.toDouble() ??
                              o.riderRating,
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
    final name = trip?.riderName ?? 'Rider';
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';

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
                    child: Text(
                      trip == null ? '—' : '${trip.estimatedFare} Br',
                      style: const TextStyle(
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
                child: Row(
                  children: [
                    const Icon(Icons.turn_right, color: GariColors.amber400, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(
                              trip?.pickupLandmark ?? 'Navigate to pickup',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              trip?.destinationLandmark ?? '',
                              style: const TextStyle(
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
                        GariProfileAvatar(
                          imageUrl: () {
                            final u = GariConfig.mediaUrl(trip?.riderPhotoUrl);
                            return u.isEmpty ? null : u;
                          }(),
                          fallbackLetter: name,
                          radius: 24,
                          onTap: () => showGariContactSheet(
                            context,
                            title: isAm ? 'ተሳፋሪ' : 'Rider',
                            name: name,
                            photoUrl: () {
                              final u = GariConfig.mediaUrl(trip?.riderPhotoUrl);
                              return u.isEmpty ? null : u;
                            }(),
                            phone: trip?.riderPhone,
                            subtitle: trip?.riderRating != null
                                ? '${trip!.riderRating!.toStringAsFixed(1)} ★'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: GariColors.nightBlue,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (trip?.riderRating != null) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.star,
                                      size: 12,
                                      color: GariColors.amber,
                                    ),
                                    Text(
                                      ' ${trip!.riderRating!.toStringAsFixed(1)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: GariColors.nightBlue,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                trip?.riderPhone ??
                                    (ref.watch(authProvider)
                                                .locale
                                                .languageCode ==
                                            'am'
                                        ? 'ስልክ በመጫን…'
                                        : 'Loading phone…'),
                                style: AppText.caption(
                                  context,
                                  color: GariColors.amberDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _circleAction(
                          Icons.phone,
                          () => _callRider(context, ref, widget.id),
                        ),
                        const SizedBox(width: 8),
                        _circleAction(
                          Icons.chat_bubble_outline,
                          () => context.push('/trip/${widget.id}/chat'),
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

Widget _circleAction(IconData icon, VoidCallback onTap) {
  return Material(
    color: Colors.white,
    shape: CircleBorder(
      side: BorderSide(color: GariColors.border, width: 1.5),
    ),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: GariColors.nightBlue, size: 18),
      ),
    ),
  );
}

Future<void> _callRider(
  BuildContext context,
  WidgetRef ref,
  String tripId,
) async {
  var phone = ref.read(activeTripProvider)?.riderPhone;
  try {
    final session =
        await ref.read(apiProvider).client.createCallSession(tripId);
    phone = session['counterpartPhone']?.toString() ?? phone;
    if (phone != null && phone.isNotEmpty) {
      ref.read(activeTripProvider.notifier).state =
          ref.read(activeTripProvider)?.copyWith(riderPhone: phone);
    }
  } catch (_) {}
  if (phone == null || phone.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number unavailable')),
      );
    }
    return;
  }
  final uri = Uri(scheme: 'tel', path: phone);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(phone)));
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
              'PIN: ${trip?.riderPin ?? '—'}',
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
  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(activeTripProvider);
    final fare = trip?.estimatedFare ?? 0;
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
                    if (trip?.riderPhone != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        trip!.riderPhone!,
                        style: AppText.caption(context,
                            color: GariColors.amberDeep),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _callRider(context, ref, widget.id),
                            icon: const Icon(Icons.phone_outlined),
                            label: const Text('Call'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: GariColors.nightBlue,
                              side: const BorderSide(color: GariColors.border),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/trip/${widget.id}/chat'),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Message'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: GariColors.nightBlue,
                              side: const BorderSide(color: GariColors.border),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GariPrimaryButton(
                      label: s.endTrip,
                      onPressed: () async {
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

class _Earn extends ConsumerStatefulWidget {
  const _Earn();
  @override
  ConsumerState<_Earn> createState() => _EarnState();
}

class _EarnState extends ConsumerState<_Earn> {
  int period = 0; // 0 today, 1 week
  Map<String, dynamic>? bundle;
  String? err;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final b = await ref.read(apiProvider).earningsBundle();
      if (mounted) setState(() {
        bundle = b;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        err = drvErr(e);
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    final bal = Map<String, dynamic>.from(bundle?['balance'] as Map? ?? {});
    final today = Map<String, dynamic>.from(bundle?['today'] as Map? ?? {});
    final week = Map<String, dynamic>.from(bundle?['week'] as Map? ?? {});
    final trips = List<dynamic>.from(bundle?['trips'] as List? ?? const []);
    final gross = period == 0
        ? (today['gross'] as num?)?.round() ?? 0
        : (week['gross'] as num?)?.round() ?? 0;
    final count = period == 0
        ? (today['trips'] as num?)?.round() ?? 0
        : (week['trips'] as num?)?.round() ?? 0;
    final available = (bal['available_balance'] as num?)?.round() ??
        ref.watch(apiProvider).balance;
    final avg = count > 0 ? (gross / count).round() : 0;

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
                Row(
                  children: [
                    Text(
                      s.earnings,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => period = 0),
                          child: _earnTab(isAm ? 'ዛሬ' : 'Today', period == 0),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => period = 1),
                          child: _earnTab(
                              isAm ? 'ሳምንት' : 'This week', period == 1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (loading)
                  const Text('…',
                      style: TextStyle(color: Colors.white, fontSize: 38))
                else if (err != null)
                  Text(err!, style: const TextStyle(color: Colors.white70))
                else ...[
                  Text(
                    '$gross Br',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    isAm ? '$count ጉዞ' : '$count trips',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
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
                      '$avg Br',
                      isAm ? 'አማካይ ጉዞ' : 'Avg. per trip',
                    ),
                    const SizedBox(width: 10),
                    _earnCard(
                      Icons.account_balance_wallet_outlined,
                      '$available Br',
                      isAm ? 'ሊወጣ የሚችል' : 'Available',
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
                      const Icon(Icons.payments_outlined,
                          color: GariColors.amber400),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isAm
                              ? '$available ብር · ወዲያውኑ ቴሌብር'
                              : '$available Br ready to cash out',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/earnings/cashout'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
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
                const SizedBox(height: 18),
                Text(isAm ? 'የቅርብ ጉዞዎች' : 'Recent trips',
                    style: AppText.headline(context)),
                const SizedBox(height: 10),
                if (trips.isEmpty)
                  Text(isAm ? 'ጉዞ የለም' : 'No completed trips yet',
                      style: AppText.caption(context, color: GariColors.muted)),
                ...trips.take(10).map((raw) {
                  final t = Map<String, dynamic>.from(raw as Map);
                  final route =
                      '${t['pickup_landmark'] ?? 'Pickup'} → ${t['dropoff_landmark'] ?? 'Drop'}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GariCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(route,
                                style: AppText.body(context),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('${t['fare_total']} Br',
                              style: AppText.headline(context)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _earnTab(String t, bool on) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          t,
          style: TextStyle(
            color: on ? Colors.white : Colors.white54,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      );

  Widget _earnCard(IconData icon, String n, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GariColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: GariColors.amberDeep),
              const SizedBox(height: 8),
              Text(n,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: GariColors.nightBlue)),
              Text(l,
                  style: const TextStyle(
                      fontSize: 11, color: GariColors.muted, fontWeight: FontWeight.w600)),
            ],
          ),
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

class _Trips extends ConsumerStatefulWidget {
  const _Trips();
  @override
  ConsumerState<_Trips> createState() => _TripsState();
}

class _TripsState extends ConsumerState<_Trips> {
  List<Map<String, dynamic>> trips = [];
  bool loading = true;
  String? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = null;
    });
    try {
      final list = await ref.read(apiProvider).earningsTrips();
      if (mounted) {
        setState(() {
          trips = list;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          err = drvErr(e);
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);

    return Scaffold(
      backgroundColor: GariColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Text(
                    s.tripHistory,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: GariColors.nightBlue,
                    ),
                  ),
                  const Spacer(),
                  IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : err != null
                      ? Center(child: Text(err!))
                      : trips.isEmpty
                          ? Center(
                              child: Text(
                                isAm ? 'ጉዞ የለም' : 'No trips yet',
                                style: AppText.caption(context,
                                    color: GariColors.muted),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              itemCount: trips.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final t = trips[i];
                                final route =
                                    '${t['pickup_landmark'] ?? 'Pickup'} → ${t['dropoff_landmark'] ?? 'Drop'}';
                                final km = t['distance_km'];
                                final dist = km != null
                                    ? '${(km as num).toStringAsFixed(1)} km'
                                    : '';
                                final when = t['completed_at']?.toString() ?? '';
                                final rating = t['rider_rating'];
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: GariColors.border, width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(route,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color: GariColors.nightBlue,
                                                )),
                                            Text(
                                              [
                                                if (dist.isNotEmpty) dist,
                                                if (when.isNotEmpty)
                                                  when.length > 16
                                                      ? when.substring(0, 16)
                                                      : when,
                                              ].join(' · '),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text('${t['fare_total']} Br',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                                color: GariColors.nightBlue,
                                              )),
                                          if (rating != null)
                                            Text('★ $rating',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11,
                                                  color: GariColors.amber,
                                                )),
                                        ],
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
}

class _Prof extends ConsumerWidget {
  const _Prof();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(authProvider).driver!;
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    final name = d.name?.trim().isNotEmpty == true ? d.name! : d.phone;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';
    final photo = d.photoUrl;

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
                GestureDetector(
                  onTap: () {
                    final u = GariConfig.mediaUrl(photo);
                    if (u.isNotEmpty) {
                      showGariPhotoPreview(context, u);
                    } else {
                      context.push('/profile/edit');
                    }
                  },
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: GariColors.amber.withValues(alpha: 0.15),
                    backgroundImage: () {
                      final u = GariConfig.mediaUrl(photo);
                      return u.isNotEmpty ? NetworkImage(u) : null;
                    }(),
                    child: photo == null || photo.isEmpty
                        ? Text(
                            initial,
                            style: const TextStyle(
                              color: GariColors.amber400,
                              fontWeight: FontWeight.w800,
                              fontSize: 26,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
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
                    if (d.approvalStatus == ApprovalStatus.approved)
                      _badge(isAm ? 'KYC ተረጋግጧል' : 'KYC verified'),
                    const SizedBox(width: 8),
                    _badge(
                      '${(d.matchRadiusKm * 1000).round()} m radius',
                    ),
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
                _section(isAm ? 'መለያ' : 'Account'),
                _profRow(
                  Icons.edit_outlined,
                  isAm ? 'መገለጫ አርትዕ' : 'Edit profile & photo',
                  trailing: const Icon(Icons.chevron_right,
                      color: GariColors.muted, size: 18),
                  onTap: () => context.push('/profile/edit'),
                ),
                _profRow(
                  Icons.tune_rounded,
                  isAm ? 'ቅንብሮች እና ራዲየስ' : 'Settings & job radius',
                  trailing: const Icon(Icons.chevron_right,
                      color: GariColors.muted, size: 18),
                  onTap: () => context.push('/profile/settings'),
                ),
                _section(isAm ? 'ተሽከርካሪ' : 'Vehicle'),
                _profRow(
                  Icons.directions_car_filled_outlined,
                  '${d.vehicleCategory?.labelEn ?? '—'} · ${d.vehicleColor ?? '—'} · ${d.plate ?? '—'}',
                  trailing: const Icon(Icons.chevron_right,
                      color: GariColors.muted, size: 18),
                  onTap: () => context.push('/documents'),
                ),
                _section(isAm ? 'ሰነዶች' : 'Documents'),
                _profRow(
                  Icons.description_outlined,
                  isAm ? 'ሰነዶች ማዕከል' : 'Document center',
                  trailing: const Icon(Icons.chevron_right,
                      color: GariColors.muted, size: 18),
                  onTap: () => context.push('/documents'),
                ),
                _section(isAm ? 'ሌላ' : 'More'),
                _profRow(
                  Icons.account_balance_wallet_outlined,
                  isAm ? 'የክፍያ ዘዴ / ገንዘብ ማውጣት' : 'Payout / cash out',
                  trailing: const Icon(Icons.chevron_right,
                      color: GariColors.muted, size: 18),
                  onTap: () => context.push('/earnings/cashout'),
                ),
                _profRow(
                  Icons.emoji_events_outlined,
                  isAm ? 'ተልእኮዎች' : 'Quests & incentives',
                  trailing: const Icon(Icons.chevron_right,
                      color: GariColors.muted, size: 18),
                  onTap: () => context.push('/incentives'),
                ),
                _profRow(
                  Icons.help_outline,
                  isAm ? 'እገዛ እና ድጋፍ' : 'Help and support',
                  trailing: const Icon(Icons.chevron_right,
                      color: GariColors.muted, size: 18),
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

class _Quest extends ConsumerStatefulWidget {
  const _Quest();
  @override
  ConsumerState<_Quest> createState() => _QuestState();
}

class _QuestState extends ConsumerState<_Quest> {
  List<dynamic> quests = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final q = await ref.read(apiProvider).client.driverQuests();
      if (mounted) setState(() {
        quests = q;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(title: Text(isAm ? 'ተልእኮዎች' : 'Incentives')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : quests.isEmpty
              ? Center(
                  child: Text(isAm ? 'ንቁ ተልእኮ የለም' : 'No active quests',
                      style: AppText.caption(context, color: GariColors.muted)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: quests.map((raw) {
                    final q = Map<String, dynamic>.from(raw as Map);
                    final title = isAm
                        ? (q['title_am'] ?? q['title_en'])
                        : (q['title_en'] ?? q['title_am']);
                    final progress = q['progress'] ?? 0;
                    final goal = q['goal'] ?? 1;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GariCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$title', style: AppText.headline(context)),
                            const SizedBox(height: 6),
                            Text(
                              '$progress / $goal · ${q['reward_birr']} Br',
                              style: AppText.caption(context,
                                  color: GariColors.muted),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: goal > 0
                                  ? (progress as num) / (goal as num)
                                  : 0,
                              color: GariColors.amber,
                              backgroundColor: GariColors.creamDim,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
    );
  }
}

class _DocCenter extends ConsumerStatefulWidget {
  const _DocCenter();
  @override
  ConsumerState<_DocCenter> createState() => _DocCenterState();
}

class _DocCenterState extends ConsumerState<_DocCenter> {
  Map<String, dynamic>? data;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(apiProvider).client.listDriverDocuments();
      if (mounted) setState(() {
        data = d;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final docs = List<dynamic>.from(data?['documents'] as List? ?? const []);
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(title: Text(isAm ? 'ሰነዶች' : 'Documents')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (docs.isEmpty)
                  Text(isAm ? 'ሰነድ የለም' : 'No documents uploaded yet'),
                ...docs.map((raw) {
                  final d = Map<String, dynamic>.from(raw as Map);
                  final ok = d['verified'] == true;
                  final rejected = d['rejection_reason'] != null;
                  return ListTile(
                    title: Text('${d['doc_type']}'),
                    subtitle: Text(rejected
                        ? '${d['rejection_reason']}'
                        : (ok
                            ? (isAm ? 'ተረጋግጧል' : 'Verified')
                            : (isAm ? 'በመጠባበቅ' : 'Pending review'))),
                    trailing: Icon(
                      ok
                          ? Icons.check_circle
                          : rejected
                              ? Icons.cancel
                              : Icons.schedule,
                      color: ok
                          ? GariColors.emerald
                          : rejected
                              ? GariColors.crimson
                              : GariColors.amberDeep,
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _Support extends ConsumerStatefulWidget {
  const _Support();
  @override
  ConsumerState<_Support> createState() => _SupportState();
}

class _SupportState extends ConsumerState<_Support> {
  final subject = TextEditingController();
  final message = TextEditingController();
  List<dynamic> tickets = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await ref.read(apiProvider).client.driverTickets();
      if (mounted) setState(() => tickets = t);
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (subject.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      await ref.read(apiProvider).client.createDriverTicket(
            subject: subject.text.trim(),
            message: message.text.trim().isEmpty ? null : message.text.trim(),
          );
      subject.clear();
      message.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket submitted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(drvErr(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(title: Text(S.of(isAm).support)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: subject,
            decoration: InputDecoration(
              labelText: isAm ? 'ርዕስ' : 'Subject',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: message,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: isAm ? 'መልዕክት' : 'Message',
            ),
          ),
          const SizedBox(height: 12),
          GariPrimaryButton(
            label: busy ? '…' : (isAm ? 'ላክ' : 'Submit ticket'),
            onPressed: busy ? null : _submit,
          ),
          const SizedBox(height: 20),
          Text(isAm ? 'የእርስዎ ትኬቶች' : 'Your tickets',
              style: AppText.headline(context)),
          ...tickets.map((raw) {
            final t = Map<String, dynamic>.from(raw as Map);
            return ListTile(
              title: Text('${t['subject']}'),
              subtitle: Text('${t['status']} · ${t['created_at']}'),
            );
          }),
        ],
      ),
    );
  }
}

class _EditProfile extends ConsumerStatefulWidget {
  const _EditProfile();
  @override
  ConsumerState<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends ConsumerState<_EditProfile> {
  late final TextEditingController name;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
        text: ref.read(authProvider).driver?.name ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await pickUpload(allowPdf: false);
      if (picked == null) return;
      setState(() => busy = true);
      await ref.read(apiProvider).uploadPhoto(
            bytes: picked.bytes,
            filename: picked.name,
          );
      ref.read(authProvider.notifier).upd(ref.read(apiProvider).driver!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated')),
        );
      }
    } catch (e) {
      setState(() => error = drvErr(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final d = await ref.read(apiProvider).updateProfile(
            name: name.text.trim(),
          );
      ref.read(authProvider.notifier).upd(d);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => error = drvErr(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(authProvider).driver!;
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(title: Text(isAm ? 'መገለጫ' : 'Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: GestureDetector(
              onTap: busy ? null : _pickPhoto,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: GariColors.creamDim,
                backgroundImage: () {
                  final u = GariConfig.mediaUrl(d.photoUrl);
                  return u.isNotEmpty ? NetworkImage(u) : null;
                }(),
                child: (d.photoUrl == null || d.photoUrl!.isEmpty)
                    ? const Icon(Icons.add_a_photo, color: GariColors.amberDeep)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAm ? 'ፎቶ ለመቀየር ይንኩ' : 'Tap to change photo',
            textAlign: TextAlign.center,
            style: AppText.caption(context, color: GariColors.muted),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: name,
            decoration: InputDecoration(
              labelText: isAm ? 'ሙሉ ስም' : 'Full name',
            ),
          ),
          const SizedBox(height: 8),
          Text(d.phone, style: AppText.caption(context, color: GariColors.muted)),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: GariColors.crimson)),
          ],
          const SizedBox(height: 20),
          GariPrimaryButton(
            label: busy ? '…' : (isAm ? 'አስቀምጥ' : 'Save'),
            onPressed: busy ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _Settings extends ConsumerStatefulWidget {
  const _Settings();
  @override
  ConsumerState<_Settings> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<_Settings> {
  late double radiusKm;
  bool busy = false;
  bool ringEnabled = true;

  @override
  void initState() {
    super.initState();
    radiusKm = ref.read(authProvider).driver?.matchRadiusKm ?? 2.0;
    ringEnabled =
        ref.read(apiProvider).prefs.getBool('offer_ring') ?? true;
  }

  Future<void> _saveRadius(double v) async {
    setState(() {
      radiusKm = v;
      busy = true;
    });
    try {
      final d = await ref.read(apiProvider).updateProfile(matchRadiusKm: v);
      ref.read(authProvider.notifier).upd(d);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(drvErr(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final meters = (radiusKm * 1000).round();
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(title: Text(isAm ? 'ቅንብሮች' : 'Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            isAm ? 'የስራ ራዲየስ' : 'Job search radius',
            style: AppText.headline(context),
          ),
          const SizedBox(height: 6),
          Text(
            isAm
                ? 'ከ500 ሜትር እስከ 2 ኪሜ — ብቻ በዚህ ርቀት ውስጥ ጉዞዎች ይቀርባሉ።'
                : 'From 500 m to 2 km — you only get jobs within this distance.',
            style: AppText.caption(context, color: GariColors.muted),
          ),
          const SizedBox(height: 16),
          Text(
            meters >= 1000
                ? '${(meters / 1000).toStringAsFixed(1)} km'
                : '$meters m',
            style: AppText.display(context, color: GariColors.amberDeep),
          ),
          Slider(
            value: radiusKm.clamp(0.5, 2.0),
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: meters >= 1000
                ? '${(meters / 1000).toStringAsFixed(1)} km'
                : '$meters m',
            onChanged: busy
                ? null
                : (v) => setState(() => radiusKm = v),
            onChangeEnd: busy ? null : _saveRadius,
          ),
          Row(
            children: [
              Text('500 m',
                  style: AppText.caption(context, color: GariColors.muted)),
              const Spacer(),
              Text('2 km',
                  style: AppText.caption(context, color: GariColors.muted)),
            ],
          ),
          const SizedBox(height: 28),
          Text(isAm ? 'ቋንቋ' : 'Language', style: AppText.headline(context)),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('English'),
                selected:
                    ref.watch(authProvider).locale.languageCode != 'am',
                onSelected: (_) async {
                  await ref
                      .read(authProvider.notifier)
                      .setLocale(const Locale('en'));
                  await ref
                      .read(apiProvider)
                      .updateProfile(languagePref: 'en');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('አማርኛ'),
                selected:
                    ref.watch(authProvider).locale.languageCode == 'am',
                onSelected: (_) async {
                  await ref
                      .read(authProvider.notifier)
                      .setLocale(const Locale('am'));
                  await ref
                      .read(apiProvider)
                      .updateProfile(languagePref: 'am');
                },
              ),
            ],
          ),
          const SizedBox(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(isAm ? 'የጥያቄ ድምፅ' : 'Ring on new job offer'),
            subtitle: Text(
              isAm
                  ? 'አዲስ ጉዞ ሲመጣ ድምፅ ያሰማ'
                  : 'Play a beep when a rider request arrives',
              style: AppText.caption(context, color: GariColors.muted),
            ),
            value: ringEnabled,
            onChanged: (v) async {
              setState(() => ringEnabled = v);
              await ref.read(apiProvider).prefs.setBool('offer_ring', v);
              if (!v) OfferRing.stop();
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder(
            future: ref.read(apiProvider).client.driverAnnouncements(),
            builder: (context, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isAm ? 'ማስታወቂያዎች' : 'Announcements',
                      style: AppText.headline(context)),
                  const SizedBox(height: 8),
                  ...list.take(5).map((raw) {
                    final a = Map<String, dynamic>.from(raw as Map);
                    return GariCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${a['title']}',
                              style: AppText.headline(context)),
                          Text('${a['body']}',
                              style: AppText.caption(context,
                                  color: GariColors.muted)),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Ref extends ConsumerWidget {
  const _Ref();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(authProvider).driver;
    final digits = (d?.phone ?? '0000').replaceAll(RegExp(r'\D'), '');
    final start = (digits.length - 4).clamp(0, digits.length);
    final code = 'GARI${digits.substring(start)}';
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(title: const Text('Refer')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              code,
              style: AppText.display(context, color: GariColors.amberDeep),
            ),
            GariPrimaryButton(
              label: 'Share',
              onPressed: () =>
                  Share.share('Join GariGo Driver with code $code'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripChat extends ConsumerStatefulWidget {
  const _TripChat({required this.id});
  final String id;
  @override
  ConsumerState<_TripChat> createState() => _TripChatState();
}

class _TripChatState extends ConsumerState<_TripChat> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final client = ref.read(apiProvider).client;
      client.joinTrip(widget.id);
      client.socket?.off('trip_message');
      client.socket?.on('trip_message', _onSocket);
    });
  }

  void _onSocket(dynamic data) {
    final m = Map<String, dynamic>.from(data as Map);
    if (m['tripId']?.toString() != widget.id) return;
    if (!mounted) return;
    setState(() {
      if (_messages.any((e) => e['id']?.toString() == m['id']?.toString())) {
        return;
      }
      _messages.add(m);
    });
    _scrollEnd();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(apiProvider).client.tripMessages(widget.id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _loading = false;
      });
      _scrollEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = drvErr(e);
      });
    }
  }

  void _scrollEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg =
          await ref.read(apiProvider).client.sendTripMessage(widget.id, text);
      _ctrl.clear();
      if (!mounted) return;
      setState(() {
        if (!_messages.any((e) => e['id']?.toString() == msg['id']?.toString())) {
          _messages.add(msg);
        }
        _sending = false;
      });
      _scrollEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(drvErr(e))),
      );
    }
  }

  @override
  void dispose() {
    ref.read(apiProvider).client.socket?.off('trip_message');
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    return Scaffold(
      backgroundColor: GariColors.cream,
      appBar: AppBar(
        backgroundColor: GariColors.cream,
        title: Text(isAm ? 'ከተሳፋሪ ጋር መልእክት' : 'Message rider'),
      ),
      body: Column(
        children: [
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!)))
          else
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final m = _messages[i];
                  final mine = m['senderRole']?.toString() == 'driver';
                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: mine ? GariColors.nightBlue : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: mine
                            ? null
                            : Border.all(color: GariColors.border, width: 1.5),
                      ),
                      child: Text(
                        '${m['body']}',
                        style: TextStyle(
                          color: mine ? Colors.white : GariColors.nightBlue,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: GariColors.border, width: 1.5),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: isAm ? 'መልእክት ይጻፉ…' : 'Type a message…',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: GariColors.amber,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _sending ? null : _send,
                      borderRadius: BorderRadius.circular(14),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.send_rounded,
                            color: Color(0xFF1A1408)),
                      ),
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
}
