import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/podcast_models.dart';
import '../core/services/audio_player_service.dart';
import '../core/services/firebase_service.dart';
import '../core/services/local_storage_service.dart';

class AudioProvider extends ChangeNotifier {
  final AudioPlayerService _audioService = AudioPlayerService();
  final FirebaseService _firebaseService = FirebaseService();
  final LocalStorageService _localStorage = LocalStorageService();

  Episode? _currentEpisode;
  Podcast? _currentPodcast;
  bool _isLoading = false;
  bool _isShuffled = false;
  bool _isRepeating = false;

  // Getters
  Episode? get currentEpisode => _currentEpisode;
  Podcast? get currentPodcast => _currentPodcast;
  Duration get position => _audioService.position;
  Duration? get duration => _audioService.duration;
  bool get isPlaying => _audioService.isPlaying;
  bool get isLoading => _isLoading;
  double get playbackSpeed => _audioService.speed;
  bool get isShuffled => _isShuffled;
  bool get isRepeating => _isRepeating;
  List<Episode> get playlist => _audioService.playlist;
  int get currentIndex => _audioService.currentIndex;

  // Initialize audio provider
  Future<void> initialize() async {
    // Listen to audio service streams
    _audioService.positionStream.listen(_onPositionChanged);
    _audioService.durationStream.listen(_onDurationChanged);
    _audioService.playerStateStream.listen(_onPlayerStateChanged);
    _audioService.currentEpisodeStream.listen(_onCurrentEpisodeChanged);
    
    // Load last played episode
    await _loadLastPlayedEpisode();
  }

  // Load last played episode
  Future<void> _loadLastPlayedEpisode() async {
    try {
      final lastPlayed = _localStorage.getCurrentlyPlaying();
      if (lastPlayed != null) {
        final episodeId = lastPlayed['episodeId'] as String;
        final episode = _localStorage.getEpisode(episodeId);
        if (episode != null) {
          final position = Duration(milliseconds: lastPlayed['position'] as int);
          await playEpisode(episode, seekTo: position);
        }
      }
    } catch (e) {
      debugPrint('Error loading last played episode: $e');
    }
  }

  // Play episode
  Future<void> playEpisode(Episode episode, {Duration? seekTo}) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Set current episode and podcast info
      _currentEpisode = episode;
      _currentPodcast = _localStorage.getPodcast(episode.podcastId);
      
      await _audioService.playEpisode(episode);
      
      if (seekTo != null) {
        await _audioService.seekTo(seekTo);
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      debugPrint('Error playing episode: $e');
      notifyListeners();
    }
  }

  // Play playlist
  Future<void> playPlaylist(List<Episode> episodes, int startIndex) async {
    _isShuffled = false;
    
    if (episodes.isNotEmpty) {
      final episode = episodes[startIndex];
      _currentEpisode = episode;
      _currentPodcast = _localStorage.getPodcast(episode.podcastId);
      await _audioService.playEpisode(episode, playlist: episodes);
    }
  }

  // Play/Pause
  Future<void> togglePlayPause() async {
    await _audioService.togglePlayPause();
  }

  // Pause
  Future<void> pause() async {
    await _audioService.pause();
  }

  // Resume
  Future<void> resume() async {
    await _audioService.play();
  }

  // Stop
  Future<void> stop() async {
    await _audioService.stop();
  }

  // Seek
  Future<void> seek(Duration position) async {
    await _audioService.seekTo(position);
  }

  // Set playback speed
  Future<void> setPlaybackSpeed(double speed) async {
    await _audioService.setSpeed(speed);
  }

  // Skip to next episode
  Future<void> skipToNext() async {
    await _audioService.playNext();
  }

  // Skip to previous episode
  Future<void> skipToPrevious() async {
    await _audioService.playPrevious();
  }

  // Toggle shuffle
  void toggleShuffle() {
    _isShuffled = !_isShuffled;
    if (_isShuffled) {
      _audioService.shuffle();
    }
    notifyListeners();
  }

  // Toggle repeat
  void toggleRepeat() {
    _isRepeating = !_isRepeating;
    notifyListeners();
  }

  // Save listening progress
  Future<void> saveListeningProgress() async {
    if (_currentEpisode != null && _firebaseService.currentUserId != null) {
      final progress = ListeningProgress(
        episodeId: _currentEpisode!.id,
        userId: _firebaseService.currentUserId!,
        positionMs: position.inMilliseconds,
        durationMs: duration?.inMilliseconds ?? 0,
        lastListened: DateTime.now(),
        isCompleted: position >= (duration ?? Duration.zero),
      );
      
      await _firebaseService.saveListeningProgress(progress);
      await _localStorage.saveListeningProgress(progress);
    }
  }

  // Callbacks
  void _onPositionChanged(Duration position) {
    notifyListeners();
  }

  void _onDurationChanged(Duration? duration) {
    notifyListeners();
  }

  void _onPlayerStateChanged(PlayerState state) {
    notifyListeners();
  }

  void _onCurrentEpisodeChanged(Episode? episode) {
    _currentEpisode = episode;
    if (episode != null) {
      _currentPodcast = _localStorage.getPodcast(episode.podcastId);
    } else {
      _currentPodcast = null;
    }
    notifyListeners();
  }

  // Dispose
  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
