import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/podcast_provider.dart';
import '../../providers/audio_provider.dart';
import 'all_podcasts_screen.dart';
import '../podcast_detail/podcast_detail_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
 
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
    final audio = context.read<AudioProvider>();
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
      await audio.playEpisode(ep);
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

            _buildSectionHeader('Trending Podcasts'),
            Consumer<PodcastProvider>(
              builder: (context, provider, _) {
                // Show loading state
                if (provider.isLoading && provider.trendingPodcasts.isEmpty) {
                  return SizedBox(height: 210.h, child: _buildTrendingShimmers());
                }
                
                // Show error state
                if ((provider.error ?? '').isNotEmpty && provider.trendingPodcasts.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Center(
                      child: Column(
                        children: [
                          Text(provider.error!, style: theme.textTheme.bodyMedium),
                          SizedBox(height: 8.h),
                          TextButton(
                            onPressed: () => provider.fetchTrendingPodcasts(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final list = provider.trendingPodcasts;
                
                // Debug logging
                debugPrint('📊 Trending podcasts count: ${list.length}');
                debugPrint('📊 Is loading: ${provider.isLoading}');
                debugPrint('📊 Error: ${provider.error}');
                
                // Show empty state
                if (list.isEmpty) {
                  debugPrint('⚠️ Trending podcasts list is empty');
                  return Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            'No trending podcasts available',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          TextButton(
                            onPressed: () {
                              debugPrint('🔄 Retrying to fetch trending podcasts...');
                              provider.fetchTrendingPodcasts();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final hasImages = list.any((p) => p.imageUrl.isNotEmpty);
                debugPrint('📊 Has images: $hasImages');
                debugPrint('📊 First podcast: ${list.first.title}');

                // ✅ Horizontal cards if podcasts have images
                if (hasImages) {
                  return SizedBox(
                    height: kIsWeb ? 200.0 : 180.h,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 16.0 : 16.w),
                      scrollDirection: Axis.horizontal,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => SizedBox(width: kIsWeb ? 12.0 : 12.w),
                      itemBuilder: (context, index) {
                        final p = list[index];
                        debugPrint('🎨 Rendering podcast card $index: ${p.title}');
                        return SizedBox(
                          width: kIsWeb ? 140.0 : 140.w,
                          height: kIsWeb ? 200.0 : 180.h,
                          child: _PodcastCard(
                            imageUrl: p.imageUrl,
                            title: p.title.isNotEmpty ? p.title : 'Untitled Podcast',
                            description: p.publisher.isNotEmpty ? p.publisher : 'Unknown Publisher',
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
                          ),
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
                        p.title.isNotEmpty ? p.title : 'Untitled Podcast',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        p.publisher.isNotEmpty ? p.publisher : 'Unknown Publisher',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
                          title: p.title.isNotEmpty ? p.title : 'Untitled Podcast',
                          description: p.publisher.isNotEmpty ? p.publisher : 'Unknown Publisher',
                          duration: '${p.totalEpisodes} eps',
                          onPlay: () => _playPodcast(context, podcastId: p.id, podcastTitle: p.title, podcastImage: p.imageUrl),
                          onTap: () async {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(child: CircularProgressIndicator()),
                            );

                            final provider = Provider.of<PodcastProvider>(context, listen: false);
                            debugPrint("➡ Fetch podcast: ${p.id}");
                            debugPrint("🎧 Episodes loaded: ${provider.episodes.length}");
                            debugPrint("⚠ Error: ${provider.detailError}");
                            await provider.fetchPodcastById(p.id);

                            Navigator.pop(context); // close loader

                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PodcastDetailScreen(podcastId: p.id)),
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
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kIsWeb ? 10.0 : 12.0)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image with play button overlay
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(kIsWeb ? 10.0 : 12.0)),
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: Colors.grey.shade300,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: Colors.grey.shade300,
                              child: Icon(Icons.podcasts_rounded, size: 40, color: Colors.grey.shade600),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.grey.shade300,
                            child: Icon(Icons.podcasts_rounded, size: 40, color: Colors.grey.shade600),
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
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(kIsWeb ? 6.0 : 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Podcast title with ellipsis
                    Flexible(
                      flex: 2,
                      child: Text(
                        title.isNotEmpty ? title : 'Untitled Podcast',
                        maxLines: kIsWeb ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: kIsWeb ? 11.0 : 12.0,
                          height: 1.2,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(height: kIsWeb ? 2.0 : 2),
                    // Publisher/subtitle with ellipsis
                    Flexible(
                      flex: 1,
                      child: Text(
                        description.isNotEmpty ? description : 'Unknown Publisher',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: kIsWeb ? 9.0 : 10.0,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.2,
                        ),
                      ),
                    ),
                    SizedBox(height: kIsWeb ? 2.0 : 4),
                    // Duration at bottom
                    Text(
                      duration,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: kIsWeb ? 8.5 : 9.0,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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



