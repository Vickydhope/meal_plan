import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meal_plan/core/error/app_exception.dart';
import 'package:meal_plan/features/meal_log/data/datasources/image_remote_data_source.dart';
import 'package:meal_plan/features/meal_log/data/repositories/image_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class _MockDataSource extends Mock implements ImageRemoteDataSource {}

void main() {
  late _MockDataSource dataSource;
  late ImageRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    dataSource = _MockDataSource();
    repository = ImageRepositoryImpl(dataSource);
  });

  Uint8List kb(int n) => Uint8List(n * 1024);

  void stubCompress(List<Uint8List?> results) {
    when(
      () => dataSource.compress(
        any(),
        quality: any(named: 'quality'),
        minWidth: any(named: 'minWidth'),
        minHeight: any(named: 'minHeight'),
      ),
    ).thenAnswer((_) async => results.removeAt(0));
  }

  test('compressImage steps quality and size down until under 200KB', () async {
    stubCompress([kb(300), kb(250), kb(150)]);

    final bytes = await repository.compressImage('photo.jpg');

    expect(bytes.lengthInBytes, 150 * 1024);
    verifyInOrder([
      () => dataSource.compress(
        'photo.jpg',
        quality: 85,
        minWidth: 1280,
        minHeight: 1280,
      ),
      () => dataSource.compress(
        'photo.jpg',
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      ),
      () => dataSource.compress(
        'photo.jpg',
        quality: 55,
        minWidth: 819,
        minHeight: 819,
      ),
    ]);
  });

  test(
    'compressImage gives up after 5 attempts and returns the last result',
    () async {
      stubCompress([kb(900), kb(800), kb(700), kb(600), kb(500)]);

      final bytes = await repository.compressImage('photo.jpg');

      expect(bytes.lengthInBytes, 500 * 1024);
    },
  );

  test(
    'compressImage throws ImageProcessingException when compression fails',
    () {
      stubCompress([null]);

      expect(
        repository.compressImage('photo.jpg'),
        throwsA(isA<ImageProcessingException>()),
      );
    },
  );

  test('uploadImage stores under the user folder and wraps failures', () async {
    when(() => dataSource.upload(any(), any())).thenAnswer((_) async {});
    final path = await repository.uploadImage(userId: 'user-1', bytes: kb(1));
    expect(path, matches(RegExp(r'^user-1/\d+\.jpg$')));

    when(() => dataSource.upload(any(), any())).thenThrow(Exception('boom'));
    expect(
      repository.uploadImage(userId: 'user-1', bytes: kb(1)),
      throwsA(isA<ImageProcessingException>()),
    );
  });

  test('deleteImage swallows failures', () async {
    when(() => dataSource.remove(any())).thenThrow(Exception('boom'));
    await repository.deleteImage('user-1/1.jpg');
  });
}
