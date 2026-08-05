# Release status — Soccer Course

Synthesized after 16 phases of work (mobile UI x2, movement/ball/AI feel, Settings/save
system, audio/VFX, camera, deep LAN multiplayer, performance pooling, presentation
screens + real stat tracking, menu/settings expansion, warning cleanup, gameplay/
atmosphere polish, QA/documentation, and real live multiplayer verification). See
`README.md` for the full phase-by-phase feature log and `EXPORT.md` for build/export
mechanics.

## Release checklist

| Subsystem | Status | Notes |
|---|---|---|
| Core gameplay (movement, ball physics, passing, shooting, sprint, curved shots) | ✅ Completed | Reviewed and re-verified across Phases 14-16; no changes needed. |
| AI (role-differentiated defenders/midfielders/attackers/goalkeeper) | ✅ Completed | Re-read; behavior matches documentation, nothing further to add. |
| Goalkeeper saves/parries | ✅ Completed | Verified via code read; save/parry split by shot speed/height confirmed present. |
| Multiplayer (discovery, lobby, ready system, score/clock sync, disconnect/reconnect, host authority) | ⚠️ Partially completed | **Phase 15 verified the connection/lobby layer live; Phase 16 went further and ran a real live match between two instances** — this found and fixed a genuine, previously-invisible bug (see "Live in-match gameplay test (Phase 16)" below): `MultiplayerSynchronizer`/`Player` nodes lacked deterministic names, silently breaking ALL state replication. After the fix: kickoff, clock sync, and ball-position sync during live play were all confirmed working for real. NOT yet exercised live: an actual goal during a live test, pause/sprint/shot input sync specifically, UDP broadcast auto-discovery (only manual-IP connection was live-tested), and anything across a real physical LAN/two separate devices. |
| Settings persistence | ✅ Completed | `save()`/`load_settings()` field parity re-verified in Phase 10 and spot-checked again this pass. |
| Audio/VFX (SFX pitch variation, confetti, shot trail, shadows) | ✅ Completed | No crowd/commentary/net/rain assets exist in the project — explicitly out of scope, documented via `# TODO:` in `world_screen.gd`. |
| Camera (ball-follow, dynamic goal zoom, shake, goal-moment hold) | ✅ Completed | No regressions found this pass. |
| UI/Menus (main menu, settings, pause, lineup, kickoff, full-time, tournament bracket, touch controls) | ✅ Completed | Translation-key coverage confirmed 100% (55/55 keys present, 0 unused). |
| Statistics (shots, shots-on-target, saves, passes, tackles, assists) | ⚠️ Partially completed | Real, event-driven, and consistently defined — but several are honest **heuristics** (e.g. "shot on target" = scores or reaches keeper within a time window; "pass completed" = same-country different-player possession within a window), not perfect classifiers. Documented as such in `README.md`. |
| Android export | ❌ Blocked | Headless CLI reports an unitemized "Cannot export project... due to configuration errors" with no detail line; the itemized list only renders in Godot's GUI export dialog, which cannot be shown in this sandbox (no working GPU/compositor — confirmed independently with an unrelated Flutter template hang). SDK path, debug keystore, Java, build-tools, and the extracted Gradle build template are all confirmed present/correct; `export_presets.cfg` has `gradle_build/use_gradle_build=true`, a valid-looking `package/unique_name` (`com.example.soccercourse`), `version/code`/`version/name` set. See `EXPORT.md` for what a human with GUI access needs to check next. |
| Flutter embedding (Android AAR / Linux GTK socket) | ⚠️ Partially completed | Code exists and reads correctly (`football_game_screen.dart`, `GodotEmbedView.kt`, `linux_godot_embed_view.dart`, `linux/godot_embed/`), but this pass's agent scope is the Godot project only (`soccer-course/`) — Flutter-side files were not re-verified this session. Blocked transitively by the Android export blocker above; Linux path is untested (no export binary was produced in this environment either). |
| Documentation | ✅ Completed | This pass: `README.md` Phase 14 section added, `RELEASE.md` created (this file). `EXPORT.md` was read and found already accurate/current — no changes needed. |

## Features implemented (synthesized across all 14 phases)

- Three local modes (1P vs CPU, 2P local co-op, 8-team knockout Tournament) plus LAN
  Multiplayer, 9 national squads with per-player stats and roles.
