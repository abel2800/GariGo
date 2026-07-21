part of 'main.dart';

String _mediaUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return '${GariConfig.apiBaseUrl}$path';
}

bool _isPdfUrl(String? path) {
  final p = (path ?? '').toLowerCase();
  return p.endsWith('.pdf') || p.contains('.pdf?');
}

Future<void> _openKycMedia(
  BuildContext context,
  String? path, {
  String title = 'Document',
}) async {
  final url = _mediaUrl(path);
  if (url.isEmpty) return;
  if (!context.mounted) return;
  await openKycMediaFullscreen(
    context,
    url: url,
    title: title,
    isPdf: _isPdfUrl(path) || _isPdfUrl(url),
  );
}

Widget _kycThumb(String? path, {double size = 72}) {
  final url = _mediaUrl(path);
  if (url.isEmpty) {
    return Icon(Icons.description, size: size * 0.55);
  }
  if (_isPdfUrl(path) || _isPdfUrl(url)) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.picture_as_pdf, size: 36, color: Color(0xFFC62828)),
    );
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.broken_image, size: size * 0.55),
    ),
  );
}

class _Login extends ConsumerStatefulWidget {
  const _Login();
  @override
  ConsumerState<_Login> createState() => _LoginState();
}

class _LoginState extends ConsumerState<_Login> {
  final email = TextEditingController(text: 'ops@garigo.et');
  final pass = TextEditingController(text: 'admin123');
  final otp = TextEditingController(text: '123456');
  bool step2 = false;
  bool busy = false;
  bool keepSignedIn = true;
  bool obscurePass = true;
  String? error;
  String? tempToken;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    otp.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = ref.read(apiProvider);
      final res = await api.adminLogin(email.text.trim(), pass.text.trim());
      setState(() {
        step2 = true;
        tempToken = res['tempToken']?.toString();
        busy = false;
      });
    } catch (e) {
      setState(() {
        busy = false;
        error = _err(e);
      });
    }
  }

  Future<void> _verify() async {
    final token = tempToken;
    if (token == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final api = ref.read(apiProvider);
      final res = await api.admin2fa(token, otp.text.trim());
      final jwt = res['token']?.toString();
      final admin = Map<String, dynamic>.from(res['admin'] as Map);
      if (jwt == null) throw Exception('No token');
      await ref.read(sessionProvider.notifier).completeLogin(
            token: jwt,
            admin: admin,
          );
    } catch (e) {
      setState(() {
        busy = false;
        error = _err(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: const Color(0xFFE9E4D8),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 680),
          child: Padding(
            padding: EdgeInsets.all(wide ? 24 : 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              elevation: 12,
              shadowColor: Colors.black45,
              child: wide
                  ? Row(
                      children: [
                        Expanded(flex: 44, child: _brandPanel()),
                        Expanded(flex: 56, child: _formPanel()),
                      ],
                    )
                  : _formPanel(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GariColors.nightBlue,
            GariColors.navy800,
            GariColors.navy700,
          ],
          stops: [0.0, 0.7, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _AdminRoadPainter()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 44, 44, 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GariGo Ops',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'OPERATIONS CONSOLE',
                          style: TextStyle(
                            color: GariColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                const Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                    children: [
                      TextSpan(text: 'Run every ride in Addis '),
                      TextSpan(
                        text: 'from one screen.',
                        style: TextStyle(color: GariColors.amber400),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Live dispatch, driver verification, payouts, and safety alerts across bajaj, moto, and car fleets — in real time.',
                  style: TextStyle(
                    color: Color(0xFF9AA2B5),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 34),
                const Row(
                  children: [
                    _AdminStat(value: '1,204', label: 'drivers online'),
                    SizedBox(width: 24),
                    _AdminStat(value: '328', label: 'trips in progress'),
                    SizedBox(width: 24),
                    _AdminStat(value: '99.4%', label: 'uptime, 30d'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formPanel() {
    return ColoredBox(
      color: GariColors.cream,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  step2 ? 'Two-factor auth' : 'Welcome back',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: GariColors.nightBlue,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step2
                      ? 'Enter the code from your authenticator.'
                      : 'Sign in to the operations console.',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: GariColors.muted,
                  ),
                ),
                const SizedBox(height: 28),
                if (!step2) ...[
                  _fieldLabel('Work email'),
                  _iconField(
                    controller: email,
                    icon: Icons.mail_outline,
                    hint: 'ops@garigo.et',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _fieldLabel('Password'),
                  _iconField(
                    controller: pass,
                    icon: Icons.lock_outline,
                    hint: '••••••••••',
                    obscure: obscurePass,
                    suffix: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          setState(() => obscurePass = !obscurePass),
                      icon: Icon(
                        obscurePass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                        color: GariColors.muted,
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    Text(
                      error!,
                      style: const TextStyle(
                        color: GariColors.crimson,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => keepSignedIn = !keepSignedIn),
                        child: Row(
                          children: [
                            Container(
                              width: 15,
                              height: 15,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: keepSignedIn
                                    ? GariColors.nightBlue
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: keepSignedIn
                                      ? GariColors.nightBlue
                                      : GariColors.border,
                                ),
                              ),
                              child: keepSignedIn
                                  ? const Icon(
                                      Icons.check,
                                      size: 10,
                                      color: GariColors.amber400,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              'Keep me signed in',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: GariColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: GariColors.navy800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _signInButton(
                    label: busy ? 'Signing in…' : 'Sign in',
                    onPressed: busy ? null : _continue,
                  ),
                ] else ...[
                  _fieldLabel('Authentication code'),
                  _iconField(
                    controller: otp,
                    icon: Icons.shield_outlined,
                    hint: '123456',
                    keyboardType: TextInputType.number,
                  ),
                  if (error != null) ...[
                    Text(
                      error!,
                      style: const TextStyle(
                        color: GariColors.crimson,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _signInButton(
                    label: busy ? 'Verifying…' : 'Verify & enter',
                    onPressed: busy ? null : _verify,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                              step2 = false;
                              error = null;
                            }),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: GariColors.muted,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBEED9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF2DCA9)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: Color(0xFFB4790E),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Protected by two-factor authentication for all admin roles.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7A5A0B),
                            height: 1.4,
                          ),
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
    );
  }

  Widget _fieldLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: GariColors.nightBlue,
          ),
        ),
      );

  Widget _iconField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: GariColors.nightBlue,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: GariColors.muted,
            fontWeight: FontWeight.w500,
            fontSize: 14.5,
          ),
          prefixIcon: Icon(icon, size: 16, color: GariColors.muted),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: GariColors.border, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: GariColors.border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: GariColors.amber, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _signInButton({required String label, VoidCallback? onPressed}) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: GariColors.nightBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_forward, size: 15, color: GariColors.amber400),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminStat extends StatelessWidget {
  const _AdminStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: GariColors.amber400,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7C849A),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AdminRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dots = Paint()..color = GariColors.amber.withValues(alpha: 0.5);

    void line(double x1, double y1, double x2, double y2) {
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), road);
    }

    line(-20, size.height * 0.19, size.width + 20, size.height * 0.34);
    line(-20, size.height * 0.50, size.width + 20, size.height * 0.28);
    line(-20, size.height * 0.75, size.width + 20, size.height * 0.66);
    line(size.width * 0.26, -20, size.width * 0.43, size.height + 20);
    line(size.width * 0.74, -20, size.width * 0.61, size.height + 20);

    canvas.drawCircle(Offset(size.width * 0.39, size.height * 0.31), 3, dots);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.53), 3, dots);
    canvas.drawCircle(Offset(size.width * 0.48, size.height * 0.72), 3, dots);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AdminShell extends ConsumerWidget {
  const _AdminShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final session = ref.watch(sessionProvider);
    Widget nav(String path, String label, IconData icon) {
      final sel = loc == path || loc.startsWith('$path/');
      return ListTile(
        dense: true,
        selected: sel,
        selectedTileColor: GariColors.amber.withValues(alpha: 0.15),
        leading: Icon(icon,
            color: sel ? GariColors.amber : Colors.white54, size: 20),
        title: Text(label,
            style: TextStyle(
              color: sel ? GariColors.amber : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            )),
        onTap: () => context.go(path),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 220,
            color: GariColors.nightBlue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: GariColors.amber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('GG',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: GariColors.nightBlue)),
                    ),
                    const SizedBox(width: 8),
                    Text('GariGo Ops',
                        style: AppText.headline(context, color: Colors.white)),
                  ]),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      nav('/ops', 'Live map', Icons.map),
                      nav('/drivers/approvals', 'Driver KYC', Icons.verified_user),
                      nav('/docs', 'Documents', Icons.folder_open),
                      nav('/trips', 'Trips', Icons.route),
                      nav('/tickets', 'Tickets', Icons.support_agent),
                      nav('/pricing', 'Pricing', Icons.attach_money),
                      nav('/zones', 'Zones', Icons.layers),
                      nav('/promos', 'Promos', Icons.local_offer),
                      nav('/finance', 'Finance', Icons.account_balance),
                      nav('/finance/payouts', 'Payouts', Icons.payments),
                      nav('/finance/cash-debt', 'Cash debt', Icons.money_off),
                      nav('/analytics', 'Analytics', Icons.insights),
                      nav('/kpi', 'KPI wall', Icons.speed),
                      nav('/comms/push', 'Push', Icons.notifications),
                      nav('/comms/announcements', 'Announce', Icons.campaign),
                      nav('/quests', 'Quests', Icons.emoji_events),
                      nav('/settings/roles', 'Roles', Icons.admin_panel_settings),
                      nav('/settings/audit', 'Audit', Icons.history),
                      nav('/settings/security', 'Security', Icons.security),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${session.name ?? 'Admin'}\n${session.role ?? ''}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(sessionProvider.notifier).logout(),
                        child: const Text('Log out',
                            style: TextStyle(color: Colors.white54)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

Widget _kpiChip(String l, String v, {bool warn = false}) => Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: GariColors.cream,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$l ', style: const TextStyle(fontSize: 12)),
          TextSpan(
            text: v,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: warn ? GariColors.crimson : GariColors.emerald,
            ),
          ),
        ])),
      ),
    );

class _Ops extends ConsumerWidget {
  const _Ops();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(opsSnapshotProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(_err(e))),
      data: (snap) {
        final kpis = Map<String, dynamic>.from(snap['kpis'] as Map? ?? {});
        final sos = List<dynamic>.from(snap['sos'] as List? ?? const []);
        final pending =
            List<dynamic>.from(snap['pendingDrivers'] as List? ?? const []);
        final trips =
            List<dynamic>.from(snap['activeTrips'] as List? ?? const []);
        final drivers =
            List<dynamic>.from(snap['drivers'] as List? ?? const []);
        final pins = drivers
            .where((d) => d['lat'] != null && d['lng'] != null)
            .map((d) => GariMapPin(
                  point: LatLngPoint(
                    (d['lat'] as num).toDouble(),
                    (d['lng'] as num).toDouble(),
                  ),
                  color: d['online_status'] == 'on_trip'
                      ? GariColors.crimson
                      : GariColors.emerald,
                  icon: Icons.local_taxi,
                  size: 28,
                ))
            .toList();
        final sosPins = sos
            .where((s) => s['lat'] != null && s['lng'] != null)
            .map((s) => GariMapPin(
                  point: LatLngPoint(
                    (s['lat'] as num).toDouble(),
                    (s['lng'] as num).toDouble(),
                  ),
                  color: GariColors.crimson,
                  icon: Icons.warning_amber,
                  size: 34,
                ))
            .toList();

        return Column(
          children: [
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text('Live map · Addis', style: AppText.title(context)),
                  const Spacer(),
                  _kpiChip('Online', '${kpis['online'] ?? 0}'),
                  _kpiChip('Trips', '${kpis['activeTrips'] ?? 0}'),
                  _kpiChip('Req/min', '${kpis['reqPerMin'] ?? 0}'),
                  _kpiChip('SOS', '${kpis['sos'] ?? 0}', warn: true),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => ref.invalidate(opsSnapshotProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: GariMapCanvas(
                      mode: GariMapMode.heatmap,
                      zoom: 12.5,
                      center: GariMapDefaults.addis,
                      pins: [...pins, ...sosPins],
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: Material(
                      color: Colors.white,
                      child: DefaultTabController(
                        length: 3,
                        child: Column(
                          children: [
                            const TabBar(tabs: [
                              Tab(text: 'Alerts'),
                              Tab(text: 'KYC'),
                              Tab(text: 'Trips'),
                            ]),
                            Expanded(
                              child: TabBarView(children: [
                                ListView(
                                  padding: const EdgeInsets.all(12),
                                  children: [
                                    if (sos.isEmpty)
                                      const ListTile(
                                          title: Text('No open SOS')),
                                    ...sos.map((s) {
                                      final id = s['id'].toString();
                                      final tripId =
                                          s['trip_id']?.toString() ?? '—';
                                      final status =
                                          s['status']?.toString() ?? 'open';
                                      return GariCard(
                                        borderColor: GariColors.crimson,
                                        onTap: () =>
                                            context.go('/trips/$tripId'),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'SOS · ${status.toUpperCase()}',
                                              style:
                                                  AppText.headline(context),
                                            ),
                                            Text(
                                              '${s['pickup_landmark'] ?? 'Location'} · by ${s['triggered_by']}',
                                              style:
                                                  AppText.caption(context),
                                            ),
                                            const SizedBox(height: 8),
                                            if (status == 'open')
                                              GariPrimaryButton(
                                                label: 'Dispatch unit',
                                                onPressed: () async {
                                                  await ref
                                                      .read(apiProvider)
                                                      .updateSos(id,
                                                          status:
                                                              'dispatched');
                                                  ref.invalidate(
                                                      opsSnapshotProvider);
                                                },
                                              ),
                                            if (status == 'dispatched')
                                              GariSecondaryButton(
                                                label: 'Resolve',
                                                onPressed: () async {
                                                  await ref
                                                      .read(apiProvider)
                                                      .updateSos(id,
                                                          status:
                                                              'resolved');
                                                  ref.invalidate(
                                                      opsSnapshotProvider);
                                                },
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                                ListView(
                                  children: [
                                    if (pending.isEmpty)
                                      const ListTile(
                                          title: Text('No pending KYC')),
                                    ...pending.map((d) {
                                      final id = d['id'].toString();
                                      return ListTile(
                                        title: Text(
                                            '${d['name'] ?? 'Driver'} · ${d['category'] ?? ''}'),
                                        subtitle:
                                            Text(d['phone']?.toString() ?? ''),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.check,
                                                  color: GariColors.emerald),
                                              onPressed: () async {
                                                await ref
                                                    .read(apiProvider)
                                                    .approveDriver(id);
                                                ref.invalidate(
                                                    opsSnapshotProvider);
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close,
                                                  color: GariColors.crimson),
                                              onPressed: () async {
                                                await ref
                                                    .read(apiProvider)
                                                    .rejectDriver(id);
                                                ref.invalidate(
                                                    opsSnapshotProvider);
                                              },
                                            ),
                                          ],
                                        ),
                                        onTap: () =>
                                            context.go('/drivers/$id'),
                                      );
                                    }),
                                  ],
                                ),
                                ListView(
                                  children: [
                                    if (trips.isEmpty)
                                      const ListTile(
                                          title: Text('No active trips')),
                                    ...trips.map((t) {
                                      final id = t['id'].toString();
                                      return ListTile(
                                        title: Text(
                                            '#${id.substring(0, 8)} · ${t['vehicle_category'] ?? ''}'),
                                        subtitle: Text(
                                            '${t['pickup_landmark'] ?? '?'} → ${t['dropoff_landmark'] ?? '?'} · ${t['status']}'),
                                        onTap: () =>
                                            context.go('/trips/$id'),
                                      );
                                    }),
                                  ],
                                ),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Page extends StatelessWidget {
  const _Page(this.title, this.body);
  final String title;
  final Widget body;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Text(title, style: AppText.title(context)),
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _Approvals extends ConsumerStatefulWidget {
  const _Approvals();
  @override
  ConsumerState<_Approvals> createState() => _ApprovalsState();
}

class _ApprovalsState extends ConsumerState<_Approvals> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(opsSnapshotProvider);
    return _Page(
      'Driver approval queue',
      async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(_err(e))),
        data: (snap) {
          final list =
              List<dynamic>.from(snap['pendingDrivers'] as List? ?? const []);
          if (list.isEmpty) {
            return const Center(child: Text('No pending drivers'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Tap a driver to review full KYC (photos, plate, TIN, docs) then Approve or Reject.',
                style: AppText.caption(context, color: GariColors.muted),
              ),
              const SizedBox(height: 12),
              ...list.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GariCard(
                      onTap: () => context.go('/drivers/${d['id']}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${d['name'] ?? 'Driver'} · ${d['category'] ?? '—'}',
                            style: AppText.headline(context),
                          ),
                          Text(
                            '${d['phone'] ?? ''} · KYC pending',
                            style: AppText.caption(context),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () =>
                                    context.go('/drivers/${d['id']}'),
                                child: const Text('Review details'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(apiProvider)
                                      .approveDriver(d['id'].toString());
                                  ref.invalidate(opsSnapshotProvider);
                                },
                                child: const Text('Approve'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await ref.read(apiProvider).rejectDriver(
                                        d['id'].toString(),
                                        reasons: const [
                                          'Incomplete or unclear documents',
                                        ],
                                      );
                                  ref.invalidate(opsSnapshotProvider);
                                },
                                child: const Text('Reject'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _DriverDetail extends ConsumerStatefulWidget {
  const _DriverDetail({required this.id});
  final String id;
  @override
  ConsumerState<_DriverDetail> createState() => _DriverDetailState();
}

class _DriverDetailState extends ConsumerState<_DriverDetail> {
  Map<String, dynamic>? data;
  String? error;
  bool loading = true;
  bool actionBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await ref.read(apiProvider).adminDriver(widget.id);
      setState(() {
        data = res;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = _err(e);
        loading = false;
      });
    }
  }

  Future<void> _runAction(String label, Future<void> Function() action) async {
    if (actionBusy) return;
    setState(() => actionBusy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label done')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_err(e))),
      );
    } finally {
      if (mounted) setState(() => actionBusy = false);
    }
  }

  Future<void> _declineDoc(Map doc) async {
    final reasonCtrl = TextEditingController(text: 'Unclear or invalid — please re-upload');
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Decline ${doc['doc_type'] ?? 'document'}'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason for driver',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
    if (reason == null || reason.isEmpty) return;
    await _runAction(
      'Document declined',
      () => ref.read(apiProvider).verifyDocument(
            doc['id'].toString(),
            verified: false,
            rejectionReason: reason,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(child: Text(error!));
    }
    final d = Map<String, dynamic>.from(data!['driver'] as Map);
    final docs = List<dynamic>.from(data!['documents'] as List? ?? const []);
    final vehicles =
        List<dynamic>.from(data!['vehicles'] as List? ?? const []);
    final accountStatus = d['status']?.toString() ?? 'active';
    final kycStatus = d['approval_status']?.toString() ?? 'none';
    final declinedCount = docs
        .where((x) => (x['rejection_reason']?.toString() ?? '').isNotEmpty)
        .length;

    return _Page(
      'Driver · ${d['name'] ?? widget.id}',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GariCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${d['name'] ?? '—'} · ${d['category'] ?? ''} · ★ ${d['rating_avg'] ?? '—'}',
                  style: AppText.title(context),
                ),
                Text(
                  '${d['phone']} · ${d['total_trips'] ?? 0} trips',
                  style: AppText.body(context),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(
                      label: Text('Account: $accountStatus'),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text('KYC: $kycStatus'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: kycStatus == 'approved'
                          ? const Color(0xFFE8F5E9)
                          : kycStatus == 'rejected'
                              ? const Color(0xFFFFEBEE)
                              : null,
                    ),
                  ],
                ),
                Text(
                  'Balance ${d['available_balance'] ?? 0} Br · cash debt ${d['cash_debt'] ?? 0} Br',
                  style: AppText.caption(context),
                ),
                Text(
                  'TIN ${d['tin_number'] ?? '—'} · Biz ${d['business_reg_number'] ?? '—'} · '
                  'Owner ${d['is_vehicle_owner'] == false ? 'No (auth letter required)' : 'Yes'}',
                  style: AppText.caption(context),
                ),
                if (d['photo_url'] != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _openKycMedia(
                      context,
                      d['photo_url']?.toString(),
                      title: 'Driver photo',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _mediaUrl(d['photo_url']?.toString()),
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openKycMedia(
                      context,
                      d['photo_url']?.toString(),
                      title: 'Driver photo',
                    ),
                    icon: const Icon(Icons.zoom_in, size: 18),
                    label: const Text('View driver photo'),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Account', style: AppText.headline(context)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (accountStatus == 'active')
                      GariSecondaryButton(
                        label: actionBusy ? '…' : 'Suspend',
                        enabled: !actionBusy,
                        onPressed: () => _runAction(
                          'Suspended',
                          () => ref
                              .read(apiProvider)
                              .setDriverStatus(widget.id, 'suspended'),
                        ),
                      )
                    else
                      GariPrimaryButton(
                        label: actionBusy ? '…' : 'Activate',
                        enabled: !actionBusy,
                        onPressed: () => _runAction(
                          'Activated',
                          () => ref
                              .read(apiProvider)
                              .setDriverStatus(widget.id, 'active'),
                        ),
                      ),
                    if (accountStatus != 'banned')
                      GariSecondaryButton(
                        label: actionBusy ? '…' : 'Ban',
                        enabled: !actionBusy,
                        onPressed: () => _runAction(
                          'Banned',
                          () => ref
                              .read(apiProvider)
                              .setDriverStatus(widget.id, 'banned'),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('KYC decision', style: AppText.headline(context)),
                Text(
                  'Decline individual documents below if only some are wrong. Approve when everything looks good.',
                  style: AppText.caption(context, color: GariColors.muted),
                ),
                const SizedBox(height: 8),
                if (kycStatus != 'approved')
                  GariPrimaryButton(
                    label: actionBusy
                        ? '…'
                        : declinedCount > 0
                            ? 'Approve (after fixes)'
                            : 'Approve KYC',
                    enabled: !actionBusy && declinedCount == 0,
                    onPressed: () => _runAction(
                      'KYC approved',
                      () => ref.read(apiProvider).approveDriver(widget.id),
                    ),
                  ),
                if (declinedCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$declinedCount document(s) declined — waiting for driver re-upload',
                    style: AppText.caption(context, color: GariColors.crimson),
                  ),
                ],
                if (kycStatus == 'approved')
                  Text(
                    'KYC already approved',
                    style: AppText.caption(context, color: GariColors.emerald),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Vehicles', style: AppText.headline(context)),
          ...vehicles.map((v) => ListTile(
                title: Text('${v['plate_number']} · ${v['category']}'),
                subtitle: Text('${v['make'] ?? ''} ${v['model'] ?? ''}'),
              )),
          Text('KYC documents', style: AppText.headline(context)),
          Text(
            'Open fullscreen to inspect · Verify or Decline each document',
            style: AppText.caption(context, color: GariColors.muted),
          ),
          const SizedBox(height: 8),
          ...docs.map((doc) {
            final url = doc['url']?.toString();
            final pdf = _isPdfUrl(url);
            final docTitle = doc['doc_type']?.toString() ?? 'Document';
            final verified = doc['verified'] == true;
            final rejection = doc['rejection_reason']?.toString();
            final declined = rejection != null && rejection.isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GariCard(
                onTap: url == null || url.isEmpty
                    ? null
                    : () => _openKycMedia(context, url, title: docTitle),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kycThumb(url),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(docTitle, style: AppText.headline(context)),
                          Text(
                            verified
                                ? 'Verified'
                                : declined
                                    ? 'Declined — $rejection'
                                    : 'Pending review',
                            style: AppText.caption(
                              context,
                              color: verified
                                  ? GariColors.emerald
                                  : declined
                                      ? GariColors.crimson
                                      : null,
                            ),
                          ),
                          Text(
                            pdf
                                ? 'PDF — tap for fullscreen'
                                : 'Image — tap for fullscreen',
                            style: AppText.caption(
                              context,
                              color: GariColors.amber,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: [
                              if (!verified && !declined)
                                TextButton(
                                  onPressed: actionBusy
                                      ? null
                                      : () => _runAction(
                                            'Verified',
                                            () => ref
                                                .read(apiProvider)
                                                .verifyDocument(
                                                  doc['id'].toString(),
                                                ),
                                          ),
                                  child: const Text('Verify'),
                                ),
                              if (!verified)
                                TextButton(
                                  onPressed:
                                      actionBusy ? null : () => _declineDoc(doc),
                                  child: Text(
                                    declined ? 'Decline again' : 'Decline',
                                    style: const TextStyle(
                                      color: GariColors.crimson,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (url != null && url.isNotEmpty)
                      IconButton(
                        tooltip: 'Open fullscreen',
                        onPressed: () =>
                            _openKycMedia(context, url, title: docTitle),
                        icon: Icon(
                          pdf ? Icons.picture_as_pdf : Icons.open_in_full,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RiderDetail extends ConsumerStatefulWidget {
  const _RiderDetail({required this.id});
  final String id;
  @override
  ConsumerState<_RiderDetail> createState() => _RiderDetailState();
}

class _RiderDetailState extends ConsumerState<_RiderDetail> {
  Map<String, dynamic>? rider;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiProvider).adminRider(widget.id);
      setState(
          () => rider = Map<String, dynamic>.from(res['rider'] as Map));
    } catch (e) {
      setState(() => error = _err(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return Center(child: Text(error!));
    if (rider == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final r = rider!;
    return _Page(
      'Rider · ${r['name'] ?? widget.id}',
      Padding(
        padding: const EdgeInsets.all(16),
        child: GariCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${r['name'] ?? '—'} · ${r['total_trips'] ?? 0} trips',
                  style: AppText.title(context)),
              Text('${r['phone']} · status ${r['status']} · wallet ${r['wallet_balance']} Br',
                  style: AppText.body(context)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                GariSecondaryButton(
                  label: 'Suspend',
                  onPressed: () async {
                    await ref
                        .read(apiProvider)
                        .setRiderStatus(widget.id, 'suspended');
                    _load();
                  },
                ),
                GariSecondaryButton(
                  label: 'Ban',
                  onPressed: () async {
                    await ref
                        .read(apiProvider)
                        .setRiderStatus(widget.id, 'banned');
                    _load();
                  },
                ),
                GariPrimaryButton(
                  label: 'Reactivate',
                  onPressed: () async {
                    await ref
                        .read(apiProvider)
                        .setRiderStatus(widget.id, 'active');
                    _load();
                  },
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Documents extends ConsumerStatefulWidget {
  const _Documents();
  @override
  ConsumerState<_Documents> createState() => _DocumentsState();
}

class _DocumentsState extends ConsumerState<_Documents> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).pendingDocuments();
  }

  void _reload() {
    setState(() {
      _future = ref.read(apiProvider).pendingDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      'Document review',
      FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(_err(snap.error!)));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!;
          if (docs.isEmpty) {
            return const Center(child: Text('No pending documents'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: docs
                .map((d) {
                  final url = d['url']?.toString();
                  final pdf = _isPdfUrl(url);
                  final docTitle =
                      '${d['driver_name']} · ${d['doc_type']}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GariCard(
                      onTap: url == null || url.isEmpty
                          ? null
                          : () => _openKycMedia(
                                context,
                                url,
                                title: docTitle,
                              ),
                      child: Row(children: [
                        _kycThumb(url, size: 64),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                docTitle,
                                style: AppText.headline(context),
                              ),
                              Text(
                                'Tap for fullscreen verification',
                                style: AppText.caption(
                                  context,
                                  color: GariColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (url != null && url.isNotEmpty)
                          IconButton(
                            tooltip: 'Open fullscreen',
                            onPressed: () => _openKycMedia(
                              context,
                              url,
                              title: docTitle,
                            ),
                            icon: Icon(
                              pdf ? Icons.picture_as_pdf : Icons.open_in_full,
                            ),
                          ),
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(apiProvider)
                                .verifyDocument(d['id'].toString());
                            _reload();
                          },
                          child: const Text('Verify'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await ref.read(apiProvider).verifyDocument(
                                  d['id'].toString(),
                                  verified: false,
                                  rejectionReason: 'Unclear / expired',
                                );
                            _reload();
                          },
                          child: const Text('Reject'),
                        ),
                      ]),
                    ),
                  );
                })
                .toList(),
          );
        },
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
  final q = TextEditingController();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).adminTrips();
  }

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  void _search() {
    setState(() {
      _future = ref.read(apiProvider).adminTrips(q: q.text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      'Trip search',
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: GariTextField(
                    controller: q,
                    label: 'Search id / landmark / name',
                  ),
                ),
                const SizedBox(width: 8),
                GariPrimaryButton(label: 'Search', onPressed: _search),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text(_err(snap.error!)));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final trips = snap.data!;
                return ListView(
                  children: trips
                      .map((t) => ListTile(
                            title: Text(
                                '#${t['id'].toString().substring(0, 8)} · ${t['status']} · ${t['vehicle_category']}'),
                            subtitle: Text(
                                '${t['pickup_landmark'] ?? '?'} → ${t['dropoff_landmark'] ?? '?'} · ${t['fare_total'] ?? 0} Br'),
                            onTap: () =>
                                context.go('/trips/${t['id']}'),
                          ))
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TripDetail extends ConsumerStatefulWidget {
  const _TripDetail({required this.id});
  final String id;
  @override
  ConsumerState<_TripDetail> createState() => _TripDetailState();
}

class _TripDetailState extends ConsumerState<_TripDetail> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiProvider).adminTrip(widget.id);
      setState(() => data = res);
    } catch (e) {
      setState(() => error = _err(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return Center(child: Text(error!));
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final t = Map<String, dynamic>.from(data!['trip'] as Map);
    final pickup = t['pickup_lat'] != null
        ? LatLngPoint(
            (t['pickup_lat'] as num).toDouble(),
            (t['pickup_lng'] as num).toDouble(),
          )
        : null;
    final dropoff = t['dropoff_lat'] != null
        ? LatLngPoint(
            (t['dropoff_lat'] as num).toDouble(),
            (t['dropoff_lng'] as num).toDouble(),
          )
        : null;
    return _Page(
      'Trip #${widget.id.substring(0, 8)}',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 220,
            child: GariMapCanvas(
              showRoute: true,
              pickup: pickup,
              dropoff: dropoff,
              center: pickup ?? GariMapDefaults.addis,
            ),
          ),
          const SizedBox(height: 12),
          GariCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t['pickup_landmark'] ?? '?'} → ${t['dropoff_landmark'] ?? '?'} · ${t['vehicle_category']}',
                  style: AppText.headline(context),
                ),
                Text(
                  'Status ${t['status']} · Fare ${t['fare_total']} Br · ${t['payment_method']} / ${t['payment_status']}',
                  style: AppText.body(context),
                ),
                Text(
                  'Rider ${t['rider_name'] ?? '—'} (${t['rider_phone'] ?? ''})',
                  style: AppText.caption(context),
                ),
                Text(
                  'Driver ${t['driver_name'] ?? '—'} (${t['driver_phone'] ?? ''})',
                  style: AppText.caption(context),
                ),
                if (t['rider_id'] != null)
                  TextButton(
                    onPressed: () =>
                        context.go('/riders/${t['rider_id']}'),
                    child: const Text('Open rider'),
                  ),
                if (t['driver_id'] != null)
                  TextButton(
                    onPressed: () =>
                        context.go('/drivers/${t['driver_id']}'),
                    child: const Text('Open driver'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tickets extends ConsumerStatefulWidget {
  const _Tickets();
  @override
  ConsumerState<_Tickets> createState() => _TicketsState();
}

class _TicketsState extends ConsumerState<_Tickets> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).adminTickets();
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      'Support tickets',
      FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(_err(snap.error!)));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tickets = snap.data!;
          if (tickets.isEmpty) {
            return const Center(child: Text('No tickets yet'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: tickets
                .map((t) => ListTile(
                      title: Text(t['category']?.toString() ?? 'Ticket'),
                      subtitle: Text(
                          '${t['subject']} · ${t['priority'] ?? 'normal'}'),
                      trailing: GariStatusPill(
                        label: t['status']?.toString() ?? '',
                        tone: t['status'] == 'open'
                            ? GariPillTone.pending
                            : GariPillTone.online,
                      ),
                      onTap: () => context.go('/tickets/${t['id']}'),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _TicketDetail extends ConsumerStatefulWidget {
  const _TicketDetail({required this.id});
  final String id;
  @override
  ConsumerState<_TicketDetail> createState() => _TicketDetailState();
}

class _TicketDetailState extends ConsumerState<_TicketDetail> {
  Map<String, dynamic>? ticket;
  final notes = TextEditingController();
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiProvider).adminTicket(widget.id);
      setState(() =>
          ticket = Map<String, dynamic>.from(res['ticket'] as Map));
    } catch (e) {
      setState(() => error = _err(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return Center(child: Text(error!));
    if (ticket == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final t = ticket!;
    return _Page(
      'Ticket ${widget.id.substring(0, 8)}',
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GariCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${t['category']} · ${t['subject']}',
                      style: AppText.headline(context)),
                  Text('Status ${t['status']} · priority ${t['priority']}',
                      style: AppText.body(context)),
                  if (t['resolution_notes'] != null)
                    Text(t['resolution_notes'].toString(),
                        style: AppText.caption(context)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GariTextField(controller: notes, label: 'Resolution notes'),
            const SizedBox(height: 12),
            GariPrimaryButton(
              label: 'Resolve',
              onPressed: () async {
                await ref.read(apiProvider).updateTicket(
                      widget.id,
                      status: 'resolved',
                      resolutionNotes: notes.text.trim().isEmpty
                          ? 'Resolved by ops'
                          : notes.text.trim(),
                    );
                if (context.mounted) context.go('/tickets');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Pricing extends ConsumerStatefulWidget {
  const _Pricing();
  @override
  ConsumerState<_Pricing> createState() => _PricingState();
}

class _PricingState extends ConsumerState<_Pricing> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).adminFares();
  }

  void _reload() =>
      setState(() => _future = ref.read(apiProvider).adminFares());

  Future<void> _edit(Map<String, dynamic> fare) async {
    final base = TextEditingController(text: '${fare['base_fare']}');
    final km = TextEditingController(text: '${fare['per_km']}');
    final min = TextEditingController(text: '${fare['per_min']}');
    final minimum = TextEditingController(text: '${fare['minimum_fare']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${fare['category']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: base, decoration: const InputDecoration(labelText: 'Base')),
            TextField(controller: km, decoration: const InputDecoration(labelText: 'Per km')),
            TextField(controller: min, decoration: const InputDecoration(labelText: 'Per min')),
            TextField(controller: minimum, decoration: const InputDecoration(labelText: 'Minimum')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(apiProvider).updateFare(
            fare['category'].toString(),
            baseFare: int.parse(base.text),
            perKm: int.parse(km.text),
            perMin: int.parse(min.text),
            minimumFare: int.parse(minimum.text),
          );
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      'Fare formulas',
      FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(_err(snap.error!)));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: snap.data!
                .map((f) => GariCard(
                      onTap: () => _edit(Map<String, dynamic>.from(f as Map)),
                      child: Text(
                        '${f['category']}: base ${f['base_fare']} / km ${f['per_km']} / min ${f['per_min']} / floor ${f['minimum_fare']} Br',
                        style: AppText.headline(context),
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _Zones extends ConsumerStatefulWidget {
  const _Zones();
  @override
  ConsumerState<_Zones> createState() => _ZonesState();
}

class _ZonesState extends ConsumerState<_Zones> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).adminZones();
  }

  void _reload() =>
      setState(() => _future = ref.read(apiProvider).adminZones());

  Future<void> _add() async {
    final name = TextEditingController();
    final surge = TextEditingController(text: '1.0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: surge, decoration: const InputDecoration(labelText: 'Surge')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await ref.read(apiProvider).createZone(
            name: name.text.trim(),
            surgeMultiplier: double.tryParse(surge.text) ?? 1.0,
          );
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      'Zones & surge',
      FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(_err(snap.error!)));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final zones = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GariPrimaryButton(label: 'Add zone', onPressed: _add),
              const SizedBox(height: 12),
              if (zones.isEmpty) const Text('No zones yet — add one.'),
              ...zones.map((z) => ListTile(
                    title: Text(z['name']?.toString() ?? ''),
                    trailing: Text('${z['surge_multiplier']}×',
                        style: AppText.caption(context)),
                    onTap: () async {
                      final c = TextEditingController(
                          text: '${z['surge_multiplier']}');
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Surge · ${z['name']}'),
                          content: TextField(
                            controller: c,
                            decoration: const InputDecoration(
                                labelText: 'Multiplier'),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Save')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await ref.read(apiProvider).updateZone(
                              z['id'].toString(),
                              surgeMultiplier:
                                  double.tryParse(c.text) ?? 1.0,
                            );
                        _reload();
                      }
                    },
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _Promos extends ConsumerStatefulWidget {
  const _Promos();
  @override
  ConsumerState<_Promos> createState() => _PromosState();
}

class _PromosState extends ConsumerState<_Promos> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).adminPromos();
  }

  void _reload() =>
      setState(() => _future = ref.read(apiProvider).adminPromos());

  Future<void> _create() async {
    final code = TextEditingController();
    final value = TextEditingController(text: '50');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create promo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')),
            TextField(controller: value, decoration: const InputDecoration(labelText: 'Value (Br)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true && code.text.trim().isNotEmpty) {
      await ref.read(apiProvider).createPromo({
        'code': code.text.trim(),
        'discountType': 'fixed',
        'value': int.tryParse(value.text) ?? 50,
      });
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      'Promos & referrals',
      FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(_err(snap.error!)));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GariPrimaryButton(label: 'Create promo', onPressed: _create),
              const SizedBox(height: 12),
              ...snap.data!.map((p) => GariCard(
                    child: Text(
                      '${p['code']} · ${p['discount_type']} ${p['value']} · used ${p['used_count']}/${p['usage_limit'] ?? '∞'}',
                      style: AppText.headline(context),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _Finance extends ConsumerStatefulWidget {
  const _Finance();
  @override
  ConsumerState<_Finance> createState() => _FinanceState();
}

class _FinanceState extends ConsumerState<_Finance> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).financeSummary();
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      'Finance reconciliation',
      FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(_err(snap.error!)));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snap.data!;
          final byMethod =
              List<dynamic>.from(s['byMethod'] as List? ?? const []);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                title: const Text('Gross fares'),
                trailing: Text('${s['grossFares']} Br',
                    style: AppText.headline(context)),
              ),
              ListTile(
                title: const Text('Commission'),
                trailing: Text('${s['commission']} Br',
                    style: AppText.headline(context)),
              ),
              ListTile(
                title: const Text('Cash debt total'),
                trailing: Text('${s['cashDebtTotal']} Br',
                    style: AppText.headline(context)),
              ),
              ListTile(
                title: const Text('Driver balances'),
                trailing: Text('${s['driverBalances']} Br',
                    style: AppText.headline(context)),
              ),
              const Divider(),
              ...byMethod.map((m) => ListTile(
                    title: Text('${m['method']}'),
                    trailing: Text('${m['total']} Br',
                        style: AppText.headline(context)),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _Payouts extends ConsumerStatefulWidget {
  const _Payouts();
  @override
  ConsumerState<_Payouts> createState() => _PayoutsState();
}

class _PayoutsState extends ConsumerState<_Payouts> {
  late Future<Map<String, dynamic>> _future;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).payoutBatch();
  }

  void _reload() =>
      setState(() => _future = ref.read(apiProvider).payoutBatch());

  @override
  Widget build(BuildContext context) {
    return _Page(
      'Driver payout batch',
      FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(_err(snap.error!)));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final batch = snap.data!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: GariCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${batch['count']} drivers · ${batch['totalBr']} Br ready',
                    style: AppText.headline(context),
                  ),
                  const SizedBox(height: 12),
                  GariPrimaryButton(
                    label: busy ? 'Processing…' : 'Process batch',
                    onPressed: busy || ((batch['count'] as num?)?.toInt() ?? 0) == 0
                        ? null
                        : () async {
                            setState(() => busy = true);
                            try {
                              final res = await ref
                                  .read(apiProvider)
                                  .processPayouts();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Paid ${res['count']} drivers · ${res['totalBr']} Br'),
                                  ),
                                );
                              }
                              _reload();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(_err(e))),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CashDebt extends ConsumerStatefulWidget {
  const _CashDebt();
  @override
  ConsumerState<_CashDebt> createState() => _CashDebtState();
}

class _CashDebtState extends ConsumerState<_CashDebt> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).cashDebt();
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      'Cash-trip debt',
      FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(_err(snap.error!)));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const Center(child: Text('No cash debt'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: list
                .map((d) => ListTile(
                      title: Text(d['name']?.toString() ?? 'Driver'),
                      subtitle: Text(d['phone']?.toString() ?? ''),
                      trailing: Text('${d['cash_debt']} Br',
                          style: AppText.headline(context,
                              color: GariColors.crimson)),
                      onTap: () => context.go('/drivers/${d['id']}'),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _Analytics extends ConsumerStatefulWidget {
  const _Analytics();
  @override
  ConsumerState<_Analytics> createState() => _AnalyticsState();
}

class _AnalyticsState extends ConsumerState<_Analytics> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).adminAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      'Analytics',
      FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(_err(snap.error!)));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          final last7 =
              Map<String, dynamic>.from(data['last7Days'] as Map? ?? {});
          final series =
              List<dynamic>.from(data['series'] as List? ?? const []);
          final spots = <FlSpot>[];
          for (var i = 0; i < series.length; i++) {
            spots.add(FlSpot(
              i.toDouble(),
              ((series[i]['trips'] as num?) ?? 0).toDouble(),
            ));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(spacing: 12, runSpacing: 8, children: [
                _kpiChip('Completed 7d', '${last7['completed'] ?? 0}'),
                _kpiChip('Cancelled 7d', '${last7['cancelled'] ?? 0}',
                    warn: true),
                _kpiChip('GMV 7d', '${last7['gmv'] ?? 0} Br'),
                _kpiChip(
                  'Accept %',
                  ((last7['avgAcceptance'] as num?) ?? 0)
                      .toStringAsFixed(1),
                ),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: spots.isEmpty
                    ? const Center(child: Text('No completed trips yet'))
                    : LineChart(LineChartData(
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            color: GariColors.amber,
                            barWidth: 3,
                          ),
                        ],
                      )),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Kpi extends ConsumerWidget {
  const _Kpi();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(opsSnapshotProvider);
    return _Page(
      'KPI live wall',
      async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(_err(e))),
        data: (snap) {
          final k = Map<String, dynamic>.from(snap['kpis'] as Map? ?? {});
          Widget big(String l, String v) => GariCard(
                dark: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(v,
                        style:
                            AppText.display(context, color: GariColors.amber)),
                    Text(l,
                        style: AppText.caption(context,
                            color: Colors.white.withValues(alpha: 0.6))),
                  ],
                ),
              );
          return GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(24),
            children: [
              big('Online drivers', '${k['online'] ?? 0}'),
              big('Active trips', '${k['activeTrips'] ?? 0}'),
              big('Requests / min', '${k['reqPerMin'] ?? 0}'),
              big('SOS open', '${k['sos'] ?? 0}'),
            ],
          );
        },
      ),
    );
  }
}

class _Push extends ConsumerStatefulWidget {
  const _Push();
  @override
  ConsumerState<_Push> createState() => _PushState();
}

class _PushState extends ConsumerState<_Push> {
  final title = TextEditingController();
  final body = TextEditingController();
  String audience = 'drivers';
  bool busy = false;

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      'Push notification composer',
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GariTextField(controller: title, label: 'Title'),
            const SizedBox(height: 12),
            GariTextField(controller: body, label: 'Body'),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: audience,
              items: const [
                DropdownMenuItem(value: 'drivers', child: Text('Drivers')),
                DropdownMenuItem(value: 'riders', child: Text('Riders')),
                DropdownMenuItem(value: 'all', child: Text('All')),
              ],
              onChanged: (v) => setState(() => audience = v ?? 'drivers'),
            ),
            const SizedBox(height: 12),
            GariPrimaryButton(
              label: busy ? 'Sending…' : 'Send',
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        final res = await ref.read(apiProvider).sendAdminPush(
                              title: title.text.trim(),
                              body: body.text.trim(),
                              audience: audience,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Targeted ${res['targeted']} · sent ${res['sent']}'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(_err(e))),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _Announce extends ConsumerStatefulWidget {
  const _Announce();
  @override
  ConsumerState<_Announce> createState() => _AnnounceState();
}

class _AnnounceState extends ConsumerState<_Announce> {
  final title = TextEditingController();
  final body = TextEditingController();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).adminAnnouncements();
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  void _reload() => setState(
      () => _future = ref.read(apiProvider).adminAnnouncements());

  @override
  Widget build(BuildContext context) {
    return _Page(
      'Announcement publisher',
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GariTextField(controller: title, label: 'Title'),
          const SizedBox(height: 8),
          GariTextField(controller: body, label: 'Body'),
          const SizedBox(height: 8),
          GariPrimaryButton(
            label: 'Publish to driver feed',
            onPressed: () async {
              await ref.read(apiProvider).createAnnouncement(
                    title: title.text.trim(),
                    body: body.text.trim(),
                  );
              title.clear();
              body.clear();
              _reload();
            },
          ),
          const Divider(),
          FutureBuilder(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                children: snap.data!
                    .map((a) => ListTile(
                          title: Text(a['title']?.toString() ?? ''),
                          subtitle: Text(a['body']?.toString() ?? ''),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Quests extends ConsumerStatefulWidget {
  const _Quests();
  @override
  ConsumerState<_Quests> createState() => _QuestsState();
}

class _QuestsState extends ConsumerState<_Quests> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).adminQuests();
  }

  void _reload() =>
      setState(() => _future = ref.read(apiProvider).adminQuests());

  Future<void> _create() async {
    final title = TextEditingController();
    final goal = TextEditingController(text: '20');
    final reward = TextEditingController(text: '150');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New quest'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: goal, decoration: const InputDecoration(labelText: 'Goal trips')),
            TextField(controller: reward, decoration: const InputDecoration(labelText: 'Reward Br')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      await ref.read(apiProvider).createQuest({
        'titleEn': title.text.trim(),
        'titleAm': title.text.trim(),
        'goal': int.tryParse(goal.text) ?? 20,
        'rewardBirr': int.tryParse(reward.text) ?? 150,
        'endsAt': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      });
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      'Driver quests',
      FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(_err(snap.error!)));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GariPrimaryButton(label: 'Create quest', onPressed: _create),
              const SizedBox(height: 12),
              ...snap.data!.map((q) => GariCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${q['title_en']} · goal ${q['goal']} · ${q['reward_birr']} Br · ${q['active'] == true ? 'active' : 'off'}',
                            style: AppText.headline(context),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await ref.read(apiProvider).updateQuest(
                                  q['id'].toString(),
                                  {'active': q['active'] != true},
                                );
                            _reload();
                          },
                          child: Text(q['active'] == true ? 'Disable' : 'Enable'),
                        ),
                      ],
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _Roles extends ConsumerStatefulWidget {
  const _Roles();
  @override
  ConsumerState<_Roles> createState() => _RolesState();
}

class _RolesState extends ConsumerState<_Roles> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).adminRoles();
  }

  void _reload() =>
      setState(() => _future = ref.read(apiProvider).adminRoles());

  @override
  Widget build(BuildContext context) {
    return _Page(
      'Roles & access',
      FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(_err(snap.error!)));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final roles =
              List<dynamic>.from(snap.data!['roles'] as List? ?? const []);
          final admins =
              List<dynamic>.from(snap.data!['admins'] as List? ?? const []);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Role matrix', style: AppText.headline(context)),
              ...roles.map((r) => ListTile(
                    title: Text(r['role']?.toString() ?? ''),
                    subtitle: Text(
                        (r['permissions'] as List?)?.join(', ') ?? ''),
                  )),
              const Divider(),
              Text('Admins', style: AppText.headline(context)),
              ...admins.map((a) => ListTile(
                    title: Text('${a['name']} · ${a['email']}'),
                    subtitle: Text('role: ${a['role']}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (role) async {
                        await ref
                            .read(apiProvider)
                            .setAdminRole(a['id'].toString(), role);
                        _reload();
                      },
                      itemBuilder: (_) => [
                        'super_admin',
                        'city_ops',
                        'support',
                        'finance',
                        'trust_safety',
                      ]
                          .map((r) => PopupMenuItem(value: r, child: Text(r)))
                          .toList(),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _Audit extends ConsumerStatefulWidget {
  const _Audit();
  @override
  ConsumerState<_Audit> createState() => _AuditState();
}

class _AuditState extends ConsumerState<_Audit> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).adminAudit();
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      'Audit log',
      FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(_err(snap.error!)));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = snap.data!;
          if (logs.isEmpty) {
            return const Center(child: Text('No audit events yet'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: logs
                .map((l) => ListTile(
                      title: Text(
                          '${l['admin_email'] ?? 'system'} · ${l['action']}'),
                      subtitle: Text('${l['meta']} · ${l['created_at']}'),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _Security extends ConsumerStatefulWidget {
  const _Security();
  @override
  ConsumerState<_Security> createState() => _SecurityState();
}

class _SecurityState extends ConsumerState<_Security> {
  String? secret;
  String? otpauth;
  String? error;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    return _Page(
      'Security · TOTP',
      Padding(
        padding: const EdgeInsets.all(16),
        child: GariCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.hasTotp
                    ? 'Authenticator is enrolled for this account.'
                    : 'Dev login accepts 123456 until TOTP is set up.',
                style: AppText.body(context),
              ),
              const SizedBox(height: 12),
              if (secret != null) ...[
                SelectableText('Secret: $secret',
                    style: AppText.caption(context)),
                SelectableText(otpauth ?? '',
                    style: AppText.caption(context)),
              ],
              if (error != null)
                Text(error!,
                    style: AppText.body(context, color: GariColors.crimson)),
              const SizedBox(height: 12),
              GariPrimaryButton(
                label: busy ? '…' : 'Generate / rotate TOTP secret',
                onPressed: busy
                    ? null
                    : () async {
                        setState(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          final res =
                              await ref.read(apiProvider).adminSetupTotp();
                          setState(() {
                            secret = res['secret']?.toString();
                            otpauth = res['otpauthUrl']?.toString();
                            busy = false;
                          });
                        } catch (e) {
                          setState(() {
                            busy = false;
                            error = _err(e);
                          });
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
