class_name MovementTuning

# Phase 2: frame-rate-independent accel/decel instead of an instant velocity
# snap. Reaching full speed from a stop within ~0.15s and coming to a full
# stop within ~0.2s reads as tight/responsive (mobile action game, not a
# sim) while removing the "stiff" instant-direction-change feel.
#
# Single source of truth shared by PlayerStateMoving (human-controlled
# players) and AIBehavior (CPU-controlled players) so both share the same
# movement feel. Previously these were two independently-declared copies
# of the same two consts, manually kept in sync via a comment; consolidated
# here in Phase 10 to remove that duplication.
const ACCEL_TIME_TO_MAX := 0.15
const DECEL_TIME_TO_STOP := 0.2
