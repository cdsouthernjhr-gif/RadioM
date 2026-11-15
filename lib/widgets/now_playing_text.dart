import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/player/player_controller.dart';
import '../features/settings/settings_controller.dart';

/// RDS-style "now playing" panel for the full player: song title and artist
/// from the stream's own metadata. Renders nothing when the station sends no
/// metadata or the user turned it off in Settings.
class NowPlayingPanel extends StatelessWidget {
  const NowPlayingPanel({super.key, this.center = true});
  final bool center;

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsController>(); // rebuild when the setting changes
    final np = context.watch<PlayerController>().nowPlaying;
    if (np == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final align = center ? TextAlign.center : TextAlign.start;
    return Semantics(
      label: 'Kini bersiaran: ${np.text}',
      container: true,
      child: Container(
        key: const Key('now-playing-panel'),
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withOpacity(0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.music_note_rounded, size: 16, color: theme.colorScheme.secondary),
              const SizedBox(width: 4),
              Text('KINI BERSIARAN',
                  style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Text(np.headline,
                key: const Key('now-playing-title'),
                textAlign: align,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (np.artist != null)
              Text(np.artist!,
                  key: const Key('now-playing-artist'),
                  textAlign: align,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// One-line now-playing text for the mini player (null-safe, may be empty).
class NowPlayingLine extends StatelessWidget {
  const NowPlayingLine({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsController>();
    final np = context.watch<PlayerController>().nowPlaying;
    if (np == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Text(np.text,
          key: const Key('mini-now-playing'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
