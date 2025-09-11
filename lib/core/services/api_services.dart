import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../../models/podcast_models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late Dio _dio;

  void initialize() {
    _dio = Dio();
    _dio.options.baseUrl = AppConstants.listenNotesBaseUrl;
    _dio.options.headers = {
      'X-ListenAPI-Key': AppConstants.listenNotesApiKey,
      'Content-Type': 'application/json',
    };
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // Add interceptor for logging (optional)
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print(obj),
    ));
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
        final podcasts = data['podcasts'] as List;
        return podcasts.map((json) => Podcast.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _handleError(e);
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