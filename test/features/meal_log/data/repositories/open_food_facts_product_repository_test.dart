import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meal_plan/core/error/app_exception.dart';
import 'package:meal_plan/features/meal_log/data/repositories/open_food_facts_product_repository.dart';

void main() {
  group('resultFromProduct', () {
    test('sizes the item to one serving and names it with its brand', () {
      final result = OpenFoodFactsProductRepository.resultFromProduct({
        'product_name': 'Greek Yogurt',
        'brands': 'Fage, Total',
        'serving_quantity': '150',
        'nutriscore_grade': 'a',
        'nutriments': {
          'energy-kcal_100g': 100,
          'proteins_100g': 10,
          'carbohydrates_100g': 4,
          'fat_100g': 5,
        },
      });

      expect(result.mealName, 'Greek Yogurt');
      expect(result.healthScore, 9);
      final item = result.items.single;
      expect(item.foodName, 'Greek Yogurt (Fage)');
      expect(item.estimatedWeightG, 150);
      expect(item.calories, 150);
      expect(item.proteinG, 15);
      expect(item.carbsG, closeTo(6, 1e-9));
      expect(item.fatsG, 7.5);
    });

    test('falls back to 100 g, kJ energy and a generic name', () {
      final item = OpenFoodFactsProductRepository.resultFromProduct({
        'nutriments': {'energy_100g': 418.4},
      }).items.single;

      expect(item.foodName, 'Scanned product');
      expect(item.estimatedWeightG, 100);
      expect(item.calories, closeTo(100, 1e-9));
      expect(item.proteinG, 0);
    });

    test('rejects a product without nutrition facts', () {
      expect(
        () => OpenFoodFactsProductRepository.resultFromProduct({
          'product_name': 'Mystery',
        }),
        throwsA(isA<FoodAnalysisException>()),
      );
    });
  });

  group('findByBarcode', () {
    test('returns null for an unknown product (status 0 or 404)', () async {
      for (final response in [
        http.Response(jsonEncode({'status': 0}), 200),
        http.Response('', 404),
      ]) {
        final repo = OpenFoodFactsProductRepository(
          MockClient((_) async => response),
        );
        expect(await repo.findByBarcode('3017620422003'), isNull);
      }
    });

    test('never requests a malformed barcode', () async {
      var requests = 0;
      final repo = OpenFoodFactsProductRepository(
        MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );

      expect(await repo.findByBarcode('../../etc'), isNull);
      expect(await repo.findByBarcode('123'), isNull);
      expect(requests, 0);
    });

    test('a network failure becomes a user-facing error', () async {
      final repo = OpenFoodFactsProductRepository(
        MockClient((_) async => throw http.ClientException('offline')),
      );

      await expectLater(
        repo.findByBarcode('3017620422003'),
        throwsA(isA<FoodAnalysisException>()),
      );
    });
  });
}
