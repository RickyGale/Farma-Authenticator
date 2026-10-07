import 'package:flutter/material.dart';

import 'app.dart';
import 'bootstrap.dart';

Future<void> main() async {
  await bootstrap();
  runApp(const FarmaAuthApp());
}
