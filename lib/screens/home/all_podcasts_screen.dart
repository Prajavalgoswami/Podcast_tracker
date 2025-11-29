import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/podcast_provider.dart';
import '../../providers/audio_provider.dart';
import '../podcast_detail/podcast_detail_screen.dart';

class AllPodcastsScreen extends StatefulWidget {
  const AllPodcastsScreen({super.key, this.title = 'All Podcasts'});
  final String title;

  @override
  State<AllPodcastsScreen> createState() => _AllPodcastsScreenState();
}

class _AllPodcastsScreenState extends State<AllPodcastsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch best podcasts when screen loads
    Future.microtask(() =>
        context.read<PodcastProvider>().fetchTrendingPodcasts());
  }

  Future<void> _playPodcast(BuildContext context,
      {required String podcastId, required String podcastTitle}) async {
    final scaffold = ScaffoldMessenger.of(context);
    final provider = context.read<PodcastProvider>();
    final audio = context.read<AudioProvider>();

    try {
      await provider.getPodcastDetails(podcastId);
      if (provider.episodes.isEmpty) {
        scaffold.showSnackBar(const SnackBar(content: Text('No episodes available')));
        return;
      }
      final ep = provider.episodes.first;
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
    final provider = context.watch<PodcastProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.trendingPodcasts.isEmpty
              ? const Center(child: Text('No podcasts to show'))
              : ListView.separated(
                  itemCount: provider.trendingPodcasts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = provider.trendingPodcasts[index];
                    final imageUrl = p.imageUrl.isNotEmpty
                        ? p.imageUrl
                        : 'https://via.placeholder.com/200x200?text=No+Image';
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.podcasts_rounded),
                          ),
                        ),
                      ),
                      title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(p.publisher, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_circle_fill),
                        onPressed: () => _playPodcast(
                          context,
                          podcastId: p.id,
                          podcastTitle: p.title,
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
                ),
    );
  }
}
