import '../../../../core/error/app_exception.dart';
import '../../domain/entities/meal_log.dart';
import '../../domain/entities/pending_meal_analysis.dart';
import '../../domain/repositories/meal_log_repository.dart';
import '../datasources/meal_log_remote_data_source.dart';
import '../models/meal_analysis_item_dto.dart';
import '../models/meal_log_dto.dart';

class MealLogRepositoryImpl implements MealLogRepository {
  MealLogRepositoryImpl(this._dataSource);

  final MealLogRemoteDataSource _dataSource;

  @override
  Future<List<MealLog>> fetchLogsForDate({
    required String userId,
    required DateTime date,
  }) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    try {
      final rows = await _dataSource.fetchLogsForRange(
        userId: userId,
        start: start,
        end: end,
      );
      return rows.map((row) => MealLogDto.fromMap(row).toEntity()).toList();
    } catch (err) {
      throw MealLogPersistenceException('Failed to load meal logs: $err');
    }
  }

  @override
  Future<MealLog> saveMealLog({
    required String userId,
    required PendingMealAnalysis analysis,
  }) async {
    try {
      final payload = {
        'user_id': userId,
        'image_url': analysis.storagePath,
        'meal_name': analysis.mealName,
        'total_calories': analysis.totalCalories,
        'total_protein': analysis.totalProtein,
        'total_carbs': analysis.totalCarbs,
        'total_fats': analysis.totalFats,
        'health_score': analysis.healthScore,
        'meal_type': analysis.mealType.dbValue,
        'raw_json_data': {
          'items': analysis.items
              .map((item) => MealAnalysisItemDto.fromEntity(item).toMap())
              .toList(),
        },
      };

      final inserted = await _dataSource.insertMealLog(payload);
      return MealLogDto.fromMap(inserted).toEntity();
    } catch (err) {
      throw MealLogPersistenceException('Failed to save meal log: $err');
    }
  }

  @override
  Future<void> deleteMealLog(String logId) async {
    try {
      await _dataSource.deleteMealLog(logId);
    } catch (err) {
      throw MealLogPersistenceException('Failed to delete meal log: $err');
    }
  }

  @override
  Future<void> restoreMealLog(String logId) async {
    try {
      await _dataSource.restoreMealLog(logId);
    } catch (err) {
      throw MealLogPersistenceException('Failed to restore meal log: $err');
    }
  }

  @override
  Future<MealLog> updateMealLog(MealLog log) async {
    try {
      // Totals are always derived from `items` (portion-adjusted), never
      // taken at face value from the caller — mirrors PendingMealAnalysis's
      // totals getters so an edited ingredient list and its stored totals
      // can never drift apart.
      final totalCalories = log.items
          .fold(0.0, (sum, item) => sum + item.adjustedCalories)
          .round();
      final totalProtein = log.items
          .fold(0.0, (sum, item) => sum + item.adjustedProteinG)
          .round();
      final totalCarbs = log.items
          .fold(0.0, (sum, item) => sum + item.adjustedCarbsG)
          .round();
      final totalFats = log.items
          .fold(0.0, (sum, item) => sum + item.adjustedFatsG)
          .round();

      final payload = {
        'meal_name': log.mealName,
        'meal_type': log.mealType.dbValue,
        'total_calories': totalCalories,
        'total_protein': totalProtein,
        'total_carbs': totalCarbs,
        'total_fats': totalFats,
        'raw_json_data': {
          'items': log.items
              .map((item) => MealAnalysisItemDto.fromEntity(item).toMap())
              .toList(),
        },
      };
      final updated = await _dataSource.updateMealLog(log.id, payload);
      return MealLogDto.fromMap(updated).toEntity();
    } catch (err) {
      throw MealLogPersistenceException('Failed to update meal log: $err');
    }
  }
}
