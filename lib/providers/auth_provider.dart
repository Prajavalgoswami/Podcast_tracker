import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/firebase_service.dart';
import '../core/services/local_storage_service.dart';
import '../models/podcast_models.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final LocalStorageService _localStorage = LocalStorageService();

  User? _user;
  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get user => _user;
  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  String get selectedLanguage => _userProfile?.preferredLanguage ??
      _localStorage.getLanguage();

  AuthProvider() {
    _init();
  }

  void _init() {
    // Listen to auth state changes
    _firebaseService.authStateChanges.listen((User? user) async {
      _user = user;
      if (user != null) {
        await _loadUserProfile(user.uid);
      } else {
        _userProfile = null;
      }
      notifyListeners();
    });
  }

  // Sign up with email
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String language,
  }) async {
    _setLoading(true);
    try {
      final credential = await _firebaseService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );

      if (credential?.user != null) {
        // Update user profile with selected language
        final profile = UserProfile(
          uid: credential!.user!.uid,
          email: email,
          displayName: displayName,
          preferredLanguage: language,
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
        );

        await _firebaseService.createUserProfile(profile);
        await _localStorage.saveUserProfile(profile);
        await _localStorage.setLanguage(language);

        _userProfile = profile;
        _clearError();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign in with email
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final credential = await _firebaseService.signInWithEmail(
        email: email,
        password: password,
      );

      if (credential?.user != null) {
        await _loadUserProfile(credential!.user!.uid);
        _clearError();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      final credential = await _firebaseService.signInWithGoogle();

      if (credential?.user != null) {
        await _loadUserProfile(credential!.user!.uid);
        _clearError();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign out
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _firebaseService.signOut();
      await _localStorage.clearAllData();
      _user = null;
      _userProfile = null;
      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    try {
      await _firebaseService.resetPassword(email);
      _clearError();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update user profile
  Future<bool> updateUserProfile({
    String? displayName,
    String? language,
    String? photoUrl,
  }) async {
    if (_userProfile == null) return false;

    _setLoading(true);
    try {
      final updatedProfile = UserProfile(
        uid: _userProfile!.uid,
        email: _userProfile!.email,
        displayName: displayName ?? _userProfile!.displayName,
        photoUrl: photoUrl ?? _userProfile!.photoUrl,
        preferredLanguage: language ?? _userProfile!.preferredLanguage,
        createdAt: _userProfile!.createdAt,
        lastSeen: DateTime.now(),
      );

      await _firebaseService.updateUserProfile(updatedProfile);
      await _localStorage.saveUserProfile(updatedProfile);

      if (language != null) {
        await _localStorage.setLanguage(language);
      }

      _userProfile = updatedProfile;
      _clearError();
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Load user profile
  Future<void> _loadUserProfile(String uid) async {
    try {
      // Try to get from cloud first
      var profile = await _firebaseService.getUserProfile(uid);

      // If not found in cloud, check local storage
      profile ??= _localStorage.getUserProfile(uid);

      if (profile != null) {
        _userProfile = profile;
        await _localStorage.saveUserProfile(profile);
        await _localStorage.setLanguage(profile.preferredLanguage);
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  // Change language
  Future<void> changeLanguage(String languageCode) async {
    await _localStorage.setLanguage(languageCode);

    if (_userProfile != null) {
      await updateUserProfile(language: languageCode);
    }

    notifyListeners();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }
}