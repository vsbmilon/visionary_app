import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dark-mode preference persisted on device.
class AppThemeController extends ChangeNotifier {
  AppThemeController() {
    _load();
  }

  bool dark = false;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    dark = prefs.getBool('darkMode') ?? false;
    notifyListeners();
  }

  Future<void> setDark(bool v) async {
    dark = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', v);
  }
}
