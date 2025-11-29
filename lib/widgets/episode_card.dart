import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../models/podcast_models.dart';
import '../core/services/local_storage_service.dart';
import '../providers/auth_provider.dart';
import '../providers/podcast_provider.dart';

class EpisodeCard extends StatefulWidget {
  const EpisodeCard({
    super.key,
    required this.episode,
  });

  final Episode episode;

  @override
  State<EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<EpisodeCard> {
  bool _isFavorite = false;
  final LocalStorageService _localStorage = LocalStorageService();

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.uid;
    if (userId != null) {
      setState(() {
        _isFavorite = _localStorage.isFavorite(userId, widget.episode.id);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to manage favorites")),
      );
      return;
    }

    setState(() => _isFavorite = !_isFavorite);

    if (_isFavorite) {
      // Save episode data to local storage
      await _localStorage.saveEpisode(widget.episode);
      
      final favorite = Favorite(
        id: '${userId}_${widget.episode.id}',
        userId: userId,
        itemId: widget.episode.id,
        itemType: 'episode',
        addedAt: DateTime.now(),
      );
      
      // Save to both local storage and Firebase
      await _localStorage.addToFavorites(favorite);
      try {
        final podcastProvider = context.read<PodcastProvider>();
        await podcastProvider.addToFavorites(userId, widget.episode.id, 'episode');
      } catch (e) {
        debugPrint('Error saving episode favorite to Firebase: $e');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Added to favorites")),
      );
    } else {
      final favoriteId = '${userId}_${widget.episode.id}';
      await _localStorage.removeFromFavorites(favoriteId);
      try {
        final podcastProvider = context.read<PodcastProvider>();
        await podcastProvider.removeFromFavorites(userId, widget.episode.id);
      } catch (e) {
        debugPrint('Error removing episode favorite from Firebase: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Removed from favorites")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.symmetric(vertical: kIsWeb ? 4.0 : 6.h, horizontal: kIsWeb ? 8.0 : 8.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kIsWeb ? 12.0 : 12.r)),
      child: Padding(
        padding: EdgeInsets.all(kIsWeb ? 12.0 : 12.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Episode image
            ClipRRect(
              borderRadius: BorderRadius.circular(kIsWeb ? 10.0 : 10.r),
              child: (ep.imageUrl.isNotEmpty)
                  ? CachedNetworkImage(
                imageUrl: ep.imageUrl,
                width: kIsWeb ? 60.0 : 60.w,
                height: kIsWeb ? 60.0 : 60.w,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: kIsWeb ? 60.0 : 60.w,
                  height: kIsWeb ? 60.0 : 60.w,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: kIsWeb ? 60.0 : 60.w,
                  height: kIsWeb ? 60.0 : 60.w,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.podcasts_rounded, size: 30),
                ),
              )
                  : Container(
                width: kIsWeb ? 60.0 : 60.w,
                height: kIsWeb ? 60.0 : 60.w,
                color: Colors.grey.shade300,
                child: const Icon(Icons.podcasts_rounded, size: 30),
              ),
            ),

            SizedBox(width: kIsWeb ? 12.0 : 12.w),

            // Title + description + metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Episode title - adjusted for web
                  Text(
                    ep.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: kIsWeb ? 15.5 : 15.sp,
                      height: 1.3,
                    ),
                    maxLines: kIsWeb ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: kIsWeb ? 4.0 : 6.h),

                  // Episode description - smaller, lighter text
                  Text(
                    _cleanDescription(ep.description),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: kIsWeb ? 12.0 : 12.sp,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                    maxLines: kIsWeb ? 2 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: kIsWeb ? 6.0 : 8.h),
                  
                  // Duration and date - smallest text
                  Text(
                    "${_formatDuration(ep.audioLengthSec)} • ${_timeAgo(ep.pubDateMs)}",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: kIsWeb ? 11.0 : 11.sp,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Like button positioned at top-right
            Padding(
              padding: EdgeInsets.only(left: kIsWeb ? 8.0 : 8.w, top: kIsWeb ? 2.0 : 4.h),
              child: SizedBox(
                width: kIsWeb ? 36.0 : 32.w,
                height: kIsWeb ? 36.0 : 32.w,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isFavorite ? Colors.red : Colors.grey.shade600,
                    size: kIsWeb ? 20.0 : 20.sp,
                  ),
                  onPressed: _toggleFavorite,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _cleanDescription(String description) {
    // Remove HTML tags and clean up the description
    return description
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces with single space
        .trim();
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  String _timeAgo(DateTime pubDate) {
    final diff = DateTime.now().difference(pubDate);
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }
}
