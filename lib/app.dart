import 'package:flutter/material.dart';
import 'package:foldable/foldable.dart';

import 'screens/reverse_home_page.dart';

class FarmaAuthApp extends StatelessWidget {
  const FarmaAuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Su iPhone Duo espone piega e size class; altrove non fa nulla.
    return const FoldableProvider(
      child: MaterialApp(
        title: 'Farma auth',
        home: ReverseHomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
