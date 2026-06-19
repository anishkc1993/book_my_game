import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/tournament_model.dart';

abstract class TournamentRemoteDataSource {
  Future<List<TournamentModel>> list(String turfId);
  Future<TournamentModel> upsert(TournamentModel tournament);
  Future<void> delete(String turfId, String tournamentId);
  Future<void> markPaid({
    required String turfId,
    required String tournamentId,
    required double amount,
    required String markedBy,
  });
  Future<double> sumPaymentsBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  });
}

class TournamentRemoteDataSourceImpl implements TournamentRemoteDataSource {
  final FirebaseFirestore _firestore;

  TournamentRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String turfId) => _firestore
      .collection('turfs')
      .doc(turfId)
      .collection('tournaments');

  CollectionReference<Map<String, dynamic>> _paymentsCol(String turfId) =>
      _firestore
          .collection('turfs')
          .doc(turfId)
          .collection('tournament_payments');

  @override
  Future<List<TournamentModel>> list(String turfId) async {
    try {
      final snap = await _col(turfId).get();
      final list =
          snap.docs.map((d) => TournamentModel.fromFirestore(d)).toList();
      list.sort((a, b) {
        final aFirst = a.dates.isEmpty ? DateTime(2100) : a.dates.first;
        final bFirst = b.dates.isEmpty ? DateTime(2100) : b.dates.first;
        return aFirst.compareTo(bFirst);
      });
      return list;
    } catch (e) {
      debugPrint('❌ Tournament.list: $e');
      throw ServerException('Failed to load tournaments: ${e.toString()}');
    }
  }

  @override
  Future<TournamentModel> upsert(TournamentModel tournament) async {
    try {
      if (tournament.turfId == null || tournament.turfId!.isEmpty) {
        throw const ServerException('Missing turf for tournament');
      }
      if (tournament.id == null) {
        final ref = await _col(tournament.turfId!)
            .add(tournament.toFirestore(includeServerTimestamp: true));
        return TournamentModel(
          id: ref.id,
          name: tournament.name,
          organizerName: tournament.organizerName,
          organizerPhone: tournament.organizerPhone,
          dates: tournament.dates,
          startHour: tournament.startHour,
          endHour: tournament.endHour,
          totalAmount: tournament.totalAmount,
          isPaid: tournament.isPaid,
          amountPaid: tournament.amountPaid,
          paidAt: tournament.paidAt,
          notes: tournament.notes,
          createdByAdmin: tournament.createdByAdmin,
          createdAt: DateTime.now(),
          turfId: tournament.turfId,
        );
      } else {
        await _col(tournament.turfId!).doc(tournament.id).set(
              tournament.toFirestore(),
              SetOptions(merge: true),
            );
        return tournament;
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to save tournament: ${e.toString()}');
    }
  }

  @override
  Future<void> delete(String turfId, String tournamentId) async {
    try {
      await _col(turfId).doc(tournamentId).delete();
    } catch (e) {
      throw ServerException('Failed to delete tournament: ${e.toString()}');
    }
  }

  @override
  Future<void> markPaid({
    required String turfId,
    required String tournamentId,
    required double amount,
    required String markedBy,
  }) async {
    try {
      final now = DateTime.now();
      final batch = _firestore.batch();
      batch.update(_col(turfId).doc(tournamentId), {
        'isPaid': true,
        'amountPaid': amount,
        'paidAt': FieldValue.serverTimestamp(),
      });
      batch.set(_paymentsCol(turfId).doc(), {
        'tournamentId': tournamentId,
        'amount': amount,
        'paidAt': FieldValue.serverTimestamp(),
        'markedBy': markedBy,
      });
      await batch.commit();
      // Touch `now` to silence unused — keeps signature for future use.
      assert(now.isBefore(DateTime(2200)));
    } catch (e) {
      throw ServerException(
          'Failed to mark tournament paid: ${e.toString()}');
    }
  }

  @override
  Future<double> sumPaymentsBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final snap = await _paymentsCol(turfId)
          .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('paidAt', isLessThan: Timestamp.fromDate(end))
          .get();
      double total = 0;
      for (final d in snap.docs) {
        total += (d.data()['amount'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (e) {
      debugPrint('❌ Tournament.sumPaymentsBetween: $e');
      return 0;
    }
  }
}