- Full movement/ball/AI feel pass: eased acceleration/deceleration, curved shots,
  goalkeeper save-vs-parry split, role-differentiated CPU behavior (marking, pressing,
  forward runs, counter-attack window, keeper distribution).
- Persistent `Settings` autoload covering audio, graphics (FPS cap, particles),
  controls (joystick/button size, opacity, side-swap, inversion, sensitivity,
  vibration), gameplay (difficulty, match duration, auto-sprint, camera zoom/follow
  speed/shake), and 5-locale UI text lookup (English/French confident, Spanish/
  Portuguese reasonable, Arabic selectable but falls back to English — no RTL layout
  was attempted).
- Always-on touch controls with FIFA-Mobile-style button triangle, press/ripple/glow
  feedback, and full keyboard/touch/mouse parity.
- Camera dynamic zoom near goals and a goal-moment hold/ease, screen shake, slow-motion
  on goals (single-player only, to protect host-authoritative sync).
- Presentation flow: team lineup screen, 3-2-1 kickoff countdown, full-time screen with
  real (heuristic-documented) stats, tournament champion banner.
- LAN multiplayer: UDP discovery + ENet connection, host-authoritative goal/clock
  detection, client-side position/height interpolation, ready-up system, live ping +
  connection-quality display, disconnect handling with a retry-to-lobby flow, editable
  player name broadcast in discovery.
- Performance: pooled confetti objects, a full `Settings.particles_enabled` gate audit
  across every VFX spawn site, and a `_process`/`_physics_process` hot-path audit
  finding no per-frame allocations.

## Features intentionally postponed or declined

Rollback netcode / deterministic lockstep / client prediction / lag compensation / host
migration; a half-time screen (this game's `GameState` machine has no half-time concept
at all — confirmed by reading every file in `scenes/game_manager/game_states/`); a full
referee/foul/card/out-of-bounds rule system (confirmed absent by direct search); crowd/
stadium/commentary audio and crowd sprite assets (none exist in `assets/`, documented via
a `# TODO:` in `world_screen.gd`); RTL Arabic support; real dynamic lighting/shadow/LOD
tiers (flat 2D pixel-art game, nothing to back them); a chat system in multiplayer;
camera mode switching (TV/Tactical/Be-A-Pro) and instant replay; auto player
switching/pass/shoot assist as gameplay-feel subsystems; bandwidth/serialization
optimization for network traffic (already light for 1v1).

## Confirmed bugs fixed across this project's history

Autoload/`class_name` collision; several `:=` type-inference traps (including one from
the generic `abs()` builtin, and one in `multiplayer_lobby.gd`'s `difficulty_key`,
fixed with an explicit `: String` type in Phase 12); a `CanvasLayer.modulate` misuse;
a `setup()`-before-`add_child()` ordering bug; two shadowed-variable warnings; a
narrowing-conversion warning; a confetti position-double-counting bug; a missing
particles-gate on the impact spark VFX (Phase 9); a stale Godot UID-cache bug breaking
custom theme resource resolution during export, fixed by deleting `.godot/` and forcing
a clean reimport (confirmed via the real Godot binary, Phase 14); Phase 14 itself found
no new bugs, only re-confirming the already-known forced-quit `ObjectDB`/"resource still
in use" shutdown warning by name (`AudioStreamMP3`/`menu.mp3`), not evidence of an actual
runtime leak. **Phase 16: a significant bug, found only by actually running two live
instances into a real match** (impossible to catch by reading alone) — `Player`'s and
`Ball`'s `MultiplayerSynchronizer` nodes, and the 22 spawned `Player` nodes themselves,
relied on Godot's default auto-generated node naming, which uses a creation-order-
dependent global counter that does not reliably match between two independently-running
processes. This silently broke ALL Player/Ball state replication on the client (`Node
not found` for every synchronizer). Fixed by giving each an explicit, deterministic name
(`"NetworkSync"` for synchronizers, `"Player_<country>_<index>"` for players) — confirmed
fixed by re-running the same live two-instance test, which then also successfully
completed a real kickoff and showed correctly-tracking ball-position sync during ~40s of
live play.

## Remaining known issues

