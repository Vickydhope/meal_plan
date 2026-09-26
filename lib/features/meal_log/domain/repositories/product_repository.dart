import '../entities/pending_meal_analysis.dart';

/// Packaged-food lookup by barcode.
abstract class ProductRepository {
  /// The product with [barcode] as a one-ingredient analysis sized to one
  /// serving, or `null` if no product has that barcode. Throws a
  /// [FoodAnalysisException] with a user-facing message if the product is
  /// found but can't be used (e.g. it has no nutrition facts).
  Future<MealAnalysisResult?> findByBarcode(String barcode);
}
