import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service pour gérer la liste des "restes" (ingrédients disponibles)
/// Stockage dans Firestore: collection `users/{uid}` champ `leftovers: List<String>`
class LeftoversService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  /// Récupère la liste des restes pour l'utilisateur
  Future<List<String>> getLeftovers(String uid) async {
    try {
      final doc = await _userDoc(uid).get();
      if (!doc.exists) return <String>[];
      final data = doc.data();
      final raw = data?[ 'leftovers' ];
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return <String>[];
    } catch (e) {
      debugPrint('Erreur getLeftovers: $e');
      return <String>[];
    }
  }

  /// Enregistre la liste des restes (merge sans écraser d'autres champs)
  Future<bool> setLeftovers(String uid, List<String> leftovers) async {
    try {
      await _userDoc(uid).set({
        'leftovers': leftovers,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Erreur setLeftovers: $e');
      return false;
    }
  }
}
