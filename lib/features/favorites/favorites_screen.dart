import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/radio_card.dart';
import '../home/library_controller.dart';
import '../../widgets/logo_editor.dart';
import '../player/play_actions.dart';
import '../player/player_controller.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final playingId = context.select<PlayerController, String?>((p) => p.station?.id);
    final favs = lib.favorites;
    return Scaffold(
      appBar: AppBar(title: const Text('Kegemaran')),
      body: favs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Tiada kegemaran lagi.\nTekan ♡ pada mana-mana stesen untuk menambah.',
                    textAlign: TextAlign.center),
              ),
            )
          : ReorderableListView.builder(
              key: const Key('favorites-list'),
              buildDefaultDragHandles: false,
              itemCount: favs.length,
              onReorder: lib.reorderFavorite,
              itemBuilder: (context, i) {
                final s = favs[i];
                return StationListTile(
                  key: ValueKey('fav-${s.id}'),
                  station: s,
                  isPlaying: playingId == s.id,
                  isFavorite: true,
                  onFavorite: () => lib.toggleFavorite(s.id),
                  onTap: () => playOrOpen(context, s),
                  onLongPress: () => showLogoEditor(context, s),
                  // Up/down buttons make reordering possible with a TV remote.
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Naik',
                      icon: const Icon(Icons.keyboard_arrow_up),
                      onPressed: i == 0 ? null : () => lib.reorderFavorite(i, i - 1),
                    ),
                    IconButton(
                      tooltip: 'Turun',
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: i == favs.length - 1 ? null : () => lib.reorderFavorite(i, i + 2),
                    ),
                    ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                  ]),
                );
              },
            ),
    );
  }
}
