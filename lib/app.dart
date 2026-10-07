import 'package:flutter/material.dart';

import 'screens/reverse_home_page.dart';

class FarmaAuthApp extends StatelessWidget {
  const FarmaAuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Farma auth',
      home: ReverseHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
