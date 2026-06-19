import 'package:equatable/equatable.dart';

/// One concession sale — admin records this after the customer pays.
/// [itemName] is denormalized so historical sales survive item renames /
/// deletions; [itemId] still links back to the catalog when present.
class ConcessionSaleEntity extends Equatable {
  final String? id;
  final String? itemId;
  final String itemName;
  final int quantity;
  final double amount;
  final DateTime soldAt;
  final String? markedBy;
  final String? notes;
  final String? turfId;

  const ConcessionSaleEntity({
    this.id,
    this.itemId,
    required this.itemName,
    required this.quantity,
    required this.amount,
    required this.soldAt,
    this.markedBy,
    this.notes,
    this.turfId,
  });

  ConcessionSaleEntity copyWith({
    String? id,
    String? itemId,
    String? itemName,
    int? quantity,
    double? amount,
    DateTime? soldAt,
    String? markedBy,
    String? notes,
    String? turfId,
  }) {
    return ConcessionSaleEntity(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      amount: amount ?? this.amount,
      soldAt: soldAt ?? this.soldAt,
      markedBy: markedBy ?? this.markedBy,
      notes: notes ?? this.notes,
      turfId: turfId ?? this.turfId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        itemId,
        itemName,
        quantity,
        amount,
        soldAt,
        markedBy,
        notes,
        turfId,
      ];
}
