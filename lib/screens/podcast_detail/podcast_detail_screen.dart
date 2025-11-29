import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import '../../widgets/episodes_list.dart';
import '../../models/podcast_models.dart';
import '../../providers/audio_provider.dart';
import '../../providers/podcast_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/local_storage_service.dart';

class PodcastDetailScreen extends StatefulWidget {
  const PodcastDetailScreen({super.key, required this.podcastId});

  final String podcastId;

  @override
  State<PodcastDetailScreen> createState() => _PodcastDetailScreenState();
}

class _PodcastDetailScreenState extends State<PodcastDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool descriptionExpanded = false;
  bool _isFavorite = false;

  final LocalStorageService _localStorage = LocalStorageService();

  bool _hasRequestedDetail = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasRequestedDetail) return;
    _hasRequestedDetail = true;

    final provider = context.read<PodcastProvider>();

    // Always fetch to ensure we have the correct podcast data
    // This handles the case where we navigate from one podcast to another
    provider.fetchPodcastById(widget.podcastId).then((_) {
      if (!mounted) return;
      // Verify the fetched podcast matches before initializing
      if (provider.selectedPodcast?.id == widget.podcastId) {
        _initializeFavoriteState();
        _precacheImage(provider.selectedPodcast);
      }
    });
  }

  void _initializeFavoriteState() {
    final provider = context.read<PodcastProvider>();
    final podcast = provider.selectedPodcast;
    if (podcast == null) return;

    final auth = context.read<AuthProvider>();
    final userId = auth.user?.uid;
    if (userId != null) {
      _isFavorite = _localStorage.isFavorite(userId, podcast.id);
      setState(() {});
    }
  }

  void _precacheImage(Podcast? podcast) {
    if (kIsWeb && podcast != null) {
      final imageUrl = "https://corsproxy.io/?${Uri.encodeComponent(podcast.imageUrl)}";
      precacheImage(NetworkImage(imageUrl), context);
    }
  }

  Future<void> _toggleFavorite() async {
    final provider = context.read<PodcastProvider>();
    final podcast = provider.selectedPodcast;
    if (podcast == null) return;

    final auth = context.read<AuthProvider>();
    final userId = auth.user?.uid;
    if (userId == null) {
      _showSnackBar(context, 'Please sign in to manage favorites');
      return;
    }

    setState(() => _isFavorite = !_isFavorite);
    if (_isFavorite) {
      await _localStorage.savePodcast(podcast);
      final favorite = Favorite(
        id: '${userId}_${podcast.id}',
        userId: userId,
        itemId: podcast.id,
        itemType: 'podcast',
        addedAt: DateTime.now(),
      );
      // Save to both local storage and Firebase for persistence
      await _localStorage.addToFavorites(favorite);
      try {
        final podcastProvider = context.read<PodcastProvider>();
        await podcastProvider.addToFavorites(userId, podcast.id, 'podcast');
      } catch (e) {
        debugPrint('Error saving favorite to Firebase: $e');
        // Continue even if Firebase fails - local storage is saved
      }
      if (!mounted) return;
      _showSnackBar(context, 'Added to favorites');
    } else {
      final favorites = _localStorage.getUserFavorites(userId);
      final fav = favorites.firstWhere(
            (f) => f.itemId == podcast.id && f.itemType == 'podcast',
        orElse: () => Favorite(
          id: '',
          userId: userId,
          itemId: podcast.id,
          itemType: 'podcast',
          addedAt: DateTime.now(),
        ),
      );
      final favoriteId = fav.id.isNotEmpty ? fav.id : '${userId}_${podcast.id}';
      await _localStorage.removeFromFavorites(favoriteId);
      try {
        // Remove from Firebase as well
        final podcastProvider = context.read<PodcastProvider>();
        await podcastProvider.removeFromFavorites(userId, podcast.id);
      } catch (e) {
        debugPrint('Error removing favorite from Firebase: $e');
      }
      if (!mounted) return;
      _showSnackBar(context, 'Removed from favorites');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PodcastProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingDetail) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.detailError != null) {
          return Scaffold(
            body: Center(child: Text('Error: ${provider.detailError}')),
          );
        }

        final podcast = provider.selectedPodcast;
        // Ensure we're showing the correct podcast for this screen
        if (podcast == null || podcast.id != widget.podcastId) {
          // Still loading or wrong podcast - show loading or error
          if (provider.isLoadingDetail) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return Scaffold(
            body: Center(
              child: podcast == null
                  ? const Text('Podcast not found')
                  : const Text('Loading podcast details...'),
            ),
          );
        }

        final episodes = provider.episodes;
        final theme = Theme.of(context);

        final imageUrl = kIsWeb
            ? "https://corsproxy.io/?${Uri.encodeComponent(podcast.imageUrl)}"
            : podcast.imageUrl;

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverOverlapAbsorber(
                handle:
                NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverAppBar(
                  pinned: true,
                  expandedHeight: 300.h,
                  backgroundColor: theme.colorScheme.surface,
                  automaticallyImplyLeading: false,
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      final double expandedHeight = 300.h;
                      final double t = ((constraints.maxHeight - kToolbarHeight) /
                          (expandedHeight - kToolbarHeight))
                          .clamp(0.0, 1.0);

                      final double collapsedSize = kIsWeb ? 16.0 : 16.sp;
                      final double expandedSize = kIsWeb ? 22.0 : 28.sp;
                      final double fontSize =
                          ui.lerpDouble(collapsedSize, expandedSize, t) ?? collapsedSize;

                      final double minBottomPadding = 8.h;
                      final double maxBottomPadding = 48.h;
                      final double bottomPadding =
                          ui.lerpDouble(minBottomPadding, maxBottomPadding, t) ?? minBottomPadding;

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Hero(
                            tag: 'podcast_${podcast.id}',
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                              const Icon(Icons.podcasts, size: 80),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.4),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),
                          SafeArea(
                            child: Padding(
                              padding:
                              EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.arrow_back_rounded,
                                        size: 26.sp, color: Colors.white),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: _isFavorite
                                            ? 'Remove from favorites'
                                            : 'Add to favorites',
                                        icon: Icon(
                                          _isFavorite
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          color: _isFavorite
                                              ? theme.colorScheme.error
                                              : Colors.white,
                                          size: 24.sp,
                                        ),
                                        onPressed: _toggleFavorite,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16.w,
                            right: 16.w,
                            bottom: bottomPadding,
                            child: Text(
                              podcast.title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: fontSize,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  bottom: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Episodes'),
                      Tab(text: 'About'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                Builder(
                  builder: (context) {
                    return EpisodesList(
                      episodes: episodes,
                      useOverlapInjector: true,
                      onFavorite: (ep, fav) async {
                        _showSnackBar(
                            context,
                            fav
                                ? 'Added to favorites'
                                : 'Removed from favorites');
                      },
                      onShare: (ep) async {
                        await Clipboard.setData(
                            ClipboardData(text: 'Listen: ${ep.title}'));
                        if (!mounted) return;
                        _showSnackBar(context, 'Episode link copied');
                      },
                    );
                  },
                ),
                Builder(
                  builder: (context) {
                    return CustomScrollView(
                      slivers: [
                        SliverOverlapInjector(
                          handle: NestedScrollView
                              .sliverOverlapAbsorberHandleFor(context),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Podcast Information',
                                  style:
                                  theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18.sp,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                _buildInfoRow('Publisher', podcast.publisher),
                                _buildInfoRow('Language', podcast.language),
                                _buildInfoRow('Total Episodes',
                                    podcast.totalEpisodes.toString()),
                                _buildInfoRow(
                                    'Categories', podcast.genres.join(', ')),
                                SizedBox(height: 20.h),
                                Text(
                                  'About',
                                  style:
                                  theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18.sp,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                Html(data: podcast.description),
                                SizedBox(height: 20.h),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: const Text('Play All'),
                                    onPressed: episodes.isEmpty
                                        ? null
                                        : () async {
                                      final audioProvider = context.read<AudioProvider>();
                                      await audioProvider.playPlaylist(episodes, 0);
                                      if (!mounted) return;
                                      _showSnackBar(context,
                                          'Playing all from latest');
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
