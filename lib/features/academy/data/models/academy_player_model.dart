import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/academy_player_entity.dart';

class AcademyPlayerModel extends AcademyPlayerEntity {
  const AcademyPlayerModel({
    super.id,
    required super.name,
    super.dob,
    super.parentPhone,
    super.position,
    super.skillLevel,
    super.photoUrl,
    super.monthlyFee,
    super.enrolledAt,
    super.isActive,
    super.lastPaidMonth,
    super.squadId,
  });

  factory AcademyPlayerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AcademyPlayerModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      dob: (data['dob'] as Timestamp?)?.toDate(),
      parentPhone: data['parentPhone'] as String?,
      position: data['position'] as String?,
      skillLevel: (data['skillLevel'] as num?)?.toInt() ?? 1,
      photoUrl: data['photoUrl'] as String?,
      monthlyFee: (data['monthlyFee'] as num?)?.toDouble() ?? 0,
      enrolledAt: (data['enrolledAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] as bool? ?? true,
      lastPaidMonth: data['lastPaidMonth'] as String?,
      squadId: data['squadId'] as String?,
    );
  }

  factory AcademyPlayerModel.fromEntity(AcademyPlayerEntity e) {
    return AcademyPlayerModel(
      id: e.id,
      name: e.name,
      dob: e.dob,
      parentPhone: e.parentPhone,
      position: e.position,
      skillLevel: e.skillLevel,
      photoUrl: e.photoUrl,
      monthlyFee: e.monthlyFee,
      enrolledAt: e.enrolledAt,
      isActive: e.isActive,
      lastPaidMonth: e.lastPaidMonth,
      squadId: e.squadId,
    );
  }

  Map<String, dynamic> toFirestore({bool includeServerTimestamp = false}) {
    final map = <String, dynamic>{
      'name': name,
      'dob': dob == null ? null : Timestamp.fromDate(dob!),
      'parentPhone': parentPhone,
      'position': position,
      'skillLevel': skillLevel,
      'photoUrl': photoUrl,
      'monthlyFee': monthlyFee,
      'isActive': isActive,
      'lastPaidMonth': lastPaidMonth,
      'squadId': squadId,
    };
    if (includeServerTimestamp) {
      map['enrolledAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }
}
