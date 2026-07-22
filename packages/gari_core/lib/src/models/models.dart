import 'package:flutter/material.dart';

enum VehicleCategory { moto, bajaj, car }

enum ApprovalStatus { none, pending, approved, rejected }

enum OnlineStatus { offline, online, onTrip }

enum PaymentMethod {
  wallet,
  telebirr,
  cbeBirr,
  helloCash,
  cash,
  card,
}

enum PayoutMethodType { telebirr, cbeBirr, helloCash }

enum TripStatus {
  requested,
  matching,
  matched,
  arriving,
  arrived,
  verifying,
  inProgress,
  completed,
  cancelled,
}

enum DocumentType {
  nationalIdFront,
  nationalIdBack,
  licenseFront,
  licenseBack,
  selfie,
  vehicleLibre,
  insurance,
  vehicleFront,
  vehicleBack,
  vehicleLeft,
  vehicleRight,
  vehicleSide,
  helmetVest,
  tinCertificate,
  businessRegistration,
  ownerAuthorization,
}

enum DocumentStatus { empty, uploaded, verified, rejected, expiring, expired }

enum TicketStatus { open, inProgress, resolved }

enum SosStatus { open, dispatched, resolved }

extension DocumentTypeX on DocumentType {
  String get apiKey => switch (this) {
        DocumentType.nationalIdFront => 'national_id_front',
        DocumentType.nationalIdBack => 'national_id_back',
        DocumentType.licenseFront => 'license_front',
        DocumentType.licenseBack => 'license_back',
        DocumentType.selfie => 'selfie',
        DocumentType.vehicleLibre => 'vehicle_libre',
        DocumentType.insurance => 'insurance',
        DocumentType.vehicleFront => 'vehicle_front',
        DocumentType.vehicleBack => 'vehicle_back',
        DocumentType.vehicleLeft => 'vehicle_left',
        DocumentType.vehicleRight => 'vehicle_right',
        DocumentType.vehicleSide => 'vehicle_left',
        DocumentType.helmetVest => 'helmet_vest',
        DocumentType.tinCertificate => 'tin_certificate',
        DocumentType.businessRegistration => 'business_registration',
        DocumentType.ownerAuthorization => 'owner_authorization',
      };

  String get labelEn => switch (this) {
        DocumentType.nationalIdFront => 'National ID (front)',
        DocumentType.nationalIdBack => 'National ID (back)',
        DocumentType.licenseFront => 'Driver licence',
        DocumentType.licenseBack => 'Licence (back)',
        DocumentType.selfie => 'Your photo',
        DocumentType.vehicleLibre => 'Vehicle libre / certification',
        DocumentType.insurance => 'Insurance',
        DocumentType.vehicleFront => 'Car photo — front',
        DocumentType.vehicleBack => 'Car photo — back',
        DocumentType.vehicleLeft => 'Car photo — left',
        DocumentType.vehicleRight => 'Car photo — right',
        DocumentType.vehicleSide => 'Car photo — side',
        DocumentType.helmetVest => 'Helmet / vest',
        DocumentType.tinCertificate => 'TIN certificate',
        DocumentType.businessRegistration => 'Business registration',
        DocumentType.ownerAuthorization => 'Owner authorization letter',
      };
}

extension VehicleCategoryX on VehicleCategory {
  String get labelEn => switch (this) {
        VehicleCategory.moto => 'Moto',
        VehicleCategory.bajaj => 'Bajaj',
        VehicleCategory.car => 'Car',
      };

  String get labelAm => switch (this) {
        VehicleCategory.moto => 'ሞተር',
        VehicleCategory.bajaj => 'ባጃጅ',
        VehicleCategory.car => 'መኪና',
      };

  String get capacityEn => switch (this) {
        VehicleCategory.moto => '1 seat',
        VehicleCategory.bajaj => 'up to 2',
        VehicleCategory.car => 'up to 4',
      };

