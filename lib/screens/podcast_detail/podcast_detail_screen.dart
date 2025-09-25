import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_html/flutter_html.dart'; // for parsing description
import 'package:provider/provider.dart';
import '../../widgets/episodes_list.dart';
import '../../models/podcast_models.dart';
import '../../providers/audio_provider.dart';
import '../../providers/podcast_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/local_storage_service.dart';

class PodcastDetailScreen extends StatefulWidget {
  const PodcastDetailScreen({Key? key, required this.podcastId})
      : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PodcastProvider>();
      provider.getPodcastDetails(widget.podcastId).then((_) {
        _initializeFavoriteState();
      });
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
      // Save podcast data to local storage
      await _localStorage.savePodcast(podcast);
      
      final favorite = Favorite(
        id: '${userId}_${podcast.id}',
        userId: userId,
        itemId: podcast.id,
        itemType: 'podcast',
        addedAt: DateTime.now(),
      );
      await _localStorage.addToFavorites(favorite);
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
      if (fav.id.isNotEmpty) {
        await _localStorage.removeFromFavorites(fav.id);
      } else {
        await _localStorage.removeFromFavorites('${userId}_${podcast.id}');
      }
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
        if (podcast == null) {
          return const Scaffold(
            body: Center(child: Text('Podcast not found')),
          );
        }

        final episodes = provider.episodes;
        final theme = Theme.of(context);

        return Scaffold(
          backgroundColor: theme.colorScheme.background,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                pinned: true,
                expandedHeight: 300.h,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, size: 24.sp),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    tooltip:
                        _isFavorite ? 'Remove from favorites' : 'Add to favorites',
                    icon: Icon(
                      _isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _isFavorite
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                      size: 24.sp,
                    ),
                    onPressed: _toggleFavorite,
                  ),
                  IconButton(
                    tooltip: 'Share',
                    icon: Icon(Icons.share_rounded, size: 24.sp),
                    onPressed: () async {
                      final shareText =
                          'Check out this podcast: ${podcast.title}';
                      await Clipboard.setData(ClipboardData(text: shareText));
                      if (!mounted) return;
                      _showSnackBar(
                          context, 'Podcast details copied to clipboard');
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding:
                      EdgeInsetsDirectional.only(start: 16.w, bottom: 12.h, end: 16.w),
                  title: Text(
                    podcast.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: Hero(
                    tag: 'podcast_${podcast.id}',
                    child: Image.network(
                      podcast.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.podcasts, size: 80),
                    ),
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Episodes'),
                    Tab(text: 'About'),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                // Episodes tab
                EpisodesList(
                  episodes: episodes,
                  onFavorite: (ep, fav) async {
                    _showSnackBar(
                        context, fav ? 'Added to favorites' : 'Removed from favorites');
                  },
                  onShare: (ep) async {
                    await Clipboard.setData(ClipboardData(text: 'Listen: ${ep.title}'));
                    if (!mounted) return;
                    _showSnackBar(context, 'Episode link copied');
                  },
                ),

                // About tab
                SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Podcast Info Section
                      Text(
                        'Podcast Information',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 18.sp,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      
                      _buildInfoRow('Publisher', podcast.publisher),
                      _buildInfoRow('Language', podcast.language),
                      _buildInfoRow('Total Episodes', podcast.totalEpisodes.toString()),
                      _buildInfoRow('Categories', podcast.genres.join(', ')),
                      
                      SizedBox(height: 20.h),
                      
                      // About Section
                      Text(
                        'About',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 18.sp,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Html(data: podcast.description), // parse HTML nicely
                      SizedBox(height: 20.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play All'),
                          onPressed: episodes.isEmpty
                              ? null
                              : () {
                                  context
                                      .read<AudioProvider>()
                                      .playEpisode(episodes.first);
                                  _showSnackBar(context, 'Playing all from latest');
                                },
                        ),
                      ),
                    ],
                  ),
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
