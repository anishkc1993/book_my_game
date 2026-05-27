import '../entities/turf_entity.dart';

abstract class TurfRepository {
  /// List all active turfs (for customer selection).
  Future<List<TurfEntity>> listActiveTurfs();

  /// Get a turf by id.
  Future<TurfEntity?> getTurf(String id);

  /// Lookup a turf where adminPhone matches the given phone. Used to resolve
  /// the turf an admin user manages.
  Future<TurfEntity?> findTurfByAdminPhone(String phone);

  /// Create a new turf (used by admin registration / seed).
  Future<TurfEntity> createTurf({
    required String name,
    required String adminPhone,
    String? address,
  });

  /// Update venue location details (admin only).
  Future<void> updateVenueDetails({
    required String turfId,
    String? venueName,
    String? street,
    String? cityArea,
    String? landmark,
    double? latitude,
    double? longitude,
    String? shareSlug,
  });
}
