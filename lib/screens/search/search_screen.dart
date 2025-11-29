import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/podcast_provider.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/api_services.dart';
import '../../models/podcast_models.dart';
import '../podcast_detail/podcast_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  
  const SearchScreen({super.key, this.onBackPressed});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  bool _isLoading = false;
  bool _showSuggestions = false;
  final LocalStorageService _localStorage = LocalStorageService();
  final ApiService _api = ApiService();
  List<String> _recentSearches = [];
  List<String> _suggestions = [];
  List<Podcast> _results = [];
  List<Podcast> _allPodcasts = []; // All available podcasts for client-side filtering

  // Filters
  String? _selectedCategory; // e.g., Technology, Business, Health
  RangeValues _durationRange = const RangeValues(0, 120); // minutes
  DateTimeRange? _dateRange; // published between

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // Load persisted search history
    _recentSearches = _localStorage.getSearchHistory();
    // Load initial podcasts for client-side filtering
    _loadInitialPodcasts();
  }

  Future<void> _loadInitialPodcasts() async {
    try {
      // Load trending podcasts as initial dataset
      await context.read<PodcastProvider>().fetchTrendingPodcasts();
      final provider = context.read<PodcastProvider>();
      setState(() {
        _allPodcasts = List.from(provider.trendingPodcasts);
        // Also try to get regular podcasts if available
        if (provider.podcasts.isNotEmpty) {
          _allPodcasts.addAll(provider.podcasts);
        }
      });
    } catch (e) {
      print('Error loading initial podcasts: $e');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() => _showSuggestions = query.isNotEmpty);

    // Apply client-side filtering immediately (like episodes list)
    _applyClientSideFilter(query);

    // Also do API search with debounce for more results
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _performApiSearch(query);
      _loadSuggestions(query);
    });
  }

  // Client-side filtering (immediate, like episodes list)
  void _applyClientSideFilter(String query) {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    final q = query.toLowerCase();
    setState(() {
      _results = _allPodcasts.where((p) {
        return p.title.toLowerCase().contains(q) ||
               p.publisher.toLowerCase().contains(q) ||
               p.description.toLowerCase().contains(q) ||
               p.genres.any((genre) => genre.toLowerCase().contains(q));
      }).toList();
    });
  }

  // API search (with debounce, for more comprehensive results)
  Future<void> _performApiSearch(String query) async {
    if (query.isEmpty) {
      return;
    }

    try {
      // Use provider to fetch real podcasts from API
      await context.read<PodcastProvider>().searchPodcasts(query);
      final fetched = context.read<PodcastProvider>().podcasts;

      // Merge API results with existing results (avoid duplicates)
      final existingIds = _results.map((p) => p.id).toSet();
      final newResults = fetched.where((p) => !existingIds.contains(p.id)).toList();

      setState(() {
        _allPodcasts.addAll(newResults); // Add to all podcasts for future filtering
        _results.addAll(newResults); // Add to current results
      });

      // Persist search history
      await _localStorage.addToSearchHistory(query);
      setState(() => _recentSearches = _localStorage.getSearchHistory());
    } catch (e) {
      // Silently fail - client-side filtering still works
      print('API search error: $e');
    }
  }

  Future<void> _loadSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    try {
      final trending = await _api.getTrendingSearches();
      final fromHistory = _recentSearches
          .where((s) => s.toLowerCase().contains(query.toLowerCase()))
          .toList();
      final merged = {
        ...fromHistory,
        ...trending.where((s) => s.toLowerCase().contains(query.toLowerCase())),
      }.toList();
      setState(() => _suggestions = merged.take(8).toList());
    } catch (_) {
      setState(() => _suggestions = []);
    }
  }

  // Filters UI removed; keep state for future use if needed

  void _clearHistory() {
    _localStorage.clearSearchHistory();
    setState(() => _recentSearches = []);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        leading: widget.onBackPressed != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackPressed,
              )
            : (Navigator.of(context).canPop()
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null),
        title: _SearchBar(
          controller: _searchController,
          focusNode: _focusNode,
          onClear: () {
            _searchController.clear();
            setState(() {
              _showSuggestions = false;
              _results = [];
            });
          },
        ),
      ),
      body: Stack(
        children: [
          if (query.isEmpty) _buildRecentSearches(theme) else _buildResults(theme),
          if (_showSuggestions && _suggestions.isNotEmpty) _buildSuggestionsOverlay(),
        ],
      ),
    );
  }

  Widget _buildRecentSearches(ThemeData theme) {
    if (_recentSearches.isEmpty) {
      return _emptyState('Start typing to search podcasts');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent searches', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              TextButton(onPressed: _clearHistory, child: const Text('Clear')),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _recentSearches.length,
            padding: const EdgeInsets.only(bottom: 24),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final term = _recentSearches[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(term),
                trailing: IconButton(
                  icon: const Icon(Icons.north_west_rounded),
                  onPressed: () {
                    _searchController.text = term;
                    _searchController.selection = TextSelection.fromPosition(TextPosition(offset: term.length));
                    _applyClientSideFilter(term);
                    _performApiSearch(term);
                  },
                ),
                onTap: () {
                  _searchController.text = term;
                  _searchController.selection = TextSelection.fromPosition(TextPosition(offset: term.length));
                  _applyClientSideFilter(term);
                  _performApiSearch(term);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResults(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return _emptyState('No results found');
    }
    return ListView.separated(
      itemCount: _results.length,
      padding: const EdgeInsets.only(bottom: 24),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = _results[index];
        final title = p.title.isNotEmpty ? p.title : 'Untitled Podcast';
        final publisher = p.publisher.isNotEmpty ? p.publisher : 'Unknown Publisher';
        
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: p.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: p.imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 56,
                      height: 56,
                      color: theme.colorScheme.surfaceVariant,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 56,
                      height: 56,
                      color: theme.colorScheme.surfaceVariant,
                      child: Icon(Icons.podcasts_rounded, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: theme.colorScheme.surfaceVariant,
                    child: Icon(Icons.podcasts_rounded, color: theme.colorScheme.onSurfaceVariant),
                  ),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            publisher,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PodcastDetailScreen(podcastId: p.id),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSuggestionsOverlay() {
    final query = _searchController.text.trim();
    return Positioned(
      left: 12,
      right: 12,
      top: kToolbarHeight + 4,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _suggestions.length,
            itemBuilder: (context, index) {
              final s = _suggestions[index];
              return ListTile(
                leading: const Icon(Icons.search),
                title: _highlightedText(s, query),
                onTap: () {
                  _searchController.text = s;
                  _searchController.selection = TextSelection.fromPosition(TextPosition(offset: s.length));
                  setState(() => _showSuggestions = false);
                  _applyClientSideFilter(s);
                  _performApiSearch(s);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.podcasts_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _highlightedText(String full, String query) {
    if (query.isEmpty) return Text(full);
    final lower = full.toLowerCase();
    final q = query.toLowerCase();
    final index = lower.indexOf(q);
    if (index == -1) return Text(full);
    final before = full.substring(0, index);
    final match = full.substring(index, index + q.length);
    final after = full.substring(index + q.length);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: before, style: DefaultTextStyle.of(context).style),
          TextSpan(text: match, style: DefaultTextStyle.of(context).style.copyWith(fontWeight: FontWeight.bold)),
          TextSpan(text: after, style: DefaultTextStyle.of(context).style),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;
  const _SearchBar({required this.controller, required this.focusNode, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.search),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  hintText: 'Search podcasts',
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {},
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close_rounded),
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  final String? initialCategory;
  final RangeValues initialDuration;
  final DateTimeRange? initialDateRange;

  const _FiltersSheet({
    required this.initialCategory,
    required this.initialDuration,
    required this.initialDateRange,
  });

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  final List<String> _categories = const ['Technology','Business','Health','Education','Entertainment'];
  String? _category;
  late RangeValues _duration;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _duration = widget.initialDuration;
    _dateRange = widget.initialDateRange;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filters', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _category = null;
                      _duration = const RangeValues(0, 120);
                      _dateRange = null;
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            Text('Duration (minutes)', style: theme.textTheme.labelLarge),
            RangeSlider(
              values: _duration,
              min: 0,
              max: 180,
              divisions: 36,
              labels: RangeLabels(_duration.start.round().toString(), _duration.end.round().toString()),
              onChanged: (v) => setState(() => _duration = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(_dateRange == null ? 'Select date range' : '${_dateRange!.start.toString().split(' ').first} - ${_dateRange!.end.toString().split(' ').first}'),
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(now.year - 5),
                        lastDate: DateTime(now.year + 1),
                        initialDateRange: _dateRange,
                      );
                      if (picked != null) setState(() => _dateRange = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Apply filters'),
                onPressed: () {
                  Navigator.pop(context, _FiltersResult(
                    category: _category,
                    duration: _duration,
                    dateRange: _dateRange,
                  ));
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _FiltersResult {
  final String? category;
  final RangeValues duration;
  final DateTimeRange? dateRange;
  _FiltersResult({required this.category, required this.duration, required this.dateRange});
}

