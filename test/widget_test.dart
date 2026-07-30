import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tvremote/main.dart';
import 'package:tvremote/providers/tv_provider.dart';
import 'package:tvremote/providers/theme_provider.dart';
import 'package:tvremote/ads/app_open_ad_manager.dart';

void main() {
  testWidgets('App renders dashboard screen', (WidgetTester tester) async {
    final adManager = AppOpenAdManager();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TVProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          Provider<AppOpenAdManager>.value(value: adManager),
        ],
        child: const UniversalRemoteApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Universal Remote Control'), findsOneWidget);
  });
}
