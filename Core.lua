-- InfiGCD/Core.lua
-- Tracks the Global Cooldown and displays the icon of the last ability cast.
-- Design goals:
--   * Zero polling / zero OnUpdate tickers -- every action is event-driven.
--   * The circular-sweep animation is handled entirely by WoW's native Cooldown
--     frame (C engine, GPU-composited). No Lua executes per-frame during display.
--   * Fade-out after the GCD expires uses the engine Animation system, also
--     zero per-frame Lua.
--   * SavedVariables persist position and scale across sessions.

local ADDON_NAME, ns = ...
local L = ns.L  -- locale table populated by Locales/enUS.lua (or any override)

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

local GCD_SPELL_ID  = 61304
local FRAME_SIZE    = 64
local FADE_DURATION = 0.3
local MAX_GCD       = 1.6
local DEFAULT_X     = 0
local DEFAULT_Y     = -120

-- ---------------------------------------------------------------------------
-- SavedVariables defaults
-- ---------------------------------------------------------------------------

local DB_DEFAULTS = {
    x           = DEFAULT_X,
    y           = DEFAULT_Y,
    scale       = 1.0,
    locked      = true,
    instantOnly = false,  -- when true, cast-time spells are silently skipped
}

-- ---------------------------------------------------------------------------
-- State
--
-- isCasting / isChanneling: prevent SUCCEEDED from firing for cast-time spells
-- and channel ticks as before.
--
-- lastShownGCDStart: the GCD startTime of the last spell we displayed.
--   Every GCD has a unique, monotonically-increasing startTime stamped by the
--   server. A real new ability always brings a NEWER startTime than the one
--   currently running. Auto Shot / Auto Attack fire SUCCEEDED while an existing
--   GCD is still active -- their startTime is the same stale value from the
--   ability that triggered the GCD. By only showing when startTime > lastShown
--   we block all background autos with zero ID-based logic and no thresholds.
-- ---------------------------------------------------------------------------

local isCasting        = false
local isChanneling     = false
local lastShownGCDStart = 0

-- ---------------------------------------------------------------------------
-- Main display frame
-- ---------------------------------------------------------------------------

local frame = CreateFrame("Frame", "InfiGCDFrame", UIParent)
frame:SetSize(FRAME_SIZE, FRAME_SIZE)
frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_X, DEFAULT_Y)
frame:SetClampedToScreen(true)
frame:SetFrameStrata("HIGH")
frame:Hide()

-- ---------------------------------------------------------------------------
-- Circular mask
-- ---------------------------------------------------------------------------

local circleMask = frame:CreateMaskTexture()
circleMask:SetAllPoints(frame)
circleMask:SetTexture(
    "Interface\\CharacterFrame\\TempPortraitAlphaMask",
    "CLAMPTOBLACKADDITIVE",
    "CLAMPTOBLACKADDITIVE"
)

-- ---------------------------------------------------------------------------
-- Spell icon
-- ---------------------------------------------------------------------------

local iconTex = frame:CreateTexture(nil, "BACKGROUND")
iconTex:SetAllPoints()
iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
iconTex:AddMaskTexture(circleMask)
iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

-- ---------------------------------------------------------------------------
-- Cooldown sweep frame
-- ---------------------------------------------------------------------------

local cd = CreateFrame("Cooldown", "InfiGCDCooldown", frame, "CooldownFrameTemplate")
cd:SetAllPoints()
cd:SetDrawSwipe(true)
cd:SetDrawEdge(false)
cd:SetDrawBling(false)
cd:SetSwipeColor(0, 0, 0, 0.8)

cd:SetCooldown(GetTime(), 1)
for _, region in ipairs({ cd:GetRegions() }) do
    if region.AddMaskTexture then
        region:AddMaskTexture(circleMask)
    end
end
cd:SetCooldown(0, 0)

-- ---------------------------------------------------------------------------
-- Fade-out animation
-- ---------------------------------------------------------------------------

local fadeGroup = frame:CreateAnimationGroup()

local fadeAnim = fadeGroup:CreateAnimation("Alpha")
fadeAnim:SetFromAlpha(1)
fadeAnim:SetToAlpha(0)
fadeAnim:SetDuration(FADE_DURATION)
fadeAnim:SetSmoothing("OUT")

fadeGroup:SetScript("OnFinished", function()
    frame:Hide()
    frame:SetAlpha(1)
end)

cd:SetScript("OnCooldownDone", function()
    fadeGroup:Play()
end)

-- ---------------------------------------------------------------------------
-- Drag / repositioning
-- ---------------------------------------------------------------------------

frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")

frame:SetScript("OnDragStart", function(self)
    if InfiGCDDB and not InfiGCDDB.locked then
        self:StartMoving()
    end
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if InfiGCDDB then
        local _, _, _, x, y = self:GetPoint()
        InfiGCDDB.x = x
        InfiGCDDB.y = y
    end
end)

-- ---------------------------------------------------------------------------
-- Core display logic
-- ---------------------------------------------------------------------------

