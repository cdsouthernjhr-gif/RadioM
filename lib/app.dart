import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/config/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/home/root_shell.dart';
import 'features/player/player_controller.dart';
import 'features/settings/settings_controller.dart';

class MalaysiaRadioApp extends StatelessWidget {
  const MalaysiaRadioApp({super.key, this.isTv = false});
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsController, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      // TV remotes: DPAD_CENTER (select) and Enter already map to ActivateIntent in
      // WidgetsApp defaults; media keys are handled here when the app has focus.
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
      },
      builder: (context, child) => _MediaKeys(child: child ?? const SizedBox.shrink()),
      home: RootShell(isTv: isTv),
    );
  }
}

class _MediaKeys extends StatelessWidget {
  const _MediaKeys({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pc = context.read<PlayerController>();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): pc.toggle,
        const SingleActivator(LogicalKeyboardKey.mediaPlay): pc.toggle,
        const SingleActivator(LogicalKeyboardKey.mediaPause): pc.toggle,
        const SingleActivator(LogicalKeyboardKey.mediaStop): pc.stop,
      },
      child: child,
    );
  }
}
