import '../../domain/entities/turf_entity.dart';
import '../../domain/repositories/turf_repository.dart';
import '../datasources/turf_remote_datasource.dart';

class TurfRepositoryImpl implements TurfRepository {
  final TurfRemoteDataSource _remote;

  TurfRepositoryImpl({required TurfRemoteDataSource remoteDataSource})
      : _remote = remoteDataSource;

  @override
  Future<List<TurfEntity>> listActiveTurfs() => _remote.listActiveTurfs();

  @override
  Future<TurfEntity?> getTurf(String id) => _remote.getTurf(id);

  @override
  Future<TurfEntity?> findTurfByAdminPhone(String phone) =>
      _remote.findTurfByAdminPhone(phone);

  @override
  Future<TurfEntity> createTurf({
    required String name,
    required String adminPhone,
    String? address,
  }) =>
      _remote.createTurf(
          name: name, adminPhone: adminPhone, address: address);

  @override
  Future<void> updateVenueDetails({
    required String turfId,
    String? venueName,
    String? street,
    String? cityArea,
    String? landmark,
    double? latitude,
    double? longitude,
    String? shareSlug,
  }) =>
      _remote.updateVenueDetails(
        turfId: turfId,
        venueName: venueName,
        street: street,
        cityArea: cityArea,
        landmark: landmark,
        latitude: latitude,
        longitude: longitude,
        shareSlug: shareSlug,
      );
}
