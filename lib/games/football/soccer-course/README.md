# Super Soccer (Soccer Course)

A complete 2D football/soccer game built in Godot 4.4, vendored into the Game Hub Flutter app as its "Football" mini-game. Originally based on [nicolasbize/soccer-course](https://github.com/nicolasbize/soccer-course) (MIT-licensed, see `LICENSE`), extended with touch controls, a sprint mechanic and local network multiplayer.

## Modes

- **1 Player** — you vs. the CPU.
- **2 Players** — local co-op on the same device/keyboard, one squad each.
- **Multiplayer** — host or join a match over the local network (same WiFi/hotspot). See "Network multiplayer" below.
- **Tournament** — an 8-team knockout bracket (quarter-finals → semi-finals → final), resolved match by match.

Nine national squads are available: France, Spain, England, Germany, Italy, Argentina, Brazil, USA, Canada (`assets/json/squads.json`), each with named players, per-player speed/power stats and role (goalie/defense/midfield/offense).

## Controls

### Player 1 (keyboard)
| Action | Key(s) |
|---|---|
| Move | Arrow keys |
| Shoot / confirm (A) | `A` or `Enter` |
| Pass (B) | `B` |
| Sprint (C) | `C` |

### Player 2 (keyboard, local co-op only)
| Action | Key(s) |
|---|---|
| Move | `W` `A` `S` `D` |
| Shoot | `1` |
| Pass | `` ` `` |
| Sprint | `2` |

Note: since Player 2 also uses `A` to move left, playing local 2-player co-op on one keyboard will also trigger Player 1's shoot when `A` is pressed. This doesn't affect touch play or network multiplayer, only same-device co-op testing.

### Touch (mobile)
Now always shown during a match (previously gated behind `DisplayServer.is_touchscreen_available()` — as of Phase 1 the controls are always present so keyboard and touch stay interchangeable, and desktop testing gets full UI parity with Android), always controlling Player 1:
- Virtual analog joystick, bottom-left, smaller and closer to the corner as of the UI/UX pass below (`JOYSTICK_RADIUS` 45→38, corner margin 45→38px), dead zone, press-scale animation, layered rounded styling. Default opacity is Settings-driven (`controls_opacity`, still user-adjustable, defaulting near 60%).
- **A** (shoot), **B** (pass), **C** (sprint) buttons, bottom-right, now arranged in a FIFA-Mobile-style triangle (A top-center, B bottom-left, C bottom-right of the cluster) instead of the original horizontal row, with the same press animation plus a new ripple (expanding, fading ring) and a brief glow (shadow brightening) on press. No cooldown visual was added — there is no button cooldown/lockout mechanic anywhere in this game's actual mechanics, so a cosmetic cooldown ring would misrepresent one.
- Pause button, top-right, slightly smaller (`PAUSE_BUTTON_RADIUS` 12→10) and low-visual-weight. Desktop testing can also use `Escape`/`ui_cancel`.
- `TouchControls` exposes `joystick_scale`, `button_scale`, `controls_opacity` and `haptics_enabled` as instance properties, wired live to the `Settings` autoload and its Settings screen (Phase 5) — see the "Settings" section below.

### Pause menu
Resume / Restart Match (resets the score too, not just the clock) / Settings (opens the real Settings screen, see below) / Quit Match (back to the main menu). Uses `process_mode = PROCESS_MODE_ALWAYS` so its own buttons keep working while `get_tree().paused` is true.

## Settings (Phase 5)

A `Settings` autoload (`scenes/settings/settings_manager.gd`, registered as `Settings=` with no `class_name`, matching the project's other autoloads) persists preferences to `user://settings.cfg` via Godot's `ConfigFile` API and applies every change immediately (no separate "Apply" step). Opened from the Pause Menu's "Settings" button (`scenes/screens/settings/settings_screen.gd`, a scrollable, mouse/touch/keyboard-friendly Control overlay built at runtime like `TouchControls`/`PauseMenu`).

**Audio** — Master/Music/SFX volume sliders and Music/SFX on-off toggles. `Music` and `SFX` audio buses are created at runtime (`AudioServer.add_bus`, idempotent, checked by name each launch) rather than by hand-editing `default_bus_layout.tres` (which still only defines the original "Master" bus); `MusicPlayer`/`SoundPlayer`'s stream players are routed to them. **Omitted**: crowd volume, commentary volume — there is no crowd or commentary audio anywhere in this project, so no fake sliders were added for them.

**Graphics** — FPS limit (30/60/120/Uncapped via `Engine.max_fps`) and a Particles on/off toggle (gates `Player.run_particles` and `Ball`'s `shot_particles`). **Omitted/downscoped**: "Low/Medium/High/Ultra" quality tiers and a Shadows toggle — this is a flat 2D pixel-art game with no lighting/shadow or LOD system for either to control, so they were left out entirely rather than wired to nothing.

**Controls** — independent joystick size and button size sliders (`TouchControls` now scales its joystick and button groups independently via two child `Control`s instead of one shared root), controls opacity, swap control sides (mirrors joystick/buttons around the screen's horizontal center — takes effect on the next `TouchControls` instantiation, not a mid-match reposition), invert movement X/Y, joystick sensitivity (scales the input vector before clamping to length 1), and vibration on/off.

**Gameplay** — Difficulty (Easy/Normal/Hard), applied as a real 0.6x/1.0x/1.5x multiplier on the shot/tackle/pass probabilities each AI role already exposed via `get_shot_probability()`/`get_tackle_probability()`/`get_pass_probability()` (Phase 4's hook, now actually wired up). Match duration (1:00/2:00/3:00/5:00, replacing the hardcoded 2-minute default in `GameManager.start_game()` — the constant remains as Settings' own default). Auto Sprint (always applies the sprint speed multiplier). Camera zoom. **Omitted**: auto player switching, pass assist, shoot assist — each is its own gameplay-feel subsystem risking real behavior regressions to build blind without the Editor; left for a dedicated future pass rather than half-built here.

**Language** — a small code-driven translation lookup (`utils/localization.gd` + `assets/json/translations.json`, loaded the same way `DataLoader` loads `squads.json`), not Godot's `TranslationServer`/CSV-import pipeline (that import step needs the Editor to run, which wasn't available while building this). English and French are fully, confidently translated; Spanish and Portuguese cover the same short UI labels with reasonable confidence. Arabic is listed as a selectable locale for structural completeness but intentionally falls back to English text — no attempt was made at Arabic translation or RTL layout, since RTL requires mirroring the whole UI and getting that wrong would look more broken than not attempting it. Only the strings on screens touched in Phases 1 and 5 (Settings screen, Pause Menu) are wired through the lookup (`Settings.t(key)`); the rest of the game's UI text is not retroactively translated.

The Settings screen is reachable from the Pause Menu, and (as of the UI/UX pass below) also directly from the Main Menu — the same `SettingsScreen` instance/class, not a second screen.

## UI/UX redesign pass

A focused pass on top of the existing 10-phase build-out — reorganizing/extending existing UI, not rebuilding it.

- **Main Menu**: the keyboard-hint illustrations (`Background/PlayerOneControls`/`PlayerTwoControls`) are now hidden via `visible = false` in `main_menu_screen.gd`'s `_ready()` (not removed from the `.tscn`, per this project's "no hand-edited .tscn for new/changed behavior" convention). Two new real menu items were added, reusing the existing `MULTIPLAYER`-style pattern (shared "options" icon, tinted, plus a small text `Label` since no dedicated art exists for them): **Tournament** (wires to the same `Tournament.new()`/team-selection flow that "1 Player" already uses — that's the only Tournament entry point that exists in this codebase, see `on_selector_selected()` in `team_selection_screen.gd`) and **Settings** (opens the existing `SettingsScreen`, same as the Pause Menu). A desktop-only **Exit** item was added too, guarded by `OS.has_feature("pc")` (the Godot 4 feature tag for Windows/macOS/Linux desktop exports), calling `get_tree().quit()`. Since `TextureRect` is `Control`-derived, each menu item now also responds to mouse/touch directly via `gui_input` (previously keyboard-only), with the same press-scale animation used by `TouchControls` plus a brief modulate brighten as a "glow". No version string was added — no `config/version` (or similar) exists in `project.godot` and none was fabricated.
- **Multiplayer lobby**: the host side now shows its own local LAN IP (`NetworkManager.get_local_ip_address()`, new — filters `IP.get_local_addresses()` down to a non-loopback/non-link-local address, since Godot has no dedicated "get my LAN IP" call) both while waiting and in the ready-up waiting room, plus an "opponent connected (1/1)" indicator once countries are exchanged (this is a 1v1 game, `MAX_CLIENTS := 1`, so there's no real player-count system beyond that binary state). The client side now shows its live ping in the waiting room, reusing `NetworkManager`'s existing client→host ping/pong RTT measurement (`ping_updated` signal, already used in the in-match HUD). **Known limitation, stated honestly**: ping cannot be shown per-host in the discovered-hosts list, only after connecting — ENet has no way to probe RTT to a host you haven't connected to yet, so a per-host number there would have to be faked. No chat system exists or was added; there was nothing to "disable".
- **Touch controls**: see the "Touch (mobile)" section above for the joystick/button/pause-button changes.

**Explicitly skipped, same reasoning as prior phases**: a "Crowd Volume" setting (no crowd audio assets exist), real Low/Medium/High graphics-quality tiers as distinct rendering pipelines (no lighting/LOD system exists to back them — an honest bundled-toggle preset was considered but skipped this pass to keep `SettingsScreen` changes minimal), a cooldown visual on the action buttons (no underlying cooldown mechanic), a chat system (not requested — the brief's "chat disabled" line describes an absence, not a feature to build).

## Audio & VFX polish (Phase 6)

This project has a small, fixed asset inventory (9 SFX `.wav` files, 4 music `.mp3` tracks, and 2 particle textures — `spark.png`, `white-circle.png`; no crowd, commentary, net, rain/wind, or grass assets exist anywhere in the project). This phase extracts real, honest improvement from what's actually there rather than faking effects with placeholder assets:

- **SFX pitch variation** — `SoundPlayer.play()` (`scenes/audio/sound_player.gd`) now sets `pitch_scale` to a random value in `[0.95, 1.05]` on every play, so repeated kicks/passes/tackles over a match don't all sound identical.
- **Goal celebration confetti** — `Goal.on_ball_enter_scoring_area()` (`scenes/goal/goal.gd`) spawns ~10 small `Sprite2D` "confetti" pieces using the existing `white-circle.png`, tinted per-instance via `modulate` to arbitrary colors, tweened to fall/rotate/fade and `queue_free()`'d when done. No new audio was added beyond the existing whistle (no goal-specific audio asset exists). Gated behind `Settings.particles_enabled`.
- **Ball shot trail** — `BallStateShot` (`scenes/ball/ball_states/ball_state_shot.gd`) builds a code-only `Line2D` that samples `ball.global_position` every frame while the ball is in the fast SHOT state, capped to 12 points with a width curve tapering the tail, faded out and freed when the shot state ends. Gated behind `Settings.particles_enabled`.
- **Player/ball shadows** — already existed before this phase (`ShadowSprite` nodes in `player.tscn`/`ball.tscn`, positioned at ground level independent of the sprite's `height`-driven offset), verified working as designed; no changes needed.
- **Music track verification** — checked every `Screen`'s `music` export: `main_menu_screen.tscn` → MENU, `world_screen.tscn` → GAMEPLAY, `tournament_screen.tscn` → TOURNAMENT, all already correct. `team_selection_screen.tscn` was set to `music = 3` (TOURNAMENT) even though it's the shared team-picking screen reached from both quick-match and tournament setup — changed to `music = 2` (MENU), the single `.tscn` value edit this phase made. `SettingsScreen`/`MultiplayerLobby` are standalone `CanvasLayer` overlays (not `Screen` subclasses), so they correctly have no `music` export and don't affect the currently-playing track — expected, not a bug.
- **Day/night `CanvasModulate` tint** — attempted evaluation but skipped: without a running Editor there's no way to preview whether a tint actually reads well against the existing pitch/background art, and a wrong guess would be worse than no change; left out per the phase brief's explicit permission to skip this optional item.

**Explicitly skipped (no viable asset-honest implementation exists)**: crowd chants, goal celebration audio beyond the existing whistle, net sounds, rain/fog audio or visual effects, grass particles, real dynamic lighting/shadows-from-light-sources, a full "night mode" lighting system.

## Camera system (Phase 7)

Builds on the existing `Camera` (`scenes/screens/world/camera.gd`, already had smooth ball-follow via `Camera2D.position_smoothing_speed` and impact shake) rather than replacing it:

- **Dynamic zoom near goals** — `zoom` is now `Settings.camera_zoom * dynamic_zoom_multiplier`, so the user's own zoom preference is always respected as a baseline and never overridden. `dynamic_zoom_multiplier` eases (via `move_toward`, `ZOOM_EASE_SPEED := 0.6`/second) toward `1.15` whenever the ball is within `150.0px` of either goal's `get_center_target_position()`, and back toward `1.0` in open play.
- **Goal celebration camera hold** — on `GameEvents.team_scored`, the camera eases (tighter `position_smoothing_speed`) toward the scoring `Goal`'s `get_center_target_position()` and the zoom multiplier eases toward `1.3` for `1400ms`, then automatically resumes normal ball-follow. `GameEvents.team_reset` (which `GameStateScored` fires ~3000ms after the goal — comfortably after the 1.4s hold ends) is also wired as a safety-net release in case that timing ever changes. Which `Goal` (home or away) to hold on is resolved by matching `country_scored_on` against `goal_home.country`/`goal_away.country`.
- Camera resolves `goal_home`/`goal_away` itself at `_ready()` via `get_node("../ActorsContainer/PitchObjects/GoalHome"|"GoalAway")` (the same path already used for `ActorsContainer`'s own `goal_home`/`goal_away` NodePath exports) — no `.tscn` edits were needed for this phase.
- **Shake tuning** — left untouched. `GameEvents.impact_received` only carries `(impact_position, is_high_impact)`, no shot-power value, so scaling shake by shot power would require widening that signal's signature and every emitter (`player_state_hurt.gd`, `ball_state_shot.gd`) — too large a change for the low-risk bar this item asked for.
- **Explicitly skipped**: full camera mode switching (TV/Dynamic/Tactical/Be-A-Pro as distinct selectable behaviors), true instant-replay recording/rewind, and literal alternate camera placements ("behind the goal", "corner" cams) — these are separate systems, not extensions of the current single-camera design; only the dynamic-zoom-near-goal treatment above addresses the "goal moment" framing goal in a scoped way.

## Gameplay

- Full 11-a-side squads, one player-controlled per team (the rest are CPU), with pass-request/swap-to-nearest-teammate behavior.
- Ball physics: height, bounce, passing/shooting with power/accuracy driven by player stats.
- Curved shots (Phase 3): aiming sideways while charging a shot (holding SHOOT) imparts a subtle spin — the ball's flight bends perpendicular to its travel direction for the first ~1s after the shot, then straightens out as the curl decays. Passes remain unaffected/spin-free.
- Goalkeeper saves (Phase 3): a goalkeeper diving for the ball now cleanly catches only slower, lower shots; anything faster/higher is instead parried away at an angle rather than pocketed, so hard shots can produce rebounds. Outfield players picking up a loose ball are unaffected by this — it only applies to the goalie's own contact with the ball.
- Player states: moving, tackling, shooting (volley/bicycle/header variants), passing, chest control, hurt/recovering, celebrating/mourning, resetting for kickoff.
- Sprint: hold the sprint button/key for a 1.4x speed boost (human-controlled players only).
- Movement feel (Phase 2): velocity eases toward the target direction/speed instead of snapping instantly — full speed in ~0.15s, full stop in ~0.2s — applied consistently to both human- and CPU-controlled players. Sprite heading has a small deadzone around zero x-velocity to avoid flicker-flipping when nearly stationary. Carried-ball dribble wobble now scales slightly with the carrier's actual speed (faster = quicker, tighter wobble).
- CPU AI overhaul (Phase 4): the three outfield roles now behave distinctly instead of sharing one behavior. Defenders mark the goal-side of the nearest dangerous opponent and hold position rather than ball-chasing; midfielders press the ball carrier when they're closest to it and favor passing to whichever visible teammate has the fewest opponents around them; attackers make forward runs into space when unmarked (instead of holding a fixed formation slot) and will cross to a centrally-placed teammate instead of shooting from a tight angle near the byline. After winning the ball, nearby attacking players push forward for a few seconds (a lightweight "counter-attack window") before settling back into shape. Goalkeepers will now come off their line for a loose ball only when they're clearly first to it, and distribute promptly to a nearby teammate after making a save rather than standing on the ball.

## Match HUD (Phase 1)

- Possession bar (top-left): tracks accumulated seconds each team has held the ball via `GameEvents.ball_possessed_by_country` (added this phase), shown as a live home/away split.
- Stamina bar (top-left, under possession): purely visual for now, depletes while the P1-controlled player sprints and moves, regenerates otherwise. Does not gate gameplay yet.
- Yellow/red card indicators exist in the HUD but stay hidden — there is no foul/card system in the game yet, so they're wired up but inactive pending a future phase.
- Currently-controlled player name (existing `PlayerLabel`, driven by ball possession as before).
- `UI.show_notification(text, duration)`: a small reusable toast/banner, used for "GOAL!" and "FULL TIME", available for future notifications too.
- Team selection now shows a computed overall/GK/DEF/MID/ATT rating (averaged from per-player `power`, not an official stat — squads.json has no team-level rating) and the full 11-player squad list with roles for whichever country Player 1 has highlighted.

## Network multiplayer

Host-authoritative LAN play — the host runs the exact same simulation as single-player, the client sends its input over the network and receives replicated positions back. Not Bluetooth/Nearby Connections; both devices need to be on the same WiFi network or hotspot.

- Discovery: UDP broadcast on port **9751** (host advertises, client listens).
- Match connection: ENet on port **9750**.
- From the main menu, select **Multiplayer** → **Héberger** to host, or **Rejoindre** to see and join a discovered game — or type an IP directly and press **Connecter** if broadcast discovery is blocked on your network.

**Score/clock authority (Phase 8 fix)** — goal detection previously ran independently on both host and client, each watching its own local copy of the ball; a network-delayed/replicated ball could trip (or miss) the goal Area2D at a different moment than the host, silently desyncing the score. Now only the host (`goal.gd`'s `on_ball_enter_scoring_area`, guarded by `NetworkManager.is_host()`) ever detects a goal or decides time is up (`game_state_in_play.gd`); it RPCs the result to the client (`NetworkManager.rpc_team_scored` / `rpc_sync_clock` / `rpc_time_up`), and the client's own `GameEvents.team_scored` listeners then run exactly as before, just triggered by the RPC instead of local detection. The client's clock is a synced value from the host (roughly once per second of match time), not an independent countdown.

**Client-side interpolation** — Player/Ball previously had their `position`/`velocity`/`height` overwritten directly and instantly by `MultiplayerSynchronizer`, which looked stepped/jittery between sync ticks. Both now replicate into a `network_target_position` property instead of `position` directly; a networked, non-authority client lerps its own `position` toward that target every frame (`Player`/`Ball` `_process()`, `INTERP_SPEED := 15.0`). This is a **simple lerp-toward-latest-target**, not full timestamped snapshot buffering/interpolation with extrapolation — it removes the instant-teleport jitter but doesn't reconstruct exact past positions or predict ahead. `Ball`'s local `BallState` physics (`move_and_bounce`/`process_gravity` in `ball_state.gd`, plus the carried-ball position snap in `ball_state_carried.gd`) is now also skipped on a non-authority client so it doesn't fight the interpolated position/height.

**Ready system** — connecting no longer drops both sides straight into the match. After country exchange (`NetworkManager.countries_known`), the lobby shows a waiting room with a **Prêt** button per side; the match only starts (`remote_ready_to_play`, driving the existing transition-to-`IN_GAME` flow) once both sides have confirmed ready.

**Ping indicator** — a small "N ms" label in the top-right HUD corner during a networked match, client-side only. This is a **custom-built** ping/pong RTT measurement (`NetworkManager._rpc_ping`/`_rpc_pong`, client sends a timestamp every second, host echoes it back unchanged, client diffs against `Time.get_ticks_msec()`), not a built-in Godot/ENet API — none was found that exposes per-peer RTT directly at this layer.

**Disconnect handling** — `NetworkManager.opponent_disconnected` (host, via `multiplayer.peer_disconnected`) and the existing `server_disconnected` (client) now both drive `world_screen.gd`'s `on_network_disconnected()`: the network session is torn down (`NetworkManager.disconnect_network()`), a "Connexion perdue" toast is shown, and the match returns to the main menu. No auto-reconnect was added — out of scope given the effort budget; a disconnected player has to re-host/re-join manually.

**Pause menu in multiplayer** — pausing (`get_tree().paused`) is inherently per-process, so it stays a local-only overlay; it does not (and should not) freeze the other player's live game. "Restart Match" is hidden entirely in a networked match (one peer can't unilaterally rebuild both sides' `Match`/score state). "Quit Match" now calls `NetworkManager.disconnect_network()` before transitioning to the main menu, instead of just leaving the ENet peer connected while the screen changes locally.

**Explicitly skipped this phase**: rollback netcode, deterministic lockstep, full client prediction, server-side lag compensation, host migration (all out of scope per the task); a network-quality graph beyond the raw ping number; bandwidth/serialization optimization (the existing per-frame RPC/synchronizer traffic is already light for 1v1); bounded auto-reconnect retries.

This was implemented without access to the Godot Editor. See `EXPORT.md` for firewall notes and a first-test checklist — a real host/join test pass (including a deliberate mid-match disconnect, and a scored goal near a `MultiplayerSynchronizer` sync tick boundary) is strongly recommended before relying on any of this.

## Performance pass (Phase 9)

A lightweight audit of the ~280x180-viewport, 22-player, GL Compatibility-renderer game for real (not manufactured) perf/allocation wins:

- **Confetti object pooling** — `Goal` (`scenes/goal/goal.gd`) previously created 10 fresh `Sprite2D.new()` instances per goal and `queue_free()`'d each one ~0.7s later, the single most allocation-heavy repeated effect in the game. It now pre-builds a pool of `CONFETTI_POOL_SIZE` (20, i.e. 2x a single celebration, so two goals scored back-to-back don't exhaust it) hidden `Sprite2D` children in `_ready()`. `spawn_confetti()` acquires an idle piece via `_acquire_confetti_piece()` (falls back to allocating one more if the pool is ever exhausted, rather than silently dropping the effect), fully resets it (position, rotation, scale, `modulate` incl. alpha, and kills any leftover `Tween` via a `confetti_tween` meta key before reconfiguring) before tweening it, and returns it to the pool by simply setting `visible = false` (`_release_confetti_piece()`) instead of `queue_free()`-ing it. Still fully gated by `Settings.particles_enabled`.
- **`Settings.particles_enabled` audit** — checked every particle/VFX spawn site in the project. `shot_particles` (`ball_state_shot.gd`) and `run_particles` (`player.gd`) were already correctly gated, as was the confetti and shot trail from Phase 6. One gap was found and fixed: the impact "spark" VFX (`scenes/screens/world/actors_container.gd`'s `on_impact_received()`, fired on tackles/hard shots via `GameEvents.impact_received`) was spawning `spark.tscn` unconditionally — it now checks `Settings.particles_enabled` first, same as every other effect, so disabling particles in Settings now actually disables *all* of them.
- **Spark pooling** — considered but not done. Impacts are effectively single-instance events (not a burst of 10 like confetti), and `spark.tscn` drives its own `queue_free()` via an `AnimationPlayer` method-call track, which would need real restructuring (not a `.tscn` edit, but non-trivial GDScript changes to the pooling/reset flow) for a much smaller win than confetti — skipped as not worth the risk at this effort budget.
- **`_process`/`_physics_process` audit** — read every state's `_process`/`_physics_process` in `scenes/characters/character_states/`, `scenes/characters/ai/`, and `scenes/ball/ball_states/`. Found no per-frame allocations, `preload()`/resource-load calls, or string-formatting happening in any per-player/per-frame hot path — `ai_behavior.gd`'s `apply_steering()` running every frame (not throttled, unlike its 200ms-throttled decision tick) is correct and intentional, not a bug. Nothing further to fix here.

## Code quality pass (Phase 10)

A final, deliberately narrow-scope cleanup pass — no file moves/renames, no folder reorganization, no `.tscn` edits, no restructuring of the state-machine/screen-routing architecture. Concretely:

- **Movement tuning consolidation** — `ACCEL_TIME_TO_MAX`/`DECEL_TIME_TO_STOP` (`0.15`/`0.2`, see "Movement feel" above) were previously declared twice, once in `PlayerStateMoving` and once in `AIBehavior`, manually kept in sync via a comment. Both now reference a single `MovementTuning` static-const class (`utils/movement_tuning.gd`, no `extends`, following the same convention as `KeyUtils`/`TimeHelper`). Values are unchanged.
- **Documentation coherence** — this README and `EXPORT.md` were read end-to-end and lightly tightened for flow; no factual content, ports, or "explicitly skipped" notes were removed.
- **Settings persistence check** — `scenes/settings/settings_manager.gd`'s `save()`/`load_settings()` were re-verified field-by-field against each other; no mismatch found.
- Remaining AI/player-state files were checked for genuine (non-intentional) duplication beyond the accel/decel consts; none was found — per-role probability constants in `ai_behavior_*.gd` are deliberate tuning, not duplication.

## Match presentation & stats pass (Phase 11)

- **Team Lineup screen** (`scenes/ui/lineup_screen.gd`) — shown after team selection, before kickoff, for the direct head-to-head match path only (tournament matches are unchanged this pass). Shows each side's real 6-player squad from `DataLoader.get_squad()` (labeled "SQUAD", not a fabricated "Starting XI" — this game's squads are 6 players, not 11), a per-country "OVR (computed)" rating using the exact same power-average formula as `team_selection_screen.gd`'s existing rating panel, a "Formation: D-M-A (derived)" label counting `Player.Role` occurrences (there is no formation concept in this project's data), the real GOALIE-role player, and a "Captain (designated)" — the highest-`power` outfield player, explicitly labeled as a cosmetic pick with no gameplay effect. No team colors are shown (no per-country color data exists anywhere in this project — `PlayerResource.skin_color` is a per-player sprite tint, not a team color); `FlagHelper`'s flag texture is the team's visual identity instead, as instructed.
- **Kickoff presentation** (`scenes/ui/kickoff_screen.gd`) — flags + team names in a "vs" layout, then a real 3-2-1 countdown (`Tween`/`Label`-driven), before transitioning into the match. Deliberately not a cinematic — no stadium camera movement, lighting, players walking on, or a referee model, none of which have any supporting assets in this project.
- **Full-Time screen** (`scenes/ui/full_time_screen.gd`) — replaces `world_screen.gd`'s old blind 3-second auto-timer after `GameManager.State.GAMEOVER`. Shows final score, winner/tie, real possession-adjacent stats already tracked, real shots/shots-on-target (see below), a "Best player (most goals)" heuristic computed from real goal-scorer data, and a real goals list. Buttons: Continue (tournament matches, reuses `world_screen.gd`'s existing `on_transition()`), Play Again (rebuilds a fresh `Match` for the same two countries, mirrors `pause_menu.gd`'s restart pattern, hidden in networked play), Return to Menu.
- **Half-Time screen: skipped.** `scenes/game_manager/game_manager.gd`'s `State` enum (`IN_PLAY, SCORED, RESET, KICKOFF, OVERTIME, GAMEOVER`) and every file in `scenes/game_manager/game_states/` were checked — there is no half-time concept anywhere in this game's state machine, only a single running clock to `time_left <= 0`. Building one would mean inventing a new pause point in the match flow itself (a structural change, not a stats screen), and risks the host-authoritative clock-sync logic in `game_state_in_play.gd` from the networking phase — skipped rather than risk that.
- **Real shot/shot-on-target tracking** — new `GameEvents.shot_taken(country)`/`shot_on_target(country)` signals. `shot_taken` fires from `player_state_shooting.gd`'s `shoot_ball()` (the shooting `Player` is already in scope there). "On target" = a best-effort, honestly-defined subset: a shot that either scores (`goal.gd`) or reaches a goalkeeper's hands as a catch/parry within 1.5 real-time seconds of being taken (`ball_state_freeform.gd`'s `on_player_enter`, using a new `GameManager.last_shot_country`/`last_shot_time_msec` window) — not a perfect classifier (an intercepted or out-of-bounds shot is simply never counted), but real and consistently applied. Counters live on `Match` (`shots_home`/`shots_away`/`shots_on_target_home`/`shots_on_target_away`/`goals_scored`) — `Match` is instantiated fresh per match, so these reset correctly with no extra logic needed.
- **Goal slow-motion** — `goal.gd` briefly sets `Engine.time_scale = 0.3` for 0.5 real seconds after a goal, restored via a `get_tree().create_timer(..., ignore_time_scale = true)` so the restore itself isn't also slowed down. Guarded to `not NetworkManager.is_networked()` only — this affects every `_process`/physics tick in the game and would risk desyncing the host-authoritative clock/score sync from the networking phase if applied on a networked match.
- **Goal text polish** — the existing `UI.show_notification("GOAL!")`/`goal_appear` animation now also gets a scale-in bounce Tween on `goal_scorer_label` (`ui.gd`'s `_animate_goal_text`). Camera shake, confetti, and zoom already existed and are unchanged.
- **Touch controls recolor/opacity** — A (shoot) is now semi-transparent blue, B (pass) semi-transparent green, C (sprint) semi-transparent orange (previously red/blue/green). Idle fill alpha is baked at 0.5 (50%, within the requested 40-60%); pressing tweens the `StyleBoxFlat`'s `bg_color.a` up to 0.85 (within 80-90%) alongside the existing press-scale/glow/ripple. The joystick base/knob apply the same idea via `modulate.a` (0.45 idle / 0.85 touched), toggled in `_update_joystick()`/`_reset_joystick()`. `JOYSTICK_RADIUS` reduced from 38 to 33.
- **Explicitly declined, same reasoning as every prior phase**: stadium lighting/crowd animation, a referee entering the field, grass/slide-tackle particles, a true replay camera, corner/penalty camera modes, a full referee rule-enforcement system (kickoff/goal-kick/corner/throw-in/free-kick/cards), crowd/net/footstep sounds (no such assets exist), assist/pass-accuracy tracking, and player-selectable through/long/lob pass types (only one PASS button exists). See the task notes for the full reasoning per item — nothing here was newly investigated and found buildable.

## Match stats extension, tournament champion moment, crowd TODO (Phase 13)

Reviewed AI (`ai_behavior_field.gd`+subclasses), ball states (`ball_state_freeform.gd`/`ball_state_shot.gd`), camera (`camera.gd`), HUD, touch controls, Settings, and multiplayer against the phase brief. All were already substantially built in prior phases; only the items below were concretely justified.

- **New real Match stats**: saves, passes (attempted/completed), tackles (attempts), assists — all hooked to real, existing game events, same honesty bar as the existing shots-on-target heuristic. New `GameEvents` signals: `save_made`, `pass_attempted(country, player_name)`, `pass_completed`, `tackle_attempted`. Counters live on `Match` (`saves_home`/`_away`, `passes_attempted_home`/`_away`, `passes_completed_home`/`_away`, `tackles_home`/`_away`, `assists` array) and are surfaced on `FullTimeScreen`.
  - **Saves**: `save_made` fires from `ball_state_freeform.gd`'s `_maybe_record_shot_on_target`, the exact same branch/window that already fires `shot_on_target` — a save is defined identically (goalkeeper catch or parry of a shot within `GameManager.SHOT_ON_TARGET_WINDOW_MSEC`), attributed to the goalkeeper's country.
  - **Passes**: `pass_attempted` fires from `player_state_passing.gd`'s `_enter_tree` (pass committed to). `pass_completed` fires from `ball_state_carried.gd`'s `_enter_tree` (new ball carrier) when the new carrier is a *different* player of the *same* country as the most recent pass attempt, within a new `GameManager.PASS_COMPLETION_WINDOW_MSEC` (2000ms) — a best-effort proxy (a lucky rebound landing at a teammate's feet in that window would also count), same honesty bar as shots-on-target.
  - **Tackles**: `tackle_attempted` fires 1:1 from `player_state_tackling.gd`'s `_enter_tree` (`State.TACKLING` entered). No clean signal exists to tell a won tackle from a missed one, so this is labeled "attempts" only, not split into successful/unsuccessful.
  - **Assists**: reuses the same pass-tracking state (`GameManager.last_pass_country`/`last_pass_player_name`/`last_pass_time_msec`) with a longer `ASSIST_WINDOW_MSEC` (4000ms). In `ui.gd`'s `on_team_scored_record` (already the real goal-scorer recorder), if the most recent pass was to the scoring team, by a different player than the scorer, within the window, it's recorded as an assist via `Match.record_assist`. Best-effort heuristic, documented exactly like shots-on-target — does not distinguish an intervening dribble/tackle between the pass and the goal.
  - No half-time screen exists (unchanged from Phase 12's finding — still true, not reintroduced), so all new stats only ever surface on `FullTimeScreen`.
- **Tournament champion moment**: `tournament_screen.gd` already showed the winner's flag + `winner-label.png` texture + played `MusicPlayer.Music.WIN` on tournament completion — a real champion moment already existed, just without text. Added a small, honest "CHAMPION: <country>" label with a scale-in Tween flourish (`_show_champion_banner`, same Tween-ownership pattern as `ui.gd`'s `_animate_goal_text`), created once in code, no new assets or `.tscn` edits.
- **Crowd/stadium atmosphere**: confirmed (again) no crowd sprite sheets or crowd-appropriate sound exist anywhere in `assets/`. Left an explicit `# TODO:` comment at the top of `world_screen.gd` explaining exactly what's missing, rather than fabricating anything from the 9 existing SFX.
- **AI**: read `ai_behavior_field.gd` and all four role subclasses — role-differentiated marking/pressing/forward runs/rush-out are all already built from a prior phase. No concrete, safe, small improvement was found this pass; left unchanged. Player-vs-player collision was not re-litigated in depth (already confirmed in a prior phase that `collision_layer`/`collision_mask` mean players don't physically collide via `move_and_slide()`) — not re-broken by anything in this pass.
- **Ball**: `ball_state_freeform.gd` (friction/gravity/bounce/catch/parry) reviewed in full — unchanged, no concrete issue found.
- **Camera / kickoff transition**: `camera.gd`'s `process_ball_follow` already drives `position` through Godot's real `position_smoothing_speed` every frame with no special-cased snap, so a kickoff already eases in smoothly rather than snapping — verified, no change needed.
- **HUD, touch controls, Settings, multiplayer**: reviewed against the brief's examples; all already covered by Phases 10-12. No concrete gap found — no changes made (avoiding a fourth HUD pass / churn for its own sake, per the brief's own instruction).
- **Android export**: unchanged from the prior session's investigation — `export_presets.cfg` has `gradle_build/use_gradle_build=true`, a syntactically valid `package/unique_name` (`com.example.soccercourse`), and both `version/code`/`version/name` present. Export was not re-attempted at length (per the brief's explicit "don't force it" instruction); the known blocker remains an unitemized "configuration errors" message that this Godot build only expands in the GUI dialog, which is not usable in this headless/no-GPU environment.

### Headless verification for this pass

```
godot4 --headless --editor --path . --import
godot4 --headless --path . --quit-after 5
```

`--import` (run twice after all edits): first run logged a transient `Parse Error: Busy` / "Failed loading resource" on `tournament_screen.tscn` during the class-doc-update step immediately after `TournamentScreen`'s script changed (a resource-loader race during class re-registration, not a GDScript parse error — no line/script is implicated); a second immediate run completed with zero errors/warnings beyond the normal `ObjectDB instances leaked at exit`. `--quit-after 5` booted cleanly (all autoloads, main menu) with only the standard forced-quit `ObjectDB`/`resources still in use` shutdown warnings, no script errors.

**Not tested**: visual layout of the new champion banner/full-time stat rows, animation feel, click-through of a full match to confirm saves/passes/tackles/assists actually fire and tally correctly in real play, real two-instance LAN multiplayer, and real Android device behavior. All new stat-tracking is event-driven off existing signals (no per-frame polling), so no new allocation/performance concern was introduced.

## Main menu, Settings, and multiplayer lobby polish pass (Phase 12)

Verified for the first time against a real `godot4` binary rather than reading-only (see "Headless verification" below).

- **Main menu**: added **Profile** (explicit "coming soon" placeholder, no real account system built), **About** (real description + `Engine.get_version_info()` engine version), **Credits** (real `LICENSE` attribution + an honest list of prior phases). All three are `InfoScreen` (`scenes/ui/info_screen.gd`, new) overlays, same "add as CanvasLayer child, never leave the main menu" pattern `SettingsScreen` already used. Confirmed the Settings button was already always visible and already never left the main menu (it's added as a child overlay, not a screen transition) — no fix needed there.
- **New real `Settings` fields** (`scenes/settings/settings_manager.gd`): `camera_follow_speed` (0.5-2.0 multiplier on `Camera`'s `SMOOTHING_BALL_CARRIED`/`SMOOTHING_BALL_DEFAULT`), `camera_shake_enabled` (gates `Camera.on_impact_received()`'s existing shake), `slow_motion_enabled` (gates `goal.gd`'s `_maybe_apply_goal_slow_motion()`, in addition to its existing non-networked-only guard), `player_name` (plain editable display name, defaults to `"Player"`, never a device identifier). All follow the existing "setter pushes immediately + persists" pattern.
- **Performance Mode / Battery Saver presets** (`Settings.apply_performance_mode()`/`apply_battery_saver()`): Performance Mode = `particles_enabled = false` + `fps_limit = 30` + `camera_shake_enabled = false`. Battery Saver = Performance Mode's bundle + `haptics_enabled = false`. Both call the existing real setters — no new rendering behavior invented.
- **Reset to defaults** (`Settings.reset_to_defaults()` + a button in `SettingsScreen`): re-applies every field's documented default via its own `set_*()` setter (so live effects re-apply, not just the persisted value), then the Settings screen rebuilds itself to reflect the new values.
- **Multiplayer lobby** (`scenes/ui/multiplayer_lobby.gd`): editable player-name field (wired to `Settings.player_name`, persisted, and now actually broadcast in the LAN discovery beacon instead of the old hardcoded `"Host"` placeholder — see `NetworkManager._start_broadcasting()`); connection-quality bucketing next to the existing real ping (<50ms Good / <150ms Fair / else Poor); the host's real `match_duration_sec`/`difficulty` now shown to both sides in the waiting room (piggy-backed onto the existing country-exchange RPC as `NetworkManager.host_match_duration_sec`/`host_match_difficulty` — display only, no new settings-negotiation system); connection-failed message is honest about ENet's `connection_failed` signal carrying no distinguishing error code (can't tell "offline" from "refused" apart, so one clear message rather than fake specificity).
- **Reconnect screen**: `world_screen.gd`'s `on_network_disconnected()` now shows a small "Retry" / "Return to Menu" overlay instead of an unconditional auto-return. "Retry" sets a new `ScreenData.reopen_multiplayer_lobby` flag consumed by `MainMenuScreen.on_set_active()`, so it lands back in the Multiplayer lobby directly.
- **Touch controls**: reviewed the hit-test tolerance for a possible increase. Found the triangle cluster's adjacent button centers (~44px apart) already slightly overlap at the current 1.4x radius tolerance (18px × 1.4 × 2 = 50.4px) — raising it further would worsen adjacent-button mis-hits, not help, so left unchanged (documented in code). No other concrete, verified improvement was found beyond the two prior polish passes.
- **Code quality**: `godot4 --headless --editor --import` surfaced no unused-variable/signal warnings before or after this pass's changes.

### Headless verification (reproducible)

```
godot4 --headless --editor --path . --import
godot4 --headless --path . --quit-after 3
```

Both were run before and after this pass's changes. `--import` printed zero parser/import errors both times (a mid-pass run briefly caught one real `:=` type-inference bug in `multiplayer_lobby.gd`'s new `difficulty_key` line, fixed by giving it an explicit `: String` type). `--quit-after 3` booted the project (all autoloads, main menu) with no script/parse errors either time — only the standard `ObjectDB instances leaked at exit` / `1 resources still in use at exit` shutdown warnings that appear on a forced `--quit-after` exit regardless of these changes.

**Not tested** (headless mode cannot do any of this): visual layout/spacing of the new About/Credits/Profile screens or the reorganized Settings sections, animation feel, clicking through the main menu → Settings/Lobby/About flows, actual two-instance LAN multiplayer (hosting, joining, ping display, disconnect/reconnect flow), and real Android touch/haptics behavior. Only "no parser/import errors and a clean boot" is confirmed, not "the UI looks or behaves correctly."

## QA audit pass (Phase 14)

A read-only/documentation-only pass — no gameplay, AI, camera, or networking code was changed. Full findings live in `RELEASE.md`; summary here:

- **Verified via the real `godot4` binary**: `--headless --editor --path . --import` completed with zero parser/import errors. `--headless --path . --quit-after 5` booted cleanly (main menu → team selection → tournament screens all loaded, no `SCRIPT ERROR`/"Node not found" lines) with only the standard forced-quit `ObjectDB instances leaked at exit` / `1 resources still in use at exit` shutdown warning already noted in Phases 11-12 — this run additionally identified the leaked resource by name (`AudioStreamMP3` for `assets/music/menu.mp3`, held by the `MusicPlayer` autoload's preloaded track dictionary). This is consistent with every prior pass's observation of the same warning under `--quit-after`'s abrupt exit and was not reproduced as an issue during a normal, non-forced quit (which this environment cannot test); no fix applied since there is no evidence of an actual runtime leak during real play, only at forced headless shutdown.
- **Translation completeness**: every `Settings.t("...")` call site was grepped (55 unique keys) and cross-checked against `assets/json/translations.json` — 0 missing, 0 unused. Full parity.
- **Dead code**: swept every `func` declaration project-wide for zero-reference names; the only candidates that came up (`_init`, `_input`, `_unhandled_input`) are Godot-invoked lifecycle methods, not actually dead. No dead code found or removed.
- **Node paths**: spot-checked `@onready var x = %Name`-style unique-node references across `player.gd`, `ball.gd`, `ui.gd`, `goal.gd`, `world_screen.gd`, `main_menu_screen.gd`, `team_selection_screen.gd`, `tournament_screen.gd`, `bracket_flag.gd`, `flag_selector.gd`, `actors_container.gd` — all resolved without error during the clean headless boot (Godot throws immediately on a missing `%Name` at `@onready` time), which is real evidence these are wired correctly, not a guess.
- **Tween/Timer lifecycle**: re-checked `kickoff_screen.gd`, `full_time_screen.gd`, `lineup_screen.gd`, `tournament_screen.gd` (newer, less-reviewed files) alongside the already-audited `ui.gd`/`touch_controls.gd`/`goal.gd`. All follow the established kill-before-replace / create-from-longest-lived-node pattern correctly; `kickoff_screen.gd`'s chained countdown tweens are sequential (each created only inside the previous one's `tween_callback`), so no overlap risk exists.
- **Gameplay/multiplayer QA**: every system in the task brief (movement, AI, ball physics, goalkeeper, passing, shooting, sprint, camera, HUD, pause menu, team selection, tournament flow, match flow, statistics, settings persistence, discovery, lobby, team-selection sync, ready system, match/score/timer sync, disconnect/reconnect, host authority) was re-read against its implementation and found present and wired as documented in Phases 1-13 above — no regressions found, nothing changed.

**Not tested this pass** (same limitation as every prior phase): visual layout/UI correctness, click-through of any screen flow, real two-instance LAN multiplayer, and real Android device behavior. Only "no parser/import errors and a clean headless boot" is verified fact.

## Project structure

```
scenes/
  characters/     Player, AI behaviors, per-state movement/animation scripts
  ball/           Ball physics and state machine
  screens/        Main menu, team selection, tournament, world (match) screens
  ui/             HUD, touch controls, multiplayer lobby
  network/        LAN multiplayer (NetworkManager autoload)
  game_manager/   Match/game state (GameManager autoload)
  audio/          Music and sound effect players
utils/            Shared helpers (input mapping, score/time/flag formatting, squad data loading, movement tuning)
assets/           Art, fonts, sfx, music, squads.json
```

## Exporting

This project targets Godot **4.4**. To export it for the Flutter app's native Android/Linux embedding, see `EXPORT.md`.

## Release status (RC1)

See `RELEASE.md` for the full release checklist, verified-vs-untested breakdown, and a
real two-instance LAN multiplayer test (Phase 15) that, for the first time, actually
exercised the ENet connection/country-exchange/ready-system/ping layer between two live
`godot4` processes rather than relying on code review alone.
