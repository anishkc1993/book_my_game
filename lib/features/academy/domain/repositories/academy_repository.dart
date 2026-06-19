import '../entities/academy_player_entity.dart';
import '../entities/squad_entity.dart';

abstract class AcademyRepository {
  // Squads
  Future<List<SquadEntity>> listSquads(String turfId);
  Future<SquadEntity> upsertSquad(String turfId, SquadEntity squad);
  Future<void> deleteSquad(String turfId, String squadId);

  // Players
  Future<List<AcademyPlayerEntity>> listPlayers(String turfId);
  Future<AcademyPlayerEntity> upsertPlayer(
      String turfId, AcademyPlayerEntity player);
  Future<void> deletePlayer(String turfId, String playerId);

  /// Mark this player's fee for the given month (`YYYY-MM`) as paid.
  /// Updates `lastPaidMonth` on the player doc and records a payment row.
  Future<void> markFeePaid({
    required String turfId,
    required String playerId,
    required String month,
    required double amount,
    required String markedBy,
  });
}
