import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cards the provider swiped away from their dashboard / requests list.
///
/// This is a purely local preference: the job stays OPEN for every other
/// provider and the booking is untouched on the server. The provider can undo,
/// and the choice survives a restart.
///
/// Shared by the dashboard and the requests screen so a card removed in one
/// place does not come back in the other.
class DismissedCards extends ChangeNotifier {
  static final DismissedCards instance = DismissedCards._();
  DismissedCards._() {
    _load();
  }

  static const _key = 'provider_dismissed_cards';
  Set<String> _ids = {};

  bool contains(String id) => _ids.contains(id);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _ids = (prefs.getStringList(_key) ?? []).toSet();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ids.toList());
  }

  Future<void> dismiss(String id) async {
    if (_ids.add(id)) {
      notifyListeners();
      await _save();
    }
  }

  Future<void> restore(String id) async {
    if (_ids.remove(id)) {
      notifyListeners();
      await _save();
    }
  }

  /// Bring everything back — the escape hatch when a provider has swiped away
  /// something they still wanted.
  Future<void> restoreAll() async {
    if (_ids.isEmpty) return;
    _ids = {};
    notifyListeners();
    await _save();
  }

  int get count => _ids.length;
}
