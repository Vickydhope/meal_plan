import '../repositories/fitness_repository.dart';

/// Mirrors a day's water total into the health store when write-back is on
/// (the same switch as meals).
class WriteWaterToHealthUseCase {
  WriteWaterToHealthUseCase(this._repository);

  final FitnessRepository _repository;

  Future<void> call(DateTime day, int ml) async {
    if (!await _repository.isMealWriteBackEnabled()) return;
    await _repository.writeWater(day, ml);
  }
}
