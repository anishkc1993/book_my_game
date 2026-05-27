import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/slot_config_entity.dart';

class SlotConfigModel extends SlotConfigEntity {
  const SlotConfigModel({
    required super.enabledHours,
    super.morningPrice = 1000.0,
    super.dayPrice = 1000.0,
    super.eveningPrice = 1200.0,
    super.updatedAt,
    super.updatedBy,
  });

  factory SlotConfigModel.fromEntity(SlotConfigEntity entity) {
    return SlotConfigModel(
      enabledHours: entity.enabledHours,
      morningPrice: entity.morningPrice,
      dayPrice: entity.dayPrice,
      eveningPrice: entity.eveningPrice,
      updatedAt: entity.updatedAt,
      updatedBy: entity.updatedBy,
    );
  }

  factory SlotConfigModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return SlotConfigModel.fromEntity(SlotConfigEntity.defaultConfig());
    }

    final enabledHoursRaw = data['enabledHours'] as List<dynamic>?;
    final enabledHours = enabledHoursRaw?.map((e) => e as int).toList() ??
        SlotConfigEntity.allPossibleHours;

    return SlotConfigModel(
      enabledHours: enabledHours,
      morningPrice: (data['morningPrice'] as num?)?.toDouble() ?? 1000.0,
      dayPrice: (data['dayPrice'] as num?)?.toDouble() ?? 1000.0,
      eveningPrice: (data['eveningPrice'] as num?)?.toDouble() ?? 1200.0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'enabledHours': enabledHours,
      'morningPrice': morningPrice,
      'dayPrice': dayPrice,
      'eveningPrice': eveningPrice,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  SlotConfigModel copyWith({
    List<int>? enabledHours,
    double? morningPrice,
    double? dayPrice,
    double? eveningPrice,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return SlotConfigModel(
      enabledHours: enabledHours ?? this.enabledHours,
      morningPrice: morningPrice ?? this.morningPrice,
      dayPrice: dayPrice ?? this.dayPrice,
      eveningPrice: eveningPrice ?? this.eveningPrice,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
