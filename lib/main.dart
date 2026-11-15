import 'dart:async';

import 'package:flutter/material.dart';

import 'bootstrap.dart';

Future<void> main() async {
  final services = await bootstrap();
  runApp(services.buildApp());
  await services.library.init();
  unawaited(services.player.autoPlayLastIfEnabled());
}
