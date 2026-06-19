import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/concession_sale_entity.dart';

class ConcessionSaleModel extends ConcessionSaleEntity {
  const ConcessionSaleModel({
    super.id,
    super.itemId,
    required super.itemName,
    required super.quantity,
    required super.amount,
    required super.soldAt,
    super.markedBy,
    super.notes,
    super.turfId,
  });

  factory ConcessionSaleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConcessionSaleModel(
      id: doc.id,
      itemId: data['itemId'] as String?,
      itemName: data['itemName'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      soldAt: (data['soldAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      markedBy: data['markedBy'] as String?,
      notes: data['notes'] as String?,
      turfId: data['turfId'] as String?,
    );
  }

  factory ConcessionSaleModel.fromEntity(ConcessionSaleEntity e) {
    return ConcessionSaleModel(
      id: e.id,
      itemId: e.itemId,
      itemName: e.itemName,
      quantity: e.quantity,
      amount: e.amount,
      soldAt: e.soldAt,
      markedBy: e.markedBy,
      notes: e.notes,
      turfId: e.turfId,
    );
  }

  Map<String, dynamic> toFirestore({bool includeServerTimestamp = false}) {
    final map = <String, dynamic>{
      'itemId': itemId,
      'itemName': itemName,
      'quantity': quantity,
      'amount': amount,
      'markedBy': markedBy,
      'notes': notes,
      'turfId': turfId,
    };
    if (includeServerTimestamp) {
      map['soldAt'] = FieldValue.serverTimestamp();
    } else {
      map['soldAt'] = Timestamp.fromDate(soldAt);
    }
    return map;
  }
}
