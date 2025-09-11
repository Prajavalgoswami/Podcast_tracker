class AppConstants {
  // Firestore Collections
  static const String usersCollection = 'users';
  static const String favoritesCollection = 'favorites';
  static const String progressCollection = 'listening_progress';
  static const String uploadedPodcastsCollection = 'uploaded_podcasts';
  static const String listeningStatsCollection = 'listening_stats';

  // Storage Paths
  static const String podcastsStoragePath = 'podcasts';
  static const String userProfilesStoragePath = 'user_profiles';

  // API Configuration (Listen Notes API)
  static const String listenNotesBaseUrl = 'https://listen-api.listennotes.com/api/v2';
  static const String listenNotesApiKey = 'c33f2782e43948828c22ebca101e2a0e'; // Replace with your actual API key

  // App Settings
  static const String appName = 'Podcast Tracker';
  static const String appVersion = '1.0.0';

  // Error Messages
  static const String networkError = 'Network error. Please check your connection.';
  static const String unknownError = 'Something went wrong. Please try again.';

  // SharedPreferences Keys
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language_code';
}