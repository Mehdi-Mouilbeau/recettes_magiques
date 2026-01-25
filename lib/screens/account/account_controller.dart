import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class AccountController extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;
  Uint8List? _profileImageBytes;
  String? _profileImagePath;

  bool get isLoading => _isLoading;
  Uint8List? get profileImageBytes => _profileImageBytes;
  String? get profileImagePath => _profileImagePath;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> pickProfileImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (image != null) {
        _profileImagePath = image.path;
        
        try {
          final bytes = await image.readAsBytes();
          _profileImageBytes = bytes;
          notifyListeners();
        } catch (_) {
          // ignore preview error
        }
      }
    } catch (e) {
      throw Exception('Erreur lors de la sélection de l\'image');
    }
  }

  void setProfileImage(Uint8List? bytes) {
    _profileImageBytes = bytes;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void reset() {
    _isLoading = false;
    _profileImageBytes = null;
    _profileImagePath = null;
    notifyListeners();
  }
}