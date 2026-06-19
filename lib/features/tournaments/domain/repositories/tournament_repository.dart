import '../entities/tournament_entity.dart';

abstract class TournamentRepository {
  Future<List<TournamentEntity>> list(String turfId);
  Future<TournamentEntity> upsert(TournamentEntity tournament);
  Future<void> delete(String turfId, String tournamentId);

  /// Mark the lump-sum payment received. Stamps `isPaid`, `amountPaid`,
  /// `paidAt` on the tournament doc and records a payment row.
  Future<void> markPaid({
    required String turfId,
    required String tournamentId,
    required double amount,
    required String markedBy,
  });

  /// Sum of tournament payments at [turfId] whose `paidAt` is within
  /// [start, end). Used by analytics to fold tournament revenue in.
  Future<double> sumPaymentsBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  });
}
