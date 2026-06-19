import '../../domain/entities/concession_item_entity.dart';
import '../../domain/entities/concession_sale_entity.dart';
import '../../domain/repositories/concession_repository.dart';
import '../datasources/concession_remote_datasource.dart';
import '../models/concession_item_model.dart';
import '../models/concession_sale_model.dart';

class ConcessionRepositoryImpl implements ConcessionRepository {
  final ConcessionRemoteDataSource remoteDataSource;
  ConcessionRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<ConcessionItemEntity>> listItems(String turfId) async {
    final models = await remoteDataSource.listItems(turfId);
    return List<ConcessionItemEntity>.from(models);
  }

  @override
  Future<ConcessionItemEntity> upsertItem(ConcessionItemEntity item) =>
      remoteDataSource.upsertItem(ConcessionItemModel.fromEntity(item));

  @override
  Future<void> deleteItem(String turfId, String itemId) =>
      remoteDataSource.deleteItem(turfId, itemId);

  @override
  Future<ConcessionSaleEntity> recordSale(ConcessionSaleEntity sale) =>
      remoteDataSource.recordSale(ConcessionSaleModel.fromEntity(sale));

  @override
  Future<List<ConcessionSaleEntity>> listSales(
    String turfId, {
    DateTime? since,
    int limit = 100,
  }) async {
    final models = await remoteDataSource.listSales(turfId,
        since: since, limit: limit);
    return List<ConcessionSaleEntity>.from(models);
  }

  @override
  Future<void> deleteSale(String turfId, String saleId) =>
      remoteDataSource.deleteSale(turfId, saleId);

  @override
  Future<double> sumSalesBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  }) =>
      remoteDataSource.sumSalesBetween(
        turfId: turfId,
        start: start,
        end: end,
      );

  @override
  Future<List<ConcessionSaleEntity>> listSalesBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  }) async {
    final models = await remoteDataSource.listSalesBetween(
      turfId: turfId,
      start: start,
      end: end,
    );
    return List<ConcessionSaleEntity>.from(models);
  }
}
