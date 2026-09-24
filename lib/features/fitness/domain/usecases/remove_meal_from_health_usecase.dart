import '../../../meal_log/domain/entities/meal_log.dart';
import '../repositories/fitness_repository.dart';

/// Removes a deleted meal's record from the health store when write-back
/// is on.
class RemoveMealFromHealthUseCase {
  RemoveMealFromHealthUseCase(this._repository);

  final FitnessRepository _repository;

  Future<void> call(MealLog log) async {
    if (!await _repository.isMealWriteBackEnabled()) return;
    await _repository.deleteMeal(log.createdAt);
  }
}
