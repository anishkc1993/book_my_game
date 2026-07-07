import 'package:equatable/equatable.dart';

/// One concession-side expense — items bought to stock the cafe
/// (drinks, snacks, supplies). Tracked separately from sales so net
/// profit can be displayed.
class ConcessionExpenseEntity extends Equatable {
  final String? id;
  final String itemName;
  final int quantity;
  final double amount; // total spent for this purchase line
  final DateTime spentAt;
  final String? markedBy;
  final String? notes;
  final String? turfId;

  const ConcessionExpenseEntity({
    this.id,
    required this.itemName,
    required this.quantity,
    required this.amount,
    required this.spentAt,
    this.markedBy,
    this.notes,
    this.turfId,
  });

  ConcessionExpenseEntity copyWith({
    String? id,
    String? itemName,
    int? quantity,
    double? amount,
    DateTime? spentAt,
    String? markedBy,
    String? notes,
    String? turfId,
  }) {
    return ConcessionExpenseEntity(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      amount: amount ?? this.amount,
      spentAt: spentAt ?? this.spentAt,
      markedBy: markedBy ?? this.markedBy,
      notes: notes ?? this.notes,
      turfId: turfId ?? this.turfId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        itemName,
        quantity,
        amount,
        spentAt,
        markedBy,
        notes,
        turfId,
      ];
}
