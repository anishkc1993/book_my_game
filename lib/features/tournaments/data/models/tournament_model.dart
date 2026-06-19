import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tournament_entity.dart';

class TournamentModel extends TournamentEntity {
  const TournamentModel({
    super.id,
    required super.name,
    required super.organizerName,
    required super.organizerPhone,
    required super.dates,
    required super.startHour,
    required super.endHour,
    required super.totalAmount,
    super.isPaid = false,
    super.amountPaid,
    super.paidAt,
    super.notes,
    super.createdByAdmin,
    super.createdAt,
    super.turfId,
  });

  factory TournamentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawDates = data['dates'] as List<dynamic>? ?? const [];
    final dates = <DateTime>[
      for (final v in rawDates)
        if (v is Timestamp) v.toDate(),
    ];
    return TournamentModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      organizerName: data['organizerName'] as String? ?? '',
      organizerPhone: data['organizerPhone'] as String? ?? '',
      dates: dates,
      startHour: (data['startHour'] as num?)?.toInt() ?? 0,
      endHour: (data['endHour'] as num?)?.toInt() ?? 0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      isPaid: data['isPaid'] as bool? ?? false,
      amountPaid: (data['amountPaid'] as num?)?.toDouble(),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      notes: data['notes'] as String?,
      createdByAdmin: data['createdByAdmin'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      turfId: data['turfId'] as String?,
    );
  }

  factory TournamentModel.fromEntity(TournamentEntity e) {
    return TournamentModel(
      id: e.id,
      name: e.name,
      organizerName: e.organizerName,
      organizerPhone: e.organizerPhone,
      dates: e.dates,
      startHour: e.startHour,
      endHour: e.endHour,
      totalAmount: e.totalAmount,
      isPaid: e.isPaid,
      amountPaid: e.amountPaid,
      paidAt: e.paidAt,
      notes: e.notes,
      createdByAdmin: e.createdByAdmin,
      createdAt: e.createdAt,
      turfId: e.turfId,
    );
  }

  /// `dateKeys` mirror `dates` as `YYYY-MM-DD` strings — lets us run
  /// efficient "tournaments for date" queries without composite indexes.
  List<String> get dateKeys => [
        for (final d in dates)
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
      ];

  Map<String, dynamic> toFirestore({bool includeServerTimestamp = false}) {
    final map = <String, dynamic>{
      'name': name,
      'organizerName': organizerName,
      'organizerPhone': organizerPhone,
      'dates': [
        for (final d in dates)
          Timestamp.fromDate(DateTime(d.year, d.month, d.day))
      ],
      'dateKeys': dateKeys,
      'startHour': startHour,
      'endHour': endHour,
      'totalAmount': totalAmount,
      'isPaid': isPaid,
      'amountPaid': amountPaid,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'notes': notes,
      'createdByAdmin': createdByAdmin,
      'turfId': turfId,
    };
    if (includeServerTimestamp) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }
}
