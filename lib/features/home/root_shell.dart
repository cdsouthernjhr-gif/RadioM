import 'package:flutter/material.dart';

import '../../widgets/mini_player.dart';
import '../directory/directory_screen.dart';
import '../favorites/favorites_screen.dart';
import '../settings/settings_screen.dart';
import 'home_screen.dart';

/// Responsive shell: bottom NavigationBar on phones, NavigationRail on
/// tablets / Android TV (landscape, D-pad friendly).
class RootShell extends StatefulWidget {
  const RootShell({super.key, this.isTv = false});
  final bool isTv;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  final _searchFocus = FocusNode(debugLabel: 'search');

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _select(int i) => setState(() => _index = i);

  void _openSearch() {
    _select(1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
  }

  static const _dest = [
    (Icons.home_outlined, Icons.home_rounded, 'Utama'),
    (Icons.radio_outlined, Icons.radio_rounded, 'Direktori'),
    (Icons.favorite_border, Icons.favorite, 'Kegemaran'),
    (Icons.settings_outlined, Icons.settings, 'Tetapan'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = widget.isTv || MediaQuery.sizeOf(context).width >= 840;
    final pages = [
      HomeScreen(onOpenSearch: _openSearch, isTv: widget.isTv),
      DirectoryScreen(searchFocusNode: _searchFocus),
      const FavoritesScreen(),
      const SettingsScreen(),
    ];
    final body = IndexedStack(index: _index, children: [
      for (var i = 0; i < pages.length; i++)
        // Only the visible tab participates in focus traversal.
        ExcludeFocus(excluding: i != _index, child: pages[i]),
    ]);
    if (wide) {
      return Scaffold(
        body: Row(children: [
          FocusTraversalGroup(
            child: NavigationRail(
              key: const Key('nav-rail'),
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.8,
              destinations: [
                for (final d in _dest)
                  NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: Column(children: [Expanded(child: body), const MiniPlayer()])),
        ]),
      );
    }
    return Scaffold(
      body: Column(children: [Expanded(child: body), const MiniPlayer()]),
      bottomNavigationBar: NavigationBar(
        key: const Key('nav-bar'),
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final d in _dest) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
        ],
      ),
    );
  }
}
