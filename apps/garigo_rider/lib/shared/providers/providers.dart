import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gari_api/gari_api.dart';
import 'package:gari_core/gari_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final secureProvider = Provider((ref) => const FlutterSecureStorage());

const _tokenKey = 'rider_token';

VehicleCategory _cat(dynamic v) {
  final s = v?.toString().toLowerCase() ?? 'bajaj';
  return VehicleCategory.values.firstWhere(
    (e) => e.name == s,
    orElse: () => VehicleCategory.bajaj,
  );
}

PlaceResult placeFromJson(Map<String, dynamic> m) => PlaceResult(
      id: m['id'].toString(),
      nameEn: (m['name_en'] ?? m['nameEn'] ?? '').toString(),
      nameAm: (m['name_am'] ?? m['nameAm'] ?? '').toString(),
      area: (m['area'] ?? '').toString(),
      location: LatLngPoint(
        (m['lat'] as num).toDouble(),
        (m['lng'] as num).toDouble(),
      ),
    );

FareQuote quoteFromJson(Map<String, dynamic> m) => FareQuote(
      category: _cat(m['category']),
      etaMin: (m['etaMin'] as num?)?.round() ?? 5,
      total: (m['total'] as num?)?.round() ?? 0,
      base: (m['base'] as num?)?.round() ?? 0,
      distanceFee: (m['distanceFee'] as num?)?.round() ?? 0,
      timeFee: (m['timeFee'] as num?)?.round() ?? 0,
      surge: (m['surgeMultiplier'] as num?)?.toDouble() ?? 1,
      fuelAdjustment: (m['fuelAdjustment'] as num?)?.round() ?? 0,
      promoDiscount: (m['promoDiscount'] as num?)?.round() ?? 0,
      available: true,
    );

Rider riderFromJson(Map<String, dynamic> m) => Rider(
      id: m['id'].toString(),
      phone: m['phone']?.toString() ?? '',
      name: m['name']?.toString(),
      email: m['email']?.toString(),
      photoUrl: m['photo_url']?.toString() ?? m['photoUrl']?.toString(),
      isGuest: m['is_guest'] == true || m['isGuest'] == true,
      hasPassword: m['has_password'] == true ||
          m['hasPassword'] == true ||
          m['password_hash'] != null,
      walletBalance: _asInt(m['wallet_balance'] ?? m['walletBalance']),
      rating: _asDouble(m['rating_avg'] ?? m['ratingAvg'], 5),
      totalTrips: _asInt(m['total_trips'] ?? m['totalTrips']),
    );

double _asDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

int _asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.round();
  return int.tryParse(v.toString()) ??
      double.tryParse(v.toString())?.round() ??
      fallback;
}

/// Real backend API for the rider app (no local fake trips/OTP).
class RiderApi {
  RiderApi(this.prefs, this.secure, {String? token})
      : client = GariApiClient(token: token);

  final SharedPreferences prefs;
  final FlutterSecureStorage secure;
  final GariApiClient client;

  Rider? rider;
  int wallet = 0;
  List<PlaceResult> landmarks = const [];

  Future<String?> getToken() async {
    final secureTok = await secure.read(key: _tokenKey);
    if (secureTok != null && secureTok.isNotEmpty) return secureTok;
    return prefs.getString(_tokenKey);
  }

  Future<void> _persistToken(String token) async {
    await secure.write(key: _tokenKey, value: token);
    await prefs.setString(_tokenKey, token);
    client.setToken(token);
  }

  Future<void> setLocale(String c) => prefs.setString('locale', c);
  String? get locale => prefs.getString('locale');

  Future<void> requestOtp(String phone) async {
    await client.requestOtp(phone: phone, role: 'rider');
  }

  Future<Rider> verifyOtp(
    String phone,
    String code, {
    bool guest = false,
  }) async {
    final res = await client.verifyOtp(
      phone: phone,
      code: code,
      role: 'rider',
      isGuest: guest,
    );
    final token = res['token']?.toString();
    final raw = Map<String, dynamic>.from(res['rider'] as Map);
    rider = riderFromJson(raw);
    wallet = rider!.walletBalance;
    if (token != null) {
      await _persistToken(token);
      client.connectSocket(role: 'rider', userId: rider!.id);
    }
    return rider!;
  }

  Future<void> restore() async {
    final t = await getToken();
    if (t == null) return;
    client.setToken(t);
    try {
      final me = await client.me();
      final profile = Map<String, dynamic>.from(me['profile'] as Map);
      rider = riderFromJson(profile);
      wallet = rider!.walletBalance;
      client.connectSocket(role: 'rider', userId: rider!.id);
    } catch (_) {
      await logout();
    }
  }

  Future<void> logout() async {
    client.disconnectSocket();
    await secure.delete(key: _tokenKey);
    await prefs.remove(_tokenKey);
    client.setToken(null);
    rider = null;
    wallet = 0;
  }

