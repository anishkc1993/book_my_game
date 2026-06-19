import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/squad_entity.dart';

class SquadModel extends SquadEntity {
  const SquadModel({
    super.id,
    required super.name,
    required super.shortLabel,
    super.description,
    super.daysOfWeek,
    super.startMinutes,
    super.endMinutes,
    super.coachName,
    super.isActive,
    super.createdAt,
  });

  factory SquadModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SquadModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      shortLabel: data['shortLabel'] as String? ?? '',
      description: data['description'] as String?,
      daysOfWeek:
          (data['daysOfWeek'] as List<dynamic>?)?.cast<int>() ?? const [],
      startMinutes: (data['startMinutes'] as num?)?.toInt(),
      endMinutes: (data['endMinutes'] as num?)?.toInt(),
      coachName: data['coachName'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory SquadModel.fromEntity(SquadEntity e) {
    return SquadModel(
      id: e.id,
      name: e.name,
      shortLabel: e.shortLabel,
      description: e.description,
      daysOfWeek: e.daysOfWeek,
      startMinutes: e.startMinutes,
      endMinutes: e.endMinutes,
      coachName: e.coachName,
      isActive: e.isActive,
      createdAt: e.createdAt,
    );
  }

  Map<String, dynamic> toFirestore({bool includeServerTimestamp = false}) {
    final map = <String, dynamic>{
      'name': name,
      'shortLabel': shortLabel,
      'description': description,
      'daysOfWeek': daysOfWeek,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'coachName': coachName,
      'isActive': isActive,
    };
    if (includeServerTimestamp) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }
}
