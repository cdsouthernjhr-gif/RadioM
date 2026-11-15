import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/text_utils.dart';
import '../../data/models/radio_database.dart';
import '../../services/custom_logo_store.dart';
import '../home/library_controller.dart';
import '../player/player_controller.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final lib = context.watch<LibraryController>();
    final db = lib.database;
    final messenger = ScaffoldMessenger.of(context);
    final sourceLabel = switch (db?.source) {
      DatabaseSource.remote => 'Dimuat turun (GitHub)',
      DatabaseSource.cache => 'Salinan tempatan (cache)',
      DatabaseSource.bundled => 'Terbina dalam aplikasi',
      null => '-',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Tetapan')),
      body: ListView(children: [
        const _Header('Paparan'),
        for (final m in ThemeMode.values)
          RadioListTile<ThemeMode>(
            value: m,
            groupValue: settings.themeMode,
            onChanged: (v) => settings.setThemeMode(v!),
            title: Text(switch (m) {
              ThemeMode.system => 'Ikut sistem',
              ThemeMode.light => 'Light mode',
              ThemeMode.dark => 'Dark mode',
            }),
          ),
        const _Header('Main balik'),
        SwitchListTile(
          title: const Text('Auto reconnect'),
          subtitle: const Text('Sambung semula strim apabila sambungan terputus'),
          value: settings.autoReconnect,
          onChanged: (v) {
            settings.setAutoReconnect(v);
            context.read<PlayerController>().autoReconnect = v;
          },
        ),
        SwitchListTile(
          key: const Key('setting-now-playing'),
          title: const Text('Papar info lagu (RDS)'),
          subtitle: const Text('Tajuk lagu / rancangan daripada metadata strim stesen (ICY), jika dihantar'),
          value: settings.showNowPlaying,
          onChanged: settings.setShowNowPlaying,
        ),
        SwitchListTile(
          title: const Text('Auto play last station'),
          subtitle: const Text('Mainkan stesen terakhir apabila aplikasi dibuka'),
          value: settings.autoPlayLast,
          onChanged: settings.setAutoPlayLast,
        ),
        const _Header('Logo sendiri'),
        Builder(builder: (context) {
          final logos = context.watch<CustomLogoStore>();
          return ListTile(
            key: const Key('setting-custom-logos'),
            leading: const Icon(Icons.image_outlined),
            title: const Text('Padam semua logo sendiri'),
            subtitle: Text(logos.count == 0
                ? 'Tiada logo sendiri. Tambah melalui pemain penuh (ikon gambar) atau tekan lama stesen dalam Direktori.'
                : '${logos.count} stesen menggunakan logo anda sendiri'),
            enabled: logos.count > 0,
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Padam semua logo sendiri?'),
                  content: const Text('Stesen akan kembali menggunakan logo asal.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                    FilledButton(
                        key: const Key('confirm-delete-logos'),
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Padam')),
                  ],
                ),
              );
              if (ok == true) await logos.clearAll();
            },
          );
        }),
        const _Header('Pangkalan data'),
        ListTile(
          leading: const Icon(Icons.storage_rounded),
          title: Text('Versi ${db?.version ?? '-'} • ${db?.stations.length ?? 0} stesen'),
          subtitle: Text('Kemas kini: ${TextUtils.formatDate(db?.lastUpdated)}\n'
              'Sumber: $sourceLabel\n'
              'Strim disahkan: ${db?.directCount ?? 0} • Belum disahkan: ${db?.unverifiedCount ?? 0} • '
              'Web sahaja: ${db?.webPlayerCount ?? 0}\n'
              'Ujian strim terakhir: ${TextUtils.formatDate(db?.verificationCheckedAt)}'),
          isThreeLine: true,
        ),
        ListTile(
          key: const Key('refresh-db'),
          leading: lib.refreshing
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh_rounded),
          title: const Text('Refresh database'),
          subtitle: Text(lib.lastMessage ?? 'Semak versi baharu di GitHub'),
          onTap: lib.refreshing
              ? null
              : () async {
                  final r = await lib.refresh(force: false);
                  messenger.showSnackBar(SnackBar(content: Text(r.message ?? '')));
                },
        ),
        ListTile(
          leading: const Icon(Icons.cleaning_services_rounded),
          title: const Text('Clear cache'),
          subtitle: const Text('Padam cache logo. Pangkalan data stesen dikekalkan.'),
          onTap: () async {
            await settings.clearCache();
            messenger.showSnackBar(const SnackBar(content: Text('Cache dibersihkan')));
          },
        ),
        const _Header('Maklumat'),
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('About application'),
          subtitle: const Text('Version ${AppConstants.appVersion} (${AppConstants.appBuild})'),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: AppConstants.appName,
            applicationVersion: '${AppConstants.appVersion} (${AppConstants.appBuild})',
            applicationLegalese: 'Strim audio milik penyiar masing-masing. Aplikasi ini hanya memainkan URL '
                'strim awam dan membuka pemain web rasmi; tiada sekatan penyiar dipintas.\n\n'
                'Status "Strim disahkan" bermaksud ujian automatik berjaya menyahkod audio pada tarikh '
                'ujian, bukan jaminan stesen sedang bersiaran.',
          ),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w800)),
      );
}
