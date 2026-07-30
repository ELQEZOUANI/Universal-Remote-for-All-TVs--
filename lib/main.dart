import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'providers/tv_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'views/splash_screen.dart';
import 'ads/app_open_ad_manager.dart';
import 'ads/interstitial_ad_manager.dart';
import 'ads/app_lifecycle_reactor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await MobileAds.instance.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final appOpenAdManager = AppOpenAdManager();
  appOpenAdManager.loadAd();

  final interstitialAdManager = InterstitialAdManager();
  interstitialAdManager.loadAd();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TVProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<AppOpenAdManager>.value(value: appOpenAdManager),
        Provider<InterstitialAdManager>.value(value: interstitialAdManager),
      ],
      child: AppLifecycleReactor(
        appOpenAdManager: appOpenAdManager,
        child: const UniversalRemoteApp(),
      ),
    ),
  );
}

class UniversalRemoteApp extends StatelessWidget {
  const UniversalRemoteApp({super.key});

  static const _lightBg = Color(0xFFF4F6F8);
  static const _lightText = Color(0xFF1A202C);

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    // Keep status-bar icons readable in both themes.
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'Uni TV Remote+',
      theme: CupertinoThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primaryColor: AppTheme.emerald,
        scaffoldBackgroundColor: isDark ? AppTheme.midnight : _lightBg,
        barBackgroundColor: isDark
            ? AppTheme.midnight.withOpacity(0.8)
            : _lightBg.withOpacity(0.8),
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: '.SF Pro Display',
            color: isDark ? AppTheme.white : _lightText,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
