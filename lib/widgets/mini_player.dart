import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/player/player_controller.dart';
import '../services/player_types.dart';
import 'full_player.dart';
import 'now_playing_text.dart';
import 'player_status_chip.dart';
import 'station_logo.dart';
import 'tv_focusable.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = context.watch<PlayerController>();
    final station = pc.station;
    if (station == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final status = pc.status;
    final playingish = status == PlayerStatus.playing || status.isBusy;
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 8,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(children: [
            Expanded(
              child: TvFocusable(
                borderRadius: 12,
                semanticLabel: 'Buka pemain penuh',
                onTap: () => FullPlayer.open(context),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(children: [
                    StationLogo(station: station, size: 44, radius: 10),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(station.name,
                            key: const Key('mini-player-title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const NowPlayingLine(),
                        const SizedBox(height: 2),
                        PlayerStatusChip(status: status),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
            if (status.isBusy) const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
            ),
            IconButton(
              key: const Key('mini-play-pause'),
              iconSize: 36,
              tooltip: playingish ? 'Pause' : 'Play',
              icon: Icon(playingish ? Icons.pause_circle_filled : Icons.play_circle_fill),
              color: theme.colorScheme.secondary,
              onPressed: pc.toggle,
            ),
            IconButton(
              key: const Key('mini-stop'),
              tooltip: 'Stop',
              icon: const Icon(Icons.stop_rounded),
              onPressed: pc.stop,
            ),
          ]),
        ),
      ),
    );
  }
}
