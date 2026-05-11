import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/slot_config_entity.dart';

class SlotConfigModel extends SlotConfigEntity {
  const SlotConfigModel({
    required super.enabledHours,
    super.updatedAt,
    super.updatedBy,
  });

  factory SlotConfigModel.fromEntity(SlotConfigEntity entity) {
    return SlotConfigModel(
      enabledHours: entity.enabledHours,
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
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'enabledHours': enabledHours,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  SlotConfigModel copyWith({
    List<int>? enabledHours,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return SlotConfigModel(
      enabledHours: enabledHours ?? this.enabledHours,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
