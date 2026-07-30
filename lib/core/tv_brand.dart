/// Identifies the brand/platform of a discovered TV.
enum TVBrand { lg, samsung, androidTv, roku, unknown }

extension TVBrandLabel on TVBrand {
  String get label {
    switch (this) {
      case TVBrand.lg:
        return 'LG (WebOS)';
      case TVBrand.samsung:
        return 'Samsung (Tizen)';
      case TVBrand.androidTv:
        return 'Android TV';
      case TVBrand.roku:
        return 'Roku';
      case TVBrand.unknown:
        return 'Unknown';
    }
  }
}
