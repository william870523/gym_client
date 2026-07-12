import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gym_client/src/core/sync/sync_status_provider.dart';
import 'package:gym_client/src/features/auth/presentation/screens/login_screen.dart';
import 'package:gym_client/src/l10n/app_localizations.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(isOptional: true);
  });

  testWidgets('shows the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusProvider.overrideWith(
            (ref) => Stream.value(
              SyncStatusSnapshot(
                level: SyncStatusLevel.synced,
                label: 'Sincronizado',
                detail: 'Test',
                checkedAt: DateTime(2026),
              ),
            ),
          ),
        ],
        child: NeumorphicApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