  Future<Rider> completeRegistration({
    required String name,
    required String password,
    String? email,
    List<int>? photoBytes,
    String photoName = 'photo.jpg',
  }) async {
    final res = await client.registerRider(
      name: name,
      password: password,
      email: email,
    );
    rider = riderFromJson(Map<String, dynamic>.from(res['rider'] as Map))
        .copyWith(hasPassword: true);
    if (photoBytes != null && photoBytes.isNotEmpty) {
      final photo = await client.uploadRiderPhoto(
        bytes: photoBytes,
        filename: photoName,
      );
      rider = riderFromJson(Map<String, dynamic>.from(photo['rider'] as Map))
          .copyWith(hasPassword: true);
    }
    wallet = rider!.walletBalance;
    return rider!;
  }

  Future<List<PlaceResult>> search(String q) async {
    final rows = await client.searchPlaces(q);
    final list = rows
        .map((e) => placeFromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (q.trim().isEmpty && list.isNotEmpty) {
      landmarks = list;
    }
    return list;
  }

  Future<List<FareQuote>> quotes({
    required LatLngPoint pickup,
    required LatLngPoint dropoff,
    int stops = 0,
    String? promoCode,
  }) async {
    final res = await client.quote(
      pickupLat: pickup.lat,
      pickupLng: pickup.lng,
      dropoffLat: dropoff.lat,
      dropoffLng: dropoff.lng,
      promoCode: promoCode,
      stops: List.generate(stops, (_) => {}),
    );
    final list = (res['quotes'] as List)
        .map((e) => quoteFromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return list;
  }

  /// Default Bole → Megenagna quotes for the home sheet.
  Future<List<FareQuote>> homeQuotes() => quotes(
        pickup: const LatLngPoint(9.010, 38.780),
        dropoff: const LatLngPoint(9.022, 38.802),
      );

  Future<List<TripHistoryItem>> history() async {
    try {
      final rows = await client.myTrips();
      return rows.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final pickup = m['pickup_landmark']?.toString() ?? '';
        final drop = m['dropoff_landmark']?.toString() ?? '';
        final at = m['completed_at'] ?? m['created_at'];
        return TripHistoryItem(
          id: m['id'].toString(),
          route: '$pickup → $drop',
          completedAt:
              at != null ? DateTime.parse(at.toString()) : DateTime.now(),
          fare: (m['fare_total'] as num?)?.round() ?? 0,
          category: _cat(m['vehicle_category']),
          rating: (m['rider_rating'] as num?)?.round(),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  List<WalletTxn> txns() => const [];

  Future<List<SavedCard>> listCards() async {
    final rows = await client.listCards();
    return rows.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return SavedCard(
        id: m['id'].toString(),
        brand: m['brand']?.toString() ?? 'card',
        last4: m['last4']?.toString() ?? '••••',
        expMonth: (m['expMonth'] as num?)?.round() ?? 1,
        expYear: (m['expYear'] as num?)?.round() ?? 2030,
        holderName: m['holderName']?.toString() ?? '',
        isDefault: m['isDefault'] == true,
      );
    }).toList();
  }

  Future<SavedCard> addCard({
    required String number,
    required int expMonth,
    required int expYear,
    required String cvc,
    required String holderName,
    bool setDefault = true,
  }) async {
    final res = await client.addCard({
      'number': number,
      'expMonth': expMonth,
      'expYear': expYear,
      'cvc': cvc,
      'holderName': holderName,
      'setDefault': setDefault,
    });
    final m = Map<String, dynamic>.from(res['card'] as Map);
    return SavedCard(
      id: m['id'].toString(),
      brand: m['brand']?.toString() ?? 'card',
      last4: m['last4']?.toString() ?? '••••',
      expMonth: (m['expMonth'] as num?)?.round() ?? expMonth,
      expYear: (m['expYear'] as num?)?.round() ?? expYear,
      holderName: m['holderName']?.toString() ?? holderName,
      isDefault: m['isDefault'] == true,
    );
  }

  Future<void> deleteCard(String id) => client.deleteCard(id);

  Future<void> setDefaultCard(String id) => client.setDefaultCard(id);
}

final apiProvider = Provider<RiderApi>((ref) {
  final prefs = ref.watch(prefsProvider);
  return RiderApi(prefs, ref.watch(secureProvider));
});

class AuthState {
  const AuthState({
    this.rider,
    this.token,
    this.locale = const Locale('am'),
    this.bootstrapped = false,
  });
  final Rider? rider;
  final String? token;
  final Locale locale;
  final bool bootstrapped;
  bool get loggedIn => token != null && rider != null;

  AuthState copyWith({
    Rider? rider,
    String? token,
    Locale? locale,
    bool? bootstrapped,
    bool clear = false,
  }) =>
      AuthState(
        rider: clear ? null : rider ?? this.rider,
        token: clear ? null : token ?? this.token,
        locale: locale ?? this.locale,
        bootstrapped: bootstrapped ?? this.bootstrapped,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this.api) : super(const AuthState());
  final RiderApi api;

  Future<void> bootstrap() async {
    final loc = api.locale;
    await api.restore();
    final t = await api.getToken();
    state = AuthState(
      locale: Locale(loc ?? 'am'),
      token: t,
      rider: api.rider,
      bootstrapped: true,
    );
  }

  Future<void> setLocale(Locale l) async {
    await api.setLocale(l.languageCode);
    state = state.copyWith(locale: l);
  }

  Future<void> login(String phone, String code) async {
    final r = await api.verifyOtp(phone, code);
    final t = await api.getToken();
    state = state.copyWith(rider: r, token: t);
  }

  Future<void> completeRegistration({
    required String name,
    required String password,
    String? email,
    List<int>? photoBytes,
  }) async {
    final r = await api.completeRegistration(
      name: name,
      password: password,
      email: email,
      photoBytes: photoBytes,
    );
    state = state.copyWith(rider: r);
  }

  Future<void> guest() async {
    await api.requestOtp('+251900000000');
    final r = await api.verifyOtp('+251900000000', '123456', guest: true);
    final t = await api.getToken();
    state = state.copyWith(rider: r, token: t);
  }

  Future<void> logout() async {
    await api.logout();
    state = AuthState(locale: state.locale, bootstrapped: true);
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref.watch(apiProvider)));

final pendingPhoneProvider = StateProvider<String>((_) => '');

final homeQuotesProvider = FutureProvider<List<FareQuote>>((ref) async {
  try {
    return await ref.watch(apiProvider).homeQuotes();
  } catch (_) {
    return const [];
  }
});

final vehicleQuotesProvider = FutureProvider.autoDispose<List<FareQuote>>((ref) async {
  final b = ref.watch(bookingProvider);
  final dest = b.destination?.location ?? const LatLngPoint(9.022, 38.802);
  return ref.read(apiProvider).quotes(
        pickup: b.pickupLatLng,
        dropoff: dest,
        stops: b.stops.length,
        promoCode: b.promo,
      );
});

final tripHistoryProvider = FutureProvider.autoDispose<List<TripHistoryItem>>((ref) async {
  return ref.watch(apiProvider).history();
});

final savedCardsProvider = FutureProvider.autoDispose<List<SavedCard>>((ref) async {
  return ref.watch(apiProvider).listCards();
});

class BookingState {
  const BookingState({
    this.pickup = 'Bole Medhanialem',
    this.pickupPlace,
    this.destination,
    this.stops = const [],
    this.category,
    this.payment = PaymentMethod.telebirr,
    this.cardId,
    this.promo,
    this.quote,
    this.note,
  });

  final String pickup;
  final PlaceResult? pickupPlace;
  final PlaceResult? destination;
  final List<PlaceResult> stops;
  final VehicleCategory? category;
  final PaymentMethod payment;
  final String? cardId;
  final String? promo;
  final FareQuote? quote;
  final String? note;

  LatLngPoint get pickupLatLng =>
      pickupPlace?.location ?? const LatLngPoint(9.010, 38.780);

  BookingState copyWith({
    String? pickup,
    PlaceResult? pickupPlace,
    PlaceResult? destination,
    List<PlaceResult>? stops,
    VehicleCategory? category,
    PaymentMethod? payment,
    String? cardId,
    String? promo,
    FareQuote? quote,
    String? note,
    bool clearCard = false,
  }) =>
      BookingState(
        pickup: pickup ?? this.pickup,
        pickupPlace: pickupPlace ?? this.pickupPlace,
        destination: destination ?? this.destination,
        stops: stops ?? this.stops,
        category: category ?? this.category,
        payment: payment ?? this.payment,
        cardId: clearCard ? null : cardId ?? this.cardId,
        promo: promo ?? this.promo,
        quote: quote ?? this.quote,
        note: note ?? this.note,
      );
}

class BookingNotifier extends StateNotifier<BookingState> {
  BookingNotifier() : super(const BookingState());
  void setDest(PlaceResult p) => state = state.copyWith(destination: p);
  void setCategory(VehicleCategory c, FareQuote q) =>
      state = state.copyWith(category: c, quote: q);
  void setPayment(PaymentMethod m, {String? cardId}) => state = state.copyWith(
        payment: m,
        cardId: cardId,
        clearCard: m != PaymentMethod.card,
      );
  void setPromo(String? p) => state = state.copyWith(promo: p);
  void setNote(String? n) => state = state.copyWith(note: n);
  void addStop(PlaceResult p) =>
      state = state.copyWith(stops: [...state.stops, p]);
  void clear() => state = BookingState(pickup: state.pickup);
}

final bookingProvider =
    StateNotifierProvider<BookingNotifier, BookingState>((_) => BookingNotifier());

class TripNotifier extends StateNotifier<ActiveTrip?> {
  TripNotifier(this.ref) : super(null);
  final Ref ref;
  StreamSubscription? _sub;

  Future<void> start(BookingState b) async {
    final api = ref.read(apiProvider);
    final dest = b.destination!;
    final q = b.quote!;
    final pay = switch (b.payment) {
      PaymentMethod.telebirr => 'telebirr',
      PaymentMethod.cbeBirr => 'cbe_birr',
      PaymentMethod.helloCash => 'hellocash',
      PaymentMethod.wallet => 'wallet',
      PaymentMethod.cash => 'cash',
      PaymentMethod.card => 'card',
    };

    final res = await api.client.requestTrip({
      'pickupLat': b.pickupLatLng.lat,
      'pickupLng': b.pickupLatLng.lng,
      'pickupLandmark': b.pickup,
      'dropoffLat': dest.location.lat,
      'dropoffLng': dest.location.lng,
      'dropoffLandmark': dest.nameEn,
      'category': q.category.name,
      'paymentMethod': pay,
      if (b.cardId != null) 'cardId': b.cardId,
      'promoCode': b.promo,
      'stops': b.stops
          .map((s) => {
                'lat': s.location.lat,
                'lng': s.location.lng,
                'name': s.nameEn,
              })
          .toList(),
    });

    final trip = Map<String, dynamic>.from(res['trip'] as Map);
    final id = trip['id'].toString();
    final pin = trip['rider_pin']?.toString() ?? '----';

    state = ActiveTrip(
      id: id,
      riderName: ref.read(authProvider).rider?.name ?? 'You',
      pickupLandmark: b.pickup,
      destinationLandmark: dest.nameEn,
      estimatedFare: q.total,
      riderPin: pin,
      status: TripStatus.matching,
      fareQuote: q,
    );

    api.client.joinTrip(id);
    _listen(id, q);
  }

  void _listen(String tripId, FareQuote q) {
    final socket = ref.read(apiProvider).client.socket;
    _sub?.cancel();
    socket?.on('driver_matched', (data) {
      final m = Map<String, dynamic>.from(data as Map);
      if (m['tripId']?.toString() != tripId) return;
      final d = Map<String, dynamic>.from(m['driver'] as Map? ?? {});
      state = state?.copyWith(
        status: TripStatus.matched,
        driver: MatchedDriverInfo(
          name: d['name']?.toString() ?? 'Driver',
          rating: (d['rating'] as num?)?.toDouble() ?? 4.9,
          plate: d['plate']?.toString() ?? '—',
          vehicleColor: d['vehicleColor']?.toString() ?? '—',
          vehicleModel: d['vehicleModel']?.toString() ?? '—',
          etaMin: (m['etaMin'] as num?)?.round() ?? q.etaMin,
          category: _cat(d['category'] ?? q.category.name),
        ),
      );
      if (m['riderPin'] != null) {
        state = ActiveTrip(
          id: state!.id,
          riderName: state!.riderName,
          pickupLandmark: state!.pickupLandmark,
          destinationLandmark: state!.destinationLandmark,
          estimatedFare: state!.estimatedFare,
          riderPin: m['riderPin'].toString(),
          status: TripStatus.matched,
          fareQuote: state!.fareQuote,
          driver: state!.driver,
        );
      }
    });
    socket?.on('driver_arrived', (_) {
      if (state?.id == tripId) {
        state = state?.copyWith(status: TripStatus.arrived);
      }
    });
    socket?.on('trip_started', (_) {
      if (state?.id == tripId) {
        state = state?.copyWith(status: TripStatus.inProgress, accruedFare: 0);
      }
    });
    socket?.on('trip_completed', (data) {
      if (state?.id != tripId) return;
      final m = Map<String, dynamic>.from(data as Map? ?? {});
      final fare = (m['fareTotal'] as num?)?.round() ?? state!.estimatedFare;
      state = state?.copyWith(status: TripStatus.completed, accruedFare: fare);
    });
    socket?.on('match_timeout', (_) {
      if (state?.id == tripId) clear();
    });
  }

  void arrive() => state = state?.copyWith(status: TripStatus.arrived);
  void progress() =>
      state = state?.copyWith(status: TripStatus.inProgress, accruedFare: 42);
  void tick(int f) => state = state?.copyWith(accruedFare: f);

  void clear() {
    _sub?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final tripProvider =
    StateNotifierProvider<TripNotifier, ActiveTrip?>((ref) => TripNotifier(ref));

String apiError(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return e.message ?? 'Network error';
  }
  return e.toString();
}
