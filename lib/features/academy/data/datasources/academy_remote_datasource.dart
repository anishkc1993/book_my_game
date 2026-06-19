import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/academy_player_model.dart';
import '../models/squad_model.dart';

abstract class AcademyRemoteDataSource {
  Future<List<SquadModel>> listSquads(String turfId);
  Future<SquadModel> upsertSquad(String turfId, SquadModel squad);
  Future<void> deleteSquad(String turfId, String squadId);

  Future<List<AcademyPlayerModel>> listPlayers(String turfId);
  Future<AcademyPlayerModel> upsertPlayer(
      String turfId, AcademyPlayerModel player);
  Future<void> deletePlayer(String turfId, String playerId);

  Future<void> markFeePaid({
    required String turfId,
    required String playerId,
    required String month,
    required double amount,
    required String markedBy,
  });
}

class AcademyRemoteDataSourceImpl implements AcademyRemoteDataSource {
  final FirebaseFirestore _firestore;
  AcademyRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _squadsCol(String turfId) =>
      _firestore
          .collection('turfs')
          .doc(turfId)
          .collection('academy')
          .doc('data')
          .collection('squads');

  CollectionReference<Map<String, dynamic>> _playersCol(String turfId) =>
      _firestore
          .collection('turfs')
          .doc(turfId)
          .collection('academy')
          .doc('data')
          .collection('players');

  CollectionReference<Map<String, dynamic>> _paymentsCol(String turfId) =>
      _firestore
          .collection('turfs')
          .doc(turfId)
          .collection('academy')
          .doc('data')
          .collection('payments');

  // ── Squads ────────────────────────────────────────────────────────────────
  @override
  Future<List<SquadModel>> listSquads(String turfId) async {
    try {
      final snap =
          await _squadsCol(turfId).where('isActive', isEqualTo: true).get();
      final list = snap.docs.map((d) => SquadModel.fromFirestore(d)).toList();
      list.sort((a, b) => a.shortLabel.compareTo(b.shortLabel));
      return list;
    } catch (e) {
      debugPrint('❌ listSquads: $e');
      throw ServerException('Failed to load squads: ${e.toString()}');
    }
  }

  @override
  Future<SquadModel> upsertSquad(String turfId, SquadModel squad) async {
    try {
      if (squad.id == null) {
        final docRef = await _squadsCol(turfId)
            .add(squad.toFirestore(includeServerTimestamp: true));
        return SquadModel.fromEntity(squad.copyWith(
          id: docRef.id,
          createdAt: DateTime.now(),
        ));
      } else {
        await _squadsCol(turfId).doc(squad.id).set(
              squad.toFirestore(),
              SetOptions(merge: true),
            );
        return squad;
      }
    } catch (e) {
      debugPrint('❌ upsertSquad: $e');
      throw ServerException('Failed to save squad: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteSquad(String turfId, String squadId) async {
    try {
      // Soft-delete so existing players keep their reference.
      await _squadsCol(turfId).doc(squadId).update({'isActive': false});
    } catch (e) {
      throw ServerException('Failed to delete squad: ${e.toString()}');
    }
  }

  // ── Players ───────────────────────────────────────────────────────────────
  @override
  Future<List<AcademyPlayerModel>> listPlayers(String turfId) async {
    try {
      final snap =
          await _playersCol(turfId).where('isActive', isEqualTo: true).get();
      final list = snap.docs
          .map((d) => AcademyPlayerModel.fromFirestore(d))
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    } catch (e) {
      debugPrint('❌ listPlayers: $e');
      throw ServerException('Failed to load players: ${e.toString()}');
    }
  }

  @override
  Future<AcademyPlayerModel> upsertPlayer(
      String turfId, AcademyPlayerModel player) async {
    try {
      if (player.id == null) {
        final docRef = await _playersCol(turfId)
            .add(player.toFirestore(includeServerTimestamp: true));
        return AcademyPlayerModel.fromEntity(player.copyWith(
          id: docRef.id,
          enrolledAt: DateTime.now(),
        ));
      } else {
        await _playersCol(turfId).doc(player.id).set(
              player.toFirestore(),
              SetOptions(merge: true),
            );
        return player;
      }
    } catch (e) {
      debugPrint('❌ upsertPlayer: $e');
      throw ServerException('Failed to save player: ${e.toString()}');
    }
  }

  @override
  Future<void> deletePlayer(String turfId, String playerId) async {
    try {
      await _playersCol(turfId).doc(playerId).update({'isActive': false});
    } catch (e) {
      throw ServerException('Failed to delete player: ${e.toString()}');
    }
  }

  @override
  Future<void> markFeePaid({
    required String turfId,
    required String playerId,
    required String month,
    required double amount,
    required String markedBy,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.update(_playersCol(turfId).doc(playerId), {
        'lastPaidMonth': month,
      });
      batch.set(_paymentsCol(turfId).doc(), {
        'playerId': playerId,
        'month': month,
        'amount': amount,
        'paidAt': FieldValue.serverTimestamp(),
        'markedBy': markedBy,
      });
      await batch.commit();
    } catch (e) {
      throw ServerException('Failed to mark fee paid: ${e.toString()}');
    }
  }
}
