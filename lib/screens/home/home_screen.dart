import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/podcast_provider.dart';
import '../../core/services/audio_player_service.dart';
import 'all_podcasts_screen.dart';
import '../podcast_detail/podcast_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _categories = const [
    'Technology', 'Business', 'Health', 'Education', 'Entertainment', 'Science', 'Sports', 'Lifestyle'
  ];
  
  int _selectedCategoryIndex = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PodcastProvider>().fetchTrendingPodcasts();
    });
  }

  Future<void> _onRefresh() async {
    await context.read<PodcastProvider>().fetchTrendingPodcasts();
  }

  Future<void> _playPodcast(BuildContext context, {required String podcastId, required String podcastTitle, String? podcastImage}) async {
    final scaffold = ScaffoldMessenger.of(context);
    final podcasts = context.read<PodcastProvider>();
    final audio = context.read<SimpleAudioPlayerService>();
    try {
      await podcasts.getPodcastDetails(podcastId);
      if (podcasts.episodes.isEmpty) {
        scaffold.showSnackBar(const SnackBar(content: Text('No episodes available')));
        return;
      }
      final ep = podcasts.episodes.first;
      if (ep.audioUrl.isEmpty) {
        scaffold.showSnackBar(const SnackBar(content: Text('Episode has no playable audio URL')));
        return;
      }
      await audio.setUrlAndPlay(
        url: ep.audioUrl,
        title: ep.title,
        subtitle: podcastTitle,
      );
    } catch (e) {
      scaffold.showSnackBar(SnackBar(content: Text('Failed to play: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final podcasts = context.watch<PodcastProvider>();

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: _buildCategories(theme),
            ),
            _buildSectionHeader('Trending Podcasts'),
            Consumer<PodcastProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.trendingPodcasts.isEmpty) {
                  return SizedBox(height: 210.h, child: _buildTrendingShimmers());
                }
                if ((provider.error ?? '').isNotEmpty && provider.trendingPodcasts.isEmpty) {
                  return Center(child: Text(provider.error!));
                }

                final list = provider.trendingPodcasts;
                final hasImages = list.any((p) => p.imageUrl.isNotEmpty);

                // ✅ Horizontal cards if podcasts have images
                if (hasImages) {
                  return SizedBox(
                    height: 180.h,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      scrollDirection: Axis.horizontal,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => SizedBox(width: 12.w),
                      itemBuilder: (context, index) {
                        final p = list[index];
                        return _PodcastCard(
                          imageUrl: p.imageUrl,
                          title: p.title,
                          description: p.publisher,
                          duration: '${p.totalEpisodes} eps',
                          onPlay: () => _playPodcast(
                            context,
                            podcastId: p.id,
                            podcastTitle: p.title,
                            podcastImage: p.imageUrl,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PodcastDetailScreen(podcastId: p.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  );
                }

                // ✅ Vertical list if no images
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) {
                    final p = list[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        p.publisher,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_circle_fill),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () => _playPodcast(
                          context,
                          podcastId: p.id,
                          podcastTitle: p.title,
                          podcastImage: p.imageUrl,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PodcastDetailScreen(podcastId: p.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),

            _buildSectionHeader('Popular Speakers'),
            _buildPopularSpeakers(),
            _buildSectionHeader('Recommended for You'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: (podcasts.isLoading && podcasts.podcasts.isEmpty)
                  ? _buildGridShimmers()
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: ScreenUtil().screenWidth > 600 ? 3 : 2,
                        crossAxisSpacing: 12.w,
                        mainAxisSpacing: 12.h,
                        mainAxisExtent: 220.h,
                      ),
                      itemCount: podcasts.podcasts.length,
                      itemBuilder: (context, index) {
                        final p = podcasts.podcasts[index % (podcasts.podcasts.isEmpty ? 1 : podcasts.podcasts.length)];
                        return _PodcastCard(
                          imageUrl: p.imageUrl,
                          title: p.title,
                          description: p.publisher,
                          duration: '${p.totalEpisodes} eps',
                          onPlay: () => _playPodcast(context, podcastId: p.id, podcastTitle: p.title, podcastImage: p.imageUrl),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PodcastDetailScreen(podcastId: p.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories(ThemeData theme) {
    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        padding: EdgeInsets.only(right: 16.w),
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final bool selected = index == _selectedCategoryIndex;
          return ChoiceChip(
            label: Text(_categories[index]),
            selected: selected,
            onSelected: (v) {
              setState(() => _selectedCategoryIndex = index);
              context.read<PodcastProvider>().searchPodcasts(_categories[index]);
            },
            selectedColor: theme.colorScheme.primary.withOpacity(0.12),
            labelStyle: TextStyle(
              color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700)),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllPodcastsScreen(title: 'All Podcasts')),
              );
            },
            child: const Text('See all'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingShimmers() {
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      scrollDirection: Axis.horizontal,
      itemCount: 6,
      separatorBuilder: (_, __) => SizedBox(width: 12.w),
      itemBuilder: (context, index) => const _ShimmerCard(width: 260, height: 200),
    );
  }


  Widget _buildGridShimmers() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Wrap(
        spacing: 12.w,
        runSpacing: 12.h,
        children: List.generate(6, (index) => const _ShimmerCard(width: 180, height: 220)),
      ),
    );
  }

  Widget _buildPopularSpeakers() {
    final speakers = [
      {'name': 'Gary Vee', 'image': 'lib/assets/images/gary.png'},
      {'name': 'Joe Rogan', 'image': 'lib/assets/images/joe.png'},
      {'name': 'Michelle Obama', 'image': 'lib/assets/images/michelle.png'},
      {'name': 'Oprah Winfrey', 'image': 'lib/assets/images/oprah.png'},
    ];

    return SizedBox(
      height: 160.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        scrollDirection: Axis.horizontal,
        itemCount: speakers.length,
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemBuilder: (context, index) {
          final speaker = speakers[index];
          return _SpeakerCard(
            name: speaker['name']!,
            imagePath: speaker['image']!,
            onTap: () {
              // You can add navigation to speaker details here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${speaker['name']} tapped')),
              );
            },
          );
        },
      ),
    );
  }
}


class _PodcastCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String description;
  final String duration;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const _PodcastCard({
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.duration,
    required this.onTap,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 160,
        height: 180,
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              // Image with play button overlay
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 160,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 160,
                          height: double.infinity,
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 160,
                          height: double.infinity,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.podcasts_rounded, size: 40),
                        ),
                      ),
                    ),
                    // Play button positioned at bottom right of image
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onPlay,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Text content area
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Podcast title with ellipsis
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Publisher/subtitle with ellipsis
                      Flexible(
                        child: Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Duration at bottom
                      Text(
                        duration,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeakerCard extends StatelessWidget {
  final String name;
  final String imagePath;
  final VoidCallback onTap;

  const _SpeakerCard({
    required this.name,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        height: 160,
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Speaker Image
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.asset(
                  imagePath,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.person, size: 40),
                  ),
                ),
              ),

              // Speaker Name
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double width;
  final double height;
  const _ShimmerCard({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width.w,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShimmerBox(width: double.infinity, height: 110, radius: 12),
              SizedBox(height: 12.h),
              const _ShimmerBox(width: 140, height: 14, radius: 6),
              SizedBox(height: 8.h),
              const _ShimmerBox(width: 180, height: 12, radius: 6),
              SizedBox(height: 12.h),
              const _ShimmerBox(width: 80, height: 12, radius: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const _ShimmerBox({required this.width, required this.height, this.radius = 8});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.onSurface.withOpacity(0.06);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width == double.infinity ? double.infinity : widget.width.w,
          height: widget.height.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius.r),
            gradient: LinearGradient(
              begin: Alignment(-1.0, -0.3),
              end: const Alignment(2.0, 0.3),
              stops: [0.2, 0.5, 0.8],
              colors: [
                baseColor,
                highlight,
                baseColor,
              ],
              transform: GradientRotation(_controller.value * 6.283185307179586),
            ),
          ),
        );
      },
    );
  }
} 



