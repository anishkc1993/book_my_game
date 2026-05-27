import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/turf_entity.dart';

class TurfModel extends TurfEntity {
  const TurfModel({
    required super.id,
    required super.name,
    required super.adminPhone,
    super.address,
    super.isActive,
    super.createdAt,
    super.venueName,
    super.street,
    super.cityArea,
    super.landmark,
    super.latitude,
    super.longitude,
    super.shareSlug,
  });

  factory TurfModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TurfModel(
      id: doc.id,
      name: data['name'] as String,
      adminPhone: data['adminPhone'] as String,
      address: data['address'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      venueName: data['venueName'] as String?,
      street: data['street'] as String?,
      cityArea: data['cityArea'] as String?,
      landmark: data['landmark'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      shareSlug: data['shareSlug'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'adminPhone': adminPhone,
      'address': address,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
