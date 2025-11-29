import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import '../constants/app_constants.dart';
import '../../models/podcast_models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late Dio _dio;
  
  // Rate limiting and retry configuration
  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(seconds: 1);
  static const Duration _maxDelay = Duration(seconds: 30);
  static const Duration _rateLimitDelay = Duration(minutes: 1);
  
  // Request throttling
  final Map<String, DateTime> _lastRequestTimes = {};
  static const Duration _minRequestInterval = Duration(milliseconds: 500);

  void initialize() {
    _dio = Dio();
    _dio.options.baseUrl = AppConstants.listenNotesBaseUrl;
    _dio.options.headers = {
      'X-ListenAPI-Key': AppConstants.listenNotesApiKey,
      'Content-Type': 'application/json',
    };
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // Add lightweight logging in debug only (avoid dumping huge payloads)
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        requestHeader: false,
        responseHeader: false,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }
  }

  // Search Podcasts
  Future<List<Podcast>> searchPodcasts({
    required String query,
    String? language,
    int offset = 0,
    int len = 20,
  }) async {
    try {
      final response = await _dio.get('/search', queryParameters: {
        'q': query,
        'type': 'podcast',
        'language': language,
        'offset': offset,
        'len_min': len,
        'sort_by_date': 0,
        'safe_mode': 1,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        final results = data['results'] as List;
        return results.map((json) => Podcast.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Error handling
  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.badResponse:
        if (e.response?.statusCode == 401) {
          return 'Invalid API key. Please check your Listen Notes API key.';
        } else if (e.response?.statusCode == 429) {
          return 'Too many requests. Please try again later.';
        } else if (e.response?.statusCode == 404) {
          return 'Podcast or episode not found.';
        }
        return 'Server error: ${e.response?.statusCode}';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.unknown:
        return 'Network error. Please check your internet connection.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  // Get Podcast by ID with Episodes
  Future<Map<String, dynamic>> getPodcastById({
    required String podcastId,
    int episodeOffset = 0,
    int episodeLen = 20,

  }) async {
    try {
      final response = await _dio.get(
        '/podcasts/$podcastId',
        queryParameters: {
          'next_episode_pub_date': episodeOffset,
          'sort': 'recent_first',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final podcast = Podcast.fromJson(data);
        final episodes = (data['episodes'] as List)
            .map((json) => Episode.fromJson(json))
            .toList();

        return {
          'podcast': podcast,
          'episodes': episodes,
        };
      }
      return {};
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Get Best Podcasts by Category
  Future<List<Podcast>> getBestPodcasts({
    String? genreId,
    String? region = 'us',
    int page = 1,
  }) async {
    try {
      final response = await _dio.get('/best_podcasts', queryParameters: {
        if (genreId != null) 'genre_id': genreId,
        'region': region,
        'page': page,
        'safe_mode': 1,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        if (data == null) {
          debugPrint('⚠️ API response data is null');
          return [];
        }
        
        final podcasts = data['podcasts'] as List?;
        if (podcasts == null) {
          debugPrint('⚠️ No podcasts array in API response');
          debugPrint('   Response keys: ${data.keys.toList()}');
          return [];
        }
        
        if (podcasts.isEmpty) {
          debugPrint('⚠️ Podcasts array is empty');
          return [];
        }
        
        debugPrint('📡 API returned ${podcasts.length} podcasts');
        final parsed = <Podcast>[];
        for (var i = 0; i < podcasts.length; i++) {
          try {
            final podcast = Podcast.fromJson(podcasts[i]);
            parsed.add(podcast);
          } catch (e) {
            debugPrint('❌ Error parsing podcast $i: $e');
          }
        }
        debugPrint('✅ Successfully parsed ${parsed.length} podcasts');
        return parsed;
      }
      debugPrint('⚠️ API returned status code: ${response.statusCode}');
      return [];
    } on DioException catch (e) {
      debugPrint('❌ DioException in getBestPodcasts: ${e.message}');
      throw _handleError(e);
    } catch (e) {
      debugPrint('❌ Unexpected error in getBestPodcasts: $e');
      return [];
    }
  }

  // Get Trending Search Terms
  Future<List<String>> getTrendingSearches() async {
    try {
      final response = await _dio.get('/trending_searches');

      if (response.statusCode == 200) {
        final data = response.data;
        final terms = data['terms'] as List;
        return terms.cast<String>();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Get Podcast Genres
  Future<List<Map<String, dynamic>>> getGenres() async {
    try {
      final response = await _dio.get('/genres');

      if (response.statusCode == 200) {
        final data = response.data;
        final genres = data['genres'] as List;
        return genres.cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Get Episode by ID
  Future<Episode?> getEpisodeById(String episodeId) async {
    try {
      final response = await _dio.get('/episodes/$episodeId');

      if (response.statusCode == 200) {
        return Episode.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Get Podcast Recommendations
  Future<List<Podcast>> getPodcastRecommendations({
    required String podcastId,
    int count = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/podcasts/$podcastId/recommendations',
        queryParameters: {'count': count},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final recommendations = data['recommendations'] as List;
        return recommendations.map((json) => Podcast.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Search Episodes
  Future<List<Episode>> searchEpisodes({
    required String query,
    String? language,
    int offset = 0,
    int len = 20,
  }) async {
    try {
      final response = await _dio.get('/search', queryParameters: {
        'q': query,
        'type': 'episode',
        'language': language,
        'offset': offset,
        'len_min': len,
        'sort_by_date': 0,
        'safe_mode': 1,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        final results = data['results'] as List;
        return results.map((json) => Episode.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}