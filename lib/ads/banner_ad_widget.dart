import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// A reusable widget that loads and displays an AdMob banner ad.
///
/// Automatically handles loading, error states, and disposal.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  // Test Ad Unit IDs (replace with real IDs for production)
  static String get _adUnitId {
    if (Platform.isIOS) {
      return 'ca-app-pub-2535194044471316/8303745396'; // iOS test banner
    }
    throw UnsupportedError('Unsupported platform');
  }

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner, // 320×50
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('✅ Banner ad loaded successfully!');
          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ Banner ad failed to load: ${error.message}');
          ad.dispose();
          _bannerAd = null;
        },
        onAdOpened: (ad) => print('📺 Banner ad opened'),
        onAdClosed: (ad) => print('👋 Banner ad closed'),
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      // Return an empty container while loading / if failed
      return const SizedBox.shrink();
    }

    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
