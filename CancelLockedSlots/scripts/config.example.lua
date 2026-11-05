-- CancelLockedSlots settings
-- To use: copy this file to config.lua in the same folder, then edit config.lua.
-- Any setting you leave out uses its default. Updates never overwrite config.lua.

return {
    -- true: keep Locked Slots selected for Prismatic, but cancel its effect.
    -- false: Locked Slots plays normally (the mod stays idle).
    cancelLockedSlots = true,

    -- How much the mod writes to UE4SS.log: DEBUG, INFO, WARN or ERROR.
    minLogLevel = "INFO",
}