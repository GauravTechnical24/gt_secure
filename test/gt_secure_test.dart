import 'package:flutter_test/flutter_test.dart';
import 'package:gt_secure/gt_secure.dart';

void main() {
  group('SecureStorageUtil', () {
    test('SecureStorageUtil singleton instance is available', () {
      // Verify that the singleton instance is accessible
      expect(secureStorage, isNotNull);
      expect(secureStorage, isA<SecureStorageUtil>());
    });

    test('SecureStorageUtil factory returns same instance', () {
      // Verify singleton pattern
      final instance1 = SecureStorageUtil();
      final instance2 = SecureStorageUtil();
      expect(identical(instance1, instance2), isTrue);
    });

    test('SecureStorageException contains message', () {
      final exception = SecureStorageException('Test error message');
      expect(exception.message, equals('Test error message'));
      expect(exception.toString(), contains('Test error message'));
    });

    test('SecureStorageException contains original error', () {
      final originalError = Exception('Original');
      final exception = SecureStorageException('Test error', originalError);
      expect(exception.originalError, equals(originalError));
      expect(exception.toString(), contains('Caused by'));
    });
  });
}
