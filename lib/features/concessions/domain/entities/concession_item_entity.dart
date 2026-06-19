import 'package:equatable/equatable.dart';

/// A catalog item sold at the turf (drinking water, tea, soft drink, etc).
/// Admin maintains this list; recording a sale references one of these.
class ConcessionItemEntity extends Equatable {
  final String? id;
  final String name;
  /// Default unit price — pre-fills the sale amount as `qty × defaultPrice`.
  /// Admin can override per-sale (discount, bulk deal, etc).
  final double defaultPrice;
  final bool isActive;
  final String? createdByAdmin;
  final DateTime? createdAt;
  final String? turfId;

  const ConcessionItemEntity({
    this.id,
    required this.name,
    required this.defaultPrice,
    this.isActive = true,
    this.createdByAdmin,
    this.createdAt,
    this.turfId,
  });

  ConcessionItemEntity copyWith({
    String? id,
    String? name,
    double? defaultPrice,
    bool? isActive,
    String? createdByAdmin,
    DateTime? createdAt,
    String? turfId,
  }) {
    return ConcessionItemEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      isActive: isActive ?? this.isActive,
      createdByAdmin: createdByAdmin ?? this.createdByAdmin,
      createdAt: createdAt ?? this.createdAt,
      turfId: turfId ?? this.turfId,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, defaultPrice, isActive, createdByAdmin, createdAt, turfId];
}
