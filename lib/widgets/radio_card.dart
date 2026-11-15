import 'package:flutter/material.dart';

import '../data/models/radio_station.dart';
import 'station_logo.dart';
import 'status_badge.dart';
import 'tv_focusable.dart';

/// Square card used in horizontal home rows.
class RadioCard extends StatelessWidget {
  const RadioCard({
    super.key,
    required this.station,
    required this.onTap,
    this.onLongPress,
    this.isPlaying = false,
    this.width = 140,
    this.autofocus = false,
  });

  final RadioStation station;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isPlaying;
  final double width;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: TvFocusable(
        onTap: onTap,
        onLongPress: onLongPress,
        autofocus: autofocus,
        semanticLabel: 'Mainkan ${station.name}',
        child: Card(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(children: [
                  StationLogo(station: station, size: width - 20),
                  if (isPlaying)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: theme.colorScheme.secondary,
                        child: Icon(Icons.graphic_eq, size: 16, color: theme.colorScheme.onSecondary),
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
                Text(station.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(station.primaryFrequency ?? (station.state ?? station.network ?? ''),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Row used in the directory and favorites lists.
class StationListTile extends StatelessWidget {
  const StationListTile({
    super.key,
    required this.station,
    required this.onTap,
    this.isPlaying = false,
    this.isFavorite = false,
    this.onFavorite,
    this.trailing,
    this.autofocus = false,
    this.onLongPress,
  });

  final RadioStation station;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final Widget? trailing;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      if (station.primaryFrequency != null) station.primaryFrequency!,
      if (station.state != null) station.state! else 'Nasional',
      if (station.network != null) station.network!,
    ].join(' • ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TvFocusable(
        onTap: onTap,
        onLongPress: onLongPress,
        autofocus: autofocus,
        semanticLabel: 'Mainkan ${station.name}',
        child: Card(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(isPlaying ? 0.95 : 0.5),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              StationLogo(station: station, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(station.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (isPlaying) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.graphic_eq, size: 18, color: theme.colorScheme.secondary),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  StationStatusBadge(station: station, dense: true),
                ]),
              ),
              if (onFavorite != null)
                IconButton(
                  tooltip: isFavorite ? 'Buang kegemaran' : 'Tambah kegemaran',
                  icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? theme.colorScheme.secondary : null),
                  onPressed: onFavorite,
                ),
              if (trailing != null) trailing!,
            ]),
          ),
        ),
      ),
    );
  }
}
