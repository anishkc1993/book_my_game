import '../../domain/entities/tournament_entity.dart';
import '../../domain/repositories/tournament_repository.dart';
import '../datasources/tournament_remote_datasource.dart';
import '../models/tournament_model.dart';

class TournamentRepositoryImpl implements TournamentRepository {
  final TournamentRemoteDataSource remoteDataSource;
  TournamentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<TournamentEntity>> list(String turfId) async {
    final models = await remoteDataSource.list(turfId);
    return List<TournamentEntity>.from(models);
  }

  @override
  Future<TournamentEntity> upsert(TournamentEntity tournament) =>
      remoteDataSource.upsert(TournamentModel.fromEntity(tournament));

  @override
  Future<void> delete(String turfId, String tournamentId) =>
      remoteDataSource.delete(turfId, tournamentId);

  @override
  Future<void> markPaid({
    required String turfId,
    required String tournamentId,
    required double amount,
    required String markedBy,
  }) =>
      remoteDataSource.markPaid(
        turfId: turfId,
        tournamentId: tournamentId,
        amount: amount,
        markedBy: markedBy,
      );

  @override
  Future<double> sumPaymentsBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  }) =>
      remoteDataSource.sumPaymentsBetween(
        turfId: turfId,
        start: start,
        end: end,
      );
}
