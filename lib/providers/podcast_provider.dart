import 'package:flutter/material.dart';
import '../models/podcast_models.dart';
import '../core/services/api_services.dart';
import '../core/services/firebase_service.dart';
import '../core/services/local_storage_service.dart';

class PodcastProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FirebaseService _firebaseService = FirebaseService();
  final LocalStorageService _localStorage = LocalStorageService();

  List<Podcast> _podcasts = [];
  List<Podcast> _trendingPodcasts = [];
  List<Episode> _episodes = [];
  List<Podcast> _favorites = [];
  List<Podcast> _userPodcasts = [];
  List<Episode> _recentEpisodes = [];
  
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _selectedGenre = '';
  String _selectedLanguage = 'en';

  // ====== New for Podcast Detail Screen ======
  Podcast? _selectedPodcast;
  Podcast? get selectedPodcast => _selectedPodcast;

  bool _isLoadingDetail = false;
  bool get isLoadingDetail => _isLoadingDetail;

  String? _detailError;
  String? get detailError => _detailError;
  // ==========================================

  // Getters
  List<Podcast> get podcasts => _podcasts;
  List<Podcast> get trendingPodcasts => _trendingPodcasts;
  List<Episode> get episodes => _episodes;
  List<Podcast> get favorites => _favorites;
  List<Podcast> get userPodcasts => _userPodcasts;
  List<Episode> get recentEpisodes => _recentEpisodes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedGenre => _selectedGenre;
  String get selectedLanguage => _selectedLanguage;

  // Search Podcasts
  Future<void> searchPodcasts(String query) async {
    if (query.isEmpty) return;
    
    _isLoading = true;
    _searchQuery = query;
    notifyListeners();

    try {
      _podcasts = await _apiService.searchPodcasts(
        query: query,
        language: _selectedLanguage,
      );
      
      // Save to local storage
      for (final podcast in _podcasts) {
        await _localStorage.savePodcast(podcast);
      }
    } catch (e) {
      debugPrint('Error searching podcasts: $e');
      _podcasts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch Trending Podcasts
  Future<void> fetchTrendingPodcasts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _trendingPodcasts = await _apiService.getBestPodcasts(region: 'us');

      // Save to local storage
      for (final podcast in _trendingPodcasts) {
        await _localStorage.savePodcast(podcast);
      }
    } catch (e) {
      debugPrint('Error fetching trending podcasts: $e');
      _trendingPodcasts = [];
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get Best Podcasts
  Future<void> getBestPodcasts({String? genreId}) async {
    _isLoading = true;
    _selectedGenre = genreId ?? '';
    notifyListeners();

    try {
      _podcasts = await _apiService.getBestPodcasts(
        genreId: genreId,
        region: 'us',
      );
      
      // Save to local storage
      for (final podcast in _podcasts) {
        await _localStorage.savePodcast(podcast);
      }
    } catch (e) {
      debugPrint('Error getting best podcasts: $e');
      _podcasts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get Podcast Details with Episodes (detail-state aware)
  Future<void> getPodcastDetails(String podcastId) async {
    // Keep this for backward compatibility; delegate to new method
    await fetchPodcastById(podcastId);
  }

  // New: Explicitly fetch a podcast by ID and store as selected with episodes
  Future<void> fetchPodcastById(String podcastId) async {
    _isLoadingDetail = true;
    _detailError = null;
    notifyListeners();

    try {
      final result = await _apiService.getPodcastById(podcastId: podcastId);
      if (result.isNotEmpty) {
        _selectedPodcast = result['podcast'] as Podcast;
        _episodes = result['episodes'] as List<Episode>;

        // Save to local storage
        await _localStorage.savePodcast(_selectedPodcast!);
        for (final episode in _episodes) {
          await _localStorage.saveEpisode(episode);
        }
      }
    } catch (e) {
      debugPrint('Error getting podcast details: $e');
      _episodes = [];
      _detailError = e.toString();
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }

  // Get User Favorites
  Future<void> getUserFavorites(String userId) async {
    try {
      final favorites = await _firebaseService.getUserFavorites(userId);
      _favorites = [];
      
      for (final favorite in favorites) {
        if (favorite.itemType == 'podcast') {
          final podcast = _localStorage.getPodcast(favorite.itemId);
          if (podcast != null) {
            _favorites.add(podcast);
          }
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error getting user favorites: $e');
    }
  }

  // Add to Favorites
  Future<void> addToFavorites(String userId, String itemId, String itemType) async {
    try {
      final favorite = Favorite(
        id: '${userId}_${itemId}',
        userId: userId,
        itemId: itemId,
        itemType: itemType,
        addedAt: DateTime.now(),
      );
      
      await _firebaseService.addToFavorites(favorite);
      await _localStorage.addToFavorites(favorite);
      
      if (itemType == 'podcast') {
        await getUserFavorites(userId);
      }
    } catch (e) {
      debugPrint('Error adding to favorites: $e');
    }
  }

  // Remove from Favorites
  Future<void> removeFromFavorites(String userId, String itemId) async {
    try {
      final favoriteId = '${userId}_$itemId';
      await _firebaseService.removeFromFavorites(favoriteId);
      await _localStorage.removeFromFavorites(favoriteId);
      
      _favorites.removeWhere((podcast) => podcast.id == itemId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing from favorites: $e');
    }
  }

  // Get User Uploaded Podcasts
  Future<void> getUserPodcasts(String userId) async {
    try {
      _userPodcasts = await _firebaseService.getUserPodcasts(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error getting user podcasts: $e');
    }
  }

  // Set Language
  void setLanguage(String language) {
    _selectedLanguage = language;
    notifyListeners();
  }

  // Clear Search
  void clearSearch() {
    _searchQuery = '';
    _podcasts = [];
    notifyListeners();
  }

  // Load Recent Episodes
  Future<void> loadRecentEpisodes() async {
    try {
      final recentIds = _localStorage.getRecentlyPlayed();
      _recentEpisodes = [];
      
      for (final episodeId in recentIds) {
        final episode = _localStorage.getEpisode(episodeId);
        if (episode != null) {
          _recentEpisodes.add(episode);
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading recent episodes: $e');
    }
  }

  
}
