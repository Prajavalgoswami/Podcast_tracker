import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../widgets/episodes_list.dart';
import '../../models/podcast_models.dart';
import '../../providers/audio_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/local_storage_service.dart';

class PodcastDetailScreen extends StatefulWidget {
  const PodcastDetailScreen({
    Key? key,
    required this.podcast,
  }) : super(key: key);

  final Podcast podcast;

  @override
  State<PodcastDetailScreen> createState() => _PodcastDetailScreenState();
}

class _PodcastDetailScreenState extends State<PodcastDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final List<Episode> _episodes;
  bool _descriptionExpanded = false;
  bool _isSubscribed = false;
  bool _isFavorite = false;

  final LocalStorageService _localStorage = LocalStorageService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _episodes = _generateMockEpisodes(widget.podcast);
    _initializeFavoriteState();
  }

  void _initializeFavoriteState() {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.uid;
    if (userId != null) {
      _isFavorite = _localStorage.isFavorite(userId, widget.podcast.id);
      setState(() {});
    }
  }

  Future<void> _toggleFavorite() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.uid;
    if (userId == null) {
      _showSnackBar(context, 'Please sign in to manage favorites');
      return;
    }

    setState(() => _isFavorite = !_isFavorite);
    if (_isFavorite) {
      final favorite = Favorite(
        id: '${userId}_${widget.podcast.id}',
        userId: userId,
        itemId: widget.podcast.id,
        itemType: 'podcast',
        addedAt: DateTime.now(),
      );
      await _localStorage.addToFavorites(favorite);
      _showSnackBar(context, 'Added to favorites');
    } else {
      // find favorite by composite key in stored favorites
      final favorites = _localStorage.getUserFavorites(userId);
      final fav = favorites.firstWhere(
        (f) => f.itemId == widget.podcast.id && f.itemType == 'podcast',
        orElse: () => Favorite(
          id: '',
          userId: userId,
          itemId: widget.podcast.id,
          itemType: 'podcast',
          addedAt: DateTime.now(),
        ),
      );
      if (fav.id.isNotEmpty) {
        await _localStorage.removeFromFavorites(fav.id);
      } else {
        // fallback to constructed id
        await _localStorage.removeFromFavorites('${userId}_${widget.podcast.id}');
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: DefaultTabController(
        length: 2,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: true,
              pinned: true,
              expandedHeight: 300.h,
              backgroundColor: theme.colorScheme.surface,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, size: 24.sp),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
                  icon: Icon(
                    _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
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
                    final shareText = 'Check out this podcast: ${widget.podcast.title}';
                    await Clipboard.setData(ClipboardData(text: shareText));
                    if (!mounted) return;
                    _showSnackBar(context, 'Podcast details copied to clipboard');
                  },
                ),
                SizedBox(width: 8.w),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsetsDirectional.only(start: 16.w, bottom: 12.h, end: 16.w),
                title: _buildAppBarTitle(theme),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'podcast_${widget.podcast.id}',
                      child: _NetworkImageWithFallback(
                        imageUrl: widget.podcast.imageUrl,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.1),
                              Colors.black.withOpacity(0.25),
                              Colors.black.withOpacity(0.6),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(48.h),
                child: Container(
                  alignment: Alignment.centerLeft,
                  color: theme.colorScheme.surface.withOpacity(0.9),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: false,
                    labelStyle: theme.textTheme.titleMedium?.copyWith(fontSize: 14.sp),
                    unselectedLabelStyle: theme.textTheme.titleMedium?.copyWith(fontSize: 14.sp),
                    indicatorColor: theme.colorScheme.primary,
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.7),
                    tabs: const [
                      Tab(text: 'Episodes'),
                      Tab(text: 'About'),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildHeaderInfo(theme)),
            SliverToBoxAdapter(child: SizedBox(height: 12.h)),
            SliverFillRemaining(
              hasScrollBody: true,
              child: TabBarView(
                controller: _tabController,
                children: [
                  EpisodesList(
                    episodes: _episodes,
                    onDownload: (ep) async {
                      _showSnackBar(context, 'Downloading "${ep.title}"...');
                    },
                    onFavorite: (ep, fav) async {
                      _showSnackBar(context, fav ? 'Added to favorites' : 'Removed from favorites');
                    },
                    onShare: (ep) async {
                      await Clipboard.setData(ClipboardData(text: 'Listen: ${ep.title}'));
                      if (!mounted) return;
                      _showSnackBar(context, 'Episode link copied');
                    },
                  ),
                  _AboutTab(
                    podcast: widget.podcast,
                    fullDescription: widget.podcast.description,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarTitle(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: 1.0,
          child: Text(
            widget.podcast.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderInfo(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.podcast.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 22.sp,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            widget.podcast.publisher,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 10.h),
          _buildCategoryChips(theme, widget.podcast.genres),
          SizedBox(height: 12.h),
          _ExpandableText(
            text: widget.podcast.description,
            expanded: _descriptionExpanded,
            onToggle: () {
              setState(() => _descriptionExpanded = !_descriptionExpanded);
            },
          ),
          SizedBox(height: 12.h),
          _buildActionButtons(theme),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(ThemeData theme, List<String> categories) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 6.h,
      children: categories.map((c) => _buildChipForCategory(theme, c)).toList(),
    );
  }

  Widget _buildChipForCategory(ThemeData theme, String category) {
    final color = _chipColorForCategory(category);
    return Chip(
      label: Text(
        category,
        style: theme.textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12.sp,
        ),
      ),
      backgroundColor: color,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
    );
  }

  Color _chipColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'technology':
        return const Color(0xFF0984e3);
      case 'business':
        return const Color(0xFF00b894);
      case 'health':
        return const Color(0xFFe17055);
      case 'education':
        return const Color(0xFFfdcb6e);
      default:
        return Colors.grey.shade600;
    }
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.play_arrow_rounded),
            onPressed: () {
              if (_episodes.isEmpty) {
                _showSnackBar(context, 'No episodes to play');
                return;
              }
              context.read<AudioProvider>().playEpisode(_episodes.first);
              _showSnackBar(context, 'Playing all from latest');
            },
            label: const Text('Play All'),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              textStyle: theme.textTheme.titleMedium?.copyWith(fontSize: 14.sp),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(_isSubscribed ? Icons.check_rounded : Icons.add_rounded),
            onPressed: () {
              setState(() => _isSubscribed = !_isSubscribed);
              _showSnackBar(
                context,
                _isSubscribed ? 'Subscribed to podcast' : 'Unsubscribed',
              );
            },
            label: Text(_isSubscribed ? 'Subscribed' : 'Subscribe'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              textStyle: theme.textTheme.titleMedium?.copyWith(fontSize: 14.sp),
            ),
          ),
        ),
      ],
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<Episode> _generateMockEpisodes(Podcast podcast) {
    final now = DateTime.now();
    final titles = [
      'Episode 1: Getting Started with Flutter',
      'Episode 2: State Management Deep Dive',
      'Episode 3: Building Responsive UIs',
      'Episode 4: Networking and APIs',
      'Episode 5: Animations in Flutter',
      'Episode 6: Testing Strategies',
      'Episode 7: Performance Optimization',
      'Episode 8: Deploying to Stores',
      'Episode 9: Accessibility Best Practices',
      'Episode 10: Advanced Widgets',
    ];

    return List<Episode>.generate(titles.length, (index) {
      final minutes = 30 + index * 7;
      return Episode(
        id: '${podcast.id}_ep_$index',
        title: titles[index],
        description:
            'In this episode, we discuss ${titles[index].toLowerCase()}.',
        audioUrl: 'https://example.com/audio/${podcast.id}/ep$index.mp3',
        imageUrl: podcast.imageUrl,
        audioLengthSec: minutes * 60,
        pubDateMs: now.subtract(Duration(days: (index + 1) * 3)),
        podcastId: podcast.id,
      );
    }).reversed.toList();
  }
}

