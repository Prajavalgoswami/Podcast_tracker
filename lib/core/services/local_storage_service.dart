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

    // Open boxes
    _userBox = await Hive.openBox<UserProfile>('users');
    _podcastBox = await Hive.openBox<Podcast>('podcasts');
    _episodeBox = await Hive.openBox<Episode>('episodes');
    _progressBox = await Hive.openBox<ListeningProgress>('progress');
    _favoriteBox = await Hive.openBox<Favorite>('favorites');
    _statsBox = await Hive.openBox<ListeningStats>('stats');

    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();
  }

  // User Profile Operations
  Future<void> saveUserProfile(UserProfile user) async {
    await _userBox.put(user.uid, user);
  }

  UserProfile? getUserProfile(String uid) {
    return _userBox.get(uid);
  }

  Future<void> deleteUserProfile(String uid) async {
    await _userBox.delete(uid);
  }

  // Podcast Operations
  Future<void> savePodcast(Podcast podcast) async {
    await _podcastBox.put(podcast.id, podcast);
  }

  Podcast? getPodcast(String id) {
    return _podcastBox.get(id);
  }

  List<Podcast> getAllPodcasts() {
    return _podcastBox.values.toList();
  }

  Future<void> deletePodcast(String id) async {
    await _podcastBox.delete(id);
  }

  // Episode Operations
  Future<void> saveEpisode(Episode episode) async {
    await _episodeBox.put(episode.id, episode);
  }

  Episode? getEpisode(String id) {
    return _episodeBox.get(id);
  }

  List<Episode> getEpisodesByPodcast(String podcastId) {
    return _episodeBox.values
        .where((episode) => episode.podcastId == podcastId)
        .toList();
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
    return _progressBox.values
        .where((progress) => progress.userId == userId)
        .toList()
      ..sort((a, b) => b.lastListened.compareTo(a.lastListened));
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
    return _favoriteBox.values
        .where((favorite) => favorite.userId == userId)
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  bool isFavorite(String userId, String itemId) {
    return _favoriteBox.values.any((favorite) =>
        favorite.userId == userId && favorite.itemId == itemId);
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
    await _userBox.clear();
    await _podcastBox.clear();
    await _episodeBox.clear();
    await _progressBox.clear();
    await _favoriteBox.clear();
    await _statsBox.clear();
    await _prefs.clear();
  }

  // Close all boxes (call when app is closing)
  Future<void> close() async {
    await _userBox.close();
    await _podcastBox.close();
    await _episodeBox.close();
    await _progressBox.close();
    await _favoriteBox.close();
    await _statsBox.close();
  }
}