- Android export blocked on an unitemized GUI-only error (see checklist above).
- Multiplayer has never been tested between two live instances.
- No real device (Android or otherwise) has ever run this build.
- Stat-tracking heuristics (shots-on-target, pass completion, assists) are honest
  best-effort proxies, not perfect classifiers — documented inline in `README.md`.
- No crowd/commentary atmosphere, referee system, or half-time screen (all
  intentionally out of scope, see above).

## Performance observations

Only what has actually been verified: headless `--quit-after` boots are clean with no
script errors, and a `_process`/`_physics_process` audit (Phase 9) found no per-frame
allocations or resource loads in any per-player hot path. **No FPS, memory, or
allocation profiling has ever been performed on a real device or even a real windowed
Godot session** — this environment has no working GPU/compositor. Any performance claim
beyond "boots cleanly headless" would be speculation.

## Android readiness

Not export-ready. SDK path, debug keystore, Java, build-tools, and the Gradle Android
build template are all confirmed present/correctly located; `export_presets.cfg` looks
plausible. The export itself fails with an unitemized configuration-errors message that
only Godot's GUI export dialog expands. A human with GUI access should open
**Project > Export > Android** in the real Godot 4.4 Editor and read the itemized error
list — likely candidates (informed guesses, not confirmed diagnoses) are a missing app
icon reference, an invalid permission entry, or a package-name format issue.

## Flutter integration status

Not re-verified this pass (out of scope for a Godot-project-only audit agent) — the
files exist and read correctly on their face (`lib/games/football/football_game_screen.dart`,
`android/app/src/main/kotlin/com/example/game_hub/GodotEmbedView.kt`/
`GodotEmbedViewFactory.kt`, `linux/godot_embed/`), but nothing there was executed or
checked against a real build this session.

## Multiplayer status

Built and internally consistent per extensive code review across Phases 8, 12, 14 — and,
as of **Phase 15, actually run for real** between two live headless `godot4` processes on
this machine (see below). The core connection/ready/sync-signal layer is now genuinely
verified, not just read. What remains untested: a live in-match gameplay session (no
display/input available to drive one headlessly), UDP broadcast auto-discovery
specifically (the live test connected via manual IP, matching this project's own
"Manual IP Connection" feature — broadcast discovery uses different code paths and
was not exercised), and anything across a real physical LAN (this test was two
processes on one machine over loopback, not two separate devices).

### Live multiplayer test (Phase 15)

Two real `godot4 --headless` instances were launched as separate OS processes, driven by
a temporary test hook added to `NetworkManager._ready()` for the duration of the test and
**removed immediately afterward** (confirmed via `--import`: zero parser errors both
before and after; not part of the shipped game). Host called `host_game("FRANCE")`;
client called `join_game("127.0.0.1", "SPAIN")` after a 1s delay. Real, captured results:

- **Connection**: client's `connection_succeeded` fired — a genuine ENet connection was
  established over loopback.
- **Country exchange**: both sides' `countries_known` fired with matching values
  (`host=FRANCE client=SPAIN`) — the `_rpc_announce_country`/`_rpc_announce_host_country`
  RPC pair works correctly in practice, not just by inspection.
- **Ready system**: both sides called `set_local_ready(true)`; both converged on
  `remote_ready_to_play(FRANCE, SPAIN)` — confirms the ready-system race-condition
  analysis done in an earlier code review was correct in practice, not just in theory.
- **Ping**: the client's `ping_updated` signal fired repeatedly with real RTT values,
  consistently **6-7ms** (expected for loopback).
- **Disconnect detection**: the client process was killed abruptly (`kill -9`, simulating
  a crash or dropped connection rather than a graceful quit). The host's
  `opponent_disconnected` signal did NOT fire within the first ~6 seconds, but **did
  fire within a second, longer test window (confirmed to occur somewhere between 6s and
  ~31s after the kill)** — this is expected ENet behavior (peer-timeout detection, not
  instant on a non-graceful disconnect) but is a real, previously-undocumented
  characteristic worth knowing: a player whose WiFi drops mid-match may see the existing
  "Connexion perdue" retry screen appear only after a delay of up to ~30 seconds, not
  instantly. A *graceful* quit (the existing "Quit Match" button, which calls
  `disconnect_network()` explicitly) was not separately re-verified for its disconnect
  latency in this test, but is architecturally a clean, immediate teardown rather than a
  timeout-based one, so it should not have this same delay.

