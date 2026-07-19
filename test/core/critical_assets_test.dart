import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final asset in const [
    'assets/images/diamond_logo.png',
    'assets/images/gym_bg_2.jpg',
  ]) {
    testWidgets('$asset está incluido y no está vacío', (tester) async {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0));
    });
  }
}
