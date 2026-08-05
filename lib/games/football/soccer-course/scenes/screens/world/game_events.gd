extends Node

signal ball_possessed(player_name: String)
signal ball_possessed_by_country(country: String)
signal ball_released
signal game_over(country_winner: String)
signal kickoff_ready
signal kickoff_started
signal impact_received(impact_position: Vector2, is_high_impact: bool)
signal score_changed
signal team_reset
signal team_scored(country_scored_on: String)

# New this pass: real shot/shot-on-target tracking for the Half-Time/
# Full-Time stat screens. shot_taken fires once per shot attempt (from
# player_state_shooting.gd's shoot_ball(), which already has the shooting
# Player in scope). shot_on_target fires for a best-effort, honest subset of
# those shots: one that either scores (see goal.gd) or reaches a
# goalkeeper's hands as a catch/parry shortly after being taken (see
# ball_state_freeform.gd's on_player_enter) - not a perfect "on target"
# classifier (a shot intercepted by an outfield defender, or one that goes
# out of bounds, is simply never counted as on-target), but a real,
# non-fabricated definition consistently applied.
signal shot_taken(country: String)
signal shot_on_target(country: String)

# New this pass: saves/passes/tackles for the Full-Time stat screen, same
# honest-heuristic spirit as shot_on_target above - see GameManager and
# Match for exactly how each is recorded.
# save_made: fired from ball_state_freeform.gd's _maybe_record_shot_on_target
# alongside shot_on_target - a "save" is defined identically to an on-target
# shot that reaches the goalkeeper (catch or parry), just attributed to the
# GOALKEEPER'S country instead of the shooting country.
signal save_made(country: String)
# pass_attempted: fired once per pass, from player_state_passing.gd's
# _enter_tree (the moment a pass is committed to), with the passer's name so
# GameManager can track a short completion/assist window (mirrors
# last_shot_country/last_shot_time_msec exactly).
signal pass_attempted(country: String, player_name: String)
# pass_completed: fired from ball_state_carried.gd's _enter_tree - the
# cheapest real signal for "ball changed possession" - when the new carrier
# is the SAME country as the most recent pass attempt, a different player
# than the passer, and within GameManager's short completion window. This is
# a best-effort proxy (a rebound off a teammate that happens to land at
# another teammate's feet in the same window would also count), not a
# perfect completion classifier - same honesty bar as shot_on_target.
signal pass_completed(country: String)
# tackle_attempted: fired from player_state_tackling.gd's _enter_tree, a
# direct 1:1 event (State.TACKLING is entered). Only attempts are counted -
# no clean signal exists to distinguish "won the ball" from "missed", so
# this is labeled as attempts only, not split into successful/unsuccessful.
signal tackle_attempted(country: String)
