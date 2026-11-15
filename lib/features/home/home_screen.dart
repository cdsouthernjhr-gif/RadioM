import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/radio_station.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/radio_card.dart';
import '../player/play_actions.dart';
import '../player/player_controller.dart';
import 'library_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenSearch, this.isTv = false});
  final VoidCallback onOpenSearch;
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();
    if (lib.loading) return const LoadingWidget(message: 'Memuatkan senarai radio…');
    if (lib.error != null && lib.stations.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(lib.error!)));
    }
    final playingId = context.select<PlayerController, String?>((p) => p.station?.id);
    final cardWidth = isTv ? 170.0 : 140.0;
    final sections = <(String, List<RadioStation>)>[
      ('Featured Radio', lib.featured),
      ('Recently Played', lib.recent),
      ('Favorite Stations', lib.favorites),
      ('National Radio', lib.national),
      ('State Radio', lib.stateRadio),
      ('Commercial Radio', lib.commercial),
      ('Internet Radio', lib.internet),
    ];
    var first = true;
    return RefreshIndicator(
      onRefresh: () => lib.refresh(),
      child: CustomScrollView(slivers: [
        SliverAppBar(
          floating: true,
          title: const Text('Malaysia Radio Player'),
          actions: [
            IconButton(tooltip: 'Search', icon: const Icon(Icons.search), onPressed: onOpenSearch),
          ],
        ),
        if (lib.refreshing) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
        for (final (title, items) in sections)
          if (items.isNotEmpty)
            SliverToBoxAdapter(
              // Keyed so inserting "Recently Played" doesn't rebuild other rows
              // (which would drop D-pad focus on TV).
              key: ValueKey('section-$title'),
              child: _Section(
                title: title,
                count: items.length,
                child: SizedBox(
                  height: cardWidth + 64,
                  child: FocusTraversalGroup(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final s = items[i];
                        final af = isTv && first && i == 0;
                        if (af) first = false;
                        return RadioCard(
                          key: ValueKey('$title-${s.id}'),
                          station: s,
                          width: cardWidth,
                          autofocus: af,
                          isPlaying: playingId == s.id,
                          onTap: () => playOrOpen(context, s),
                          onLongPress: () => lib.toggleFavorite(s.id),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.count, required this.child});
  final String title;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Text('$count', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          child,
        ]),
      );
}
