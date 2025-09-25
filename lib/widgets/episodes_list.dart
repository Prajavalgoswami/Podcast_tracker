import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/podcast_models.dart';
import 'episode_card.dart';

enum EpisodesSortOption { newest, oldest, duration }

class EpisodesList extends StatefulWidget {
  const EpisodesList({
    Key? key,
    required this.episodes,
    this.onRefresh,
    this.onLoadMore,
    this.onFavorite,
    this.onShare,
    this.enableMock = false,
  }) : super(key: key);

  final List<Episode> episodes;
  final Future<void> Function()? onRefresh;
  final Future<List<Episode>> Function(int nextPage)? onLoadMore;
  final Future<void> Function(Episode episode, bool isFavorite)? onFavorite;
  final Future<void> Function(Episode episode)? onShare;
  final bool enableMock;

  @override
  State<EpisodesList> createState() => _EpisodesListState();
}

class _EpisodesListState extends State<EpisodesList> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Episode> _displayed = [];
  int _page = 1;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  bool _hasMore = true;
  EpisodesSortOption _sort = EpisodesSortOption.newest;

  @override
  void initState() {
    super.initState();
    _displayed = [...widget.episodes];
    if (_displayed.isEmpty && widget.enableMock) {
      _displayed = _generateMockEpisodes();
    }
    _applySort();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_applySearchFilter);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  
  


@override
Widget build(BuildContext context) {
  return RefreshIndicator(
    onRefresh: _handleRefresh,
    child: CustomScrollView(
      controller: _scrollController,
      slivers: [
        // 🔍 Search + Sort bar (sticks to top)
        SliverToBoxAdapter(child: _buildSearchAndSortBar()),

        if (_displayed.isEmpty && (_isRefreshing || _isLoadingMore))
          _buildLoadingSkeletonSliver()
        else if (_displayed.isEmpty)
          _buildEmptyStateSliver(context)
        else ..._buildEpisodeSlivers(context),

        if (_isLoadingMore) _buildLoadingSkeletonSliver(),
        SliverPadding(padding: EdgeInsets.only(bottom: 80.h)), // space for mini player
      ],
    ),
  );
}

List<Widget> _buildEpisodeSlivers(BuildContext context) {
  final grouped = _groupByDate(_displayed);
  final slivers = <Widget>[];

  grouped.forEach((header, episodes) {
    slivers.add(_StickyHeader(title: header));
    slivers.add(
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final ep = episodes[index];
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              child: EpisodeCard(
                episode: ep,
              ),
            );
          },
          childCount: episodes.length,
        ),
      ),
    );
  });

  return slivers;
}



  Widget _buildSearchAndSortBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 4.h),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search episodes...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          PopupMenuButton<EpisodesSortOption>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            onSelected: (value) {
              setState(() => _sort = value);
              _applySort();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: EpisodesSortOption.newest,
                child: Text('Newest'),
              ),
              const PopupMenuItem(
                value: EpisodesSortOption.oldest,
                child: Text('Oldest'),
              ),
              const PopupMenuItem(
                value: EpisodesSortOption.duration,
                child: Text('Duration'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Map<String, List<Episode>> _groupByDate(List<Episode> episodes) {
    final map = <String, List<Episode>>{};
    for (final ep in episodes) {
      final key = _dateHeaderFor(ep.pubDateMs);
      map.putIfAbsent(key, () => []).add(ep);
    }
    return map;
  }

  String _dateHeaderFor(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This week';
    if (diff < 14) return 'Last week';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  SliverToBoxAdapter _buildEmptyStateSliver(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 48.h),
        child: Column(
          children: [
            Icon(Icons.podcasts_rounded, size: 72.sp, color: Colors.grey.shade400),
            SizedBox(height: 12.h),
            Text(
              'No episodes found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 6.h),
            Text(
              'Try adjusting your search or filters',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildLoadingSkeletonSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        child: Column(
          children: List.generate(5, (index) => _EpisodeSkeleton()).toList(),
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
    setState(() {
      _displayed = [...widget.episodes];
      _applySearchFilter();
      _applySort();
      _isRefreshing = false;
      _page = 1;
      _hasMore = true;
    });
  }

  void _onScroll() async {
    if (_isLoadingMore || !_hasMore || widget.onLoadMore == null) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      setState(() => _isLoadingMore = true);
      final next = _page + 1;
      final more = await widget.onLoadMore!(next);
      setState(() {
        _page = next;
        if (more.isEmpty) {
          _hasMore = false;
        } else {
          _displayed.addAll(more);
          _applySearchFilter();
          _applySort();
        }
        _isLoadingMore = false;
      });
    }
  }

  void _applySearchFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _displayed = [...widget.episodes];
      } else {
        _displayed = widget.episodes.where((e) {
          return e.title.toLowerCase().contains(q) || e.description.toLowerCase().contains(q);
        }).toList();
      }
      _applySort();
    });
  }

  void _applySort() {
    _displayed.sort((a, b) {
      switch (_sort) {
        case EpisodesSortOption.newest:
          return b.pubDateMs.compareTo(a.pubDateMs);
        case EpisodesSortOption.oldest:
          return a.pubDateMs.compareTo(b.pubDateMs);
        case EpisodesSortOption.duration:
          return b.audioLengthSec.compareTo(a.audioLengthSec);
      }
    });
    setState(() {});
  }

  List<Episode> _generateMockEpisodes() {
    final now = DateTime.now();
    final titles = [
      'The Future of AI in Mobile Development',
      'Building Scalable Flutter Apps',
      'Interview with Google Flutter Team',
      'Mastering Flutter Performance',
      'State Management Showdown',
      'Animations that Delight',
      'Networking Best Practices',
      'Testing Flutter Like a Pro',
      'Accessibility in Mobile Apps',
      'Deploying at Scale',
      'Design Systems for Flutter',
      'Offline-first Architectures',
      'Monetization Strategies',
      'Internationalization Deep Dive',
      'What’s New in Flutter',
    ];

    return List<Episode>.generate(titles.length, (index) {
      final minutes = 20 + (index * 3) % 40;
      return Episode(
        id: 'mock_ep_$index',
        title: titles[index],
        description: 'A realistic discussion on ${titles[index].toLowerCase()} with practical tips and insights.',
        audioUrl: 'https://example.com/audio/mock/ep$index.mp3',
        imageUrl: 'https://picsum.photos/seed/ep$index/200/200',
        audioLengthSec: minutes * 60 + index,
        pubDateMs: now.subtract(Duration(days: (index + 1))),
        podcastId: 'mock_podcast',
      );
    });
  }
}

class _EpisodeSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Container(
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14.h, width: 220.w, color: Colors.grey.shade300),
                SizedBox(height: 8.h),
                Container(height: 12.h, width: 260.w, color: Colors.grey.shade300),
                SizedBox(height: 8.h),
                Container(height: 12.h, width: 160.w, color: Colors.grey.shade300),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _StickyHeader extends StatelessWidget {
  const _StickyHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickyHeaderDelegate(title: title),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyHeaderDelegate({required this.title});
  final String title;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 36.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      alignment: Alignment.centerLeft,
      color: Theme.of(context).colorScheme.surface,
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }

  @override
  double get maxExtent => 36.h;

  @override
  double get minExtent => 36.h;

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.title != title;
  }
}
