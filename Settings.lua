-- InfiGCD/Settings.lua
-- Registers an options panel under Interface -> AddOns -> InfiGCD.
-- Uses the modern Settings API (retail 10.x+, RegisterCanvasLayoutCategory).
-- All changes take effect immediately and are persisted via InfiGCDDB.

local ADDON_NAME, ns = ...
local L = ns.L

local ADDON_VERSION = "1.0.2"
local REPO_URL      = "https://github.com/Seems-Good/InfiGCD"

-- ---------------------------------------------------------------------------
-- Panel frame
-- ---------------------------------------------------------------------------
 
local panel = CreateFrame("Frame")
panel.name  = ADDON_NAME
 
-- ---------------------------------------------------------------------------
-- Layout helpers
-- ---------------------------------------------------------------------------
 
local MARGIN   = 16
local LINE_H   = 24
local INDENT   = 8
 
local function Header(parent, text, yOffset)
    local f = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, yOffset)
    f:SetText(text)
    return f
end
 
local function SubText(parent, text, yOffset)
    local f = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", MARGIN, yOffset)
    f:SetText(text)
    return f
end
 
local function Divider(parent, yOffset)
    local t = parent:CreateTexture(nil, "BACKGROUND")
    t:SetPoint("TOPLEFT",  parent, "TOPLEFT",  MARGIN,      yOffset)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -MARGIN,     yOffset)
    t:SetHeight(1)
    t:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    return t
end
 
-- ---------------------------------------------------------------------------
-- Panel content
-- ---------------------------------------------------------------------------
 
panel:SetScript("OnShow", function(self)
    -- Guard: only build widgets once.
    if self._built then return end
    self._built = true
 
    local y = -MARGIN
 
    -- Title ----------------------------------------------------------------
    local title = Header(self, "|cff00ccffInfi|rGCD", y)
    y = y - 20
 
    local ver = SubText(self,
        L.ADDON_VERSION .. ": " .. ADDON_VERSION ..
        "   |cff888888" .. REPO_URL .. "|r", y)
    y = y - 28
 
    Divider(self, y)
    y = y - 20
 
    -- Section: Position ----------------------------------------------------
    local secPos = Header(self, "Position", y)
    y = y - LINE_H + 4
 
    -- Lock / Unlock checkbox
    local lockCB = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
    lockCB:SetPoint("TOPLEFT", self, "TOPLEFT", MARGIN + INDENT, y)
    -- _text suffix is set by the template
    lockCB.Text:SetText("Lock frame (disable dragging)")
    lockCB:SetChecked(InfiGCDDB and InfiGCDDB.locked or true)
    lockCB:SetScript("OnClick", function(btn)
        local locked = btn:GetChecked()
        InfiGCDDB.locked = locked
        ns.SetLocked(locked)
    end)
    -- Refresh checkbox state every time the panel is shown (in case slash
    -- command was used to change the lock state between visits).
    lockCB._refresh = function()
        lockCB:SetChecked(InfiGCDDB and InfiGCDDB.locked or true)
    end
    y = y - LINE_H - 4
 
    -- Reset position button
    local resetBtn = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    resetBtn:SetSize(140, 24)
    resetBtn:SetPoint("TOPLEFT", self, "TOPLEFT", MARGIN + INDENT, y)
    resetBtn:SetText("Reset Position")
    resetBtn:SetScript("OnClick", function()
        ns.ResetPosition()
        -- Sync the scale slider back to 1.0 after reset.
        if self._scaleSlider then
            self._scaleSlider:SetValue(1.0)
        end
        lockCB:SetChecked(InfiGCDDB.locked)
    end)
    y = y - LINE_H - 16
 
    Divider(self, y)
    y = y - 20
 
    -- Section: Scale -------------------------------------------------------
    local secScale = Header(self, "Scale", y)
    y = y - LINE_H + 4
 
    local scaleLbl = SubText(self, "Icon size multiplier (0.5 – 3.0)", y)
    y = y - LINE_H
 
    -- Slider
    local slider = CreateFrame("Slider", "InfiGCDScaleSlider", self, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", self, "TOPLEFT", MARGIN + INDENT + 4, y)
    slider:SetWidth(260)
    slider:SetMinMaxValues(0.5, 3.0)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(InfiGCDDB and InfiGCDDB.scale or 1.0)
 
    -- Template sub-labels
    _G[slider:GetName() .. "Low"]:SetText("0.5")
    _G[slider:GetName() .. "High"]:SetText("3.0")
    _G[slider:GetName() .. "Text"]:SetText(
        string.format("Scale: %.2f", InfiGCDDB and InfiGCDDB.scale or 1.0))
 
    slider:SetScript("OnValueChanged", function(s, val)
        -- Round to 2 dp so we don't spam tiny floating-point noise.
        val = math.floor(val * 100 + 0.5) / 100
        _G[s:GetName() .. "Text"]:SetText(string.format("Scale: %.2f", val))
        ns.SetScale(val)
    end)
 
    -- Expose for reset button to poke.
    self._scaleSlider = slider
    y = y - 40
 
    Divider(self, y)
    y = y - 14
 
    -- Footer note
    local note = SubText(self,
        "You can also use  |cffffff00/infigcd|r  or  |cffffff00/igcd|r  for slash commands.", y)
end)
 
-- Refresh dynamic state each time the panel is opened.
panel:SetScript("OnShow", (function(original)
    return function(self)
        original(self)
        if self._scaleSlider and InfiGCDDB then
            self._scaleSlider:SetValue(InfiGCDDB.scale or 1.0)
        end
    end
end)(panel:GetScript("OnShow")))
 
-- ---------------------------------------------------------------------------
-- Register with the retail Settings system
-- ---------------------------------------------------------------------------
 
local category = Settings.RegisterCanvasLayoutCategory(panel, ADDON_NAME)
Settings.RegisterAddOnCategory(category)
