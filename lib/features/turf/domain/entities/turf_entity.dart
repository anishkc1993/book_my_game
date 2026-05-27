import 'package:equatable/equatable.dart';

class TurfEntity extends Equatable {
  final String id;
  final String name;
  final String adminPhone; // e.g. "+9779840072995"
  // Free-form short address (legacy). Prefer the structured fields below.
  final String? address;
  final bool isActive;
  final DateTime? createdAt;

  // Venue location — populated from the "Venue location" admin screen.
  final String? venueName;
  final String? street;
  final String? cityArea;
  final String? landmark;
  final double? latitude;
  final double? longitude;
  // URL slug used for the shareable link, e.g. "patan-arena" → bmg.com.np/v/patan-arena
  final String? shareSlug;

  const TurfEntity({
    required this.id,
    required this.name,
    required this.adminPhone,
    this.address,
    this.isActive = true,
    this.createdAt,
    this.venueName,
    this.street,
    this.cityArea,
    this.landmark,
    this.latitude,
    this.longitude,
    this.shareSlug,
  });

  bool get hasLocation => latitude != null && longitude != null;

  /// Display name preferring the structured venueName, falling back to the
  /// turf's main name.
  String get displayName =>
      (venueName != null && venueName!.isNotEmpty) ? venueName! : name;

  /// Composed single-line address.
  String get oneLineAddress {
    final parts = <String>[
      if (street != null && street!.isNotEmpty) street!,
      if (cityArea != null && cityArea!.isNotEmpty) cityArea!,
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    return address ?? '';
  }

  /// "bmg.com.np/v/<slug>" — falls back to a slugified version of the name.
  String get shareUrl {
    final slug = (shareSlug != null && shareSlug!.isNotEmpty)
        ? shareSlug!
        : _slugify(displayName);
    return 'bmg.com.np/v/$slug';
  }

  static String _slugify(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  TurfEntity copyWith({
    String? id,
    String? name,
    String? adminPhone,
    String? address,
    bool? isActive,
    DateTime? createdAt,
    String? venueName,
    String? street,
    String? cityArea,
    String? landmark,
    double? latitude,
    double? longitude,
    String? shareSlug,
  }) {
    return TurfEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      adminPhone: adminPhone ?? this.adminPhone,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      venueName: venueName ?? this.venueName,
      street: street ?? this.street,
      cityArea: cityArea ?? this.cityArea,
      landmark: landmark ?? this.landmark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      shareSlug: shareSlug ?? this.shareSlug,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        adminPhone,
        address,
        isActive,
        createdAt,
        venueName,
        street,
        cityArea,
        landmark,
        latitude,
        longitude,
        shareSlug,
      ];
}