class _NetworkImageWithFallback extends StatelessWidget {
  const _NetworkImageWithFallback({
    Key? key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  final String imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade300,
          child: Center(
            child: Icon(
              Icons.podcasts_rounded,
              size: 64.sp,
              color: Colors.grey.shade600,
            ),
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.black12,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class _ExpandableText extends StatelessWidget {
  const _ExpandableText({
    Key? key,
    required this.text,
    required this.expanded,
    required this.onToggle,
  }) : super(key: key);

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          firstChild: Text(
            text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14.sp),
          ),
          secondChild: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14.sp),
          ),
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        SizedBox(height: 6.h),
        GestureDetector(
          onTap: onToggle,
          child: Text(
            expanded ? 'Read less' : 'Read more',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({
    Key? key,
    required this.podcast,
    required this.fullDescription,
  }) : super(key: key);

  final Podcast podcast;
  final String fullDescription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AboutRow(
            label: 'Publisher',
            value: podcast.publisher,
          ),
          _AboutRow(
            label: 'Language',
            value: podcast.language,
          ),
          _AboutRow(
            label: 'Total Episodes',
            value: podcast.totalEpisodes.toString(),
          ),
          _AboutRow(
            label: 'Categories',
            value: podcast.genres.join(', '),
          ),
          SizedBox(height: 12.h),
          Text(
            'Description',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16.sp,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            fullDescription,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14.sp),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
