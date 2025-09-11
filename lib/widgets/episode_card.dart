import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../models/podcast_models.dart';
import '../providers/audio_provider.dart';

class EpisodeCard extends StatefulWidget {
  const EpisodeCard({
    Key? key,
    required this.episode,
    this.onDownload,
    this.onShare,
    this.onFavorite,
  }) : super(key: key);

  final Episode episode;
  final Future<void> Function(Episode episode)? onDownload;
  final Future<void> Function(Episode episode)? onShare;
  final Future<void> Function(Episode episode, bool isFavorite)? onFavorite;

  @override
  State<EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<EpisodeCard> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audio = context.watch<AudioProvider>();
    final isActive = audio.currentEpisode?.id == widget.episode.id;

    return Dismissible(
      key: ValueKey('episode_${widget.episode.id}'),
      background: _buildSwipeBackground(Colors.green, Icons.download_rounded, 'Download'),
      secondaryBackground: _buildSwipeBackground(Colors.pink, Icons.favorite_rounded, 'Favorite'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _handleDownload();
          return false;
        } else {
          await _handleFavoriteToggle();
          return false;
        }
      },
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
          side: BorderSide(
            color: isActive
                ? theme.colorScheme.primary.withOpacity(0.35)
                : theme.colorScheme.outlineVariant,
            width: isActive ? 1.2 : 0.6,
          ),
        ),
        child: InkWell(
          onTap: () => context.read<AudioProvider>().playEpisode(widget.episode),
          child: Padding(
            padding: EdgeInsets.all(12.r),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: SizedBox(
                    width: 60.w,
                    height: 60.w,
                    child: Image.network(
                      widget.episode.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade300,
                        child: Center(
                          child: Icon(
                            Icons.podcasts_rounded,
                            size: 28.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.black12,
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.episode.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5.sp,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        widget.episode.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12.5.sp,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        '${_formatDurationFromSeconds(widget.episode.audioLengthSec)} • ${_formatRelativeDate(widget.episode.pubDateMs)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                _isDownloading
                    ? SizedBox(
                        width: 36.w,
                        height: 36.w,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 28.w,
                              height: 28.w,
                              child: CircularProgressIndicator(
                                value: _downloadProgress,
                                strokeWidth: 3,
                              ),
                            ),
                            Text('${(_downloadProgress * 100).round()}%', style: theme.textTheme.labelSmall),
                          ],
                        ),
                      )
                    : IconButton(
                        tooltip: isActive && audio.isPlaying ? 'Pause' : 'Play',
                        onPressed: () => context.read<AudioProvider>().playEpisode(widget.episode),
                        icon: Icon(
                          isActive && audio.isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_fill_rounded,
                          size: 30.sp,
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                IconButton(
                  tooltip: 'Download',
                  onPressed: _handleDownload,
                  icon: const Icon(Icons.download_rounded),
                ),
                PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'share', child: const Text('Share')),
                    PopupMenuItem(value: 'favorite', child: Text(_isFavorite ? 'Unfavorite' : 'Favorite')),
                  ],
                  onSelected: (value) async {
                    if (value == 'share') {
                      await widget.onShare?.call(widget.episode);
                    } else if (value == 'favorite') {
                      await _handleFavoriteToggle();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDownload() async {
    if (widget.onDownload == null) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
    // Simulate progress if external handler does not report
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() {
        _downloadProgress = i / 10;
      });
    }
    await widget.onDownload!(widget.episode);
    if (!mounted) return;
    setState(() {
      _isDownloading = false;
    });
  }

  Future<void> _handleFavoriteToggle() async {
    _isFavorite = !_isFavorite;
    setState(() {});
    await widget.onFavorite?.call(widget.episode, _isFavorite);
  }

  Widget _buildSwipeBackground(Color color, IconData icon, String label) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14.r),
      ),
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Icon(icon, color: color),
          SizedBox(width: 8.w),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');
String _formatDurationFromSeconds(int audioLengthSec) {
  final minutes = (audioLengthSec ~/ 60).clamp(0, 5999);
  final seconds = audioLengthSec % 60;
  return '${_twoDigits(minutes)}:${_twoDigits(seconds)}';
}
String _formatRelativeDate(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);
  if (difference.inSeconds < 60) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  final weeks = (difference.inDays / 7).floor();
  if (weeks < 5) return '${weeks}w ago';
  final months = (difference.inDays / 30).floor();
  if (months < 12) return '${months}mo ago';
  final years = (difference.inDays / 365).floor();
  return '${years}y ago';
}