  IconData get icon => switch (this) {
        VehicleCategory.moto => Icons.two_wheeler,
        VehicleCategory.bajaj => Icons.airport_shuttle,
        VehicleCategory.car => Icons.directions_car,
      };
}

class LatLngPoint {
  const LatLngPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

class PlaceResult {
  const PlaceResult({
    required this.id,
    required this.nameEn,
    required this.nameAm,
    required this.area,
    required this.location,
    this.isSaved = false,
    this.isRecent = false,
  });

  final String id;
  final String nameEn;
  final String nameAm;
  final String area;
  final LatLngPoint location;
  final bool isSaved;
  final bool isRecent;

  String name(bool isAm) => isAm ? nameAm : nameEn;
}

class FareQuote {
  const FareQuote({
    required this.category,
    required this.etaMin,
    required this.total,
    required this.base,
    required this.distanceFee,
    required this.timeFee,
    this.surge = 1.0,
    this.fuelAdjustment = 0,
    this.promoDiscount = 0,
    this.available = true,
  });

  final VehicleCategory category;
  final int etaMin;
  final int total;
  final int base;
  final int distanceFee;
  final int timeFee;
  final double surge;
  final int fuelAdjustment;
  final int promoDiscount;
  final bool available;
}

class FareBreakdown {
  const FareBreakdown({
    required this.gross,
    required this.commissionPercent,
    required this.commissionAmount,
    required this.net,
  });

  final int gross;
  final double commissionPercent;
  final int commissionAmount;
  final int net;

  factory FareBreakdown.fromGross(int gross, double commissionPercent) {
    final c = (gross * commissionPercent / 100).round();
    return FareBreakdown(
      gross: gross,
      commissionPercent: commissionPercent,
      commissionAmount: c,
      net: gross - c,
    );
  }
}

class Rider {
  const Rider({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    this.photoUrl,
    this.isGuest = false,
    this.hasPassword = false,
    this.walletBalance = 0,
    this.rating = 5.0,
    this.totalTrips = 0,
  });

  final String id;
  final String phone;
  final String? name;
  final String? email;
  final String? photoUrl;
  final bool isGuest;
  final bool hasPassword;
  final int walletBalance;
  final double rating;
  final int totalTrips;

  bool get profileComplete =>
      (name?.trim().isNotEmpty ?? false) && hasPassword;

  Rider copyWith({
    String? name,
    String? email,
    String? photoUrl,
    bool? isGuest,
    bool? hasPassword,
    int? walletBalance,
    double? rating,
    int? totalTrips,
  }) {
    return Rider(
      id: id,
      phone: phone,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      isGuest: isGuest ?? this.isGuest,
      hasPassword: hasPassword ?? this.hasPassword,
      walletBalance: walletBalance ?? this.walletBalance,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
    );
  }
}

class Driver {
  const Driver({
    required this.id,
    required this.phone,
    this.name,
    this.photoUrl,
    this.rating = 5.0,
    this.approvalStatus = ApprovalStatus.none,
    this.vehicleCategory,
    this.onlineStatus = OnlineStatus.offline,
    this.commissionPercent = 15,
    this.totalTrips = 0,
    this.plate,
    this.vehicleColor,
    this.vehicleModel,
    this.rejectionReasons = const [],
    this.lat = 9.0222,
    this.lng = 38.7468,
    this.matchRadiusKm = 2.0,
    this.availableBalance = 0,
  });

  final String id;
  final String phone;
  final String? name;
  final String? photoUrl;
  final double rating;
  final ApprovalStatus approvalStatus;
  final VehicleCategory? vehicleCategory;
  final OnlineStatus onlineStatus;
  final double commissionPercent;
  final int totalTrips;
  final String? plate;
  final String? vehicleColor;
  final String? vehicleModel;
  final List<String> rejectionReasons;
  final double lat;
  final double lng;
  /// Preferred job search radius in km (0.5–2.0).
  final double matchRadiusKm;
  final int availableBalance;

