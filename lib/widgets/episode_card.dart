import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../models/podcast_models.dart';
import '../core/services/local_storage_service.dart';
import '../providers/auth_provider.dart';

class EpisodeCard extends StatefulWidget {
  const EpisodeCard({
    Key? key,
    required this.episode,
  }) : super(key: key);

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
      
      await _localStorage.addToFavorites(Favorite(
        id: '${userId}_${widget.episode.id}',
        userId: userId,
        itemId: widget.episode.id,
        itemType: 'episode',
        addedAt: DateTime.now(),
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Added to favorites")),
      );
    } else {
      await _localStorage.removeFromFavorites('${userId}_${widget.episode.id}');
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
      margin: EdgeInsets.symmetric(vertical: 6.h, horizontal: 8.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Episode image
            ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: (ep.imageUrl.isNotEmpty)
                  ? CachedNetworkImage(
                imageUrl: ep.imageUrl,
                width: 60.w,
                height: 60.w,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 60.w,
                  height: 60.w,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 60.w,
                  height: 60.w,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.podcasts_rounded, size: 30),
                ),
              )
                  : Container(
                width: 60.w,
                height: 60.w,
                color: Colors.grey.shade300,
                child: const Icon(Icons.podcasts_rounded, size: 30),
              ),
            ),

            SizedBox(width: 12.w),

            // Title + description + metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Episode title - medium bold
                  Text(
                    ep.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 15.sp,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),

                  // Episode description - smaller, lighter text
                  Text(
                    _cleanDescription(ep.description),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12.sp,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 8.h),
                  
                  // Duration and date - smallest text
                  Text(
                    "${_formatDuration(ep.audioLengthSec)} • ${_timeAgo(ep.pubDateMs)}",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11.sp,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Like button positioned at top-right
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: SizedBox(
                width: 32.w,
                height: 32.w,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    _isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isFavorite ? Colors.red : Colors.grey.shade600,
                    size: 20.sp,
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
