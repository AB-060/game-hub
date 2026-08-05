import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Path convention for the Godot Linux export binary, relative to the
/// package root this app is run from. See `soccer-course/EXPORT.md` for how
/// a human produces it from the Godot 4.4 Editor.
const String linuxGodotBinaryPath =
    'lib/games/football/soccer-course/linux-export/soccer_course.x86_64';

const _channel = MethodChannel('game_hub/linux_godot_embed');

/// Embeds the Godot Linux export binary as a genuine child X11 window,
/// reparented via `GtkSocket`/XEmbed into this app's own GTK widget tree by
/// the native plugin under `linux/godot_embed/` (see that folder's
/// `godot_embed_channel.cc` for the reparenting mechanism).
///
/// This is real window embedding, not a window-manager overlay: the Godot
/// process's window becomes a child of a `GtkSocket` Flutter's Linux runner
/// creates, at coordinates this widget keeps in sync with its own on-screen
/// bounds.
///
/// X11-only. `GtkSocket` implements the XEmbed protocol, which has no
/// Wayland-native equivalent; GTK4 removed `GtkSocket` entirely. This only
/// works when the session is X11 or XWayland, which is what
/// `flutter run -d linux` normally uses today. There is no runtime
/// detection surfaced to Dart for "pure Wayland, no XWayland" — if that
/// happens, the native side logs a warning and the socket stays empty; the
/// Flutter-side UI here does not currently distinguish that from "still
/// waiting for the window to appear" (a known limitation, see native
/// warnings in the app's stdout as the diagnostic path today).
class LinuxGodotEmbedView extends StatefulWidget {
  const LinuxGodotEmbedView({super.key});

  @override
  State<LinuxGodotEmbedView> createState() => _LinuxGodotEmbedViewState();
}

class _LinuxGodotEmbedViewState extends State<LinuxGodotEmbedView> {
  bool _launched = false;
  Rect? _lastBounds;
  final GlobalKey _boundsKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncGeometry());
  }

  Rect? _currentGlobalBounds() {
    final renderObject = _boundsKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    return topLeft & renderObject.size;
  }

  Future<void> _syncGeometry() async {
    if (!mounted) return;
    final bounds = _currentGlobalBounds();
    if (bounds == null) return;

    if (!_launched) {
      _launched = true;
      _lastBounds = bounds;
      await _channel.invokeMethod('launch', {
        'godotBinaryPath': linuxGodotBinaryPath,
        'x': bounds.left.round(),
        'y': bounds.top.round(),
        'width': bounds.width.round(),
        'height': bounds.height.round(),
      });
      return;
    }

    if (bounds != _lastBounds) {
      _lastBounds = bounds;
      await _channel.invokeMethod('updateGeometry', {
        'x': bounds.left.round(),
        'y': bounds.top.round(),
        'width': bounds.width.round(),
        'height': bounds.height.round(),
      });
    }
  }

  @override
  void dispose() {
    if (_launched) {
      // Fire-and-forget: the widget is going away regardless of whether
      // this completes, and there is no context left to await it in.
      unawaited(_channel.invokeMethod('terminate'));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NotificationListener catches layout-size changes of this widget
    // (window resizes, orientation changes, splits) so the native GtkSocket
    // stays aligned with the Flutter-side widget bounds.
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _syncGeometry());
        return false;
      },
      child: SizeChangedLayoutNotifier(
        key: _boundsKey,
        // The actual pixels here are drawn by the native GtkSocket overlay
        // compositor (see linux/runner/my_application.cc), which sits above
        // the Flutter view at these exact bounds. This widget itself must
        // stay visually transparent so it doesn't paint over the embedded
        // Godot window.
        child: const ColoredBox(color: Colors.transparent),
      ),
    );
  }
}

/// Whether the Godot Linux export binary is present at
/// [linuxGodotBinaryPath] (resolved relative to the working directory the
/// app process was started from, which for `flutter run`/installed Linux
/// builds is the bundle's data directory containing the Flutter assets —
/// same convention `soccer-course/EXPORT.md` documents).
bool linuxGodotBinaryExists() {
  try {
    return File(linuxGodotBinaryPath).existsSync();
  } catch (_) {
    return false;
  }
}
