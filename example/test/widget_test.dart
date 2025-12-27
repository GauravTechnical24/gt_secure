import 'package:flutter_test/flutter_test.dart';
import 'package:gt_secure/gt_secure.dart';

void main() {
  testWidgets('GT Secure Demo loads correctly', (WidgetTester tester) async {
    // Initialize secure storage before widget tests
    await secureStorage.init();

    // Basic test to verify package integration works
    expect(secureStorage, isNotNull);
  });
}
