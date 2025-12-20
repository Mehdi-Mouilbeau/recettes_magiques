import 'package:flutter/material.dart';
import 'package:recette_magique/services/leftovers_service.dart';
import 'package:recette_magique/services/backend_config.dart';
import 'package:flutter/foundation.dart';

/// Provider pour gérer la liste des ingrédients restants ("mes restes")
class LeftoversProvider extends ChangeNotifier {
  final LeftoversService _service = LeftoversService();

  List<String> _leftovers = <String>[];
  bool _isLoading = false;
  String? _errorMessage;

  List<String> get leftovers => _leftovers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Charge les restes depuis Firestore
  Future<void> load(String uid) async {
    if (!BackendConfig.firebaseReady) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _leftovers = await _service.getLeftovers(uid);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('LeftoversProvider.load error: $e');
      _errorMessage = 'Impossible de charger vos restes';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sauvegarde et met à jour localement
  Future<bool> save(String uid, List<String> items) async {
    if (!BackendConfig.firebaseReady) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final cleaned = items
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      final ok = await _service.setLeftovers(uid, cleaned);
      if (ok) {
        _leftovers = cleaned;
      }
      _isLoading = false;
      notifyListeners();
      return ok;
    } catch (e) {
      debugPrint('LeftoversProvider.save error: $e');
      _errorMessage = 'Impossible d\'enregistrer vos restes';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void setLocal(List<String> items) {
    _leftovers = items;
    notifyListeners();
  }
}