  Driver copyWith({
    String? name,
    String? photoUrl,
    ApprovalStatus? approvalStatus,
    VehicleCategory? vehicleCategory,
    OnlineStatus? onlineStatus,
    int? totalTrips,
    List<String>? rejectionReasons,
    double? lat,
    double? lng,
    double? matchRadiusKm,
    int? availableBalance,
    String? plate,
    String? vehicleColor,
    String? vehicleModel,
  }) {
    return Driver(
      id: id,
      phone: phone,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      rating: rating,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      vehicleCategory: vehicleCategory ?? this.vehicleCategory,
      onlineStatus: onlineStatus ?? this.onlineStatus,
      commissionPercent: commissionPercent,
      totalTrips: totalTrips ?? this.totalTrips,
      plate: plate ?? this.plate,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      rejectionReasons: rejectionReasons ?? this.rejectionReasons,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      matchRadiusKm: matchRadiusKm ?? this.matchRadiusKm,
      availableBalance: availableBalance ?? this.availableBalance,
    );
  }
}

class DriverDocument {
  const DriverDocument({
    required this.type,
    required this.nameEn,
    required this.nameAm,
    this.status = DocumentStatus.empty,
    this.localPath,
    this.url,
    this.expiryDate,
    this.rejectionReason,
  });

  final DocumentType type;
  final String nameEn;
  final String nameAm;
  final DocumentStatus status;
  final String? localPath;
  final String? url;
  final DateTime? expiryDate;
  final String? rejectionReason;

  DriverDocument copyWith({
    DocumentStatus? status,
    String? localPath,
    String? url,
    DateTime? expiryDate,
    String? rejectionReason,
  }) {
    return DriverDocument(
      type: type,
      nameEn: nameEn,
      nameAm: nameAm,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      url: url ?? this.url,
      expiryDate: expiryDate ?? this.expiryDate,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

class TripOffer {
  const TripOffer({
    required this.id,
    required this.pickupLandmark,
    required this.pickupDistanceKm,
    required this.destinationArea,
    required this.estimatedFare,
    required this.estimatedDurationMin,
    required this.acceptWindowSec,
    this.riderName,
    this.riderPhotoUrl,
    this.riderPhone,
    this.riderRating,
    this.riderPin = '0000',
    this.category,
    this.tripDistanceKm,
    this.paymentMethod,
  });

  final String id;
  final String pickupLandmark;
  final double pickupDistanceKm;
  final String destinationArea;
  final int estimatedFare;
  final int estimatedDurationMin;
  final int acceptWindowSec;
  final String? riderName;
  final String? riderPhotoUrl;
  final String? riderPhone;
  final double? riderRating;
  final String riderPin;
  final String? category;
  final double? tripDistanceKm;
  final String? paymentMethod;
}

class MatchedDriverInfo {
  const MatchedDriverInfo({
    required this.name,
    required this.rating,
    required this.plate,
    required this.vehicleColor,
    required this.vehicleModel,
    required this.etaMin,
    required this.category,
    this.id,
    this.photoUrl,
    this.phone,
    this.verified = true,
  });

  final String? id;
  final String name;
  final double rating;
  final String plate;
  final String vehicleColor;
  final String vehicleModel;
  final int etaMin;
  final VehicleCategory category;
  final String? photoUrl;
  final String? phone;
  final bool verified;
}

class ActiveTrip {
  const ActiveTrip({
    required this.id,
    required this.riderName,
    required this.pickupLandmark,
    required this.destinationLandmark,
    required this.estimatedFare,
    required this.riderPin,
    this.status = TripStatus.arriving,
    this.accruedFare = 0,
    this.hasVoiceNote = false,
    this.driver,
    this.fareQuote,
    this.riderPhotoUrl,
    this.riderPhone,
    this.riderRating,
  });

  final String id;
  final String riderName;
  final String pickupLandmark;
  final String destinationLandmark;
  final int estimatedFare;
  final String riderPin;
  final TripStatus status;
  final int accruedFare;
  final bool hasVoiceNote;
  final MatchedDriverInfo? driver;
  final FareQuote? fareQuote;
  final String? riderPhotoUrl;
  final String? riderPhone;
  final double? riderRating;

  ActiveTrip copyWith({
    TripStatus? status,
    int? accruedFare,
    MatchedDriverInfo? driver,
    String? riderName,
    String? riderPhotoUrl,
    String? riderPhone,
    double? riderRating,
  }) {
    return ActiveTrip(
      id: id,
      riderName: riderName ?? this.riderName,
      pickupLandmark: pickupLandmark,
      destinationLandmark: destinationLandmark,
      estimatedFare: estimatedFare,
      riderPin: riderPin,
      status: status ?? this.status,
      accruedFare: accruedFare ?? this.accruedFare,
      hasVoiceNote: hasVoiceNote,
      driver: driver ?? this.driver,
      fareQuote: fareQuote,
      riderPhotoUrl: riderPhotoUrl ?? this.riderPhotoUrl,
      riderPhone: riderPhone ?? this.riderPhone,
      riderRating: riderRating ?? this.riderRating,
    );
  }
}

class TripHistoryItem {
  const TripHistoryItem({
    required this.id,
    required this.route,
    required this.completedAt,
    required this.fare,
    required this.category,
    this.rating,
  });

  final String id;
  final String route;
  final DateTime completedAt;
  final int fare;
  final VehicleCategory category;
  final int? rating;
}

class WalletTxn {
  const WalletTxn({
    required this.id,
    required this.label,
    required this.amount,
    required this.at,
    this.isCredit = true,
  });

  final String id;
  final String label;
  final int amount;
  final DateTime at;
  final bool isCredit;
}

class Quest {
  const Quest({
    required this.id,
    required this.titleEn,
    required this.titleAm,
    required this.goal,
    required this.progress,
    required this.rewardBirr,
    required this.endsAt,
  });

  final String id;
  final String titleEn;
  final String titleAm;
  final int goal;
  final int progress;
  final int rewardBirr;
  final DateTime endsAt;

  double get progressRatio => (progress / goal).clamp(0, 1);
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.postedAt,
    this.unread = true,
  });

  final String id;
  final String title;
  final String body;
  final DateTime postedAt;
  final bool unread;
}

class PayoutMethod {
  const PayoutMethod({required this.type, required this.details});
  final PayoutMethodType type;
  final String details;

