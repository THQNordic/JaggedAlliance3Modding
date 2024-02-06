SetupVarTable(collision, "collision.")

_AsyncCollideCallbacks = {}

DefineClass.TerrainCollision = {
	__parents = { "Object" },
	flags = { cofComponentCollider = true },
}
