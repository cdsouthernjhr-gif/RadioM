import 'package:flutter/material.dart';

import '../core/config/app_theme.dart';
import '../services/player_types.dart';

class PlayerStatusChip extends StatelessWidget {
  const PlayerStatusChip({super.key, required this.status});
  final PlayerStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PlayerStatus.playing => AppColors.success,
      PlayerStatus.paused || PlayerStatus.idle => Colors.blueGrey,
      PlayerStatus.loading || PlayerStatus.buffering || PlayerStatus.reconnecting => AppColors.warning,
      PlayerStatus.error => AppColors.error,
      PlayerStatus.offline => Colors.grey,
    };
    return Container(
      key: const Key('player-status'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (status.isBusy)
          SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: color))
        else
          Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ]),
    );
  }
}
