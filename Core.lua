----------------------------------------------------------------------
-- VoidFrames — Core: saved settings, click bindings, options panel.
--
-- Click casting uses Blizzard's secure unit buttons: each frame carries
-- attributes like "shift-type2" = "spell", "shift-spell2" = "Raise Ally".
-- Attributes can only change out of combat, so binding changes made in
-- combat are applied the moment combat ends.
----------------------------------------------------------------------
local ADDON, VF = ...
_G.VoidFrames = VF

VF.DEFAULTS = {
    width       = 96,
    height      = 42,
    spacing     = 3,
    raidColumns = 5,     -- frames per row in raid
    opacity     = 70,    -- % opacity of the whole frame group
    autoSize    = true,  -- raid frames shrink as the raid grows (10 / 20 / 40)
    showMyBuffs = true,  -- your HoTs/shields on each frame
    showDebuffs = true,
    showMissingBuff = true, -- your class's group buff icon on players missing it (out of combat)
    showCleanse = true,     -- clickable cleanse square beside party frames
    showGroupBuffs = true,  -- row of long group buffs (Mark of the Wild, ...) above each frame
    rangeFade   = true,
    hideBlizzard = true, -- park Blizzard's party/raid frames out of sight
}

-- Mouse buttons and modifiers the bindings editor offers.
VF.BUTTONS = {
    { id = "1", label = "Left" }, { id = "2", label = "Right" }, { id = "3", label = "Middle" },
    { id = "4", label = "Button 4" }, { id = "5", label = "Button 5" },
}
VF.MODIFIERS = {
    { id = "", label = "Click" }, { id = "shift-", label = "Shift" },
    { id = "ctrl-", label = "Ctrl" }, { id = "alt-", label = "Alt" },
}

-- Words the editor accepts besides a spell name.
VF.ACTIONS = { target = "target", focus = "focus", menu = "togglemenu", assist = "assist" }

-- Starting bindings (used until you change them). Healer specs get their own set; every
-- other spec gets target / menu / focus plus its class's group help on Shift (+ Ctrl).
-- Spell names checked against 12.1.5 (warcraft.wiki.gg patch history + Method 12.1.5
-- guides, 2026-10-27): e.g. Holy Priest has no Power Word: Shield and Resto Shaman no
-- Healing Surge in 12.x; Disc's Renew is Plea; Ebon Might can't be targeted.
local TARGETING = { ["1"] = "target", ["2"] = "menu", ["3"] = "focus", ["ctrl-1"] = "focus" }
-- (no menu for healers: Blizzard only opens the menu on a click with its own Click Casting
-- interaction -- plain right-click by default -- and healers use right-click to cleanse)
local HEAL_TARGETING = { ["alt-1"] = "target", ["alt-2"] = "focus", ["3"] = "target" }

local function With(base, extra)
    local t = {}
    for k, v in pairs(base) do t[k] = v end
    for k, v in pairs(extra) do t[k] = v end
    return t
end

