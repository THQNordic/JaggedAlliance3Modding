-- Slab
const.SlabGroundOffset = -50 -- // ground got dropped by this much to avoid Z fight & passability issues
const.SlabNoMaterial = "none"
const.SlabSize = point(const.SlabSizeX, const.SlabSizeY, const.SlabSizeZ)
const.SlabBox = box(-(const.SlabSizeX/2), -(const.SlabSizeY/2), 0, const.SlabSizeX/2, const.SlabSizeY/2, const.SlabSizeZ) -- inclusive, as used by the construction locks
const.SlabOffset = point(const.SlabOffsetX, const.SlabOffsetY, 0)
const.SlabMaterialProps = { "NoShadow", "HasLOS", "Deposition", "Warped" }

-- Debris
const.DebrisFadeAwayTime = 30000
const.DebrisDisappearTime = 5000
const.DebrisExplodeDeviationAngle = 60 * 60
const.DebrisExplodeSlabDelay = 200
const.DebrisExplodeRadius = 2500
