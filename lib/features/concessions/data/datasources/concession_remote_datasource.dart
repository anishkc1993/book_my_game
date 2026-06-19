import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/concession_item_model.dart';
import '../models/concession_sale_model.dart';

abstract class ConcessionRemoteDataSource {
  Future<List<ConcessionItemModel>> listItems(String turfId);
  Future<ConcessionItemModel> upsertItem(ConcessionItemModel item);
  Future<void> deleteItem(String turfId, String itemId);

  Future<ConcessionSaleModel> recordSale(ConcessionSaleModel sale);
  Future<List<ConcessionSaleModel>> listSales(
    String turfId, {
    DateTime? since,
    int limit = 100,
  });
  Future<void> deleteSale(String turfId, String saleId);

  Future<double> sumSalesBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  });

  /// Raw sales between [start] (inclusive) and [end] (exclusive),
  /// newest first. Used by the history page.
  Future<List<ConcessionSaleModel>> listSalesBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  });
}

class ConcessionRemoteDataSourceImpl implements ConcessionRemoteDataSource {
  final FirebaseFirestore _firestore;

  ConcessionRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _itemsCol(String turfId) =>
      _firestore
          .collection('turfs')
          .doc(turfId)
          .collection('concession_items');

  CollectionReference<Map<String, dynamic>> _salesCol(String turfId) =>
      _firestore
          .collection('turfs')
          .doc(turfId)
          .collection('concession_sales');

  // ── Items ────────────────────────────────────────────────────────────────
  @override
  Future<List<ConcessionItemModel>> listItems(String turfId) async {
    try {
      final snap = await _itemsCol(turfId).get();
      final list = snap.docs
          .map((d) => ConcessionItemModel.fromFirestore(d))
          .toList();
      // Active first, then alphabetical — stable order.
      list.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    } catch (e) {
      debugPrint('❌ Concession.listItems: $e');
      throw ServerException('Failed to load items: ${e.toString()}');
    }
  }

  @override
  Future<ConcessionItemModel> upsertItem(ConcessionItemModel item) async {
    try {
      if (item.turfId == null || item.turfId!.isEmpty) {
        throw const ServerException('Missing turf for concession item');
      }
      if (item.id == null) {
        final ref = await _itemsCol(item.turfId!)
            .add(item.toFirestore(includeServerTimestamp: true));
        return ConcessionItemModel(
          id: ref.id,
          name: item.name,
          defaultPrice: item.defaultPrice,
          isActive: item.isActive,
          createdByAdmin: item.createdByAdmin,
          createdAt: DateTime.now(),
          turfId: item.turfId,
        );
      } else {
        await _itemsCol(item.turfId!).doc(item.id).set(
              item.toFirestore(),
              SetOptions(merge: true),
            );
        return item;
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to save item: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteItem(String turfId, String itemId) async {
    try {
      // Soft-delete so historical sales referencing the item still resolve.
      await _itemsCol(turfId).doc(itemId).update({'isActive': false});
    } catch (e) {
      throw ServerException('Failed to delete item: ${e.toString()}');
    }
  }

  // ── Sales ────────────────────────────────────────────────────────────────
  @override
  Future<ConcessionSaleModel> recordSale(ConcessionSaleModel sale) async {
    try {
      if (sale.turfId == null || sale.turfId!.isEmpty) {
        throw const ServerException('Missing turf for sale');
      }
      final ref = await _salesCol(sale.turfId!)
          .add(sale.toFirestore(includeServerTimestamp: true));
      return ConcessionSaleModel(
        id: ref.id,
        itemId: sale.itemId,
        itemName: sale.itemName,
        quantity: sale.quantity,
        amount: sale.amount,
        soldAt: DateTime.now(),
        markedBy: sale.markedBy,
        notes: sale.notes,
        turfId: sale.turfId,
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to record sale: ${e.toString()}');
    }
  }

  @override
  Future<List<ConcessionSaleModel>> listSales(
    String turfId, {
    DateTime? since,
    int limit = 100,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _salesCol(turfId)
          .orderBy('soldAt', descending: true)
          .limit(limit);
      if (since != null) {
        q = q.where('soldAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(since));
      }
      final snap = await q.get();
      return snap.docs
          .map((d) => ConcessionSaleModel.fromFirestore(d))
          .toList();
    } catch (e) {
      debugPrint('❌ Concession.listSales: $e');
      throw ServerException('Failed to load sales: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteSale(String turfId, String saleId) async {
    try {
      await _salesCol(turfId).doc(saleId).delete();
    } catch (e) {
      throw ServerException('Failed to delete sale: ${e.toString()}');
    }
  }

  @override
  Future<double> sumSalesBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final snap = await _salesCol(turfId)
          .where('soldAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('soldAt', isLessThan: Timestamp.fromDate(end))
          .get();
      double total = 0;
      for (final d in snap.docs) {
        total += (d.data()['amount'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (e) {
      debugPrint('❌ Concession.sumSalesBetween: $e');
      return 0;
    }
  }

  @override
  Future<List<ConcessionSaleModel>> listSalesBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final snap = await _salesCol(turfId)
          .where('soldAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('soldAt', isLessThan: Timestamp.fromDate(end))
          .orderBy('soldAt', descending: true)
          .get();
      return snap.docs
          .map((d) => ConcessionSaleModel.fromFirestore(d))
          .toList();
    } catch (e) {
      debugPrint('❌ Concession.listSalesBetween: $e');
      throw ServerException('Failed to load sales: ${e.toString()}');
    }
  }
}
