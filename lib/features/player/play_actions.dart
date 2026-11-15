import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/radio_station.dart';
import '../../services/player_types.dart';
import '../../widgets/full_player.dart';
import 'player_controller.dart';

/// Shared tap handler: plays direct/unverified streams in-app, opens the
/// official web player for web-only stations, and explains failures.
///
/// Pressing the station that is already loaded opens the full-screen player
/// (logo, now playing, volume) instead of restarting the stream. This is how
/// TV-remote users reach the full player: the mini player at the bottom is
/// awkward to reach with a D-pad.
Future<void> playOrOpen(BuildContext context, RadioStation station) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final pc = context.read<PlayerController>();
  if (pc.isCurrent(station)) {
    if (pc.status == PlayerStatus.paused) unawaited(pc.toggle());
    await FullPlayer.open(context);
    return;
  }
  if (station.streamType == StreamType.unverified) {
    messenger?.showSnackBar(SnackBar(
      content: Text('${station.name}: strim belum disahkan. Cubaan main mungkin gagal.'),
      duration: const Duration(seconds: 3),
    ));
  }
  final res = await context.read<PlayerController>().play(station);
  if (res == PlayRequestResult.openedWebPlayer) {
    messenger?.showSnackBar(SnackBar(content: Text('Membuka pemain web rasmi ${station.name}')));
  } else if (res == PlayRequestResult.failed) {
    messenger?.showSnackBar(SnackBar(
      content: Text('${station.name}: tiada strim terus dan pelayar tidak tersedia.'),
    ));
  }
}
