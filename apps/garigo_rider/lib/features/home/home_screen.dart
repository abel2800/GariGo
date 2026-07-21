import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gari_core/gari_core.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  VehicleCategory selected = VehicleCategory.bajaj;

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    final booking = ref.watch(bookingProvider);
    final auth = ref.watch(authProvider);
    final quotesAsync = ref.watch(homeQuotesProvider);
    final quotes = quotesAsync.valueOrNull ?? const <FareQuote>[];
    if (quotes.isEmpty) {
      return Scaffold(
        backgroundColor: GariColors.cream,
        body: quotesAsync.isLoading
            ? const Center(child: CircularProgressIndicator(color: GariColors.amber))
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    quotesAsync.hasError
                        ? 'Cannot reach API. Is the backend running on :4000?'
                        : 'No fare quotes yet',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
      );
    }
    final selectedQuote = quotes.firstWhere(
      (q) => q.category == selected,
      orElse: () => quotes.first,
    );
    final initial = (auth.rider?.name?.isNotEmpty == true)
        ? auth.rider!.name!.characters.first.toUpperCase()
        : 'S';

    return Scaffold(
      backgroundColor: GariColors.cream,
      body: Stack(
        children: [
          const GariMapCanvas(
            center: GariMapDefaults.boleMedhanialem,
            showPulse: true,
            zoom: 14,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        GoRouter.of(context).go('/profile'),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: GariColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(initial,
                          style: const TextStyle(
                              color: GariColors.nightBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: GariColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: GariColors.emerald,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: GariColors.emerald
                                      .withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              booking.pickup,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: GariColors.nightBlue,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: GariColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.notifications_none,
                            color: GariColors.nightBlue, size: 20),
                      ),
                      Positioned(
                        top: 10,
                        right: 11,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: GariColors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 340,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _mapChip(Icons.home_outlined, isAm ? 'ቤት' : 'Home'),
                  _mapChip(Icons.work_outline, isAm ? 'ሥራ' : 'Work'),
                  _mapChip(Icons.flight, isAm ? 'አውሮፕላን' : 'Airport',
                      onTap: () => context.push('/places')),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 360,
            child: _SosFab(
              onPressed: () => _sos(context, isAm, s),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.52,
              ),
              decoration: BoxDecoration(
                color: GariColors.cream,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCD5C4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/booking/destination'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: GariColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                color: GariColors.amber, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: AppText.headline(context),
                                  children: [
                                    TextSpan(text: s.whereTo),
                                    TextSpan(
                                      text: '  ·  ${s.firstRidePromo}',
                                      style: AppText.caption(context,
                                          color: GariColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.chooseRide,
                      style: AppText.caption(context, color: GariColors.muted)
                          .copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...quotes.map((q) {
                      final active = q.category == selected;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RideCard(
                          quote: q,
                          active: active,
                          isAm: isAm,
                          onTap: () =>
                              setState(() => selected = q.category),
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    GariPrimaryButton(
                      label:
                          '${s.confirmRide} ${selectedQuote.category.labelEn} · ${selectedQuote.total} Br',
                      onPressed: () {
                        ref
                            .read(bookingProvider.notifier)
                            .setCategory(selected, selectedQuote);
                        context.push('/booking/destination');
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

  Widget _mapChip(IconData icon, String label, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GariColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: GariColors.nightBlue),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: GariColors.nightBlue,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sos(BuildContext context, bool isAm, S s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: GariColors.cream,
        title: Text(s.sendSos),
        content: Text(s.sosConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(s.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(s.sendSos,
                  style: const TextStyle(color: GariColors.crimson))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAm ? 'SOS ተልኳል' : 'SOS sent')),
      );
    }
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({
    required this.quote,
    required this.active,
    required this.isAm,
    required this.onTap,
  });
  final FareQuote quote;
  final bool active;
  final bool isAm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = switch (quote.category) {
      VehicleCategory.bajaj =>
        isAm ? '${quote.etaMin} ደቂቃ · 2 ሰው' : '${quote.etaMin} min away · fits 2',
      VehicleCategory.moto =>
        isAm ? '${quote.etaMin} ደቂቃ · 1 ሰው' : '${quote.etaMin} min away · fits 1',
      VehicleCategory.car =>
        isAm ? '${quote.etaMin} ደቂቃ · 4 ሰው' : '${quote.etaMin} min away · fits 4',
    };
    final badge = quote.category == VehicleCategory.bajaj
        ? (isAm ? 'ፈጣን' : 'Fastest')
        : '${quote.etaMin} min';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          gradient: active
              ? LinearGradient(
                  colors: [
                    GariColors.amber.withValues(alpha: 0.08),
                    Colors.white,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? GariColors.amber : GariColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: GariColors.nightBlue,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(quote.category.icon,
                  color: GariColors.amber400, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quote.category.labelEn,
                      style: AppText.headline(context)
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(meta,
                      style: AppText.caption(context,
                          color: GariColors.muted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${quote.total} Br',
                    style: AppText.headline(context)
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(badge,
                    style: AppText.caption(context,
                            color: GariColors.emerald)
                        .copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SosFab extends StatelessWidget {
  const _SosFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GariColors.crimson,
      shape: const CircleBorder(
        side: BorderSide(color: Colors.white, width: 3),
      ),
      elevation: 8,
      shadowColor: GariColors.crimson.withValues(alpha: 0.5),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(Icons.warning_amber_rounded,
              color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class RiderShell extends StatelessWidget {
  const RiderShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final isAm = Localizations.localeOf(context).languageCode == 'am';
    final s = S.of(isAm);
    return Scaffold(
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
              icon: const Icon(Icons.show_chart_outlined),
              selectedIcon: _navIcon(Icons.show_chart),
              label: s.activity,
            ),
            NavigationDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: _navIcon(Icons.account_balance_wallet),
              label: s.wallet,
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
