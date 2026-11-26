package game

validation_error_name :: proc(err: Validation_Error) -> string {
	return validation_error_name_a(err)
}

@(private)
validation_error_name_a :: proc(err: Validation_Error) -> string {
	#partial switch err {
	case .None:
		return "none"
	case .ObstacleCountMismatch:
		return "obstacle count mismatch"
	case .FogVisibleNotExplored:
		return "fog: visible cell is not explored"
	case .AliveCountMismatch:
		return "alive count mismatch"
	case .SelectedCountMismatch:
		return "selected count mismatch"
	case .FreeCountMismatch:
		return "free slot count mismatch"
	case .FreeSlotInvalid:
		return "invalid free slot"
	case .UnitGenerationZero:
		return "unit generation is zero"
	case .UnitPositionInvalid:
		return "unit position out of bounds"
	case .UnitOnObstacle:
		return "unit stands on an obstacle"
	case .UnitWorldOutOfBounds:
		return "unit world position out of bounds"
	case .UnitHealthInvalid:
		return "unit health invalid"
	case:
		return validation_error_name_b(err)
	}
}

@(private)
validation_error_name_b :: proc(err: Validation_Error) -> string {
	#partial switch err {
	case .UnitPathTooLong:
		return "unit path too long"
	case .UnitPathIndexInvalid:
		return "unit path index invalid"
	case .UnitPathCellInvalid:
		return "unit path cell invalid"
	case .UnitPathBlocked:
		return "unit path crosses an obstacle"
	case .UnitPathNotAdjacent:
		return "unit path has non-adjacent cells"
	case .UnitPathDetached:
		return "unit path is detached from unit position"
	case .UnitStateInvalid:
		return "unit state inconsistent with path"
	case .UnitPatrolInvalid:
		return "unit patrol state invalid"
	case .UnitAttackMoveInvalid:
		return "unit attack-move state invalid"
	case .AttackTargetInvalid:
		return "attack target handle is stale"
	case .AttackTargetFriendly:
		return "attack target is friendly"
	case .AttackTargetSelf:
		return "unit targets itself"
	case .CooldownInvalid:
		return "attack cooldown out of range"
	case .UnitAggroInvalid:
		return "unit aggro timer state invalid"
	case .UnitGroupMaskInvalid:
		return "unit control group mask invalid"
	case .UnitOrderQueueInvalid:
		return "unit queued order invalid"
	case:
		return validation_error_name_c(err)
	}
}

@(private)
validation_error_name_c :: proc(err: Validation_Error) -> string {
	#partial switch err {
	case .SelectedNotPlayer:
		return "enemy unit is selected"
	case .WaypointCountInvalid:
		return "waypoint count invalid"
	case .WaypointPositionInvalid:
		return "waypoint position invalid"
	case .WaypointBlocked:
		return "waypoint is blocked"
	case .WaypointCurrentInvalid:
		return "current waypoint index invalid"
	case .CommandCountInvalid:
		return "command count invalid"
	case .CommandIndicesInvalid:
		return "command queue indices invalid"
	case .PlayerMissing:
		return "player unit is missing"
	case .UnitWorldMismatch:
		return "unit world position does not match path state"
	case .UnitPathStartInvalid:
		return "unit path does not start at unit position"
	case:
		return "unknown validation error"
	}
}
