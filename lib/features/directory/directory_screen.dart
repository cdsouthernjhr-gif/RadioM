import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/text_utils.dart';
import '../../data/models/radio_station.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/radio_card.dart';
import '../home/library_controller.dart';
import '../../widgets/logo_editor.dart';
import '../player/play_actions.dart';
import '../player/player_controller.dart';
import 'station_filter.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key, this.searchFocusNode});
  final FocusNode? searchFocusNode;

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  StationFilter _filter = const StationFilter();
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(StationFilter f) => setState(() => _filter = f);

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final playingId = context.select<PlayerController, String?>((p) => p.station?.id);
    if (lib.loading) return const LoadingWidget();
    final all = lib.stations;
    final results = _filter.apply(all);
    final states = StationFilter.statesOf(all);
    final langs = StationFilter.languagesOf(all);
    return Scaffold(
      appBar: AppBar(title: const Text('Direktori Radio')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            key: const Key('search-field'),
            controller: _search,
            focusNode: widget.searchFocusNode,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Cari nama stesen, rangkaian, frekuensi…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              suffixIcon: _filter.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Kosongkan',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        _set(_filter.copyWith(query: ''));
                      }),
            ),
            onChanged: (v) => _set(_filter.copyWith(query: v)),
          ),
        ),
        FocusTraversalGroup(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(children: [
              _chip('Semua', _filter.category == null, () => _set(_filter.copyWith(clearCategory: true))),
              for (final c in StationCategory.values)
                _chip(TextUtils.categoryName(c.name), _filter.category == c, () => _set(_filter.copyWith(category: c))),
              const SizedBox(width: 8),
              _dropdown<String>(
                label: 'Negeri',
                value: _filter.state,
                items: {
                  StationFilter.national: 'Nasional',
                  for (final s in states) s: s,
                },
                onChanged: (v) => _set(v == null ? _filter.copyWith(clearState: true) : _filter.copyWith(state: v)),
              ),
              const SizedBox(width: 8),
              _dropdown<String>(
                label: 'Bahasa',
                value: _filter.language,
                items: {for (final l in langs) l: TextUtils.languageName(l)},
                onChanged: (v) =>
                    _set(v == null ? _filter.copyWith(clearLanguage: true) : _filter.copyWith(language: v)),
              ),
              const SizedBox(width: 8),
              ActionChip(
                key: const Key('sort-toggle'),
                avatar: const Icon(Icons.sort_by_alpha, size: 18),
                label: Text(_filter.sort == SortOrder.az ? 'A-Z' : 'Z-A'),
                onPressed: () =>
                    _set(_filter.copyWith(sort: _filter.sort == SortOrder.az ? SortOrder.za : SortOrder.az)),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${results.length} stesen', style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? const Center(child: Text('Tiada stesen sepadan'))
              : ListView.builder(
                  key: const Key('directory-list'),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final s = results[i];
                    return StationListTile(
                      key: ValueKey('dir-${s.id}'),
                      station: s,
                      isPlaying: playingId == s.id,
                      isFavorite: lib.isFavorite(s.id),
                      onFavorite: () => lib.toggleFavorite(s.id),
                      onTap: () => playOrOpen(context, s),
                      onLongPress: () => showLogoEditor(context, s),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) =>
      DropdownButton<T?>(
        value: value,
        hint: Text(label),
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(12),
        items: [
          DropdownMenuItem<T?>(value: null, child: Text('$label: Semua')),
          for (final e in items.entries) DropdownMenuItem<T?>(value: e.key, child: Text(e.value)),
        ],
        onChanged: onChanged,
      );
}
