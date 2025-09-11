import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/audio_player_service.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<SimpleAudioPlayerService>();
    final colorScheme = Theme.of(context).colorScheme;
    final title = audio.currentTitle.isEmpty ? 'Nothing Playing' : audio.currentTitle;
    final subtitle = audio.currentSubtitle.isEmpty ? 'Start playback to see controls' : audio.currentSubtitle;
    final position = audio.position;
    final duration = audio.duration ?? Duration.zero;

    return Material(
      elevation: 6,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primary.withOpacity(0.12),
                  child: Icon(Icons.graphic_eq, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    if (audio.isPlaying) {
                      await audio.pause();
                    } else {
                      await audio.play();
                    }
                  },
                  icon: Icon(audio.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: colorScheme.primary),
                ),
              ],
            ),
            Slider(
              min: 0,
              max: duration.inMilliseconds.toDouble().clamp(0.0, double.infinity),
              value: position.inMilliseconds.toDouble().clamp(0.0, (duration.inMilliseconds.toDouble().clamp(0.0, double.infinity))),
              onChanged: (v) async {
                await audio.seek(Duration(milliseconds: v.round()));
              },
            ),
          ],
        ),
      ),
    );
  }
}


