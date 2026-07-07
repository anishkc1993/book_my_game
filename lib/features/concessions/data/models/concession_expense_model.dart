import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/concession_expense_entity.dart';

class ConcessionExpenseModel extends ConcessionExpenseEntity {
  const ConcessionExpenseModel({
    super.id,
    required super.itemName,
    required super.quantity,
    required super.amount,
    required super.spentAt,
    super.markedBy,
    super.notes,
    super.turfId,
  });

  factory ConcessionExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConcessionExpenseModel(
      id: doc.id,
      itemName: data['itemName'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      spentAt: (data['spentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      markedBy: data['markedBy'] as String?,
      notes: data['notes'] as String?,
      turfId: data['turfId'] as String?,
    );
  }

  factory ConcessionExpenseModel.fromEntity(ConcessionExpenseEntity e) {
    return ConcessionExpenseModel(
      id: e.id,
      itemName: e.itemName,
      quantity: e.quantity,
      amount: e.amount,
      spentAt: e.spentAt,
      markedBy: e.markedBy,
      notes: e.notes,
      turfId: e.turfId,
    );
  }

  Map<String, dynamic> toFirestore({bool includeServerTimestamp = false}) {
    final map = <String, dynamic>{
      'itemName': itemName,
      'quantity': quantity,
      'amount': amount,
      'markedBy': markedBy,
      'notes': notes,
      'turfId': turfId,
    };
    if (includeServerTimestamp) {
      map['spentAt'] = FieldValue.serverTimestamp();
    } else {
      map['spentAt'] = Timestamp.fromDate(spentAt);
    }
    return map;
  }
}
