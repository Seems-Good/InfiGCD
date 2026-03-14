-- InfiGCD/Locales/enUS.lua
-- English (default) locale table.
-- To add a new language: copy this file, rename it (e.g. deDE.lua),
-- translate every value, and load it AFTER this file in the TOC.
-- Any key not present in an alternate locale will fall back to this table
-- automatically (see the L() accessor in Core.lua).

local ADDON_NAME, ns = ...

-- Base locale — always defined first so other locales can delta-patch it.
local L = {}
ns.L   = L

-- ── Identity ─────────────────────────────────────────────────────────────────
L.ADDON_NAME        = "InfiGCD"
L.ADDON_VERSION     = "Version"

-- ── Chat feedback ─────────────────────────────────────────────────────────────
L.LOADED            = "loaded. Type |cffffff00/infigcd|r for options."
L.MOVE_UNLOCKED     = "Frame unlocked — drag to reposition, then |cffffff00/infigcd lock|r."
L.MOVE_LOCKED       = "Frame locked."
L.SCALE_SET         = "Scale set to: "
L.SCALE_INVALID     = "Scale must be a number between 0.5 and 3.0."
L.RESET             = "Position and scale reset to defaults."

-- ── Slash-command help lines ──────────────────────────────────────────────────
L.HELP_HEADER       = "Commands:"
L.HELP_MOVE         = "Unlock the frame for repositioning"
L.HELP_LOCK         = "Lock the frame in place"
L.HELP_SCALE        = "<0.5 – 3.0>  Set display scale"
L.HELP_RESET        = "Reset position and scale to defaults"
