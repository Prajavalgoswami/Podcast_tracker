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
      // Search Hindi and English, then merge unique by id (Listen Notes doesn't support region for search)
      final List<Podcast> results = [];
      final seen = <String>{};

      Future<void> addAll(List<Podcast> items) async {
        for (final p in items) {
          if (seen.add(p.id)) {
            results.add(p);
            await _localStorage.savePodcast(p);
          }
        }
      }

      // English
      final en = await _apiService.searchPodcasts(query: query, language: 'en');
      await addAll(en);
      // Hindi
      final hi = await _apiService.searchPodcasts(query: query, language: 'hi');
      await addAll(hi);

      _podcasts = results;
      
    } catch (e) {
      debugPrint('Error searching podcasts: $e');
      _podcasts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isSupportedLanguage(String? language) {
  final lang = (language ?? '').toLowerCase().trim();

  if (lang.isEmpty) return false;

  // Accept English variations
  if (lang.startsWith('en')) return true;

  // Accept Hindi variations
  if (lang.startsWith('hi')) return true;
  if (lang.contains('hindi')) return true;

  return false;
}


  // Fetch Trending Podcasts
  Future<void> fetchTrendingPodcasts() async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  try {
    final fetched = await _apiService.getBestPodcasts(region: 'in');
    debugPrint('📊 Fetched ${fetched.length} trending podcasts');

    // Filter only English + Hindi podcasts
    _trendingPodcasts = fetched.where((podcast) {
      final lang = podcast.language.toLowerCase().trim();

      // English variations
      if (lang.startsWith('en')) return true;

      // Hindi variations
      if (lang.startsWith('hi')) return true;
      if (lang.contains('hindi')) return true;

      return false;  // remove others
    }).toList();

    debugPrint("✅ Trending after filter: ${_trendingPodcasts.length}");

    if (_trendingPodcasts.isNotEmpty) {
      debugPrint('📊 First podcast: ${_trendingPodcasts.first.title}');
    }

    // Save to local storage
    for (final podcast in _trendingPodcasts) {
      try {
        await _localStorage.savePodcast(podcast);
      } catch (e) {
        debugPrint('Error saving podcast ${podcast.id}: $e');
      }
    }
  } catch (e) {
    debugPrint('❌ Error fetching trending podcasts: $e');
    _trendingPodcasts = [];
    _error = e.toString();
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}


  // Curated Indian podcasts for target genres
  Future<void> fetchIndianEducationScienceEnvironment() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Resolve genre IDs dynamically from API
      final genres = await _apiService.getGenres();
      final wantedNames = <String>{'education', 'science', 'environment', 'environmental'};
      final wanted = genres.where((g) {
        final name = (g['name'] ?? '').toString().toLowerCase();
        return wantedNames.any((w) => name.contains(w));
      }).map((g) => g['id'].toString()).toList();

      final aggregated = <Podcast>[];
      final seen = <String>{};
      for (final genreId in wanted) {
        final list = await _apiService.getBestPodcasts(genreId: genreId, region: 'in');
        for (final p in list) {
          // Filter to show supported languages (English + Hindi)
          if (_isSupportedLanguage(p.language) && seen.add(p.id)) {
            aggregated.add(p);
            await _localStorage.savePodcast(p);
          }
        }
      }

      _podcasts = aggregated;
    } catch (e) {
      debugPrint('Error fetching curated Indian podcasts: $e');
      _podcasts = [];
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
      final fetched = await _apiService.getBestPodcasts(
        genreId: genreId,
        region: 'in',
      );
      
      // Filter to show supported languages (English + Hindi)
      _podcasts = fetched.where((podcast) => _isSupportedLanguage(podcast.language)).toList();
      
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
    final isDifferentPodcast = _selectedPodcast?.id != podcastId;

    // Always clear state first if it's a different podcast to prevent showing wrong data
    if (isDifferentPodcast) {
      _selectedPodcast = null;
      _episodes = [];
      _detailError = null;
      _isLoadingDetail = true;
      notifyListeners();
      // Small delay to ensure UI updates with cleared state
      await Future.delayed(const Duration(milliseconds: 50));
    } else {
      // Same podcast, but still update loading state
      _isLoadingDetail = true;
      _detailError = null;
      notifyListeners();
    }

    // First, try to load from local storage for immediate display
    final cachedPodcast = _localStorage.getPodcast(podcastId);
    final cachedEpisodes = _localStorage.getEpisodesByPodcast(podcastId);
    
    // Only set cached data if it matches the requested podcastId
    if (cachedPodcast != null && cachedPodcast.id == podcastId) {
      _selectedPodcast = cachedPodcast;
      _episodes = cachedEpisodes;
      _isLoadingDetail = false;
      notifyListeners();
    }

    // Then try to fetch from API to get fresh data
    try {
      final result = await _apiService.getPodcastById(podcastId: podcastId);

      // Double-check that the result matches the requested podcastId
      if (result.isNotEmpty) {
        final fetchedPodcast = result['podcast'] as Podcast;
        final fetchedEpisodes = result['episodes'] as List<Episode>;
        
        // Only update if this is still the podcast we're requesting
        if (fetchedPodcast.id == podcastId) {
          _selectedPodcast = fetchedPodcast;
          _episodes = fetchedEpisodes;
        }
      }
    } catch (e) {
      // Retry ONCE in case of network error
      await Future.delayed(const Duration(milliseconds: 400));

      try {
        final result = await _apiService.getPodcastById(podcastId: podcastId);

        if (result.isNotEmpty) {
          final fetchedPodcast = result['podcast'] as Podcast;
          final fetchedEpisodes = result['episodes'] as List<Episode>;
          
          // Only update if this is still the podcast we're requesting
          if (fetchedPodcast.id == podcastId) {
            _selectedPodcast = fetchedPodcast;
            _episodes = fetchedEpisodes;
          }
        }
      } catch (err) {
        // Final fallback: use cached data only if it matches
        if (cachedPodcast != null && cachedPodcast.id == podcastId) {
          _selectedPodcast = cachedPodcast;
          _episodes = cachedEpisodes;
        } else {
          _selectedPodcast = null;
          _episodes = [];
        }

        _detailError = err.toString();
      }
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }

  // Get User Favorites
  Future<void> getUserFavorites(String userId) async {
    try {
      // First try to get from Firebase (cloud sync)
      final firebaseFavorites = await _firebaseService.getUserFavorites(userId);
      
      // Sync Firebase favorites to local storage
      for (final favorite in firebaseFavorites) {
        await _localStorage.addToFavorites(favorite);
      }
      
      // Now load from local storage (includes synced favorites)
      final localFavorites = _localStorage.getUserFavorites(userId);
      _favorites = [];
      
      for (final favorite in localFavorites) {
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
      // Fallback to local storage only
      final localFavorites = _localStorage.getUserFavorites(userId);
      _favorites = [];
      for (final favorite in localFavorites) {
        if (favorite.itemType == 'podcast') {
          final podcast = _localStorage.getPodcast(favorite.itemId);
          if (podcast != null) {
            _favorites.add(podcast);
          }
        }
      }
      notifyListeners();
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
