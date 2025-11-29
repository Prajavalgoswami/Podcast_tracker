import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/podcast_models.dart';
import '../constants/app_constants.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  late Box<UserProfile> _userBox;
  late Box<Podcast> _podcastBox;
  late Box<Episode> _episodeBox;
  late Box<ListeningProgress> _progressBox;
  late Box<Favorite> _favoriteBox;
  late Box<ListeningStats> _statsBox;
  late SharedPreferences _prefs;

  // Initialize Hive and SharedPreferences
  Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(UserProfileAdapter());
    Hive.registerAdapter(PodcastAdapter());
    Hive.registerAdapter(EpisodeAdapter());
    Hive.registerAdapter(ListeningProgressAdapter());
    Hive.registerAdapter(FavoriteAdapter());
    Hive.registerAdapter(ListeningStatsAdapter());

    // Helper function to safely open a box, deleting it if corrupted
    Future<Box<T>> _safeOpenBox<T>(String boxName) async {
      try {
        // Try to open the box
        return await Hive.openBox<T>(boxName);
      } catch (e) {
        print('Error opening box $boxName, deleting from disk: $e');
        // If opening fails, delete the box from disk
        try {
          await Hive.deleteBoxFromDisk(boxName);
          print('Deleted $boxName box from disk');
        } catch (deleteError) {
          print('Error deleting $boxName box: $deleteError');
          // Try to close if it's open
          try {
            if (Hive.isBoxOpen(boxName)) {
              await Hive.box(boxName).close();
              await Hive.deleteBoxFromDisk(boxName);
            }
          } catch (_) {
            // Ignore errors
          }
        }
        // Open a fresh box
        return await Hive.openBox<T>(boxName);
      }
    }

    // Open all boxes with error handling
    _userBox = await _safeOpenBox<UserProfile>('users');
    _podcastBox = await _safeOpenBox<Podcast>('podcasts');
    _episodeBox = await _safeOpenBox<Episode>('episodes');
    _progressBox = await _safeOpenBox<ListeningProgress>('progress');
    _favoriteBox = await _safeOpenBox<Favorite>('favorites');
    _statsBox = await _safeOpenBox<ListeningStats>('stats');
    
    // Clean up any corrupted entries after opening (in case some got through)
    _cleanupCorruptedEntries();

    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();
  }

  // User Profile Operations
  Future<void> saveUserProfile(UserProfile user) async {
    await _userBox.put(user.uid, user);
  }

  UserProfile? getUserProfile(String uid) {
    try {
      return _userBox.get(uid);
    } catch (e) {
      print('Error reading user profile $uid: $e');
      // Delete corrupted entry
      try {
        _userBox.delete(uid);
      } catch (_) {
        // Ignore deletion errors
      }
      return null;
    }
  }

  Future<void> deleteUserProfile(String uid) async {
    await _userBox.delete(uid);
  }

  // Podcast Operations
  Future<void> savePodcast(Podcast podcast) async {
    await _podcastBox.put(podcast.id, podcast);
  }

  Podcast? getPodcast(String id) {
    try {
      return _podcastBox.get(id);
    } catch (e) {
      print('Error getting podcast $id: $e');
      return null;
    }
  }

  List<Podcast> getAllPodcasts() {
    try {
      final podcasts = <Podcast>[];
      for (final key in _podcastBox.keys) {
        try {
          final podcast = _podcastBox.get(key);
          if (podcast != null) {
            podcasts.add(podcast);
          }
        } catch (e) {
          // Skip corrupted entries
          print('Error reading podcast $key: $e');
          // Delete corrupted entry
          try {
            _podcastBox.delete(key);
          } catch (_) {
            // Ignore deletion errors
          }
        }
      }
      return podcasts;
    } catch (e) {
      print('Error getting all podcasts: $e');
      return [];
    }
  }

  Future<void> deletePodcast(String id) async {
    await _podcastBox.delete(id);
  }

  // Episode Operations
  Future<void> saveEpisode(Episode episode) async {
    await _episodeBox.put(episode.id, episode);
  }

  Episode? getEpisode(String id) {
    try {
      return _episodeBox.get(id);
    } catch (e) {
      print('Error getting episode $id: $e');
      return null;
    }
  }

  List<Episode> getEpisodesByPodcast(String podcastId) {
    try {
      final episodes = <Episode>[];
      for (final key in _episodeBox.keys) {
        try {
          final episode = _episodeBox.get(key);
          if (episode != null && episode.podcastId == podcastId) {
            episodes.add(episode);
          }
        } catch (e) {
          // Skip corrupted entries
          print('Error reading episode $key: $e');
          // Delete corrupted entry
          try {
            _episodeBox.delete(key);
          } catch (_) {
            // Ignore deletion errors
          }
        }
      }
      return episodes;
    } catch (e) {
      print('Error getting episodes by podcast: $e');
      return [];
    }
  }

  Future<void> deleteEpisode(String id) async {
    await _episodeBox.delete(id);
  }

  // Listening Progress Operations
  Future<void> saveListeningProgress(ListeningProgress progress) async {
    final key = '${progress.userId}_${progress.episodeId}';
    await _progressBox.put(key, progress);
  }

  ListeningProgress? getListeningProgress(String userId, String episodeId) {
    final key = '${userId}_$episodeId';
    return _progressBox.get(key);
  }

  List<ListeningProgress> getUserProgress(String userId) {
    try {
      final progressList = <ListeningProgress>[];
      for (final key in _progressBox.keys) {
        try {
          final progress = _progressBox.get(key);
          if (progress != null && progress.userId == userId) {
            progressList.add(progress);
          }
        } catch (e) {
          // Skip corrupted entries
          print('Error reading progress $key: $e');
          // Delete corrupted entry
          try {
            _progressBox.delete(key);
          } catch (_) {
            // Ignore deletion errors
          }
        }
      }
      progressList.sort((a, b) => b.lastListened.compareTo(a.lastListened));
      return progressList;
    } catch (e) {
      print('Error getting user progress: $e');
      return [];
    }
  }

  Future<void> deleteListeningProgress(String userId, String episodeId) async {
    final key = '${userId}_$episodeId';
    await _progressBox.delete(key);
  }

  // Favorites Operations
  Future<void> addToFavorites(Favorite favorite) async {
    await _favoriteBox.put(favorite.id, favorite);
  }

  Future<void> removeFromFavorites(String favoriteId) async {
    await _favoriteBox.delete(favoriteId);
  }

  List<Favorite> getUserFavorites(String userId) {
    try {
      final favorites = <Favorite>[];
      for (final key in _favoriteBox.keys) {
        try {
          final favorite = _favoriteBox.get(key);
          if (favorite != null && favorite.userId == userId) {
            favorites.add(favorite);
          }
        } catch (e) {
          // Skip corrupted entries
          print('Error reading favorite $key: $e');
          // Delete corrupted entry
          try {
            _favoriteBox.delete(key);
          } catch (_) {
            // Ignore deletion errors
          }
        }
      }
      favorites.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return favorites;
    } catch (e) {
      print('Error getting user favorites: $e');
      return [];
    }
  }

  bool isFavorite(String userId, String itemId) {
    try {
      for (final key in _favoriteBox.keys) {
        try {
          final favorite = _favoriteBox.get(key);
          if (favorite != null && 
              favorite.userId == userId && 
              favorite.itemId == itemId) {
            return true;
          }
        } catch (e) {
          // Skip corrupted entries
          print('Error reading favorite $key: $e');
          // Delete corrupted entry
          try {
            _favoriteBox.delete(key);
          } catch (_) {
            // Ignore deletion errors
          }
        }
      }
      return false;
    } catch (e) {
      print('Error checking favorite: $e');
      return false;
    }
  }

  // Listening Stats Operations
  Future<void> saveListeningStats(ListeningStats stats) async {
    await _statsBox.put(stats.userId, stats);
  }

  ListeningStats? getListeningStats(String userId) {
    return _statsBox.get(userId);
  }

  // SharedPreferences Operations
  Future<void> setThemeMode(String themeMode) async {
    await _prefs.setString(AppConstants.themeKey, themeMode);
  }

  String getThemeMode() {
    return _prefs.getString(AppConstants.themeKey) ?? 'system';
  }

  Future<void> setLanguage(String languageCode) async {
    await _prefs.setString(AppConstants.languageKey, languageCode);
  }

  String getLanguage() {
    return _prefs.getString(AppConstants.languageKey) ?? 'en';
  }

  Future<void> setFirstTimeUser(bool isFirstTime) async {
    await _prefs.setBool('first_time_user', isFirstTime);
  }

  bool isFirstTimeUser() {
    return _prefs.getBool('first_time_user') ?? true;
  }

  // Audio Player State
  Future<void> saveCurrentlyPlaying({
    required String episodeId,
    required int position,
    required int duration,
  }) async {
    await _prefs.setString('current_episode_id', episodeId);
    await _prefs.setInt('current_position', position);
    await _prefs.setInt('current_duration', duration);
  }

  Map<String, dynamic>? getCurrentlyPlaying() {
    final episodeId = _prefs.getString('current_episode_id');
    final position = _prefs.getInt('current_position');
    final duration = _prefs.getInt('current_duration');

    if (episodeId != null && position != null && duration != null) {
      return {
        'episodeId': episodeId,
        'position': position,
        'duration': duration,
      };
    }
    return null;
  }

  Future<void> clearCurrentlyPlaying() async {
    await _prefs.remove('current_episode_id');
    await _prefs.remove('current_position');
    await _prefs.remove('current_duration');
  }

  // Search History
  Future<void> addToSearchHistory(String query) async {
    final history = getSearchHistory();
    if (history.contains(query)) {
      history.remove(query);
    }
    history.insert(0, query);
    
    // Keep only last 10 searches
    if (history.length > 10) {
      history.removeRange(10, history.length);
    }
    
    await _prefs.setStringList('search_history', history);
  }

  List<String> getSearchHistory() {
    return _prefs.getStringList('search_history') ?? [];
  }

  Future<void> clearSearchHistory() async {
    await _prefs.remove('search_history');
  }

  // Recently Played
  Future<void> addToRecentlyPlayed(String episodeId) async {
    final recent = getRecentlyPlayed();
    if (recent.contains(episodeId)) {
      recent.remove(episodeId);
    }
    recent.insert(0, episodeId);
    
    // Keep only last 20 episodes
    if (recent.length > 20) {
      recent.removeRange(20, recent.length);
    }
    
    await _prefs.setStringList('recently_played', recent);
  }

  List<String> getRecentlyPlayed() {
    return _prefs.getStringList('recently_played') ?? [];
  }

  // Download Episodes (for offline listening)
  Future<void> markEpisodeAsDownloaded(String episodeId, String localPath) async {
    await _prefs.setString('downloaded_$episodeId', localPath);
  }

  String? getDownloadedEpisodePath(String episodeId) {
    return _prefs.getString('downloaded_$episodeId');
  }

  Future<void> removeDownloadedEpisode(String episodeId) async {
    await _prefs.remove('downloaded_$episodeId');
  }

  List<String> getDownloadedEpisodes() {
    final keys = _prefs.getKeys()
        .where((key) => key.startsWith('downloaded_'))
        .toList();
    return keys.map((key) => key.replaceFirst('downloaded_', '')).toList();
  }

  // Clear all data (for logout)
  Future<void> clearAllData() async {
    try {
      // Safely clear all boxes if they are initialized
      // Note: We preserve favorites and podcasts/episodes for offline access
      // Favorites will be synced from Firebase on next login
      await _safeClearBox(() => _userBox);
      // Keep podcasts and episodes for offline access
      // await _safeClearBox(() => _podcastBox);
      // await _safeClearBox(() => _episodeBox);
      await _safeClearBox(() => _progressBox);
      // Don't clear favorites - they're synced from Firebase on login
      // await _safeClearBox(() => _favoriteBox);
      await _safeClearBox(() => _statsBox);
      await _prefs.clear();
    } catch (e) {
      print('Error in clearAllData: $e');
      // If boxes aren't initialized, just clear SharedPreferences
      try {
        await _prefs.clear();
      } catch (e2) {
        print('Error clearing SharedPreferences: $e2');
      }
    }
  }

  // Helper method to safely clear a box
  Future<void> _safeClearBox<T>(Box<T> Function() getBox) async {
    try {
      final box = getBox();
      if (box.isOpen) {
        await box.clear();
      }
    } catch (e) {
      // Box might not be initialized, ignore
    }
  }


  // Clean up corrupted entries from all boxes
  void _cleanupCorruptedEntries() {
    try {
      // Helper to safely clean a box
      void cleanBox<T>(Box<T> box, String boxName) {
        try {
          final keys = box.keys.toList();
          for (final key in keys) {
            try {
              box.get(key);
            } catch (e) {
              print('Removing corrupted $boxName entry: $key');
              try {
                box.delete(key);
              } catch (_) {
                // Ignore deletion errors
              }
            }
          }
        } catch (e) {
          print('Error cleaning $boxName box: $e');
        }
      }
      
      // Clean all boxes
      cleanBox(_userBox, 'user');
      cleanBox(_podcastBox, 'podcast');
      cleanBox(_episodeBox, 'episode');
      cleanBox(_progressBox, 'progress');
      cleanBox(_favoriteBox, 'favorite');
      cleanBox(_statsBox, 'stats');
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }

  // Close all boxes (call when app is closing)
  Future<void> close() async {
    // Helper function to safely close a box
    Future<void> safeCloseBox<T>(Box<T> Function() getBox) async {
      try {
        final box = getBox();
        if (box.isOpen) {
          await box.close();
        }
      } catch (e) {
        // Box might not be initialized, ignore
      }
    }

    await safeCloseBox(() => _userBox);
    await safeCloseBox(() => _podcastBox);
    await safeCloseBox(() => _episodeBox);
    await safeCloseBox(() => _progressBox);
    await safeCloseBox(() => _favoriteBox);
    await safeCloseBox(() => _statsBox);
  }
}