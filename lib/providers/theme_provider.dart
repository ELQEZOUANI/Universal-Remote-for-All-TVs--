import 'package:flutter/foundation.dart';

/// Manages the app-wide light/dark theme toggle.
class ThemeProvider extends ChangeNotifier {
  bool _isDark = true; // start in dark mode

  bool get isDark => _isDark;

  void toggle() {
    _isDark = !_isDark;
    notifyListeners();
  }
}
