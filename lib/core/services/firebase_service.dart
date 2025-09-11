import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../constants/app_constants.dart';
import '../../models/podcast_models.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Current user getter
  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;

  // Authentication Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email Sign Up
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await credential.user?.updateDisplayName(displayName);

      // Create user profile in Firestore
      if (credential.user != null) {
        await createUserProfile(
          UserProfile(
            uid: credential.user!.uid,
            email: email,
            displayName: displayName,
            createdAt: DateTime.now(),
            lastSeen: DateTime.now(),
          ),
        );
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Email Sign In
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last seen
      if (credential.user != null) {
        await updateUserLastSeen(credential.user!.uid);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Create or update user profile
      if (userCredential.user != null) {
        final user = userCredential.user!;
        final existingProfile = await getUserProfile(user.uid);

        if (existingProfile == null) {
          await createUserProfile(
            UserProfile(
              uid: user.uid,
              email: user.email ?? '',
              displayName: user.displayName ?? '',
              photoUrl: user.photoURL,
              createdAt: DateTime.now(),
              lastSeen: DateTime.now(),
            ),
          );
        } else {
          await updateUserLastSeen(user.uid);
        }
      }

      return userCredential;
    } catch (e) {
      throw 'Google sign-in failed: $e';
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // Password Reset
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Create User Profile
  Future<void> createUserProfile(UserProfile profile) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(profile.uid)
        .set(profile.toJson());
  }

  // Get User Profile
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        return UserProfile.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Update User Profile
  Future<void> updateUserProfile(UserProfile profile) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(profile.uid)
        .update(profile.toJson());
  }

  // Update User Last Seen
  Future<void> updateUserLastSeen(String uid) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({'lastSeen': DateTime.now().toIso8601String()});
  }

  // Add to Favorites
  Future<void> addToFavorites(Favorite favorite) async {
    await _firestore
        .collection(AppConstants.favoritesCollection)
        .doc(favorite.id)
        .set(favorite.toJson());
  }

  // Remove from Favorites
  Future<void> removeFromFavorites(String favoriteId) async {
    await _firestore
        .collection(AppConstants.favoritesCollection)
        .doc(favoriteId)
        .delete();
  }

  // Get User Favorites
  Future<List<Favorite>> getUserFavorites(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.favoritesCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('addedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Favorite.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting favorites: $e');
      return [];
    }
  }

  // Save Listening Progress
  Future<void> saveListeningProgress(ListeningProgress progress) async {
    await _firestore
        .collection(AppConstants.progressCollection)
        .doc('${progress.userId}_${progress.episodeId}')
        .set(progress.toJson());
  }

  // Get Listening Progress
  Future<ListeningProgress?> getListeningProgress(
      String userId, String episodeId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.progressCollection)
          .doc('${userId}_$episodeId')
          .get();

      if (doc.exists && doc.data() != null) {
        return ListeningProgress.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting listening progress: $e');
      return null;
    }
  }

  // Get User's All Progress
  Future<List<ListeningProgress>> getUserProgress(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.progressCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('lastListened', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ListeningProgress.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting user progress: $e');
      return [];
    }
  }

  // Upload User Podcast
  Future<String?> uploadPodcastAudio({
    required File audioFile,
    required String userId,
    required String fileName,
  }) async {
    try {
      final ref = _storage
          .ref()
          .child('podcasts')
          .child(userId)
          .child('$fileName.mp3');

      final uploadTask = await ref.putFile(audioFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading audio: $e');
      return null;
    }
  }

  // Save User Uploaded Podcast
  Future<void> saveUserPodcast(Podcast podcast) async {
    await _firestore
        .collection(AppConstants.uploadedPodcastsCollection)
        .doc(podcast.id)
        .set(podcast.toJson());
  }

  // Get User Uploaded Podcasts
  Future<List<Podcast>> getUserPodcasts(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.uploadedPodcastsCollection)
          .where('uploadedByUserId', isEqualTo: userId)
          .get();

      return querySnapshot.docs
          .map((doc) => Podcast.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting user podcasts: $e');
      return [];
    }
  }

  // Update Listening Stats
  Future<void> updateListeningStats(ListeningStats stats) async {
    await _firestore
        .collection(AppConstants.listeningStatsCollection)
        .doc(stats.userId)
        .set(stats.toJson());
  }

  // Get Listening Stats
  Future<ListeningStats?> getListeningStats(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.listeningStatsCollection)
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        return ListeningStats.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting listening stats: $e');
      return null;
    }
  }

  // Handle Authentication Errors
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
}