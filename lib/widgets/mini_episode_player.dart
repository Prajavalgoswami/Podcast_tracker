import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../models/podcast_models.dart';
import '../providers/audio_provider.dart';
import '../core/services/local_storage_service.dart';

class MiniEpisodePlayer extends StatelessWidget {
  MiniEpisodePlayer({Key? key, this.onExpand}) : super(key: key);

  final VoidCallback? onExpand;
  final LocalStorageService _storage = LocalStorageService();

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final Episode? episode = audio.currentEpisode;
    if (episode == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final podcast = _storage.getPodcast(episode.podcastId);

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta != null && details.primaryDelta! < -8) {
          onExpand?.call();
        }
      },
      child: Material(
        elevation: 4,
        color: theme.colorScheme.surface,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: SizedBox(
                  width: 40.w,
                  height: 40.w,
                  child: Image.network(
                    episode.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade300,
                      child: Icon(Icons.podcasts_rounded, color: Colors.grey.shade600),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      podcast?.title ?? 'Podcast',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    SizedBox(height: 6.h),
                    _ProgressBar(),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.skip_previous_rounded),
                onPressed: () => context.read<AudioProvider>().skipToPrevious(),
              ),
              IconButton(
                icon: Icon(audio.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                onPressed: () => context.read<AudioProvider>().togglePlayPause(),
              ),
              IconButton(
                icon: Icon(Icons.skip_next_rounded),
                onPressed: () => context.read<AudioProvider>().skipToNext(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final position = audio.position;
    final duration = audio.duration ?? Duration.zero;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final dx = details.localPosition.dx.clamp(0.0, box.size.width);
        final ratio = dx / box.size.width;
        final seekTo = Duration(milliseconds: (duration.inMilliseconds * ratio).round());
        context.read<AudioProvider>().seek(seekTo);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3.r),
        child: LinearProgressIndicator(
          minHeight: 4.h,
          value: progress,
          backgroundColor: Colors.grey.shade300,
        ),
      ),
    );
  }
}
