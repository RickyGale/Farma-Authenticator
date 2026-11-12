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
        // Segue il tema del sistema; se il sistema non lo indica resta chiaro.
        // adaptive_platform_ui sceglie i colori di barra e testo da
        // platformBrightness, quindi va lasciata quella vera del telefono.
        theme: ThemeData(brightness: Brightness.light),
        darkTheme: ThemeData(brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        // Toolbar fissa sopra il navigator (iOS 26+). Lo Scaffold trasparente
        // serve perché su iOS AdaptiveScaffold disegna una pagina Cupertino:
        // senza, SnackBar, TextField e stili di testo Material non funzionano.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: Theme.of(context).brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          // Il builder sta sopra il Navigator, quindi non c'è un Overlay:
          // i Tooltip della toolbar nativa iOS 26 ne richiedono uno.
          child: _HostOverlay(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              resizeToAvoidBottomInset: false,
              body: AdaptiveToolbarHost(child: child!),
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlay con un'unica entry che mostra [child] e si aggiorna quando cambia.
class _HostOverlay extends StatefulWidget {
  const _HostOverlay({required this.child});

  final Widget child;

  @override
  State<_HostOverlay> createState() => _HostOverlayState();
}

class _HostOverlayState extends State<_HostOverlay> {
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => widget.child);

  @override
  void didUpdateWidget(_HostOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
