import '../entities/concession_item_entity.dart';
import '../entities/concession_sale_entity.dart';

abstract class ConcessionRepository {
  // Catalog
  Future<List<ConcessionItemEntity>> listItems(String turfId);
  Future<ConcessionItemEntity> upsertItem(ConcessionItemEntity item);
  Future<void> deleteItem(String turfId, String itemId);

  // Sales
  Future<ConcessionSaleEntity> recordSale(ConcessionSaleEntity sale);
  Future<List<ConcessionSaleEntity>> listSales(
    String turfId, {
    DateTime? since,
    int limit = 100,
  });
  Future<void> deleteSale(String turfId, String saleId);

  /// Sum of all sale amounts at [turfId] with `soldAt` in [start, end).
  /// Used by analytics + admin home for the separate concession revenue.
  Future<double> sumSalesBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  });

  /// All sales between [start] (inclusive) and [end] (exclusive),
  /// newest first. Used by the cafe history page.
  Future<List<ConcessionSaleEntity>> listSalesBetween({
    required String turfId,
    required DateTime start,
    required DateTime end,
  });
}
