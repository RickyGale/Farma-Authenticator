import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:foldable/foldable.dart';

import 'screens/reverse_home_page.dart';

class FarmaAuthApp extends StatelessWidget {
  const FarmaAuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Su iPhone Duo espone piega e size class; altrove non fa nulla.
    return FoldableProvider(
      child: MaterialApp(
        title: 'Farma auth',
        home: const ReverseHomePage(),
        debugShowCheckedModeBanner: false,
        // Toolbar fissa sopra il navigator (iOS 26+). Lo Scaffold trasparente
        // serve perché su iOS AdaptiveScaffold disegna una pagina Cupertino:
        // senza, SnackBar, TextField e stili di testo Material non funzionano.
        builder: (context, child) => Scaffold(backgroundColor: Colors.transparent, resizeToAvoidBottomInset: false, body: AdaptiveToolbarHost(child: child!)),
      ),
    );
  }
}