### Live in-match gameplay test (Phase 16) — critical bug found and fixed

Phase 15 verified the connection/lobby layer only. Phase 16 extended the same temporary
test-hook technique (added to `NetworkManager`, removed immediately after, confirmed via
`--import`: zero parser errors before and after) to drive **both instances all the way
into a real, live match** — the first time this project's actual in-match replication
code has ever executed for real.

**The first attempt failed, and the failure was real and significant**: the client logged
`ERROR: Node not found: ".../Ball/@MultiplayerSynchronizer@62"` and equivalent errors for
every one of the 22 players' synchronizers, and the ball never moved on either side.
Root cause: `Player.setup_multiplayer_replication()` and `Ball.setup_multiplayer_replication()`
create their `MultiplayerSynchronizer` nodes via `MultiplayerSynchronizer.new()` without
an explicit `.name`. Godot auto-generates a name like `@MultiplayerSynchronizer@62` using a
creation-order-dependent global counter — which is **not guaranteed to match** between the
host's and client's independently-built scene trees, since the two processes don't reach
that point through identical node-creation histories. This silently broke ALL Player/Ball
state replication. A second, related instance of the same root cause also affected
`ActorsContainer.spawn_player()`, where the 22 spawned `Player` nodes relied on Godot's
default same-type-sibling auto-naming instead of an explicit name.

**Fix** (confirmed minimal, not an architecture change, per this phase's rules): both
`setup_multiplayer_replication()` methods now set `sync.name = "NetworkSync"` before
`add_child()`, and `ActorsContainer.spawn_players()` now names each player
`"Player_<country>_<squad_index>"` — both fully deterministic and identical on host and
client since they derive from data, not from call-order timing. Re-running the same test
**after the fix produced zero errors** and, further, a full live match was actually
started (kickoff triggered via a real simulated client-side "pass" press relayed through
the genuine `NetworkManager` input-relay RPC path — this also incidentally verified that
relay path for real) and observed for ~40 seconds of live play:

- `time_left` counted down in lockstep on both sides (120.0 → 80.0), confirming the
  host-authoritative clock-sync RPC works during real gameplay, not just at rest.
- The ball's position, sampled every 2s on both sides, **closely tracked between host and
  client** (e.g. host `(429.6049, 214.9876)` vs. client `(429.6048, 214.9876)` at a
  matching tick; other samples showed small, expected lag consistent with the
  documented lerp-toward-latest-target interpolation approach, not a hard desync).
- Zero `SCRIPT ERROR`/`Node not found`/other runtime errors on either side across the
  entire live match window.

**Not exercised by this test**: a goal actually being scored (AI-vs-AI play didn't produce
one in the ~40s window observed — the goal-sync RPC path itself was already separately
verified by code review in Phase 8/12, but not re-confirmed live this phase), pause
synchronization, sprint/pass/shot input synchronization specifically (the kickoff-pass
input relay was verified as a side effect, but not shooting/sprinting), and goalkeeper
behavior sync. A longer live-match window or a scripted "force a goal" test would be
needed to close those gaps — reasonable follow-up, not attempted here given the time
already invested in this phase's other verification work.

## Recommended next steps

1. A human with GUI access needs to open the project in the real Godot 4.4 Editor and
   check **Project > Export > Android** for the itemized configuration-error list.
2. A real Android device or emulator test of the exported build.
3. A real two-*device* LAN multiplayer test over an actual WiFi/hotspot network. Phases
   15-16 verified the connection/ready/kickoff/clock/ball-sync layers for real, but only
   between two processes on one machine over loopback — real physical-device latency,
   packet loss, and UDP broadcast discovery specifically (only manual-IP was live-tested)
   remain unverified. Also worth confirming live: a goal actually syncing correctly
   (not observed in the ~40s AI-vs-AI window tested), pause behavior in a networked
   match, and sprint/pass/shot input relay under real network conditions.
4. A real playtest for game-feel tuning (movement, AI difficulty, camera zoom/shake
   values, touch control ergonomics) — all of this has only ever been statically
   verified via code reading and headless boots, never played.
