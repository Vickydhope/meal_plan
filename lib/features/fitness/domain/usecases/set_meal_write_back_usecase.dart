import '../repositories/fitness_repository.dart';

/// Turns writing confirmed meals into the health store on (requesting
/// write permission first, so a denial leaves it off) or off.
class SetMealWriteBackUseCase {
  SetMealWriteBackUseCase(this._repository);

  final FitnessRepository _repository;

  Future<void> call(bool enabled) async {
    if (enabled) await _repository.requestMealWritePermissions();
    await _repository.setMealWriteBackEnabled(enabled);
  }
}
