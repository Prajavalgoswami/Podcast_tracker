import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../../models/podcast_models.dart';
import 'local_storage_service.dart';
import 'firebase_service.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  late AudioPlayer _player;
  late AudioSession _session;

  final LocalStorageService _localStorage = LocalStorageService();
  final FirebaseService _firebaseService = FirebaseService();

  // Current episode and playlist
  Episode? _currentEpisode;
  List<Episode> _playlist = [];
  int _currentIndex = 0;

  // Streams and controllers
  final StreamController<Episode?> _currentEpisodeController =
  StreamController<Episode?>.broadcast();
  final StreamController<Duration> _positionController =
  StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
  StreamController<Duration?>.broadcast();
  final StreamController<PlayerState> _playerStateController =
  StreamController<PlayerState>.broadcast();
  final StreamController<double> _speedController =
  StreamController<double>.broadcast();

  // Getters for streams
  Stream<Episode?> get currentEpisodeStream => _currentEpisodeController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  Stream<double> get speedStream => _speedController.stream;

  // Getters
  Episode? get currentEpisode => _currentEpisode;
  List<Episode> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  double get speed => _player.speed;

  // Initialize the audio player
  Future<void> initialize() async {
    _player = AudioPlayer();

    // Initialize audio session
    _session = await AudioSession.instance;
    await _session.configure(const AudioSessionConfiguration.speech());

    // Listen to player state changes
    _player.playerStateStream.listen(_playerStateController.add);
    _player.positionStream.listen(_positionController.add);
    _player.durationStream.listen(_durationController.add);
    _player.speedStream.listen(_speedController.add);

    // Listen to playback completion
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onEpisodeCompleted();
      }
    });

    // Restore last playing episode if any
    await _restoreLastSession();

    // Save progress periodically
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_player.playing && _currentEpisode != null) {
        _saveProgress();
      }
    });
  }

  // Play episode
  Future<void> playEpisode(Episode episode, {List<Episode>? playlist}) async {
    try {
      _currentEpisode = episode;

      if (playlist != null) {
        _playlist = playlist;
        _currentIndex = playlist.indexWhere((e) => e.id == episode.id);
        if (_currentIndex == -1) {
          _playlist.insert(0, episode);
          _currentIndex = 0;
        }
      } else {
        _playlist = [episode];
        _currentIndex = 0;
      }

      _currentEpisodeController.add(_currentEpisode);

      // Check if episode is downloaded for offline playback
      final localPath = _localStorage.getDownloadedEpisodePath(episode.id);
      final audioUrl = localPath ?? episode.audioUrl;

      await _player.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)));

      // Restore progress if exists
      final progress = await _getEpisodeProgress(episode.id);
      if (progress != null && progress.positionMs > 0) {
        await _player.seek(Duration(milliseconds: progress.positionMs));
      }

      await _player.play();

      // Add to recently played
      await _localStorage.addToRecentlyPlayed(episode.id);

    } catch (e) {
      print('Error playing episode: $e');
      throw 'Failed to play episode: $e';
    }
  }

  // Play/pause toggle
  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  // Play
  Future<void> play() async {
    await _player.play();
  }

  // Pause
  Future<void> pause() async {
    await _player.pause();
    if (_currentEpisode != null) {
      await _saveProgress();
    }
  }

  // Stop
  Future<void> stop() async {
    await _player.stop();
    if (_currentEpisode != null) {
      await _saveProgress();
    }
  }

  // Seek to position
  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  // Seek forward
  Future<void> seekForward([Duration duration = const Duration(seconds: 30)]) async {
    final newPosition = _player.position + duration;
    final maxDuration = _player.duration ?? Duration.zero;
    await seekTo(newPosition > maxDuration ? maxDuration : newPosition);
  }

  // Seek backward
  Future<void> seekBackward([Duration duration = const Duration(seconds: 15)]) async {
    final newPosition = _player.position - duration;
    await seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  // Set playback speed
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  // Play next episode
  Future<void> playNext() async {
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await playEpisode(_playlist[_currentIndex], playlist: _playlist);
    }
  }

  // Play previous episode
  Future<void> playPrevious() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await playEpisode(_playlist[_currentIndex], playlist: _playlist);
    }
  }

  // Shuffle playlist
  void shuffle() {
    if (_playlist.length > 1) {
      final currentEpisode = _playlist[_currentIndex];
      _playlist.shuffle();
      _currentIndex = _playlist.indexWhere((e) => e.id == currentEpisode.id);
    }
  }

  // Add episode to queue
  void addToQueue(Episode episode) {
    if (!_playlist.any((e) => e.id == episode.id)) {
      _playlist.add(episode);
    }
  }

  // Remove episode from queue
  void removeFromQueue(int index) {
    if (index < _playlist.length && index != _currentIndex) {
      _playlist.removeAt(index);
      if (index < _currentIndex) {
        _currentIndex--;
      }
    }
  }

  // Save listening progress
  Future<void> _saveProgress() async {
    if (_currentEpisode == null || _player.duration == null) return;

    final progress = ListeningProgress(
      episodeId: _currentEpisode!.id,
      userId: _firebaseService.currentUserId ?? 'local',
      positionMs: _player.position.inMilliseconds,
      durationMs: _player.duration!.inMilliseconds,
      lastListened: DateTime.now(),
      isCompleted: _player.position.inMilliseconds >=
          (_player.duration!.inMilliseconds * 0.95),
    );

    // Save locally
    await _localStorage.saveListeningProgress(progress);

    // Save to cloud if user is logged in
    if (_firebaseService.currentUserId != null) {
      await _firebaseService.saveListeningProgress(progress);
    }

    // Save current playing state
    await _localStorage.saveCurrentlyPlaying(
      episodeId: _currentEpisode!.id,
      position: _player.position.inMilliseconds,
      duration: _player.duration!.inMilliseconds,
    );
  }

  // Get episode progress
  Future<ListeningProgress?> _getEpisodeProgress(String episodeId) async {
    final userId = _firebaseService.currentUserId ?? 'local';

    // Try cloud first if user is logged in
    if (_firebaseService.currentUserId != null) {
      final cloudProgress = await _firebaseService.getListeningProgress(userId, episodeId);
      if (cloudProgress != null) return cloudProgress;
    }

    // Fallback to local storage
    return _localStorage.getListeningProgress(userId, episodeId);
  }

  // Handle episode completion
  Future<void> _onEpisodeCompleted() async {
    if (_currentEpisode != null) {
      // Mark as completed
      await _saveProgress();

      // Update listening stats
      await _updateListeningStats();

      // Auto-play next episode
      if (_currentIndex < _playlist.length - 1) {
        await Future.delayed(const Duration(seconds: 2));
        await playNext();
      }
    }
  }

  // Update listening stats
  Future<void> _updateListeningStats() async {
    if (_firebaseService.currentUserId == null || _currentEpisode == null) return;

    final userId = _firebaseService.currentUserId!;
    var stats = await _firebaseService.getListeningStats(userId) ??
        ListeningStats(
          userId: userId,
          categoryStats: {},
          dailyStats: {},
          lastUpdated: DateTime.now(),
        );

    // Update total listening time
    stats.totalListeningTimeMs += _currentEpisode!.audioLengthSec * 1000;
    stats.episodesCompleted++;

    // Update daily stats
    final today = DateTime.now().toIso8601String().split('T')[0];
    stats.dailyStats[today] = (stats.dailyStats[today] ?? 0) +
        (_currentEpisode!.audioLengthSec * 1000);

    // Update category stats (would need podcast info for genres)
    // This is simplified - you'd typically get the podcast info to determine category

    stats.lastUpdated = DateTime.now();
    await _firebaseService.updateListeningStats(stats);
  }

  // Restore last session
  Future<void> _restoreLastSession() async {
    final lastPlaying = _localStorage.getCurrentlyPlaying();
    if (lastPlaying != null) {
      final episodeId = lastPlaying['episodeId'] as String;

      // Try to get episode from local storage
      final episode = _localStorage.getEpisode(episodeId);
      if (episode != null) {
        _currentEpisode = episode;
        _currentEpisodeController.add(_currentEpisode);

        try {
          await _player.setAudioSource(AudioSource.uri(Uri.parse(episode.audioUrl)));
          await _player.seek(Duration(milliseconds: lastPlaying['position']));
          // Don't auto-play, just restore position
        } catch (e) {
          print('Error restoring session: $e');
        }
      }
    }
  }

  // Dispose
  Future<void> dispose() async {
    await _player.dispose();
    await _currentEpisodeController.close();
    await _positionController.close();
    await _durationController.close();
    await _playerStateController.close();
    await _speedController.close();
  }
}

// Simple ChangeNotifier wrapper for app-wide playback controls
class SimpleAudioPlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  String _currentTitle = '';
  String _currentSubtitle = '';
  Duration _position = Duration.zero;
  Duration? _duration;

  String get currentTitle => _currentTitle;
  String get currentSubtitle => _currentSubtitle;
  Duration get position => _position;
  Duration? get duration => _duration;
  bool get isPlaying => _player.playing;

  SimpleAudioPlayerService() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _player.durationStream.listen((d) {
      _duration = d;
      notifyListeners();
    });
    _player.playerStateStream.listen((_) => notifyListeners());
  }

  Future<void> setUrlAndPlay({
    required String url,
    String title = '',
    String subtitle = '',
  }) async {
    _currentTitle = title;
    _currentSubtitle = subtitle;
    notifyListeners();

    await _player.setUrl(url);
    await _player.play();
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}