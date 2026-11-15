import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/models/radio_station.dart';
import '../services/custom_logo_store.dart';
import 'station_logo.dart';

/// Bottom sheet to add, replace or delete the user's own logo for a station.
/// Works with touch and with a TV remote (every action is a focusable tile).
Future<void> showLogoEditor(BuildContext context, RadioStation station) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<CustomLogoStore>(),
      child: _LogoEditor(station: station),
    ),
  );
}

class _LogoEditor extends StatefulWidget {
  const _LogoEditor({required this.station});
  final RadioStation station;

  @override
  State<_LogoEditor> createState() => _LogoEditorState();
}

class _LogoEditorState extends State<_LogoEditor> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on LogoException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Logo tidak dapat disimpan.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromDevice() async {
    final store = context.read<CustomLogoStore>();
    XFile? file;
    try {
      // Picker downsizes on the device side: small files, little RAM.
      file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 90);
    } on PlatformException {
      file = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tiada aplikasi galeri/fail pada peranti ini. Gunakan "Dari URL gambar".'),
      ));
      return;
    }
    if (file == null || !mounted) return; // cancelled
    final bytes = await file.readAsBytes();
    await _run(() => store.setFromBytes(widget.station.id, bytes), 'Logo ${widget.station.name} dikemas kini');
  }

  Future<void> _fromUrl() async {
    final store = context.read<CustomLogoStore>();
    final url = await showDialog<String>(context: context, builder: (_) => const _UrlDialog());
    if (url == null || url.trim().isEmpty || !mounted) return;
    await _run(() => store.setFromUrl(widget.station.id, url), 'Logo ${widget.station.name} dikemas kini');
  }

  Future<void> _delete() async {
    final store = context.read<CustomLogoStore>();
    await _run(() => store.remove(widget.station.id), 'Logo sendiri dipadam');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CustomLogoStore>();
    final hasCustom = store.has(widget.station.id);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            StationLogo(station: widget.station, size: 72, radius: 14),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Logo ${widget.station.name}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(hasCustom ? 'Menggunakan logo anda sendiri' : 'Menggunakan logo asal',
                    style: theme.textTheme.bodySmall),
              ]),
            ),
            if (_busy) const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ]),
          const SizedBox(height: 12),
          ListTile(
            key: const Key('logo-pick-device'),
            autofocus: true,
            enabled: !_busy,
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(hasCustom ? 'Tukar logo dari peranti' : 'Tambah logo dari peranti'),
            subtitle: const Text('PNG, JPG, GIF atau WebP, maksimum 3 MB'),
            onTap: _pickFromDevice,
          ),
          ListTile(
            key: const Key('logo-from-url'),
            enabled: !_busy,
            leading: const Icon(Icons.link_rounded),
            title: const Text('Dari URL gambar'),
            subtitle: const Text('Sesuai untuk TV box tanpa galeri'),
            onTap: _fromUrl,
          ),
          if (hasCustom)
            ListTile(
              key: const Key('logo-delete'),
              enabled: !_busy,
              leading: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
              title: Text('Padam logo sendiri', style: TextStyle(color: theme.colorScheme.error)),
              subtitle: const Text('Kembali kepada logo asal stesen'),
              onTap: _delete,
            ),
        ]),
      ),
    );
  }
}

class _UrlDialog extends StatefulWidget {
  const _UrlDialog();
  @override
  State<_UrlDialog> createState() => _UrlDialogState();
}

class _UrlDialogState extends State<_UrlDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('URL gambar logo'),
      content: TextField(
        key: const Key('logo-url-field'),
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(hintText: 'https://…/logo.png'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
            key: const Key('logo-url-ok'), onPressed: () => Navigator.pop(context, _c.text), child: const Text('Simpan')),
      ],
    );
  }
}
