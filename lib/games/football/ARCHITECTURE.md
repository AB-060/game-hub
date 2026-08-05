# Football architecture

Football is not implemented in Flutter/Dart. The actual game — menus,
squads, matches, tournaments — is a complete Godot 4.4 project vendored at
`lib/games/football/soccer-course/` (originally cloned from
https://github.com/nicolasbize/soccer-course.git, now a normal tracked part
of this repo).

Flutter's only job is to be a launcher shell, matching how every other game
in this hub is a self-contained widget reachable from the hub grid. Unlike a
WebView-based approach, this game is embedded **natively**, platform by
platform:

- `football_game_screen.dart` is the entire Flutter surface for this game.
  It platform-branches:
  - **Android**: an `AndroidView` backed by the `godot_embed_view`
    `PlatformView`, implemented in
    `android/app/src/main/kotlin/com/example/brick_breaker/GodotEmbedView.kt`
    (+ `GodotEmbedViewFactory.kt`, registered in `MainActivity.kt`). This
    hosts a real `org.godotengine.godot.Godot` engine instance from Godot's
    Android library export, once `godot-lib.aar` is added — see
    `soccer-course/EXPORT.md`.
  - **Linux**: `linux_godot_embed_view.dart`'s `LinuxGodotEmbedView`, backed
    by the native GTK plugin under `linux/godot_embed/`. It spawns the
    exported Godot Linux binary as a child process and reparents its X11
    window into a `GtkSocket` (XEmbed) embedded in this app's own GTK widget
    tree (`linux/runner/my_application.cc`), keeping it positioned/sized to
    match the Flutter widget's bounds. This mechanism is X11-only —
    `GtkSocket` has no Wayland equivalent and was removed in GTK4.
  - **Everything else** (iOS/macOS/Windows/web): shows an honest
    "not supported here" message. These platforms were explicitly
    deprioritized; there is no WebView fallback anywhere in this app.
- If the platform-specific exported artifact isn't in place yet (missing
  `godot-lib.aar` on Android, missing Linux binary on Linux), the screen
  shows an honest "not exported yet" state (or, on Android, the native
  `GodotEmbedView` placeholder) instead of pretending the game is running.

There is no Dart/Godot shared game-state bridge — this is intentionally
one-directional (Flutter shows/positions a native surface; Godot runs the
game inside it).

See `soccer-course/EXPORT.md` for the human steps required to produce the
Android and Linux exports these two code paths expect.
