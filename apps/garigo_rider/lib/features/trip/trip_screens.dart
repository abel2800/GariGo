import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gari_api/gari_api.dart';
import 'package:gari_core/gari_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/providers/providers.dart';

class MatchedScreen extends ConsumerWidget {
  const MatchedScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider);
    ref.listen(tripProvider, (prev, next) {
      if (next?.status == TripStatus.inProgress) {
        context.go('/trip/$tripId/in-progress');
      } else if (next?.status == TripStatus.completed) {
        context.go('/trip/$tripId/summary');
      }
    });
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    final d = trip?.driver;
    final arrived = trip?.status == TripStatus.arrived;
    final eta = arrived ? 0 : (d?.etaMin ?? 3);

    return Scaffold(
      backgroundColor: GariColors.cream,
      body: Stack(
        children: [
          const GariMapCanvas(
            showRoute: true,
            zoom: 13.5,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _roundIconBtn(
                    Icons.arrow_back_ios_new_rounded,
                    () => context.go('/home'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      decoration: BoxDecoration(
                        color: GariColors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: GariColors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: GariColors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              arrived
                                  ? (isAm
                                      ? 'ሹፌርዎ ደርሷል'
                                      : 'Driver has arrived')
                                  : (isAm
                                      ? 'ሹፌር በ$eta ደቂቃ ውስጥ'
                                      : 'Driver arriving in $eta min'),
                              style: const TextStyle(
                                color: GariColors.amber400,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _DriverSheet(
              isAm: isAm,
              s: s,
              trip: trip,
              eta: eta,
              fare: trip?.estimatedFare ?? 45,
              onCancel: () {
                ref.read(tripProvider.notifier).clear();
                context.go('/home');
              },
              arrived: arrived,
              tripId: tripId,
            ),
          ),
        ],
      ),
    );
  }
}

class InProgressScreen extends ConsumerStatefulWidget {
  const InProgressScreen({super.key, required this.tripId});
  final String tripId;
  @override
  ConsumerState<InProgressScreen> createState() => _InProgressScreenState();
}

class _InProgressScreenState extends ConsumerState<InProgressScreen> {
  Timer? t;
  int fare = 45;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 2), (_) {
      setState(() => fare++);
      ref.read(tripProvider.notifier).tick(fare);
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider);
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    final d = trip?.driver;

    return Scaffold(
      backgroundColor: GariColors.cream,
      body: Stack(
        children: [
          const GariMapCanvas(
            showRoute: true,
            zoom: 13.5,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _roundIconBtn(Icons.arrow_back_ios_new_rounded, () {}),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      decoration: BoxDecoration(
                        color: GariColors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: GariColors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: GariColors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isAm ? 'ጉዞ በሂደት ላይ' : 'Trip in progress',
                            style: const TextStyle(
                              color: GariColors.amber400,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 300,
            child: Material(
              color: GariColors.crimson,
              shape: const CircleBorder(
                side: BorderSide(color: Colors.white, width: 3),
              ),
              elevation: 8,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text(s.sendSos),
                      content: Text(s.sosConfirm),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text(s.cancel)),
                        TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: Text(s.sendSos)),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text(isAm ? 'SOS ተልኳል' : 'SOS sent')),
                    );
                  }
                },
                child: const SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(Icons.warning_amber_rounded,
                      color: Colors.white),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _DriverSheet(
              isAm: isAm,
              s: s,
              trip: trip,
              eta: 12,
              fare: fare,
              etaLabel: isAm ? 'እስከ መድረሻ' : 'to destination',
              onCancel: null,
              onShare: () => Share.share(
                  'Track my GariGo trip: https://garigo.et/t/${widget.tripId}'),
              onEnd: () {
                t?.cancel();
                context.go('/trip/${widget.tripId}/summary');
              },
              inProgress: true,
              tripId: widget.tripId,
              driverOverride: d,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverSheet extends ConsumerWidget {
  const _DriverSheet({
    required this.isAm,
    required this.s,
    required this.trip,
    required this.eta,
    required this.fare,
    required this.tripId,
    this.etaLabel,
    this.arrived = false,
    this.inProgress = false,
    this.onCancel,
    this.onShare,
    this.onEnd,
    this.driverOverride,
  });

  final bool isAm;
  final S s;
  final ActiveTrip? trip;
  final int eta;
  final int fare;
  final String tripId;
  final String? etaLabel;
  final bool arrived;
  final bool inProgress;
  final VoidCallback? onCancel;
  final VoidCallback? onShare;
  final VoidCallback? onEnd;
  final MatchedDriverInfo? driverOverride;

  Future<void> _call(BuildContext context, WidgetRef ref, MatchedDriverInfo? d) async {
    var phone = d?.phone;
    try {
      final session =
          await ref.read(apiProvider).client.createCallSession(tripId);
      phone = session['counterpartPhone']?.toString() ?? phone;
    } catch (_) {}
    if (phone == null || phone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAm ? 'ስልክ ቁጥር አልተገኘም' : 'Phone number unavailable'),
          ),
        );
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(phone)),
      );
    }
  }

  void _openProfile(BuildContext context, MatchedDriverInfo? d) {
    if (d == null) return;
    final photo = GariConfig.mediaUrl(d.photoUrl);
    showGariContactSheet(
      context,
      title: isAm ? 'ሹፌር' : 'Driver',
      name: d.name,
      photoUrl: photo.isEmpty ? null : photo,
      phone: d.phone,
      subtitle: '${d.rating.toStringAsFixed(1)} ★',
      details: [
        '${d.vehicleModel} · ${d.vehicleColor}',
        'Plate ${d.plate}',
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = driverOverride ?? trip?.driver;
    final photo = GariConfig.mediaUrl(d?.photoUrl);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$eta min',
                          style: AppText.display(context)
                              .copyWith(fontWeight: FontWeight.w800)),
                      Text(etaLabel ?? s.untilPickup,
                          style: AppText.caption(context,
                              color: GariColors.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$fare Br',
                        style: AppText.display(context)
                            .copyWith(fontWeight: FontWeight.w800)),
                    Text(s.tripFare,
                        style: AppText.caption(context,
                            color: GariColors.muted)),
                  ],
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
                    imageUrl: photo.isEmpty ? null : photo,
                    fallbackLetter: d?.name ?? 'D',
                    radius: 25,
                    onTap: () => _openProfile(context, d),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: () => _openProfile(context, d),
                                child: Text(d?.name ?? 'Driver',
                                    style: AppText.headline(context)
                                        .copyWith(fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.star,
                                size: 13, color: GariColors.amber),
                            Text(' ${d?.rating.toStringAsFixed(1) ?? '—'}',
                                style: AppText.caption(context)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${d?.vehicleModel ?? '—'} · ${d?.vehicleColor ?? '—'} · ${d?.plate ?? '—'}',
                          style: AppText.caption(context,
                              color: GariColors.muted),
                        ),
                        if (d?.phone != null && d!.phone!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            d.phone!,
                            style: AppText.caption(context,
                                color: GariColors.amberDeep),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: GariColors.nightBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      d?.plate ?? '—',
                      style: const TextStyle(
                        color: GariColors.amber400,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!inProgress) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GariColors.nightBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(s.showPin,
                        style: AppText.caption(context,
                            color: Colors.white.withValues(alpha: 0.6))),
                    Text(
                      trip?.riderPin.split('').join(' ') ?? '—',
                      style: AppText.display(context,
                          color: GariColors.amber),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _ActionBtn(
                        icon: Icons.phone_outlined,
                        label: isAm ? 'ደውል' : 'Call',
                        onTap: () => _call(context, ref, d))),
                const SizedBox(width: 10),
                Expanded(
                    child: _ActionBtn(
                        icon: Icons.chat_bubble_outline,
                        label: isAm ? 'መልእክት' : 'Message',
                        onTap: () => context.push('/trip/$tripId/chat'))),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.ios_share,
                    label: isAm ? 'አጋራ' : 'Share',
                    dark: true,
                    onTap: onShare ??
                        () => Share.share(
                            'Track my GariGo trip: https://garigo.et/t/$tripId'),
                  ),
                ),
              ],
            ),
            if (arrived)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  isAm
                      ? 'ሹፌሩ ደርሷል · ፒን ያሳዩ'
                      : 'Driver arrived · show your PIN',
                  textAlign: TextAlign.center,
                  style: AppText.caption(context, color: GariColors.emerald),
                ),
              ),
            if (onCancel != null)
              TextButton(
                onPressed: onCancel,
                child: Text(
                  s.cancelTrip,
                  style: AppText.label(context, color: GariColors.crimson),
                ),
              ),
            if (onEnd != null)
              TextButton(
                onPressed: onEnd,
                child: Text(
                  isAm ? 'ጉዞ ጨርስ' : 'End view',
                  style: AppText.label(context, color: GariColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dark = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark ? GariColors.nightBlue : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: dark
                ? null
                : Border.all(color: GariColors.border, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 17,
                  color: dark ? GariColors.amber400 : GariColors.nightBlue),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: dark ? Colors.white : GariColors.nightBlue,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _roundIconBtn(IconData icon, VoidCallback onTap) {
  return Material(
    color: Colors.white,
    shape: const CircleBorder(
      side: BorderSide(color: GariColors.border),
    ),
    elevation: 2,
    shadowColor: Colors.black26,
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

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Combined trip-end + rating flow per mockup.
    return RateScreen(tripId: tripId, showSummary: true);
  }
}

class RateScreen extends ConsumerStatefulWidget {
  const RateScreen({super.key, required this.tripId, this.showSummary = false});
  final String tripId;
  final bool showSummary;
  @override
  ConsumerState<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends ConsumerState<RateScreen> {
  int stars = 4;
  int? tip = 10;

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider);
    final isAm = ref.watch(authProvider).locale.languageCode == 'am';
    final s = S.of(isAm);
    final q = trip?.fareQuote;
    final driver = trip?.driver?.name?.trim().isNotEmpty == true
        ? trip!.driver!.name!
        : (isAm ? 'ሹፌር' : 'your driver');
    final total = q?.total ?? trip?.estimatedFare;
    final durationMin = q?.etaMin;
    final vehicle = trip?.driver?.vehicleModel?.trim().isNotEmpty == true
        ? trip!.driver!.vehicleModel!
        : (q?.category.name ?? trip?.driver?.category.name ?? '—');
    final pickup = trip?.pickupLandmark?.trim().isNotEmpty == true
        ? trip!.pickupLandmark!
        : (isAm ? 'መነሻ' : 'Pickup');
    final dropoff = trip?.destinationLandmark?.trim().isNotEmpty == true
        ? trip!.destinationLandmark!
        : (isAm ? 'መድረሻ' : 'Drop-off');

    return Scaffold(
      backgroundColor: GariColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: GariColors.emerald,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: GariColors.emerald.withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(height: 12),
            Text(s.tripCompleted,
                textAlign: TextAlign.center,
                style: AppText.title(context)
                    .copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              isAm
                  ? 'ከዋሌት ተከፍሏል · ${DateFormat('MMM d, h:mm a').format(DateTime.now())}'
                  : 'Paid from wallet · ${DateFormat('MMM d, h:mm a').format(DateTime.now())}',
              textAlign: TextAlign.center,
              style: AppText.caption(context, color: GariColors.muted),
            ),
            const SizedBox(height: 22),
            Container(
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
                            height: 26,
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
                            Text(pickup,
                                style: AppText.headline(context)
                                    .copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 22),
                            Text(dropoff,
                                style: AppText.headline(context)
                                    .copyWith(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: GariColors.creamDim),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (durationMin != null)
                        _meta(
                          context,
                          isAm ? 'ጊዜ' : 'Duration',
                          '$durationMin min',
                        ),
                      _meta(
                        context,
                        isAm ? 'ተሽከርካሪ' : 'Vehicle',
                        vehicle,
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
              child: Column(
                children: [
                  if (q != null) ...[
                    _fareRow(context, isAm ? 'መሠረት' : 'Base fare',
                        '${q.base} Br'),
                    _fareRow(context, isAm ? 'ርቀት' : 'Distance',
                        '${q.distanceFee} Br'),
                    _fareRow(
                        context, isAm ? 'ጊዜ' : 'Time', '${q.timeFee} Br'),
                    const Divider(color: GariColors.creamDim),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isAm ? 'ድምር' : 'Total',
                            style: AppText.title(context)
                                .copyWith(fontWeight: FontWeight.w800)),
                        Text(
                          total != null ? '$total Br' : '—',
                          style: AppText.title(context)
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '${s.howWasTrip} $driver?',
              textAlign: TextAlign.center,
              style: AppText.headline(context)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < stars;
                return IconButton(
                  onPressed: () => setState(() => stars = i + 1),
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 36,
                    color: filled
                        ? GariColors.amber
                        : const Color(0xFFDCD5C4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final n in [5, 10, 20])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: n == 20 ? 0 : 8),
                      child: _tipChip(
                        '+$n Br',
                        tip == n,
                        () => setState(() => tip = n),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: _tipChip(
                    s.noTip,
                    tip == null,
                    () => setState(() => tip = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Material(
              color: GariColors.nightBlue,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () {
                  ref.read(tripProvider.notifier).clear();
                  ref.read(bookingProvider.notifier).clear();
                  context.go('/home');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            isAm ? 'አመሰግናለሁ!' : 'Thanks for riding!')),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: Text(s.done,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, String l, String v) => Expanded(
        child: Text.rich(
          TextSpan(
            style: AppText.caption(context, color: GariColors.muted),
            children: [
              TextSpan(text: '$l '),
              TextSpan(
                  text: v,
                  style: const TextStyle(
                      color: GariColors.nightBlue,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );

  Widget _fareRow(BuildContext context, String l, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l,
                style: AppText.caption(context, color: GariColors.muted)
                    .copyWith(fontWeight: FontWeight.w600)),
            Text(v,
                style: AppText.caption(context, color: GariColors.muted)
                    .copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _tipChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? GariColors.amber : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? GariColors.amber : GariColors.border,
            width: 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active
                  ? const Color(0xFF1A1408)
                  : GariColors.nightBlue,
            )),
      ),
    );
  }
}
