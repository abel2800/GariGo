import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'config.dart';

MediaType _mediaTypeForFilename(String filename) {
  final ext = filename.contains('.')
      ? filename.split('.').last.toLowerCase()
      : '';
  return switch (ext) {
    'pdf' => MediaType('application', 'pdf'),
    'png' => MediaType('image', 'png'),
    'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
    'webp' => MediaType('image', 'webp'),
    'gif' => MediaType('image', 'gif'),
    'bmp' => MediaType('image', 'bmp'),
    'tif' || 'tiff' => MediaType('image', 'tiff'),
    'heic' => MediaType('image', 'heic'),
    'heif' => MediaType('image', 'heif'),
    'avif' => MediaType('image', 'avif'),
    _ => MediaType('application', 'octet-stream'),
  };
}
class GariApiClient {
  GariApiClient({String? token}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: GariConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
  }

  late final Dio _dio;
  io.Socket? socket;

  void setToken(String? token) {
    if (token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<Map<String, dynamic>> health() async {
    final r = await _dio.get('/health');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> requestOtp({
    required String phone,
    required String role,
  }) async {
    final r = await _dio.post('/auth/otp/request', data: {
      'phone': phone,
      'role': role,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
    required String role,
    bool isGuest = false,
    String? name,
  }) async {
    final r = await _dio.post('/auth/otp/verify', data: {
      'phone': phone,
      'code': code,
      'role': role,
      'isGuest': isGuest,
      'name': name,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> quote({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String? promoCode,
    List<dynamic> stops = const [],
  }) async {
    final r = await _dio.post('/trips/quote', data: {
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'promoCode': promoCode,
      'stops': stops,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<dynamic>> searchPlaces(String q) async {
    final r = await _dio.get('/trips/places/search', queryParameters: {'q': q});
    return List<dynamic>.from((r.data as Map)['places'] as List);
  }

  Future<Map<String, dynamic>> requestTrip(Map<String, dynamic> body) async {
    final r = await _dio.post('/trips/request', data: body);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> acceptTrip(String id) async {
    final r = await _dio.post('/trips/$id/accept');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> declineTrip(String id) async {
    await _dio.post('/trips/$id/decline');
  }

  Future<Map<String, dynamic>> arriveTrip(String id) async {
    final r = await _dio.post('/trips/$id/arrived');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> verifyTripPin(String id, String pin) async {
    final r = await _dio.post('/trips/$id/verify-pin', data: {'pin': pin});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> completeTrip(String id, {int? finalFare}) async {
    final r = await _dio.post('/trips/$id/complete', data: {
      if (finalFare != null) 'finalFare': finalFare,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> rateTrip(String id, {required int rating, String? tipNote}) async {
    await _dio.post('/trips/$id/rate', data: {
      'rating': rating,
      if (tipNote != null) 'note': tipNote,
    });
  }

  Future<Map<String, dynamic>> sosTrip(String id) async {
    final r = await _dio.post('/trips/$id/sos');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> getTrip(String id) async {
    final r = await _dio.get('/trips/$id');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> tripContact(String id) async {
    final r = await _dio.get('/trips/$id/contact');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> createCallSession(String id) async {
    final r = await _dio.post('/trips/$id/call-session');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<Map<String, dynamic>>> tripMessages(String id) async {
    final r = await _dio.get('/trips/$id/messages');
    return List<Map<String, dynamic>>.from(
      ((r.data as Map)['messages'] as List).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
  }

  Future<Map<String, dynamic>> sendTripMessage(String id, String body) async {
    final r = await _dio.post('/trips/$id/messages', data: {'body': body});
    return Map<String, dynamic>.from((r.data as Map)['message'] as Map);
  }

  Future<List<dynamic>> myTrips() async {
    final r = await _dio.get('/trips/mine');
    return List<dynamic>.from((r.data as Map)['trips'] as List);
  }

  Future<Map<String, dynamic>> me() async {
    final r = await _dio.get('/auth/me');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<dynamic>> listCards() async {
    final r = await _dio.get('/riders/cards');
    return List<dynamic>.from((r.data as Map)['cards'] as List);
  }

  Future<Map<String, dynamic>> addCard(Map<String, dynamic> body) async {
    final r = await _dio.post('/riders/cards', data: body);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> setDefaultCard(String id) async {
    await _dio.patch('/riders/cards/$id/default');
  }

  Future<void> deleteCard(String id) async {
    await _dio.delete('/riders/cards/$id');
  }

  Future<void> setOnline(bool online) async {
    await _dio.patch('/drivers/online', data: {'online': online});
  }

  Future<Map<String, dynamic>> updateDriverProfile({
    String? name,
    String? languagePref,
    double? matchRadiusKm,
  }) async {
    final r = await _dio.patch('/drivers/profile', data: {
      if (name != null) 'name': name,
      if (languagePref != null) 'languagePref': languagePref,
      if (matchRadiusKm != null) 'matchRadiusKm': matchRadiusKm,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> uploadDriverPhoto({
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: _mediaTypeForFilename(filename),
      ),
    });
    final r = await _dio.post('/drivers/photo', data: form);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<dynamic>> driverQuests() async {
    final r = await _dio.get('/drivers/quests');
    return List<dynamic>.from((r.data as Map)['quests'] as List? ?? const []);
  }

  Future<List<dynamic>> driverAnnouncements() async {
    final r = await _dio.get('/drivers/announcements');
    return List<dynamic>.from(
        (r.data as Map)['announcements'] as List? ?? const []);
  }

  Future<Map<String, dynamic>> createDriverTicket({
    required String subject,
    String? message,
    String category = 'general',
  }) async {
    final r = await _dio.post('/drivers/tickets', data: {
      'subject': subject,
      if (message != null) 'message': message,
      'category': category,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<dynamic>> driverTickets() async {
    final r = await _dio.get('/drivers/tickets');
    return List<dynamic>.from((r.data as Map)['tickets'] as List? ?? const []);
  }

  Future<void> pushLocation({
    required double lat,
    required double lng,
    double? heading,
  }) async {
    await _dio.post('/drivers/location', data: {
      'lat': lat,
      'lng': lng,
      'heading': heading,
    });
  }

  Future<void> setVehicleCategory(String category) async {
    await _dio.post('/drivers/vehicle-category', data: {'category': category});
  }

  Future<void> setPayoutMethod({
    required String type,
    required String details,
  }) async {
    await _dio.post('/drivers/payout-method', data: {
      'type': type,
      'details': details,
    });
  }

  Future<void> submitForApproval({
    String? name,
    String? tinNumber,
    String? businessRegNumber,
  }) async {
    await _dio.post('/drivers/submit-for-approval', data: {
      if (name != null) 'name': name,
      if (tinNumber != null) 'tinNumber': tinNumber,
      if (businessRegNumber != null) 'businessRegNumber': businessRegNumber,
    });
  }

  Future<Map<String, dynamic>> saveDriverVehicle(Map<String, dynamic> body) async {
    final r = await _dio.post('/drivers/vehicle', data: body);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> listDriverDocuments() async {
    final r = await _dio.get('/drivers/documents');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> uploadDriverDocument({
    required String docType,
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'docType': docType,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: _mediaTypeForFilename(filename),
      ),
    });
    final r = await _dio.post('/drivers/documents', data: form);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> registerRider({
    required String name,
    required String password,
    String? email,
  }) async {
    final r = await _dio.post('/riders/register', data: {
      'name': name,
      'password': password,
      if (email != null) 'email': email,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> uploadRiderPhoto({
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: _mediaTypeForFilename(filename),
      ),
    });
    final r = await _dio.post('/riders/photo', data: form);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> loginRiderPassword({
    required String phone,
    required String password,
  }) async {
    final r = await _dio.post('/riders/login-password', data: {
      'phone': phone,
      'password': password,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> driverEarnings() async {
    final r = await _dio.get('/drivers/earnings');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> payoutInstant({
    int? amount,
    String method = 'telebirr',
  }) async {
    final r = await _dio.post('/drivers/payout/instant', data: {
      if (amount != null) 'amount': amount,
      'method': method,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  void joinTrip(String tripId) {
    socket?.emit('join_trip', tripId);
  }

  // ── Admin ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> adminLogin(String email, String password) async {
    final r = await _dio.post('/admin/login', data: {
      'email': email,
      'password': password,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> admin2fa(String tempToken, String code) async {
    final r = await _dio.post('/admin/2fa', data: {
      'tempToken': tempToken,
      'code': code,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> adminMe() async {
    final r = await _dio.get('/admin/me');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> updateAdminMe(Map<String, dynamic> body) async {
    final r = await _dio.patch('/admin/me', data: body);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> uploadAdminMyPhoto({
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final r = await _dio.post('/admin/me/photo', data: form);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> createAdminStaff(Map<String, dynamic> body) async {
    final r = await _dio.post('/admin/admins', data: body);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> updateAdminStaff(
    String id,
    Map<String, dynamic> body,
  ) async {
    final r = await _dio.patch('/admin/admins/$id', data: body);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> uploadAdminStaffPhoto({
    required String id,
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final r = await _dio.post('/admin/admins/$id/photo', data: form);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> lookupRiderByPhone(String phone) async {
    final r = await _dio.get('/admin/riders/lookup', queryParameters: {
      'phone': phone,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> createAdminRider({
    required String phone,
    String? name,
  }) async {
    final r = await _dio.post('/admin/riders', data: {
      'phone': phone,
      if (name != null) 'name': name,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> bookTripForCaller(
    Map<String, dynamic> body,
  ) async {
    final r = await _dio.post('/admin/trips/book', data: body);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> adminSetupTotp() async {
    final r = await _dio.post('/admin/2fa/setup');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> opsSnapshot() async {
    final r = await _dio.get('/admin/ops/snapshot');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> approveDriver(String id) async {
    await _dio.post('/admin/drivers/$id/approve');
  }

  Future<void> rejectDriver(String id, {List<String>? reasons}) async {
    await _dio.post('/admin/drivers/$id/reject', data: {
      'reasons': reasons ?? ['Rejected by admin'],
    });
  }

  Future<Map<String, dynamic>> adminDriver(String id) async {
    final r = await _dio.get('/admin/drivers/$id');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> setDriverStatus(String id, String status) async {
    await _dio.post('/admin/drivers/$id/status', data: {'status': status});
  }

  Future<Map<String, dynamic>> adminRider(String id) async {
    final r = await _dio.get('/admin/riders/$id');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> setRiderStatus(String id, String status) async {
    await _dio.post('/admin/riders/$id/status', data: {'status': status});
  }

  Future<void> updateSos(
    String id, {
    required String status,
    String? adminNotes,
  }) async {
    await _dio.patch('/admin/sos/$id', data: {
      'status': status,
      if (adminNotes != null) 'adminNotes': adminNotes,
    });
  }

  Future<List<dynamic>> adminTrips({String? q, String? status}) async {
    final r = await _dio.get('/admin/trips', queryParameters: {
      if (q != null && q.isNotEmpty) 'q': q,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return List<dynamic>.from((r.data as Map)['trips'] as List);
  }

  Future<Map<String, dynamic>> adminTrip(String id) async {
    final r = await _dio.get('/admin/trips/$id');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<dynamic>> adminTickets() async {
    final r = await _dio.get('/admin/tickets');
    return List<dynamic>.from((r.data as Map)['tickets'] as List);
  }

  Future<Map<String, dynamic>> adminTicket(String id) async {
    final r = await _dio.get('/admin/tickets/$id');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> updateTicket(
    String id, {
    String? status,
    String? resolutionNotes,
    String? priority,
  }) async {
    await _dio.patch('/admin/tickets/$id', data: {
      if (status != null) 'status': status,
      if (resolutionNotes != null) 'resolutionNotes': resolutionNotes,
      if (priority != null) 'priority': priority,
    });
  }

  Future<List<dynamic>> adminFares() async {
    final r = await _dio.get('/admin/fares');
    return List<dynamic>.from((r.data as Map)['fares'] as List);
  }

  Future<void> updateFare(
    String category, {
    required int baseFare,
    required int perKm,
    required int perMin,
    required int minimumFare,
  }) async {
    await _dio.put('/admin/fares/$category', data: {
      'baseFare': baseFare,
      'perKm': perKm,
      'perMin': perMin,
      'minimumFare': minimumFare,
    });
  }

  Future<List<dynamic>> adminZones() async {
    final r = await _dio.get('/admin/zones');
    return List<dynamic>.from((r.data as Map)['zones'] as List);
  }

  Future<void> updateZone(String id, {double? surgeMultiplier, String? name}) async {
    await _dio.put('/admin/zones/$id', data: {
      if (surgeMultiplier != null) 'surgeMultiplier': surgeMultiplier,
      if (name != null) 'name': name,
    });
  }

  Future<Map<String, dynamic>> createZone({
    required String name,
    double surgeMultiplier = 1.0,
  }) async {
    final r = await _dio.post('/admin/zones', data: {
      'name': name,
      'surgeMultiplier': surgeMultiplier,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<dynamic>> adminPromos() async {
    final r = await _dio.get('/admin/promos');
    return List<dynamic>.from((r.data as Map)['promos'] as List);
  }

  Future<Map<String, dynamic>> createPromo(Map<String, dynamic> body) async {
    final r = await _dio.post('/admin/promos', data: body);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> updatePromo(
    String id, {
    bool? active,
    int? value,
    int? usageLimit,
    String? discountType,
  }) async {
    await _dio.patch('/admin/promos/$id', data: {
      if (active != null) 'active': active,
      if (value != null) 'value': value,
      if (usageLimit != null) 'usageLimit': usageLimit,
      if (discountType != null) 'discountType': discountType,
    });
  }

  Future<Map<String, dynamic>> financeSummary() async {
    final r = await _dio.get('/admin/finance/summary');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<dynamic>> cashDebt() async {
    final r = await _dio.get('/admin/finance/cash-debt');
    return List<dynamic>.from((r.data as Map)['drivers'] as List);
  }

  Future<Map<String, dynamic>> settleCashDebt(
    String driverId, {
    int? amount,
    bool fromBalance = true,
  }) async {
    final r = await _dio.post(
      '/admin/finance/cash-debt/$driverId/settle',
      data: {
        if (amount != null) 'amount': amount,
        'fromBalance': fromBalance,
      },
    );
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> payoutBatch() async {
    final r = await _dio.get('/admin/finance/payouts');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> processPayouts() async {
    final r = await _dio.post('/admin/finance/payouts/process');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> adminAnalytics() async {
    final r = await _dio.get('/admin/analytics');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> sendAdminPush({
    required String title,
    required String body,
    String audience = 'drivers',
  }) async {
    final r = await _dio.post('/admin/push', data: {
      'title': title,
      'body': body,
      'audience': audience,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<dynamic>> adminAnnouncements() async {
    final r = await _dio.get('/admin/announcements');
    return List<dynamic>.from((r.data as Map)['announcements'] as List);
  }

  Future<Map<String, dynamic>> createAnnouncement({
    required String title,
    required String body,
    String audience = 'drivers',
  }) async {
    final r = await _dio.post('/admin/announcements', data: {
      'title': title,
      'body': body,
      'audience': audience,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<List<dynamic>> adminQuests() async {
    final r = await _dio.get('/admin/quests');
    return List<dynamic>.from((r.data as Map)['quests'] as List);
  }

  Future<Map<String, dynamic>> createQuest(Map<String, dynamic> body) async {
    final r = await _dio.post('/admin/quests', data: body);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> updateQuest(String id, Map<String, dynamic> body) async {
    await _dio.patch('/admin/quests/$id', data: body);
  }

  Future<Map<String, dynamic>> adminRoles() async {
    final r = await _dio.get('/admin/roles');
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> setAdminRole(String id, String role) async {
    await _dio.patch('/admin/admins/$id/role', data: {'role': role});
  }

  Future<List<dynamic>> adminAudit() async {
    final r = await _dio.get('/admin/audit');
    return List<dynamic>.from((r.data as Map)['logs'] as List);
  }

  Future<List<dynamic>> pendingDocuments() async {
    final r = await _dio.get('/admin/documents/pending');
    return List<dynamic>.from((r.data as Map)['documents'] as List);
  }

  Future<void> verifyDocument(
    String id, {
    bool verified = true,
    String? rejectionReason,
  }) async {
    await _dio.post('/admin/documents/$id/verify', data: {
      'verified': verified,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    });
  }

  void connectSocket({
    required String role,
    required String userId,
  }) {
    socket?.dispose();
    socket = io.io(
      GariConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setAuth({'role': role, 'userId': userId})
          .build(),
    );
  }

  Future<Map<String, dynamic>?> driverPendingOffer() async {
    final r = await _dio.get('/drivers/pending-offer');
    final offer = (r.data as Map)['offer'];
    if (offer == null) return null;
    return Map<String, dynamic>.from(offer as Map);
  }

  void disconnectSocket() {
    socket?.dispose();
    socket = null;
  }
}
