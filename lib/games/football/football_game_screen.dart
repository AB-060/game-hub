import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show StandardMessageCodec;

import 'linux_godot_embed_view.dart';

/// Flutter's role for the football game is a thin launcher: gameplay, menus
/// and everything else live in the Godot project vendored at
/// `lib/games/football/soccer-course/`.
///
/// Two genuinely native embedding mechanisms are used, platform-branched:
///  - **Android**: an [AndroidView] backed by a `PlatformView` that hosts a
///    Godot engine instance built as an Android library (`godot-lib.aar`).
///    See `android/app/src/main/kotlin/.../GodotEmbedView.kt`.
///  - **Linux**: [LinuxGodotEmbedView], which spawns the Godot Linux export
///    binary and reparents its X11 window into a `GtkSocket` embedded in
///    this app's own GTK widget tree. See `linux/godot_embed/`.
///
/// There is no WebView-based path on any platform. Other platforms
/// (iOS/macOS/Windows/web) show an honest "not supported here" message —
/// they were explicitly deprioritized, not silently faked.
class FootballGameScreen extends StatefulWidget {
  const FootballGameScreen({super.key});

  @override
  State<FootballGameScreen> createState() => _FootballGameScreenState();
}

class _FootballGameScreenState extends State<FootballGameScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Football')),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!kIsWeb && Platform.isAndroid) {
      return const _AndroidGodotEmbed();
    }
    if (!kIsWeb && Platform.isLinux) {
      return _LinuxGodotEmbed();
    }
    return const _UnsupportedPlatformMessage();
  }
}

/// Hosts the Android `godot_embed_view` PlatformView (see
/// `android/app/src/main/kotlin/.../GodotEmbedView.kt` and
/// `GodotEmbedViewFactory.kt`). If `godot-lib.aar` hasn't been added to the
/// Android build yet, this compiles and runs fine on the Flutter side — the
/// native view itself shows the honest "not wired up yet" placeholder from
/// `GodotEmbedView.kt` rather than faking a running game.
class _AndroidGodotEmbed extends StatelessWidget {
  const _AndroidGodotEmbed();

  @override
  Widget build(BuildContext context) {
    return const AndroidView(
      viewType: 'godot_embed_view',
      creationParams: <String, dynamic>{
        'projectPath': 'lib/games/football/soccer-course',
      },
      creationParamsCodec: StandardMessageCodec(),
    );
  }
}

class _LinuxGodotEmbed extends StatelessWidget {
  _LinuxGodotEmbed();

  final bool _binaryExists = linuxGodotBinaryExists();

  @override
  Widget build(BuildContext context) {
    if (!_binaryExists) return const _NotExportedMessage();
    return const LinuxGodotEmbedView();
  }
}

class _NotExportedMessage extends StatelessWidget {
  const _NotExportedMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_soccer_rounded, size: 64),
            const SizedBox(height: 16),
            Text(
              "Le jeu Godot n'a pas encore été exporté",
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Voir lib/games/football/soccer-course/EXPORT.md pour générer "
              "l'export Linux depuis l'éditeur Godot 4.4.",
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsupportedPlatformMessage extends StatelessWidget {
  const _UnsupportedPlatformMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.desktop_access_disabled_rounded, size: 64),
            const SizedBox(height: 16),
            Text(
              "Ce mode nécessite Android ou Linux",
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Le football est intégré nativement (PlatformView Android, "
              "GtkSocket/X11 sur Linux) et n'a pas d'implémentation sur "
              "cette plateforme. Lancez plutôt le jeu Godot directement "
              "(ouvrez soccer-course/ dans Godot 4.4, ou lancez l'export "
              "produit pour votre plateforme en suivant EXPORT.md).",
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
