# Exporting soccer-course for the Flutter wrapper

The Football tile in Game Hub is a thin Flutter launcher
(`lib/games/football/football_game_screen.dart`) that embeds this Godot
project **natively** — no WebView involved. Godot itself isn't available in
the environment that prepared this repo, so a human with the **Godot 4.4
Editor** installed needs to produce the platform-specific export(s) below.
These steps are one-time per platform (repeat only when you want to ship
updated gameplay).

Only Android and Linux are wired up; other platforms show an honest
"not supported" message in the app.

## Android: library export (.aar)

1. Install export templates: **Editor → Manage Export Templates…**, matching
   your Godot 4.4 version.
2. Open `lib/games/football/soccer-course/` as a project in Godot 4.4.
3. **Project → Export…** → **Add…** → **Android**.
4. In the preset options, use Godot's **"Export as .aar" / Android library**
   export mode (as opposed to a full standalone APK) — Godot 4.4 supports
   exporting the project as a library AAR intended to be embedded inside a
   host Android app, which is what this integration needs.
5. Export it, then place the resulting file at:

   ```
   android/app/libs/godot-lib.aar
   ```

6. Uncomment the dependency line in `android/app/build.gradle.kts`:

   ```kotlin
   dependencies {
       implementation(files("libs/godot-lib.aar"))
   }
   ```

7. The native embedding code lives in
   `android/app/src/main/kotlin/com/example/game_hub/GodotEmbedView.kt`
   and `GodotEmbedViewFactory.kt`, registered in `MainActivity.kt`. Read the
   `TODO(godot-aar)` comments at the top of `GodotEmbedView.kt` before
   building — they call out the exact parts of Godot's
   `org.godotengine.godot.Godot` embedding API that were written from
   documented behavior but could not be compiled/verified against the real
   AAR in this environment, and may need small adjustments once you can see
   the AAR's actual Javadoc/sources.
8. `flutter run -d <android-device>` and open the Football tile.

## Linux: binary export

1. Install export templates as above if not already done.
2. **Project → Export…** → **Add…** → **Linux/X11** (or "Linux" depending on
   your Godot 4.4 build).
3. Set the export path to:

   ```
   lib/games/football/soccer-course/linux-export/soccer_course.x86_64
   ```

   This exact path is not arbitrary: `lib/games/football/linux_godot_embed_view.dart`
   hardcodes it as `linuxGodotBinaryPath`. Exporting anywhere else means the
   app won't find the binary and will show the "not exported yet" message.
4. Make sure the exported file is executable (`chmod +x`) — Godot's export
   usually sets this, but double-check after copying it into the repo.
5. The native embedding mechanism is a GTK/X11 plugin under
   `linux/godot_embed/` (`godot_embed_channel.cc`/`.h`), wired into
   `linux/runner/my_application.cc` and `linux/runner/CMakeLists.txt`. It
   spawns the binary and reparents its X11 window into a `GtkSocket` inside
   this app's window — true embedding, not window-manager positioning.
6. **X11 only.** `GtkSocket` implements the XEmbed protocol, which has no
   Wayland-native equivalent, and GTK4 removed `GtkSocket` entirely. This
   Flutter Linux runner links against GTK3 (`gtk+-3.0`, see
   `linux/CMakeLists.txt`), so `GtkSocket` is available, but it will only
   actually embed the window when the session is X11 or XWayland. Under a
   pure-Wayland GDK backend the native plugin logs a warning and the
   embedded area stays empty.
7. `flutter run -d linux` and open the Football tile.

## Phase 1: mobile UI redesign

Touch controls (joystick + A/B/C + pause button) are now **always**
instantiated by `UI.setup_touch_controls()`, not just when
`DisplayServer.is_touchscreen_available()` returns true — the goal is full
UI parity between Android and desktop testing, and since `TouchControls`
only ever drives `Input.action_press/release` on the existing P1 actions,
keyboard and touch input keep working simultaneously with no special-casing
needed elsewhere. Also added: button/joystick visual polish (`StyleBoxFlat`
borders/shadows, a press-scale `Tween` animation, optional
`Input.vibrate_handheld` haptics), a possession bar and visual-only stamina
bar on the match HUD, hidden-pending-future-work card indicators, a generic
`UI.show_notification()` toast helper, a programmatic pause menu
(`scenes/ui/pause_menu.gd`), and a computed (not official) team rating +
squad list on the team selection screen. None of this touched
`network_manager.gd` or the replication code called out above — see that
section for what's still unverified there. This phase's own code was also
written without access to the Godot Editor; the `Input.vibrate_handheld()`
no-op-on-unsupported-platforms assumption in `touch_controls.gd` and the
`MultiplayerSynchronizer`/`GameManager.PROCESS_MODE_ALWAYS` interplay used by
the new pause menu are worth a first real playtest, same as the multiplayer
code above.

## Verify

- **Android**: run on a device/emulator, open Football, confirm the Godot
  main menu renders inside the app rather than the native placeholder text
  ("Godot Android library (godot-lib.aar) is not present...").
- **Linux**: run `flutter run -d linux` from an X11 or XWayland session,
  open Football, confirm the exported binary's window appears embedded
  inside the app window and resizes with it.

## Local network multiplayer

A "Multiplayer" option was added to the main menu for 1v1 play between two
devices. This is **LAN/WiFi only** — it uses UDP discovery + ENet over a
regular local network, there is no Bluetooth/Nearby Connections involved, so
both devices must be on the same WiFi network/router (or otherwise routable
to each other; hotel/guest WiFi with client isolation enabled will block it).

Ports used, in case a firewall needs to allow them:

- **UDP 9751** — LAN discovery beacon (host broadcasts every ~0.5s, client
  listens for it to build the "Rejoindre" list).
- **TCP/UDP 9750** — the actual ENet game connection (`ENetMultiplayerPeer`,
  `create_server`/`create_client`), carries the real match traffic.

Both constants live at the top of `scenes/network/network_manager.gd`
(`ENET_PORT`, `DISCOVERY_PORT`) if you need to change them.

**Important**: this multiplayer implementation (network_manager.gd, the
touch controls, the multiplayer lobby UI, the sprint mechanic, and the
`MultiplayerSynchronizer`-based replication in `player.gd`/`ball.gd`) was
written entirely by hand without access to the Godot Editor — nothing in
this project could be opened, run, or compile-checked while writing it. Do
one full test pass (host on one device, join from a second device on the
same network) before relying on it. Things worth double-checking first,
flagged in code comments at their exact location too:

- `DisplayServer.is_touchscreen_available()` is no longer used to gate
  whether `TouchControls` exists (see "Phase 1: mobile UI redesign" below) —
  it's gone from `ui.gd` entirely now, so this particular check is moot.
- The `MultiplayerSynchronizer`/`SceneReplicationConfig` setup added in
  `Player._ready()`/`Ball._ready()` — property paths and authority
  assignment follow the documented pattern but were never actually run.
- The ball's physics on a networked client is not authority-gated (only
  `Player.move_and_slide()` is) since `Ball`'s movement lives in its
  `BallState` subclasses, which were out of scope to modify — if the ball
  visibly jitters/fights the replicated position on the client, that's why.
- Just-pressed/just-released edge detection for the client's replicated
  SHOOT/PASS/SPRINT actions on the host is approximated by comparing
  consecutive received network states in `NetworkManager`, since RPC
  arrival doesn't line up with Godot's own per-frame edge detection — should
  feel fine but may occasionally miss/duplicate a tap under real network
  jitter.
