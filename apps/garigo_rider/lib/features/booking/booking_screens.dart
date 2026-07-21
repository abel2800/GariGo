import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gari_core/gari_core.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/providers.dart';

class DestinationScreen extends ConsumerStatefulWidget {
  const DestinationScreen({super.key});
  @override
  ConsumerState<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends ConsumerState<DestinationScreen> {
  final q = TextEditingController();
  List<PlaceResult> results = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  Future<void> _search(String v) async {
    setState(() => loading = true);
    try {
      final list = await ref.read(apiProvider).search(v);
      if (mounted) setState(() => results = list);
    } catch (_) {
      if (mounted) setState(() => results = []);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    final selected = ref.watch(bookingProvider).destination;

    return Scaffold(
      appBar: AppBar(title: Text(s.whereTo)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(GariSpacing.lg),
            child: GariTextField(
              controller: q,
              autofocus: true,
              hint: isAm ? 'መገናኛ · Megenagna' : 'Search landmarks…',
              onChanged: _search,
            ),
          ),
          if (loading) const LinearProgressIndicator(color: GariColors.amber),
          if (selected != null)
            SizedBox(
              height: 160,
              child: GariMapCanvas(
                showRoute: true,
                pickup: GariMapDefaults.boleMedhanialem,
                dropoff: selected.location,
                zoom: 12.5,
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (_, i) {
                final p = results[i];
                return ListTile(
                  leading: const Icon(Icons.place, color: GariColors.amberDeep),
                  title: Text(p.name(isAm), style: AppText.headline(context)),
                  subtitle: Text(p.area, style: AppText.caption(context)),
                  onTap: () {
                    ref.read(bookingProvider.notifier).setDest(p);
                    setState(() {});
                  },
                  selected: selected?.id == p.id,
                  selectedTileColor: GariColors.amberGlow,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(GariSpacing.lg),
            child: Column(
              children: [
                TextButton(
                  onPressed: () => context.push('/booking/stops'),
                  child: Text(isAm ? 'ማቆሚያ ጨምር' : 'Add stop',
                      style: AppText.label(context, color: GariColors.amberDeep)),
                ),
                GariPrimaryButton(
                  label: s.confirmDestination,
                  enabled: selected != null,
                  onPressed: () => context.push('/booking/vehicle-class'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StopsScreen extends ConsumerWidget {
  const StopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final b = ref.watch(bookingProvider);
    return Scaffold(
      appBar: AppBar(title: Text(isAm ? 'ማቆሚያዎች' : 'Stops')),
      body: ListView(
        padding: const EdgeInsets.all(GariSpacing.lg),
        children: [
          GariCard(child: Text('① ${b.pickup}', style: AppText.headline(context))),
          ...b.stops.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(top: GariSpacing.sm),
                child: GariCard(
                  child: Text('② ${e.value.name(isAm)}',
                      style: AppText.headline(context)),
                ),
              )),
          if (b.destination != null)
            Padding(
              padding: const EdgeInsets.only(top: GariSpacing.sm),
              child: GariCard(
                child: Text('③ ${b.destination!.name(isAm)}',
                    style: AppText.headline(context)),
              ),
            ),
          const SizedBox(height: GariSpacing.md),
          Text(
            isAm
                ? 'ባለብዙ ማቆሚያ የተለየ ዋጋ አለው'
                : 'Multi-stop trips use a different fare calculation',
            style: AppText.caption(context, color: GariColors.amberDeep),
          ),
          const SizedBox(height: GariSpacing.lg),
          GariSecondaryButton(
            label: isAm ? 'ማቆሚያ ጨምር' : 'Add stop',
            onPressed: () async {
              final places = await ref.read(apiProvider).search('ayat');
              if (places.isNotEmpty) {
                ref.read(bookingProvider.notifier).addStop(places.first);
              }
            },
          ),
          const SizedBox(height: GariSpacing.md),
          GariPrimaryButton(
            label: S.of(isAm).continueLabel,
            onPressed: () => context.push('/booking/vehicle-class'),
          ),
        ],
      ),
    );
  }
}

class VehicleClassScreen extends ConsumerWidget {
  const VehicleClassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    final b = ref.watch(bookingProvider);
    final quotesAsync = ref.watch(vehicleQuotesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(isAm ? 'ተሽከርካሪ' : 'Choose ride')),
      body: Column(
        children: [
          SizedBox(
            height: 160,
            child: GariMapCanvas(
              showRoute: true,
              pickup: GariMapDefaults.boleMedhanialem,
              dropoff: b.destination?.location ?? GariMapDefaults.megenagna,
              zoom: 12.5,
            ),
          ),
          Expanded(
            child: quotesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: GariColors.amber),
              ),
              error: (e, _) => Center(child: Text(apiError(e))),
              data: (quotes) {
                if (quotes.isEmpty) {
                  return const Center(child: Text('No quotes available'));
                }
                return ListView(
                  padding: const EdgeInsets.all(GariSpacing.lg),
                  children: [
                    ...quotes.map((q) {
                      final sel = b.category == q.category;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GariCard(
                          borderColor: sel ? GariColors.amber : null,
                          onTap: () => ref
                              .read(bookingProvider.notifier)
                              .setCategory(q.category, q),
                          child: Row(
                            children: [
                              Icon(q.category.icon, color: GariColors.amberDeep),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${q.category.labelEn} · ${q.category.labelAm}',
                                      style: AppText.headline(context),
                                    ),
                                    Text(
                                      '${q.etaMin} min · ${formatBirr(q.total)}',
                                      style: AppText.caption(context),
                                    ),
                                  ],
                                ),
                              ),
                              BirrText(q.total,
                                  size: 20, color: GariColors.nightBlue),
                            ],
                          ),
                        ),
                      );
                    }),
                    GariPrimaryButton(
                      label: s.continueLabel,
                      enabled: b.category != null,
                      onPressed: () => context.push('/booking/payment'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});
  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool promoOpen = false;
  final promo = TextEditingController();

  @override
  void dispose() {
    promo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final b = ref.watch(bookingProvider);
    final fare = b.quote?.total ?? 0;
    final disc = b.promo != null ? 20 : 0;
    final cardsAsync = ref.watch(savedCardsProvider);

    Widget row(PaymentMethod m, String label, IconData icon, {String? cardId}) {
      final sel = b.payment == m && (cardId == null || b.cardId == cardId);
      return Padding(
        padding: const EdgeInsets.only(bottom: GariSpacing.sm),
        child: GariCard(
          borderColor: sel ? GariColors.amber : null,
          onTap: () => ref
              .read(bookingProvider.notifier)
              .setPayment(m, cardId: cardId),
          child: Row(
            children: [
              Icon(icon, color: sel ? GariColors.amberDeep : GariColors.slate),
              const SizedBox(width: GariSpacing.md),
              Expanded(child: Text(label, style: AppText.headline(context))),
              if (m == PaymentMethod.wallet)
                Text(formatBirr(ref.watch(apiProvider).wallet),
                    style: AppText.caption(context)),
              if (sel)
                const Icon(Icons.check_circle, color: GariColors.emerald),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(isAm ? 'ክፍያ' : 'Payment')),
      body: ListView(
        padding: const EdgeInsets.all(GariSpacing.lg),
        children: [
          Text(
            isAm ? 'የባንክ ካርድ' : 'Bank cards',
            style: AppText.caption(context, color: GariColors.muted)
                .copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          cardsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: CircularProgressIndicator(color: GariColors.amber),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (cards) => Column(
              children: [
                ...cards.map(
                  (c) => row(
                    PaymentMethod.card,
                    c.label,
                    Icons.credit_card,
                    cardId: c.id,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: GariSpacing.sm),
                  child: GariCard(
                    onTap: () async {
                      await context.push('/wallet/cards/add');
                      ref.invalidate(savedCardsProvider);
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.add_card, color: GariColors.amberDeep),
                        const SizedBox(width: GariSpacing.md),
                        Text(
                          isAm ? 'ካርድ ጨምር' : 'Add bank card',
                          style: AppText.headline(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isAm ? 'ሌሎች ዘዴዎች' : 'Other methods',
            style: AppText.caption(context, color: GariColors.muted)
                .copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          row(PaymentMethod.wallet, 'GariGo Wallet', Icons.account_balance_wallet),
          row(PaymentMethod.telebirr, 'Telebirr · ቴሌብር', Icons.phone_android),
          row(PaymentMethod.cbeBirr, 'CBE Birr', Icons.account_balance),
          row(PaymentMethod.helloCash, 'HelloCash', Icons.payments),
          row(PaymentMethod.cash, isAm ? 'ካሽ' : 'Cash', Icons.money),
          TextButton(
            onPressed: () => setState(() => promoOpen = !promoOpen),
            child: Text(isAm ? 'ፕሮሞ ኮድ?' : 'Have a promo code?',
                style: AppText.label(context, color: GariColors.amberDeep)),
          ),
          if (promoOpen)
            GariTextField(
              controller: promo,
              hint: 'GARI50',
              onChanged: (v) =>
                  ref.read(bookingProvider.notifier).setPromo(v.isEmpty ? null : v),
            ),
          const SizedBox(height: GariSpacing.xl),
          GariPrimaryButton(
            label:
                'Confirm ${b.category?.labelEn ?? ''} · ${formatBirr(fare - disc)}',
            enabled: b.payment != PaymentMethod.card || b.cardId != null,
            onPressed: () => context.push('/booking/pickup-note'),
          ),
        ],
      ),
    );
  }
}

class PickupNoteScreen extends ConsumerStatefulWidget {
  const PickupNoteScreen({super.key});
  @override
  ConsumerState<PickupNoteScreen> createState() => _PickupNoteScreenState();
}

class _PickupNoteScreenState extends ConsumerState<PickupNoteScreen> {
  final note = TextEditingController();
  bool recording = false;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> request() async {
    ref.read(bookingProvider.notifier).setNote(note.text);
    try {
      await ref.read(tripProvider.notifier).start(ref.read(bookingProvider));
      final id = ref.read(tripProvider)?.id;
      if (id != null && mounted) context.go('/booking/matching?id=$id');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    return Scaffold(
      appBar: AppBar(title: Text(isAm ? 'የመውሰጃ ማስታወሻ' : 'Pickup notes')),
      body: Padding(
        padding: const EdgeInsets.all(GariSpacing.xl),
        child: Column(
          children: [
            GariTextField(
              controller: note,
              label: isAm ? 'ጽሑፍ' : 'Typed instructions',
              hint: isAm ? 'ከቤተ ክርስቲያን ፊት…' : 'In front of the church…',
            ),
            const SizedBox(height: GariSpacing.xl),
            GariSecondaryButton(
              label: recording
                  ? (isAm ? 'ቆም · ማቆም' : 'Stop recording')
                  : (isAm ? '🎙 የድምፅ ማስታወሻ' : '🎙 Record voice note'),
              onPressed: () => setState(() => recording = !recording),
            ),
            if (recording)
              Padding(
                padding: const EdgeInsets.all(GariSpacing.lg),
                child: Text(isAm ? 'በመቅረጽ ላይ…' : 'Recording… 0:08',
                    style: AppText.caption(context, color: GariColors.crimson)),
              ),
            const Spacer(),
            TextButton(
              onPressed: request,
              child: Text(s.skip,
                  style: AppText.label(context, color: GariColors.slate)),
            ),
            GariPrimaryButton(
              label: isAm ? 'ጉዞ ጠይቅ' : 'Request ride',
              onPressed: request,
            ),
          ],
        ),
      ),
    );
  }
}

class MatchingScreen extends ConsumerStatefulWidget {
  const MatchingScreen({super.key});
  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends ConsumerState<MatchingScreen> {
  Timer? tipTimer;
  Timer? timeoutTimer;
  bool timeout = false;
  int tip = 0;

  @override
  void initState() {
    super.initState();
    tipTimer = Timer.periodic(const Duration(seconds: 3), (x) {
      if (!mounted) {
        x.cancel();
        return;
      }
      setState(() => tip = (tip + 1) % 3);
    });
    timeoutTimer = Timer(const Duration(seconds: 90), () {
      if (!mounted) return;
      final trip = ref.read(tripProvider);
      if (trip == null || trip.driver == null) {
        setState(() => timeout = true);
      }
    });
  }

  @override
  void dispose() {
    tipTimer?.cancel();
    timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    final trip = ref.watch(tripProvider);

    ref.listen(tripProvider, (prev, next) {
      if (next?.driver != null &&
          (next!.status == TripStatus.matched ||
              next.status == TripStatus.arriving ||
              next.status == TripStatus.arrived)) {
        context.go('/trip/${next.id}/matched');
      }
      if (next == null && prev != null) {
        setState(() => timeout = true);
      }
    });

    if (trip?.driver != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/trip/${trip!.id}/matched');
      });
    }

    final tips = isAm
        ? ['ጠቃሚ: ፒን ላይ መታ በማድረግ ማስታወሻ ይጨምሩ', 'ባጃጅ በውጭ ክፍለ ከተሞች ፈጣን ነው', 'PIN ን ለሹፌሩ ያሳዩ']
        : [
            'Tip: Add pickup notes for easier finding',
            'Bajaj is often faster in outer sub-cities',
            'Show your PIN to the driver before boarding',
          ];

    if (timeout) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(GariSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(isAm ? 'ሹፌር አልተገኘም' : 'No drivers available right now',
                  style: AppText.title(context), textAlign: TextAlign.center),
              const SizedBox(height: GariSpacing.xl),
              GariPrimaryButton(
                label: isAm ? 'ሌላ ተሽከርካሪ' : 'Try different vehicle',
                onPressed: () => context.go('/booking/vehicle-class'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(tripProvider.notifier).clear();
                  context.go('/home');
                },
                child: Text(s.cancel),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          const GariMapCanvas(showPulse: true),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                GariCard(
                  child: Column(
                    children: [
                      Text(s.findingDriver, style: AppText.title(context)),
                      const SizedBox(height: GariSpacing.sm),
                      Text(tips[tip],
                          style: AppText.caption(context),
                          textAlign: TextAlign.center),
                      const SizedBox(height: GariSpacing.lg),
                      const CircularProgressIndicator(color: GariColors.amber),
                      const SizedBox(height: GariSpacing.lg),
                      Text(
                        isAm
                            ? 'ኦንላይን ሹፌር እየተፈለገ ነው…'
                            : 'Looking for an online driver…',
                        style: AppText.caption(context, color: GariColors.muted),
                      ),
                      const SizedBox(height: GariSpacing.md),
                      GariSecondaryButton(
                        label: '${s.cancel} · ${isAm ? "ያለ ክፍያ" : "no charge"}',
                        onPressed: () {
                          ref.read(tripProvider.notifier).clear();
                          context.go('/home');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: GariSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
