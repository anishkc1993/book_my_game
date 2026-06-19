import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/concession_item_entity.dart';

class ConcessionItemModel extends ConcessionItemEntity {
  const ConcessionItemModel({
    super.id,
    required super.name,
    required super.defaultPrice,
    super.isActive,
    super.createdByAdmin,
    super.createdAt,
    super.turfId,
  });

  factory ConcessionItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConcessionItemModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      defaultPrice: (data['defaultPrice'] as num?)?.toDouble() ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdByAdmin: data['createdByAdmin'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      turfId: data['turfId'] as String?,
    );
  }

  factory ConcessionItemModel.fromEntity(ConcessionItemEntity e) {
    return ConcessionItemModel(
      id: e.id,
      name: e.name,
      defaultPrice: e.defaultPrice,
      isActive: e.isActive,
      createdByAdmin: e.createdByAdmin,
      createdAt: e.createdAt,
      turfId: e.turfId,
    );
  }

  Map<String, dynamic> toFirestore({bool includeServerTimestamp = false}) {
    final map = <String, dynamic>{
      'name': name,
      'defaultPrice': defaultPrice,
      'isActive': isActive,
      'createdByAdmin': createdByAdmin,
      'turfId': turfId,
    };
    if (includeServerTimestamp) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }
}
