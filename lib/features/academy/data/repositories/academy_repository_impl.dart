import '../../domain/entities/academy_player_entity.dart';
import '../../domain/entities/squad_entity.dart';
import '../../domain/repositories/academy_repository.dart';
import '../datasources/academy_remote_datasource.dart';
import '../models/academy_player_model.dart';
import '../models/squad_model.dart';

class AcademyRepositoryImpl implements AcademyRepository {
  final AcademyRemoteDataSource remoteDataSource;
  AcademyRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<SquadEntity>> listSquads(String turfId) =>
      remoteDataSource.listSquads(turfId);

  @override
  Future<SquadEntity> upsertSquad(String turfId, SquadEntity squad) =>
      remoteDataSource.upsertSquad(turfId, SquadModel.fromEntity(squad));

  @override
  Future<void> deleteSquad(String turfId, String squadId) =>
      remoteDataSource.deleteSquad(turfId, squadId);

  @override
  Future<List<AcademyPlayerEntity>> listPlayers(String turfId) =>
      remoteDataSource.listPlayers(turfId);

  @override
  Future<AcademyPlayerEntity> upsertPlayer(
          String turfId, AcademyPlayerEntity player) =>
      remoteDataSource.upsertPlayer(
          turfId, AcademyPlayerModel.fromEntity(player));

  @override
  Future<void> deletePlayer(String turfId, String playerId) =>
      remoteDataSource.deletePlayer(turfId, playerId);

  @override
  Future<void> markFeePaid({
    required String turfId,
    required String playerId,
    required String month,
    required double amount,
    required String markedBy,
  }) =>
      remoteDataSource.markFeePaid(
        turfId: turfId,
        playerId: playerId,
        month: month,
        amount: amount,
        markedBy: markedBy,
      );
}
