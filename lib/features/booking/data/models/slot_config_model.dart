import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/slot_config_entity.dart';

class SlotConfigModel extends SlotConfigEntity {
  const SlotConfigModel({
    required super.enabledHours,
    super.morningPrice = 1000.0,
    super.dayPrice = 1000.0,
    super.eveningPrice = 1200.0,
    super.weekendPrice = 1500.0,
    super.updatedAt,
    super.updatedBy,
    super.freeGameThreshold = 0,
  });

  factory SlotConfigModel.fromEntity(SlotConfigEntity entity) {
    return SlotConfigModel(
      enabledHours: entity.enabledHours,
      morningPrice: entity.morningPrice,
      dayPrice: entity.dayPrice,
      eveningPrice: entity.eveningPrice,
      weekendPrice: entity.weekendPrice,
      updatedAt: entity.updatedAt,
      updatedBy: entity.updatedBy,
      freeGameThreshold: entity.freeGameThreshold,
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
      weekendPrice: (data['weekendPrice'] as num?)?.toDouble() ?? 1500.0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'] as String?,
      freeGameThreshold: (data['freeGameThreshold'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'enabledHours': enabledHours,
      'morningPrice': morningPrice,
      'dayPrice': dayPrice,
      'eveningPrice': eveningPrice,
      'weekendPrice': weekendPrice,
      'freeGameThreshold': freeGameThreshold,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  SlotConfigModel copyWith({
    List<int>? enabledHours,
    double? morningPrice,
    double? dayPrice,
    double? eveningPrice,
    double? weekendPrice,
    DateTime? updatedAt,
    String? updatedBy,
    int? freeGameThreshold,
  }) {
    return SlotConfigModel(
      enabledHours: enabledHours ?? this.enabledHours,
      morningPrice: morningPrice ?? this.morningPrice,
      dayPrice: dayPrice ?? this.dayPrice,
      eveningPrice: eveningPrice ?? this.eveningPrice,
      weekendPrice: weekendPrice ?? this.weekendPrice,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      freeGameThreshold: freeGameThreshold ?? this.freeGameThreshold,
    );
  }
}
