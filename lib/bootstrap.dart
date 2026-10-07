import 'dart:io';

import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isWindows) return;
  try {
    await localNotifier.setup(appName: 'Farma authenticator');
  } catch (_) {}
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(300, 310),
    minimumSize: Size(300, 310),
    maximumSize: Size(300, 310),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'Farma authenticator',
  );
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setMaximizable(false);
    await windowManager.show();
    await windowManager.focus();
  });
}
