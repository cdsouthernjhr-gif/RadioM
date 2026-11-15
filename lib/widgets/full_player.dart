import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config/app_theme.dart';
import '../features/home/library_controller.dart';
import '../features/player/player_controller.dart';
import '../services/player_types.dart';
import 'audio_wave.dart';
import 'player_status_chip.dart';
import 'station_logo.dart';
import 'status_badge.dart';

class FullPlayer extends StatelessWidget {
  const FullPlayer({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const FullPlayer(), fullscreenDialog: true),
      );

  @override
  Widget build(BuildContext context) {
    final pc = context.watch<PlayerController>();
    final lib = context.watch<LibraryController>();
    final station = pc.station;
    final theme = Theme.of(context);
    if (station == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Tiada stesen dimainkan')));
    }
    final status = pc.status;
    final playingish = status == PlayerStatus.playing || status.isBusy;
    final fav = lib.isFavorite(station.id);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sedang Dimainkan'),
        actions: [
          IconButton(
            tooltip: fav ? 'Buang kegemaran' : 'Tambah kegemaran',
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
            onPressed: () => lib.toggleFavorite(station.id),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: theme.brightness == Brightness.dark
                ? [AppColors.navy, AppColors.navyDeep]
                : [const Color(0xFFE6F7F5), theme.scaffoldBackgroundColor],
          ),
        ),
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > c.maxHeight && c.maxWidth > 700;
          final logoSize = (wide ? c.maxHeight * 0.55 : c.maxWidth * 0.62).clamp(140.0, 360.0);
          final art = Hero(tag: 'logo', child: StationLogo(station: station, size: logoSize, radius: 28));
          final info = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Text(station.name,
                  key: const Key('full-player-title'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                [station.network, station.primaryFrequency, station.state ?? 'Nasional'].whereType<String>().join(' • '),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
                PlayerStatusChip(status: status),
                StationStatusBadge(station: station),
                if (pc.snapshot.formatLabel != null) Chip(label: Text(pc.snapshot.formatLabel!), visualDensity: VisualDensity.compact),
              ]),
              if (pc.snapshot.message != null) ...[
                const SizedBox(height: 8),
                Text(pc.snapshot.message!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: status == PlayerStatus.error ? theme.colorScheme.error : null)),
              ],
              const SizedBox(height: 16),
              SizedBox(width: 320, child: AudioWave(active: status == PlayerStatus.playing)),
              const SizedBox(height: 16),
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton.filledTonal(
                  key: const Key('full-stop'),
                  iconSize: 32,
                  tooltip: 'Stop',
                  onPressed: pc.stop,
                  icon: const Icon(Icons.stop_rounded),
                ),
                const SizedBox(width: 20),
                IconButton.filled(
                  key: const Key('full-play-pause'),
                  autofocus: true,
                  iconSize: 56,
                  tooltip: playingish ? 'Pause' : 'Play',
                  onPressed: pc.toggle,
                  icon: Icon(playingish ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
                const SizedBox(width: 20),
                IconButton.filledTonal(
                  iconSize: 32,
                  tooltip: 'Cuba semula',
                  onPressed: () => pc.play(station),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: 340,
                child: Row(children: [
                  const Icon(Icons.volume_down_rounded),
                  Expanded(
                    child: Slider(
                      key: const Key('volume-slider'),
                      value: pc.volume,
                      onChanged: pc.setVolume,
                      label: '${(pc.volume * 100).round()}%',
                      divisions: 20,
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded),
                ]),
              ),
              if (station.website != null)
                TextButton.icon(
                  onPressed: () => PlayerController.openWebPlayer(station),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Laman rasmi'),
                ),
            ],
          );
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: wide
                  ? Row(mainAxisSize: MainAxisSize.min, children: [art, const SizedBox(width: 40), Flexible(child: info)])
                  : Column(mainAxisSize: MainAxisSize.min, children: [art, const SizedBox(height: 24), info]),
            ),
          );
        }),
      ),
    );
  }
}
