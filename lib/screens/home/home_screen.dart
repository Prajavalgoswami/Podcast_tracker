import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/podcast_provider.dart';
import '../../core/services/audio_player_service.dart';
import 'all_podcasts_screen.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _categories = const [
    'Technology', 'Business', 'Health', 'Education', 'Entertainment', 'Science', 'Sports', 'Lifestyle'
  ];
  
  bool _isLoading = true;
  int _selectedCategoryIndex = 0;
  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PodcastProvider>().getBestPodcasts();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _onRefresh() async {
    await context.read<PodcastProvider>().getBestPodcasts();
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
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: _buildCategories(theme),
            ),
          ),
          SliverToBoxAdapter(child: _buildSectionHeader('Trending Podcasts')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 210.h,
              child: (podcasts.isLoading && podcasts.podcasts.isEmpty)
                  ? _buildTrendingShimmers()
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      scrollDirection: Axis.horizontal,
                      itemCount: podcasts.podcasts.length,
                      separatorBuilder: (_, __) => SizedBox(width: 12.w),
                      itemBuilder: (context, index) {
                        final p = podcasts.podcasts[index];
                        return _PodcastCard(
                          imageUrl: p.imageUrl,
                          title: p.title,
                          description: p.publisher,
                          duration: '${p.totalEpisodes} eps',
                          onPlay: () => _playPodcast(context, podcastId: p.id, podcastTitle: p.title, podcastImage: p.imageUrl),
                        );
                      },
                    ),
            ),
          ),
          SliverToBoxAdapter(child: _buildSectionHeader('Recently Played')),
          _isLoading
              ? SliverToBoxAdapter(child: _buildRecentShimmers())
              : SliverList.builder(
                  itemCount: 6,
                  itemBuilder: (context, index) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: Image.network(
                          'https://picsum.photos/seed/recent$index/100/100',
                          width: 56.w,
                          height: 56.w,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text('Recent Episode $index', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Host · ${(12 + index)} min', maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
                      onTap: () async {
                        final audio = context.read<SimpleAudioPlayerService>();
                        await audio.setUrlAndPlay(
                          url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
                          title: 'Recent Episode $index',
                          subtitle: 'Sample audio',
                        );
                      },
                    ),
                  ),
                ),
          SliverToBoxAdapter(child: _buildSectionHeader('Recommended for You')),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            sliver: (podcasts.isLoading && podcasts.podcasts.isEmpty)
                ? SliverToBoxAdapter(child: _buildGridShimmers())
                : SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final p = podcasts.podcasts[index % (podcasts.podcasts.isEmpty ? 1 : podcasts.podcasts.length)];
                        return _PodcastCard(
                          imageUrl: p.imageUrl,
                          title: p.title,
                          description: p.publisher,
                          duration: '${p.totalEpisodes} eps',
                          onPlay: () => _playPodcast(context, podcastId: p.id, podcastTitle: p.title, podcastImage: p.imageUrl),
                        );
                      },
                      childCount: podcasts.podcasts.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: ScreenUtil().screenWidth > 600 ? 3 : 2,
                      crossAxisSpacing: 12.w,
                      mainAxisSpacing: 12.h,
                      mainAxisExtent: 220.h,
                    ),
                  ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 24.h)),
        ],
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

  Widget _buildRecentShimmers() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: List.generate(
          4,
          (index) => Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Row(
              children: [
                const _ShimmerBox(width: 56, height: 56, radius: 8),
                SizedBox(width: 12.w),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBox(width: 180, height: 14, radius: 6),
                      SizedBox(height: 8),
                      _ShimmerBox(width: 120, height: 12, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
}

class _PodcastCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String description;
  final String duration;
  final VoidCallback onPlay;

  const _PodcastCard({
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.duration,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 260.w,
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                imageUrl.isNotEmpty ? imageUrl : 'https://via.placeholder.com/640x360?text=No+Image',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade300,
                  child: const Center(child: Icon(Icons.podcasts_rounded)),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6.h),
                  Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12.sp)),
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(Icons.schedule, size: 16.sp, color: theme.colorScheme.primary),
                        SizedBox(width: 4.w),
                        Text(duration, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),
                      ]),
                      IconButton(
                        icon: const Icon(Icons.play_circle_fill),
                        color: theme.colorScheme.primary,
                        onPressed: onPlay,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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