-- Healer specs by spec ID. Click = main heal/HoT, right-click = cleanse, Shift/Ctrl =
-- the rest, Alt = target / focus / menu.
VF.SPEC_DEFAULTS = {
    [105] = With(HEAL_TARGETING, {   -- Restoration Druid
        ["1"] = "Rejuvenation", ["shift-1"] = "Lifebloom", ["ctrl-1"] = "Regrowth",
        ["2"] = "Nature's Cure", ["shift-2"] = "Rebirth", ["ctrl-2"] = "Ironbark",
        ["shift-3"] = "Innervate" }),
    [264] = With(HEAL_TARGETING, {   -- Restoration Shaman
        ["1"] = "Riptide", ["shift-1"] = "Healing Wave", ["ctrl-1"] = "Chain Heal",
        ["2"] = "Purify Spirit", ["shift-2"] = "Earth Shield", ["ctrl-2"] = "Unleash Life" }),
    [270] = With(HEAL_TARGETING, {   -- Mistweaver Monk
        ["1"] = "Renewing Mist", ["shift-1"] = "Vivify", ["ctrl-1"] = "Enveloping Mist",
        ["2"] = "Detox", ["shift-2"] = "Life Cocoon", ["ctrl-2"] = "Soothing Mist",
        ["shift-3"] = "Tiger's Lust" }),
    [1468] = With(HEAL_TARGETING, {  -- Preservation Evoker
        ["1"] = "Echo", ["shift-1"] = "Living Flame", ["ctrl-1"] = "Verdant Embrace",
        ["2"] = "Naturalize", ["shift-2"] = "Time Dilation", ["ctrl-2"] = "Reversion",
        ["shift-3"] = "Rescue", ["ctrl-3"] = "Cauterizing Flame" }),
    [257] = With(HEAL_TARGETING, {   -- Holy Priest
        ["1"] = "Flash Heal", ["shift-1"] = "Prayer of Mending", ["ctrl-1"] = "Holy Word: Serenity",
        ["2"] = "Purify", ["shift-2"] = "Guardian Spirit", ["ctrl-2"] = "Power Infusion",
        ["shift-3"] = "Leap of Faith" }),
    [256] = With(HEAL_TARGETING, {   -- Discipline Priest
        ["1"] = "Power Word: Shield", ["shift-1"] = "Flash Heal", ["ctrl-1"] = "Penance",
        ["2"] = "Purify", ["shift-2"] = "Pain Suppression", ["ctrl-2"] = "Plea",
        ["shift-3"] = "Leap of Faith", ["ctrl-3"] = "Power Infusion" }),
    [65] = With(HEAL_TARGETING, {    -- Holy Paladin
        ["1"] = "Holy Shock", ["shift-1"] = "Flash of Light", ["ctrl-1"] = "Word of Glory",
        ["2"] = "Cleanse", ["shift-2"] = "Blessing of Sacrifice", ["ctrl-2"] = "Holy Light",
        ["shift-3"] = "Blessing of Protection", ["ctrl-3"] = "Lay on Hands",
        ["4"] = "Blessing of Freedom", ["5"] = "Intercession" }),
    [1473] = With(TARGETING, {       -- Augmentation Evoker (Ebon Might isn't targetable)
        ["shift-1"] = "Prescience", ["shift-2"] = "Blistering Scales", ["shift-3"] = "Rescue",
        ["ctrl-2"] = "Expunge" }),
}

-- Every other spec, by class: targeting plus the class's group help.
VF.CLASS_DEFAULTS = {
    DEATHKNIGHT = With(TARGETING, { ["shift-1"] = "Raise Ally" }),
    DRUID       = With(TARGETING, { ["shift-1"] = "Rebirth", ["shift-2"] = "Remove Corruption", ["shift-3"] = "Innervate" }),
    WARLOCK     = With(TARGETING, { ["shift-1"] = "Soulstone" }),
    PALADIN     = With(TARGETING, { ["shift-1"] = "Intercession", ["shift-2"] = "Cleanse Toxins",
                                    ["shift-3"] = "Blessing of Protection", ["ctrl-2"] = "Blessing of Freedom",
                                    ["ctrl-3"] = "Lay on Hands" }),
    ROGUE       = With(TARGETING, { ["shift-1"] = "Tricks of the Trade" }),
    HUNTER      = With(TARGETING, { ["shift-1"] = "Misdirection" }),
    WARRIOR     = With(TARGETING, { ["shift-1"] = "Intervene" }),
    MAGE        = With(TARGETING, { ["shift-1"] = "Remove Curse" }),
    PRIEST      = With(TARGETING, { ["shift-1"] = "Power Word: Shield", ["shift-2"] = "Purify Disease",
                                    ["shift-3"] = "Leap of Faith", ["ctrl-2"] = "Power Infusion" }),
    MONK        = With(TARGETING, { ["shift-1"] = "Tiger's Lust", ["shift-2"] = "Detox", ["shift-3"] = "Vivify" }),
    EVOKER      = With(TARGETING, { ["shift-1"] = "Rescue", ["shift-2"] = "Expunge", ["shift-3"] = "Verdant Embrace" }),
    SHAMAN      = With(TARGETING, { ["shift-1"] = "Healing Surge", ["shift-2"] = "Cleanse Spirit",
                                    ["shift-3"] = "Earth Shield" }),
}
VF.GENERIC_DEFAULTS = TARGETING

-- Earlier releases' defaults (v1-v4). On upgrade, a binding still holding one of these
-- untouched is replaced by the new default; anything the player set stays.
VF.OLD_DEFAULTS = {
    { -- v4 healer / class tables
        DEATHKNIGHT = { ["1"] = "target", ["2"] = "Raise Ally", ["shift-1"] = "Raise Ally",
                        ["3"] = "focus", ["4"] = "menu", ["5"] = "assist", ["ctrl-1"] = "focus", ["ctrl-2"] = "menu" },
        PRIEST      = { ["alt-1"] = "target", ["shift-1"] = "Flash Heal", ["ctrl-1"] = "Prayer of Healing",
                        ["1"] = "Purify Disease", ["2"] = "Mass Dispel", ["shift-2"] = "Power Word: Shield",
                        ["ctrl-2"] = "Holy Word: Sanctify", ["alt-2"] = "focus", ["4"] = "Prayer of Mending",
                        ["shift-3"] = "Leap of Faith", ["alt-3"] = "menu" },
        DRUID       = { ["alt-1"] = "target", ["1"] = "Rejuvenation", ["shift-1"] = "Lifebloom",
                        ["ctrl-1"] = "Innervate", ["2"] = "Nature's Cure", ["ctrl-2"] = "Lifebloom",
                        ["alt-2"] = "focus", ["3"] = "target", ["alt-3"] = "menu", ["shift-2"] = "Rebirth" },
    },
    { -- v4 non-healer tables
        DRUID  = { ["shift-1"] = "Rebirth" },
        PRIEST = { ["shift-1"] = "Power Word: Shield", ["shift-2"] = "Purify Disease", ["shift-3"] = "Leap of Faith" },
    },
}

-- v5: per-spec healer defaults (Shaman, Monk, Evoker, Holy/Disc Priest, Holy Paladin
--     added; Priest's set split by spec), utility for every class; old untouched
--     defaults are swapped for the new ones.
VF.DEFAULTS_VER = 5

-- The default set for the current spec.
function VF:DefaultsForSpec()
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    local i = getSpec and getSpec()
    local id = i and getInfo and getInfo(i)
    if not id then return nil end
    local _, class = UnitClass("player")
    return self.SPEC_DEFAULTS[id] or self.CLASS_DEFAULTS[class] or self.GENERIC_DEFAULTS
end

-- Role of the current spec ("TANK", "HEALER", "DAMAGER"), or nil.
function VF:SpecRole()
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    local i = getSpec and getSpec()
    return i and getInfo and select(5, getInfo(i))
end

function VF:Get(key)
    local v = VoidFramesDB and VoidFramesDB[key]
    if v == nil then return self.DEFAULTS[key] end
    return v
end

function VF:Set(key, value)
    VoidFramesDB[key] = value
    if self.Relayout then self:Relayout() end
    if key == "showCleanse" and self.ApplyBindings then self:ApplyBindings() end   -- cleanse squares
end

----------------------------------------------------------------------
-- Bindings: stored per character and spec.
----------------------------------------------------------------------
local function CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

local function SpecIndex()
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    return (getSpec and getSpec()) or 0
end

function VF:GetBindings()
    VoidFramesDB.bindings = VoidFramesDB.bindings or {}
    local char = VoidFramesDB.bindings[CharKey()] or {}
    VoidFramesDB.bindings[CharKey()] = char
    local spec = SpecIndex()
    local b = char[spec]
    if not b or (b._ver or 1) < self.DEFAULTS_VER then
        local src = self:DefaultsForSpec()
        if not src then return b or {} end   -- spec info not ready yet (early login): next call
        local fresh = b == nil
        b = b or {}
        if not fresh then
            -- upgrade: drop bindings still holding an earlier release's default, untouched
            -- Only the old defaults THIS spec could have had: healers the old healer table
            -- (or the generic one, for classes that had none), others the old class,
            -- non-healer and generic tables. So a Resto Druid's own Shift+click Rebirth
            -- isn't mistaken for the old Guardian default (Sol review, 2026-10-28).
            local _, class = UnitClass("player")
            local old = self.OLD_DEFAULTS
            local sets
            if self:SpecRole() == "HEALER" then
                sets = { old[1][class] or self.GENERIC_DEFAULTS }
            else
                sets = { old[1][class] or {}, old[2][class] or {}, self.GENERIC_DEFAULTS }
            end
            for _, set in ipairs(sets) do
                for k, v in pairs(set) do
                    if b[k] == v then b[k] = nil end
                end
            end
        end
        local cleared = b._cleared or {}
        for k, v in pairs(src) do
            if b[k] == nil and not cleared[k] then b[k] = v end
        end
        b._ver = self.DEFAULTS_VER
        char[spec] = b
    end
    return b
end

function VF:SetBinding(key, value)
    local b = self:GetBindings()
    value = value and strtrim(value) or ""
    b[key] = value ~= "" and value or nil
    -- Remember deliberate clears so a later defaults update doesn't refill them.
    b._cleared = b._cleared or {}
    b._cleared[key] = (value == "") or nil
    if self.ApplyBindings then self:ApplyBindings() end
end

----------------------------------------------------------------------
-- Options panel: Esc -> Options -> AddOns -> VoidFrames.
----------------------------------------------------------------------
local function BuildOptions()
    if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
    local category, layout = Settings.RegisterVerticalLayoutCategory("VoidFrames")

    if CreateSettingsButtonInitializer and layout then
        layout:AddInitializer(CreateSettingsButtonInitializer("Click bindings",
            "Edit click bindings", function() VF:OpenBindingsEditor() end,
            "Choose what each mouse button and modifier does on a frame, for this character and spec.", true))
    end

    local function Check(key, label, tip)
        local s = Settings.RegisterProxySetting(category, "VOIDFRAMES_" .. key:upper(),
            Settings.VarType.Boolean, label, VF.DEFAULTS[key],
            function() return VF:Get(key) end, function(v) VF:Set(key, v) end)
        Settings.CreateCheckbox(category, s, tip)
    end
    local function Slider(key, label, min, max, step, tip)
        local s = Settings.RegisterProxySetting(category, "VOIDFRAMES_" .. key:upper(),
            Settings.VarType.Number, label, VF.DEFAULTS[key],
            function() return VF:Get(key) end, function(v) VF:Set(key, v) end)
        local o = Settings.CreateSliderOptions(min, max, step)
        o:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
        Settings.CreateSlider(category, s, o, tip)
    end

    Slider("width", "Frame width", 60, 160, 2, "Width of each frame (applies out of combat).")
    Slider("height", "Frame height", 24, 80, 2, "Height of each frame (applies out of combat).")
    Slider("raidColumns", "Raid frames per row", 4, 10, 1, "How many raid frames sit side by side.")
    Slider("opacity", "Frame opacity (%)", 20, 100, 5,
        "How see-through the party and raid frames are, all of them: bars, names, HoTs, debuffs and the cleanse button. Applies out of combat.")
    Check("autoSize", "Shrink raid frames in bigger raids",
        "Raid frames get smaller as the raid grows: 75% at 10 players, 65% at 20, 55% above that. Width and height above set the full size.")
    Check("showMyBuffs", "Show your buffs and HoTs", "Your own buffs on each frame, with timers.")
    Check("showDebuffs", "Show debuffs", "Up to two important debuffs on each frame, bordered in their dispel type's color.")
    Check("showCleanse", "Cleanse button beside party frames",
        "When a player has a debuff you can remove, it shows in a square to the right of their frame. Click it to cleanse them (Nature's Cure, Purify, Cleanse, ...). Applies out of combat.")
    Check("showGroupBuffs", "Show group buffs above each frame",
        "Long group buffs (Mark of the Wild, Arcane Intellect, Fortitude, Battle Shout, Skyfury, Blessing of the Bronze) in a small row above each player. Frames get a little more space between them for it.")
    Check("showMissingBuff", "Show who is missing your group buff",
        "Your class's group buff (Mark of the Wild, Arcane Intellect, Power Word: Fortitude, Battle Shout) shows on players who don't have it. Out of combat only.")
    Check("rangeFade", "Fade out-of-range frames", "Frames dim when the player is out of range.")
    Check("hideBlizzard", "Hide Blizzard party and raid frames",
        "Hides Blizzard's own group frames so only VoidFrames shows. Turning this off brings them back after a /reload.")

    Settings.RegisterAddOnCategory(category)
    VF.optionsCategory = category

    -- VoidHub entry (no minimap button of its own)
    VoidHubLaunchers = VoidHubLaunchers or {}
    VoidHubLaunchers.VoidFrames = {
        icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02",
        onClick = function() VF:OpenOptions() end,
    }
end

function VF:OpenOptions()
    if self.optionsCategory then Settings.OpenToCategory(self.optionsCategory:GetID()) end
end

SLASH_VOIDFRAMES1 = "/vframes"
SlashCmdList.VOIDFRAMES = function(msg)
    if msg and msg:lower():find("bind") then VF:OpenBindingsEditor() else VF:OpenOptions() end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    VoidFramesDB = VoidFramesDB or {}
    BuildOptions()
    if VF.Init then VF:Init() end
end)
