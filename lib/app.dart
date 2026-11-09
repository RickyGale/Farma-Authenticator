import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        // L'app ha solo il tema chiaro, ma adaptive_platform_ui sceglie
        // colori di barra, sfumatura e testo da platformBrightness: col
        // telefono in modalità scura la sfumatura diventava nera e il testo
        // bianco su pagina bianca. Si forza quindi la luminosità a chiaro.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(platformBrightness: Brightness.light),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark,
            child: Scaffold(backgroundColor: Colors.transparent, resizeToAvoidBottomInset: false, body: AdaptiveToolbarHost(child: child!)),
          ),
        ),
      ),
    );
  }
}