local function ShowSpellGCD(spellID)
    local spellIcon = C_Spell.GetSpellTexture(spellID)
    if not spellIcon then return end

    local cdInfo    = C_Spell.GetSpellCooldown(GCD_SPELL_ID)
    local duration  = cdInfo and cdInfo.duration
    local startTime = cdInfo and cdInfo.startTime

    if not duration or duration == 0 then return end
    if duration > MAX_GCD then return end

    -- Core auto-attack filter: only show if this spell brought a NEW GCD.
    -- Auto Shot / Auto Attack never start a GCD -- they fire SUCCEEDED while
    -- an existing GCD (started by a real ability) is still running, so their
    -- startTime is always equal to lastShownGCDStart. A real new ability always
    -- stamps a fresh, larger startTime. No spell IDs or thresholds needed.
    if startTime <= lastShownGCDStart then return end
    lastShownGCDStart = startTime

    if fadeGroup:IsPlaying() then
        fadeGroup:Stop()
        frame:SetAlpha(1)
    end

    iconTex:SetTexture(spellIcon)
    frame:Show()
    cd:SetCooldown(0, 0)
    cd:SetCooldown(GetTime(), duration)
end

-- ---------------------------------------------------------------------------
-- Event dispatcher
-- ---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

eventFrame:SetScript("OnEvent", function(_, event, ...)

    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON_NAME then return end

        InfiGCDDB = InfiGCDDB or {}
        for k, v in pairs(DB_DEFAULTS) do
            if InfiGCDDB[k] == nil then InfiGCDDB[k] = v end
        end

        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", InfiGCDDB.x, InfiGCDDB.y)
        frame:SetScale(InfiGCDDB.scale)
        frame:EnableMouse(not InfiGCDDB.locked)

        print("|cff00ccff[" .. L.ADDON_NAME .. "]|r " .. L.LOADED)

    elseif event == "PLAYER_LOGOUT" then
        if InfiGCDDB and frame:GetPoint() then
            local _, _, _, x, y = frame:GetPoint()
            if x then InfiGCDDB.x = x end
            if y then InfiGCDDB.y = y end
        end

    elseif event == "UNIT_SPELLCAST_START" then
        local unit, _, spellID = ...
        if unit ~= "player" then return end
        isCasting = true
        -- When instantOnly is on we still track the cast state so the
        -- SUCCEEDED handler knows not to re-fire, but we don't show the GCD.
        if not InfiGCDDB.instantOnly then
            ShowSpellGCD(spellID)
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit ~= "player" then return end
        if isChanneling then return end
        if isCasting then
            isCasting = false
            return
        end
        ShowSpellGCD(spellID)

    elseif event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit = ...
        if unit ~= "player" then return end
        isCasting = false

    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit, _, spellID = ...
        if unit ~= "player" then return end
        isCasting    = false
        isChanneling = true
        ShowSpellGCD(spellID)

    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unit = ...
        if unit ~= "player" then return end
        isChanneling = false
    end
end)

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------

SLASH_INFIGCD1 = "/infigcd"
SLASH_INFIGCD2 = "/igcd"

SlashCmdList["INFIGCD"] = function(msg)
    msg = strtrim(msg:lower())

    if msg == "move" or msg == "unlock" then
        InfiGCDDB.locked = false
        frame:EnableMouse(true)
        frame:Show()
        print("|cff00ccff[" .. L.ADDON_NAME .. "]|r " .. L.MOVE_UNLOCKED)

    elseif msg == "lock" then
        InfiGCDDB.locked = true
        frame:EnableMouse(false)
        frame:Hide()
        print("|cff00ccff[" .. L.ADDON_NAME .. "]|r " .. L.MOVE_LOCKED)

    elseif msg:find("^scale%s") then
        local raw = msg:match("^scale%s+(.+)$")
        local val = tonumber(raw)
        if val and val >= 0.5 and val <= 3.0 then
            InfiGCDDB.scale = val
            frame:SetScale(val)
            print("|cff00ccff[" .. L.ADDON_NAME .. "]|r " .. L.SCALE_SET .. val)
        else
            print("|cff00ccff[" .. L.ADDON_NAME .. "]|r " .. L.SCALE_INVALID)
        end

    elseif msg == "reset" then
        InfiGCDDB.x, InfiGCDDB.y, InfiGCDDB.scale = DEFAULT_X, DEFAULT_Y, 1.0
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_X, DEFAULT_Y)
        frame:SetScale(1.0)
        print("|cff00ccff[" .. L.ADDON_NAME .. "]|r " .. L.RESET)

    else
        print("|cff00ccff[" .. L.ADDON_NAME .. "]|r  " .. L.HELP_HEADER)
        print("  |cffffff00/infigcd move|r   -- " .. L.HELP_MOVE)
        print("  |cffffff00/infigcd lock|r   -- " .. L.HELP_LOCK)
        print("  |cffffff00/infigcd scale|r  -- " .. L.HELP_SCALE)
        print("  |cffffff00/infigcd reset|r  -- " .. L.HELP_RESET)
    end
end

-- ---------------------------------------------------------------------------
-- Public API for Settings.lua
-- ---------------------------------------------------------------------------

ns.DEFAULT_X = DEFAULT_X
ns.DEFAULT_Y = DEFAULT_Y

function ns.SetLocked(locked)
    InfiGCDDB.locked = locked
    frame:EnableMouse(not locked)
    if locked then frame:Hide() else frame:Show() end
end

function ns.SetScale(val)
    InfiGCDDB.scale = val
    frame:SetScale(val)
end

function ns.ResetPosition()
    InfiGCDDB.x, InfiGCDDB.y, InfiGCDDB.scale = DEFAULT_X, DEFAULT_Y, 1.0
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_X, DEFAULT_Y)
    frame:SetScale(1.0)
end

function ns.SetInstantOnly(val)
    InfiGCDDB.instantOnly = val
end
