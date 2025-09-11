import 'dart:async';
import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  bool _isLoading = false;
  bool _showSuggestions = false;
  List<String> _recentSearches = ['AI podcasts', 'Business news', 'Health tips'];
  List<String> _suggestions = [];
  List<_PodcastResult> _results = [];

  // Filters
  String? _selectedCategory; // e.g., Technology, Business, Health
  RangeValues _durationRange = const RangeValues(0, 120); // minutes
  DateTimeRange? _dateRange; // published between

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
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

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _performSearch(query);
      _loadSuggestions(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isLoading = true);
    // Simulate network search
    await Future.delayed(const Duration(milliseconds: 700));

    // Mock results filtered by simple contains and filters
    final all = List.generate(12, (i) => _PodcastResult(
      thumbnailUrl: 'https://picsum.photos/seed/s$i/200/200',
      title: 'Podcast about $query #$i',
      creator: i % 2 == 0 ? 'Creator Alpha' : 'Creator Beta',
      durationMinutes: 10 + i * 5,
      rating: 3.5 + (i % 5) * 0.3,
      category: ['Technology','Business','Health','Education'][i % 4],
      date: DateTime.now().subtract(Duration(days: i * 3)),
    ));

    List<_PodcastResult> filtered = all
        .where((p) => p.title.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (_selectedCategory != null) {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }
    filtered = filtered
        .where((p) => p.durationMinutes >= _durationRange.start && p.durationMinutes <= _durationRange.end)
        .toList();
    if (_dateRange != null) {
      filtered = filtered.where((p) => p.date.isAfter(_dateRange!.start) && p.date.isBefore(_dateRange!.end)).toList();
    }

    setState(() {
      _results = filtered;
      _isLoading = false;
      if (query.isNotEmpty) {
        _recentSearches.remove(query);
        _recentSearches.insert(0, query);
        if (_recentSearches.length > 10) _recentSearches = _recentSearches.sublist(0, 10);
      }
    });
  }

  Future<void> _loadSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    // Simulate suggestion fetch
    await Future.delayed(const Duration(milliseconds: 200));
    setState(() {
      _suggestions = List.generate(5, (i) => '$query suggestion ${i + 1}');
    });
  }

  void _openFilters() async {
    final result = await showModalBottomSheet<_FiltersResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _FiltersSheet(
        initialCategory: _selectedCategory,
        initialDuration: _durationRange,
        initialDateRange: _dateRange,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedCategory = result.category;
        _durationRange = result.duration;
        _dateRange = result.dateRange;
      });
      // Re-run search with new filters
      _performSearch(_searchController.text.trim());
    }
  }

  void _clearHistory() {
    setState(() => _recentSearches.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
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
        actions: [
          IconButton(
            tooltip: 'Filters',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openFilters,
          ),
          const SizedBox(width: 4),
        ],
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
                    _performSearch(term);
                  },
                ),
                onTap: () {
                  _searchController.text = term;
                  _searchController.selection = TextSelection.fromPosition(TextPosition(offset: term.length));
                  _performSearch(term);
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
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(p.thumbnailUrl, width: 56, height: 56, fit: BoxFit.cover),
          ),
          title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Row(
            children: [
              Expanded(child: Text(p.creator, maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              const Icon(Icons.schedule, size: 14),
              const SizedBox(width: 2),
              Text('${p.durationMinutes}m'),
              const SizedBox(width: 8),
              const Icon(Icons.star_rate_rounded, size: 16, color: Colors.amber),
              Text(p.rating.toStringAsFixed(1)),
            ],
          ),
          onTap: () {},
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
                  _performSearch(s);
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

class _PodcastResult {
  final String thumbnailUrl;
  final String title;
  final String creator;
  final int durationMinutes;
  final double rating;
  final String category;
  final DateTime date;

  _PodcastResult({
    required this.thumbnailUrl,
    required this.title,
    required this.creator,
    required this.durationMinutes,
    required this.rating,
    required this.category,
    required this.date,
  });
}



