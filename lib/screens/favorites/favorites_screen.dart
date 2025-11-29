import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';
import '../../providers/podcast_provider.dart';
import '../../core/services/local_storage_service.dart';
import '../../models/podcast_models.dart';
import '../podcast_detail/podcast_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final LocalStorageService _localStorage = LocalStorageService();
  List<Favorite> _favorites = [];
  Map<String, Podcast> _podcastCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh favorites when screen becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavorites();
    });
  }

  Future<void> _loadFavorites() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.uid;
    
    if (userId != null) {
      setState(() => _isLoading = true);
      
      // Sync favorites from Firebase to local storage when user logs in
      final podcastProvider = context.read<PodcastProvider>();
      try {
        // This method syncs Firebase favorites to local storage
        await podcastProvider.getUserFavorites(userId);
      } catch (e) {
        print('Error syncing favorites from Firebase: $e');
        // Continue with local storage if Firebase fails
      }
      
      // Load from local storage (includes synced favorites)
      final favorites = _localStorage.getUserFavorites(userId);
      
      // Load podcast data for each favorite
      for (final favorite in favorites) {
        if (favorite.itemType == 'podcast' && !_podcastCache.containsKey(favorite.itemId)) {
          try {
            // First try to get from local storage
            var podcast = _localStorage.getPodcast(favorite.itemId);
            
            // If not found locally, try to fetch from API
            if (podcast == null) {
              try {
                await podcastProvider.getPodcastDetails(favorite.itemId);
                podcast = podcastProvider.selectedPodcast;
                
                // Save the fetched podcast to local storage for future use
                if (podcast != null) {
                  await _localStorage.savePodcast(podcast);
                }
              } catch (e) {
                print('Error fetching podcast ${favorite.itemId} from API: $e');
              }
            }
            
            if (podcast != null) {
              _podcastCache[favorite.itemId] = podcast;
            }
          } catch (e) {
            print('Error loading podcast ${favorite.itemId}: $e');
          }
        } else if (favorite.itemType == 'episode') {
          // For episodes, we need to get the parent podcast
          try {
            final episode = _localStorage.getEpisode(favorite.itemId);
            if (episode != null && !_podcastCache.containsKey(episode.podcastId)) {
              var podcast = _localStorage.getPodcast(episode.podcastId);
              
              if (podcast == null) {
                try {
                  await podcastProvider.getPodcastDetails(episode.podcastId);
                  podcast = podcastProvider.selectedPodcast;
                  
                  if (podcast != null) {
                    await _localStorage.savePodcast(podcast);
                  }
                } catch (e) {
                  print('Error fetching podcast ${episode.podcastId} for episode: $e');
                }
              }
              
              if (podcast != null) {
                _podcastCache[episode.podcastId] = podcast;
              }
            }
          } catch (e) {
            print('Error loading episode ${favorite.itemId}: $e');
          }
        }
      }
      
      setState(() {
        _favorites = favorites;
        _isLoading = false;
      });
      
      // Debug: Print loaded data
      print('Loaded ${favorites.length} favorites');
      print('Podcast cache has ${_podcastCache.length} podcasts');
      for (final entry in _podcastCache.entries) {
        print('Podcast ${entry.key}: ${entry.value.title}');
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFavorite(Favorite favorite) async {
    await _localStorage.removeFromFavorites(favorite.id);
    _loadFavorites(); // Reload the list
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from favorites')),
      );
    }
  }

  void _handleNavigation(Favorite favorite, Podcast? podcast, Episode? episode) {
    if (favorite.itemType == 'podcast') {
      if (podcast == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Podcast details are still loading. Please wait...')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PodcastDetailScreen(podcastId: favorite.itemId),
        ),
      );
    } else if (favorite.itemType == 'episode') {
      if (episode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Episode data not found. Please try again.')),
        );
        return;
      }
      if (episode.podcastId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid episode data. Cannot open podcast.')),
        );
        return;
      }
      if (podcast == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Podcast details are still loading. Please wait...')),
        );
        // Try to load the podcast if not already loaded
        _loadPodcastForEpisode(episode.podcastId);
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PodcastDetailScreen(podcastId: episode.podcastId),
        ),
      );
    }
  }

  Future<void> _loadPodcastForEpisode(String podcastId) async {
    try {
      final podcastProvider = context.read<PodcastProvider>();
      await podcastProvider.getPodcastDetails(podcastId);
      final podcast = podcastProvider.selectedPodcast;
      if (podcast != null) {
        await _localStorage.savePodcast(podcast);
        _podcastCache[podcastId] = podcast;
        setState(() {}); // Refresh the UI
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading podcast: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    if (!auth.isAuthenticated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64.sp,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16.h),
            Text(
              'Sign in to view favorites',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Your favorite podcasts will appear here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64.sp,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16.h),
            Text(
              'No favorites yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Tap the heart icon on podcasts to add them here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final favorite = _favorites[index];
          return _buildFavoriteItem(favorite);
        },
      ),
    );
  }

  Widget _buildFavoriteItem(Favorite favorite) {
    final theme = Theme.of(context);
    Podcast? podcast;
    Episode? episode;
    
    if (favorite.itemType == 'podcast') {
      podcast = _podcastCache[favorite.itemId];
    } else if (favorite.itemType == 'episode') {
      episode = _localStorage.getEpisode(favorite.itemId);
      if (episode != null) {
        podcast = _podcastCache[episode.podcastId];
      }
    }
    
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: ListTile(
        contentPadding: EdgeInsets.all(12.w),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: podcast?.imageUrl != null && podcast!.imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: podcast.imageUrl,
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
        title: Text(
          favorite.itemType == 'episode' 
              ? (episode?.title ?? 'Loading episode...')
              : (podcast?.title ?? 'Loading podcast...'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          favorite.itemType == 'episode'
              ? (podcast?.publisher ?? 'Loading podcast details...')
              : (podcast?.publisher ?? 'Loading podcast details...'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red),
              onPressed: () => _removeFavorite(favorite),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () => _handleNavigation(favorite, podcast, episode),
            ),
          ],
        ),
        onTap: () => _handleNavigation(favorite, podcast, episode),
      ),
    );
  }
}