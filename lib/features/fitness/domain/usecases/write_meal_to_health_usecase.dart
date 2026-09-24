import '../../../meal_log/domain/entities/meal_log.dart';
import '../repositories/fitness_repository.dart';

/// Mirrors [MealLog] into the health store when write-back is on. Deletes
/// any existing record for the same meal first, so the same call handles a
/// new meal, an edit, and an undone delete without duplicating it.
class WriteMealToHealthUseCase {
  WriteMealToHealthUseCase(this._repository);

  final FitnessRepository _repository;

  Future<void> call(MealLog log) async {
    if (!await _repository.isMealWriteBackEnabled()) return;
    await _repository.deleteMeal(log.createdAt);
    await _repository.writeMeal(log);
  }
}
