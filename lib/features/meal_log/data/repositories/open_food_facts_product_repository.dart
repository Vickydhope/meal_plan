import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/meal_analysis_item.dart';
import '../../domain/entities/pending_meal_analysis.dart';
import '../../domain/repositories/product_repository.dart';

/// Barcode lookup against Open Food Facts' public product API — free, no
/// key, called straight from the client like any other public read.
class OpenFoodFactsProductRepository implements ProductRepository {
  OpenFoodFactsProductRepository(this._client);

  final http.Client _client;

  static const _fields =
      'product_name,brands,nutriments,serving_quantity,nutriscore_grade';

  /// EAN-8/13, UPC-A/E and ITF-14 are all 8–14 digits; anything else can't
  /// be a product code (and never reaches the URL path).
  static final _validBarcode = RegExp(r'^\d{8,14}$');

  @override
  Future<MealAnalysisResult?> findByBarcode(String barcode) async {
    if (!_validBarcode.hasMatch(barcode)) return null;

    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.https(
              'world.openfoodfacts.org',
              '/api/v2/product/$barcode.json',
              {'fields': _fields},
            ),
            // Open Food Facts asks apps to identify themselves.
            headers: {'User-Agent': 'Cravia/1.0 (Flutter app)'},
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const FoodAnalysisException(
        "Couldn't reach the product database. Check your connection.",
      );
    }

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw const FoodAnalysisException(
        "Couldn't look up this product. Try again.",
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final product = body['product'];
    if (body['status'] != 1 || product is! Map<String, dynamic>) return null;
    return resultFromProduct(product);
  }

  /// Maps an Open Food Facts `product` object to one ingredient sized to a
  /// single serving (100 g when the package doesn't state one), so the
  /// review screen's portion slider scales from "one serving".
  static MealAnalysisResult resultFromProduct(Map<String, dynamic> product) {
    final nutriments =
        (product['nutriments'] as Map?)?.cast<String, dynamic>() ?? const {};
    double? per100g(String key) => _number(nutriments['${key}_100g']);

    // Some products only list energy in kJ.
    final kcal100 =
        per100g('energy-kcal') ??
        switch (per100g('energy')) {
          final kj? => kj / 4.184,
          null => null,
        };
    if (kcal100 == null) {
      throw const FoodAnalysisException(
        "This product has no nutrition facts listed. Try a photo instead.",
      );
    }

    final servingG = switch (_number(product['serving_quantity'])) {
      final g? when g > 0 => g,
      _ => 100.0,
    };
    final scale = servingG / 100;
    final name = switch ((product['product_name'] as String?)?.trim()) {
      final n? when n.isNotEmpty => n,
      _ => 'Scanned product',
    };
    final brand = (product['brands'] as String?)?.split(',').first.trim();

    return MealAnalysisResult(
      mealName: name,
      healthScore: switch (product['nutriscore_grade']) {
        'a' => 9,
        'b' => 7,
        'c' => 5,
        'd' => 3,
        'e' => 2,
        _ => 5,
      },
      items: [
        MealAnalysisItem(
          foodName: brand == null || brand.isEmpty ? name : '$name ($brand)',
          estimatedWeightG: servingG,
          calories: kcal100 * scale,
          proteinG: (per100g('proteins') ?? 0) * scale,
          carbsG: (per100g('carbohydrates') ?? 0) * scale,
          fatsG: (per100g('fat') ?? 0) * scale,
        ),
      ],
    );
  }

  /// Open Food Facts mixes numbers and numeric strings.
  static double? _number(Object? value) => switch (value) {
    num n => n.toDouble(),
    String s => double.tryParse(s),
    _ => null,
  };
}
