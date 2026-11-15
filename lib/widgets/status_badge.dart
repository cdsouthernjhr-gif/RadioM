import 'package:flutter/material.dart';

import '../core/config/app_theme.dart';
import '../data/models/radio_station.dart';

/// Shows the *verification* state of a station's stream. It deliberately does
/// not claim a station is on air: "Disahkan" means a CI test decoded audio.
class StationStatusBadge extends StatelessWidget {
  const StationStatusBadge({super.key, required this.station, this.dense = false});
  final RadioStation station;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (station.streamType) {
      StreamType.direct => ('Strim disahkan', AppColors.success, Icons.verified_rounded),
      StreamType.webPlayer => ('Pemain web', AppColors.warning, Icons.open_in_browser_rounded),
      StreamType.unverified => ('Belum disahkan', Colors.grey, Icons.help_outline_rounded),
    };
    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: dense ? 12 : 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: dense ? 10 : 11, color: color, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