  String get label => switch (type) {
        PayoutMethodType.telebirr => 'Telebirr',
        PayoutMethodType.cbeBirr => 'CBE Birr',
        PayoutMethodType.helloCash => 'HelloCash',
      };
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.category,
    required this.subject,
    required this.status,
    required this.createdAt,
    this.tripId,
    this.priority = 'normal',
  });

  final String id;
  final String category;
  final String subject;
  final TicketStatus status;
  final DateTime createdAt;
  final String? tripId;
  final String priority;
}

class SosAlert {
  const SosAlert({
    required this.id,
    required this.tripId,
    required this.triggeredBy,
    required this.location,
    required this.timestamp,
    this.status = SosStatus.open,
  });

  final String id;
  final String tripId;
  final String triggeredBy;
  final String location;
  final DateTime timestamp;
  final SosStatus status;
}

class TrustedContact {
  const TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    this.autoShare = false,
  });

  final String id;
  final String name;
  final String phone;
  final bool autoShare;
}

class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    required this.place,
    this.isHome = false,
    this.isWork = false,
  });

  final String id;
  final String label;
  final PlaceResult place;
  final bool isHome;
  final bool isWork;
}

/// Tokenized bank card on file (last4 only — never full PAN).
class SavedCard {
  const SavedCard({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.holderName,
    this.isDefault = false,
  });

  final String id;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final String holderName;
  final bool isDefault;

  String get label {
    final b = brand.trim().isEmpty ? 'Card' : brand.trim();
    final titled = '${b[0].toUpperCase()}${b.substring(1)}';
    return '$titled ···· $last4';
  }

  String get expiryLabel =>
      '${expMonth.toString().padLeft(2, '0')}/${expYear % 100}';
}
