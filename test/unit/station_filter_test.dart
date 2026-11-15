import 'package:flutter_test/flutter_test.dart';
import 'package:malaysia_radio_player/data/models/radio_station.dart';
import 'package:malaysia_radio_player/data/services/json_service.dart';
import 'package:malaysia_radio_player/features/directory/station_filter.dart';

import '../helpers.dart';

void main() {
  final stations = const JsonService().parse(fixture('sample_db.json')).stations;
  List<String> names(StationFilter f) => f.apply(stations).map((s) => s.name).toList();

  test('A-Z and Z-A sort', () {
    expect(names(const StationFilter()), ['Ai FM', 'Ceritera FM', 'ERA', 'HITZ', 'Kelantan FM', 'Nasional FM']);
    expect(names(const StationFilter(sort: SortOrder.za)).first, 'Nasional FM');
  });
  test('search by name, frequency, network (case-insensitive)', () {
    expect(names(const StationFilter(query: 'hitz')), ['HITZ']);
    expect(names(const StationFilter(query: '88.5')), ['Nasional FM']);
    expect(names(const StationFilter(query: 'astro')), ['ERA', 'HITZ']);
    expect(names(const StationFilter(query: 'zzz')), isEmpty);
  });
  test('category / state / language filters', () {
    expect(names(const StationFilter(category: StationCategory.commercial)), ['ERA', 'HITZ']);
    expect(names(const StationFilter(state: 'Kelantan')), ['Kelantan FM']);
    expect(names(const StationFilter(state: StationFilter.national, category: StationCategory.rtm)),
        ['Ai FM', 'Nasional FM']);
    expect(names(const StationFilter(language: 'zh')), ['Ai FM']);
  });
  test('lists of states and languages', () {
    expect(StationFilter.statesOf(stations), ['Kelantan']);
    expect(StationFilter.languagesOf(stations), ['en', 'ms', 'zh']);
  });
}
