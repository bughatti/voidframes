----------------------------------------------------------------------
-- VoidFrames — party and raid frames.
--
-- Fixed secure unit buttons (player + party1-4, raid1-40). The game shows
-- and hides them itself (RegisterUnitWatch / state drivers), so frames
-- appear and disappear correctly even in combat. Everything we draw lives
-- on a plain child frame ("vis"), which is safe to update any time.
--
-- Group-member health, range and auras can be secret in 12.x; they only
-- go into display calls (SetValue, SetText, SetTexture, *FromBoolean,
-- duration objects), never into comparisons or math.
----------------------------------------------------------------------
local _, VF = ...

local party, raid = {}, {}
local byUnit = {}            -- unit token -> button (both groups)
local partyBox, raidBox
local pendingApply, pendingLayout = false, false

local BAR = "Interface\\TargetingFrame\\UI-StatusBar"
local FONT = STANDARD_TEXT_FONT
local MAX_BUFFS, MAX_DEBUFFS = 3, 2

local function sec(v) return issecretvalue and issecretvalue(v) end
local function yes(v) return not sec(v) and v and true or false end

----------------------------------------------------------------------
-- Visual pieces
----------------------------------------------------------------------
local function Edge(parent, r, g, b, a, size, layer)
    local t = {}
    for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
                         { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local e = parent:CreateTexture(nil, layer or "OVERLAY", nil, 6)
        e:SetColorTexture(r, g, b, a)
        e:SetPoint(p[1]); e:SetPoint(p[2])
        if i <= 2 then e:SetHeight(size) else e:SetWidth(size) end
        t[i] = e
    end
    function t:SetShown(show) for _, e in ipairs(self) do e:SetShown(show) end end
    return t
end

local function Icon(parent, size)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(size, size)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetAllPoints(b.icon)
    b.cd:SetDrawEdge(false)
    b.cd:SetReverse(true)
    b.cd:SetHideCountdownNumbers(true)
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetFont(FONT, 9, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", 2, -1)
    b:Hide()
    return b
end

local function CreateUnitButton(name, parent, unit)
    local b = CreateFrame("Button", name, parent, "SecureUnitButtonTemplate")
    b:SetAttribute("unit", unit)
    b:RegisterForClicks("AnyUp")
    b.unit = unit

    local vis = CreateFrame("Frame", nil, b)
    vis:SetAllPoints()
    b.vis = vis

    local hp = CreateFrame("StatusBar", nil, vis)
    hp:SetPoint("TOPLEFT", 1, -1)
    hp:SetPoint("BOTTOMRIGHT", -1, 1)
    hp:SetStatusBarTexture(BAR)
    local bg = hp:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.08, 0.08, 0.1, 0.95)
    b.hp, b.hpTex, b.hpBg = hp, hp:GetStatusBarTexture(), bg

    b.edge = Edge(vis, 0, 0, 0, 1, 1)
    b.targetEdge = Edge(vis, 1, 1, 1, 1, 2)
    b.dispelEdge = Edge(vis, 0.75, 0.3, 1, 1, 2)
    b.targetEdge:SetShown(false); b.dispelEdge:SetShown(false)

    b.name = hp:CreateFontString(nil, "OVERLAY")
    b.name:SetFont(FONT, 11, "OUTLINE")
    b.name:SetPoint("TOPLEFT", 4, -4)
    b.name:SetPoint("RIGHT", -4, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)

    b.status = hp:CreateFontString(nil, "OVERLAY")
    b.status:SetFont(FONT, 10, "OUTLINE")
    b.status:SetPoint("CENTER", 0, -2)
    b.status:SetTextColor(0.85, 0.85, 0.85)

    b.role = hp:CreateTexture(nil, "OVERLAY")
    b.role:SetSize(12, 12)
    b.role:SetPoint("TOPRIGHT", -3, -3)

    b.mark = hp:CreateTexture(nil, "OVERLAY")
    b.mark:SetSize(14, 14)
    b.mark:SetPoint("TOP", 0, 6)
    b.mark:Hide()

    -- "missing your group buff" (Mark of the Wild, ...): left of the role icon
    b.missing = hp:CreateTexture(nil, "OVERLAY", nil, 7)
    b.missing:SetSize(12, 12)
    b.missing:SetPoint("RIGHT", b.role, "LEFT", -2, 0)
    b.missing:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    b.missing:Hide()

    b.buffs, b.debuffs = {}, {}
    for i = 1, MAX_BUFFS do
        local ic = Icon(hp, 14)
        ic:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", -2 - (i - 1) * 15, 2)
        b.buffs[i] = ic
    end
    for i = 1, MAX_DEBUFFS do
        local ic = Icon(hp, 16)
        ic:SetPoint("BOTTOMLEFT", hp, "BOTTOMLEFT", 2 + (i - 1) * 17, 2)
        b.debuffs[i] = ic
    end

    -- Cleanse click square to the right of PARTY frames (see "Cleanse button"). Raid frames
    -- sit side by side, so they keep right-click cleansing only. The icon under it is made
    -- with the aura containers (EnsureAuraBoxes).
    if not unit:find("^raid") then
        local cure = CreateFrame("Button", nil, b, "SecureActionButtonTemplate")
        cure:SetSize(20, 20)
        cure:SetPoint("LEFT", b, "RIGHT", 3, 0)
        cure:SetAttribute("unit", unit)
        cure:RegisterForClicks("AnyDown", "AnyUp")   -- follows ActionButtonUseKeyDown
        cure:SetFrameLevel(b:GetFrameLevel() + 20)
        cure:Hide()
        b.cureBtn = cure
    end

    RegisterUnitWatch(b)
    b:HookScript("OnShow", function(self) VF:UpdateButton(self) end)
    byUnit[unit] = b
    return b
end

----------------------------------------------------------------------
-- Updates (plain child frames only — safe in combat)
----------------------------------------------------------------------
local function UpdateHealth(b)
    b.hp:SetMinMaxValues(0, UnitHealthMax(b.unit))
    b.hp:SetValue(UnitHealth(b.unit))
end

-- The top-right corner holds the role icon and, out of combat, the "missing your group
-- buff" icon. The name gets the width that's left so it never runs under them (the
-- purple Mark of the Wild icon sat behind the name, 2026-10-27).
local function FitName(b)
    local pad, gap = b._pad or 4, 2
    b.missing:ClearAllPoints()
    if b.role:IsShown() then
        b.missing:SetPoint("RIGHT", b.role, "LEFT", -gap, 0)
    else
        b.missing:SetPoint("TOPRIGHT", b.hp, "TOPRIGHT", -3, -3)
    end
    local reserve = 0
    if b.role:IsShown() then reserve = reserve + b.role:GetWidth() + gap end
    if b.missing:IsShown() then reserve = reserve + b.missing:GetWidth() + gap end
    b.name:ClearAllPoints()
    b.name:SetPoint("TOPLEFT", pad, -pad)
    b.name:SetWidth(math.max(10, b.hp:GetWidth() - 2 * pad - reserve))
end

local function UpdateColorAndName(b)
    local unit = b.unit
    b.name:SetText(UnitName(unit))
    local _, class = UnitClass(unit)
    local cc = not sec(class) and class and RAID_CLASS_COLORS[class]
    if cc then b.hpTex:SetVertexColor(cc.r, cc.g, cc.b) else b.hpTex:SetVertexColor(0.3, 0.7, 0.3) end

    local conn = UnitIsConnected(unit)
    if not sec(conn) and conn == false then
        b.status:SetText("Offline"); b.hpTex:SetVertexColor(0.35, 0.35, 0.35)
    elseif yes(UnitIsDeadOrGhost(unit)) then
        b.status:SetText("Dead")
    else
        b.status:SetText("")
    end

    local role = UnitGroupRolesAssigned(unit)
    if not sec(role) and (role == "TANK" or role == "HEALER") then
        b.role:SetAtlas(role == "TANK" and "roleicon-tiny-tank" or "roleicon-tiny-healer")
        b.role:Show()
    else
        b.role:Hide()
    end
    FitName(b)
end

local function UpdateTarget(b)
    b.targetEdge:SetShown(yes(UnitIsUnit(b.unit, "target")))
end

local function UpdateRaidMark(b)
    local idx = GetRaidTargetIndex(b.unit)
    if not sec(idx) and idx == nil then b.mark:Hide(); return end
    -- idx can be secret: build the path inside the pcall so a secret value fails safely
    local ok = pcall(function() b.mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. idx) end)
    b.mark:SetShown(ok)
end

local function FillIcons(icons, unit, filter, enabled)
    local n = 0
    if enabled then
        local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter, #icons)
        if ok and list then
            for _, aura in ipairs(list) do
                n = n + 1
                local ic = icons[n]
                ic.icon:SetTexture(aura.icon)
                local id = aura.auraInstanceID
                if not sec(id) and id ~= nil then
                    local okD, d = pcall(C_UnitAuras.GetAuraDuration, unit, id)
                    if okD and d then ic.cd:SetCooldownFromDurationObject(d, true) else ic.cd:Clear() end
                    local okC, c = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, id, 2)
                    if okC then ic.count:SetText(c) else ic.count:SetText("") end
                else
                    ic.cd:Clear(); ic.count:SetText("")
                end
                ic:Show()
                if n >= #icons then break end
            end
        end
    end
    for i = n + 1, #icons do icons[i]:Hide() end
end

----------------------------------------------------------------------
-- Auras in combat (2026-10-27). In an instance fight, addon code can't read group
-- members' auras any more (secret), so FillIcons' read failed and every icon vanished
-- the moment combat started ("all players' frames clear of everything"). Blizzard's
-- CustomAuraContainer (Blizzard_AuraContainer, 12.1) is the supported way: we hand it
-- a unit + filter, Blizzard picks and updates the auras itself, in combat too, and we
-- only style the buttons (icon, timer swipe, stacks, dispel-type border). Made lazily,
-- out of combat, the first time a frame shows; until then (or if it can't be made) the
-- old icons stay.
----------------------------------------------------------------------
local HOT_MAX_DURATION = 120   -- your HoTs/shields; hides hour-long buffs (Mark of the Wild)

-- Long-lasting group buffs (anyone's), shown in a row ABOVE each frame so they don't mix
-- with your HoTs (the player, 2026-10-27: "the constant buffs like mark, not the hots").
local BUFF_ROW_SIZE = 12   -- icon size of that row (Relayout leaves room for it)
local GROUP_BUFF_IDS = {
    [1126] = true,   -- Mark of the Wild
    [1459] = true,   -- Arcane Intellect
    [21562] = true,  -- Power Word: Fortitude
    [6673] = true,   -- Battle Shout
    [462854] = true, -- Skyfury
    -- Blessing of the Bronze (one aura per class)
    [381732] = true, [381741] = true, [381746] = true, [381748] = true, [381749] = true,
    [381750] = true, [381751] = true, [381752] = true, [381753] = true, [381754] = true,
    [381756] = true, [381757] = true, [381758] = true,
}

local function StyleAuraButton(size, withDispelBorder)
    return function(frame)
        frame:SetSize(size, size)
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetColorTexture(0, 0, 0, 1)
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 1, -1); icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        frame:SetIcon(icon)
        local cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
        cd:SetAllPoints(icon); cd:SetDrawEdge(false); cd:SetReverse(true); cd:SetHideCountdownNumbers(true)
        frame:SetDurationCooldown(cd)
        local count = frame:CreateFontString(nil, "OVERLAY")
        count:SetFont(FONT, 9, "OUTLINE"); count:SetPoint("BOTTOMRIGHT", 2, -1)
        frame:SetApplicationCount(count)
        if withDispelBorder then
            local border = frame:CreateTexture(nil, "OVERLAY")
            border:SetAllPoints()
            local styles = Enum.CustomAuraButtonDispelTypeTextureStyle
            frame:AddDispelTypeTexture(border, styles and { style = styles.Border } or nil)
        end
    end
end

local function MakeAuraBox(b, filter, anchor, hDir, x, y, max, size, candidateFilters, dispelBorder)
    local ok, box = pcall(CreateFrame, "AuraContainer", nil, b.hp, "CustomAuraContainerTemplate")
    if not ok or not box then return nil end
    local ok2 = pcall(function()
        box:SetUnit(b.unit)
        box:SetFlowLayoutAnchorPoint(anchor)
        box:SetFlowLayoutGrowthDirection(hDir, AnchorUtil.FlowDirection.Up)
        box:AddAuraGroup("main", filter, {
            maxFrameCount = max,
            candidateFilters = candidateFilters,
            initializeFrame = StyleAuraButton(size, dispelBorder),
            layout = { elementSpacing = 1, elementWidth = size, elementHeight = size },
        })
    end)
    if not ok2 then box:Hide(); return nil end
    box:SetPoint(anchor, b.hp, anchor, x, y)
    box:SetFrameLevel(b.hp:GetFrameLevel() + 3)
    return box
end

local function EnsureAuraBoxes(b)
    if b.auraBoxTried or InCombatLockdown() then return end
    b.auraBoxTried = true
    b.hotBox = MakeAuraBox(b, "HELPFUL|PLAYER", "BOTTOMRIGHT", AnchorUtil.FlowDirection.Left, -2, 2,
        3, 14, { maxDuration = HOT_MAX_DURATION }, false)   -- 3 + 2 debuffs fit the narrowest frame
    -- RAID_IN_COMBAT = the debuffs Blizzard's raid frames show in combat ("RAID" alone
    -- would mean only the ones YOU can dispel, hiding boss debuffs)
    b.debuffBox = MakeAuraBox(b, "HARMFUL|RAID_IN_COMBAT", "BOTTOMLEFT", AnchorUtil.FlowDirection.Right, 2, 2,
        2, 16, nil, true)
    -- group buffs (anyone's Mark of the Wild, Fortitude, ...) in a row just above the frame
    b.buffRowBox = MakeAuraBox(b, "HELPFUL", "BOTTOMLEFT", AnchorUtil.FlowDirection.Right, 0, 0,
        4, BUFF_ROW_SIZE, { includeSpellIDs = GROUP_BUFF_IDS }, false)
    if b.buffRowBox then
        b.buffRowBox:ClearAllPoints()
        b.buffRowBox:SetPoint("BOTTOMLEFT", b, "TOPLEFT", 0, 1)
    end
    if b.cureBtn then
        -- the dispellable debuff under the cleanse square: one aura slot, drawn by Blizzard
        local okC, box = pcall(CreateFrame, "AuraContainer", nil, b, "CustomAuraContainerTemplate")
        if okC and box then
            -- Blizzard locks aura frames against addon access right after initializeFrame
            -- (DenyTaintedAccessWhenAurasAreSecret, which can hold between M+ pulls too),
            -- so the anchor goes in there and visibility is set on our container, not the slot.
            local style = StyleAuraButton(20, true)
            local okS, slot = pcall(function()
                box:SetUnit(b.unit)
                -- RAID = harmful auras YOU can dispel (RAID_PLAYER_DISPELLABLE was "anyone in
                -- the group", so a Mage's square could show a disease it can't remove)
                return box:AddAuraSlot("cure", "HARMFUL|RAID", {
                    initializeFrame = function(frame)
                        style(frame)
                        frame:SetPoint("CENTER", b.cureBtn, "CENTER")
                    end,
                })
            end)
            if okS and slot then
                box:SetFrameLevel(b:GetFrameLevel() + 5)
                b.cureBox = box
                box:SetAlpha((VF:CleanseSpell() and VF:Get("showCleanse") ~= false) and 1 or 0)
            else
                box:Hide()
            end
        end
    end
    if b.hotBox then for _, ic in ipairs(b.buffs) do ic:Hide() end end
    if b.debuffBox then for _, ic in ipairs(b.debuffs) do ic:Hide() end end
    if b._scale then
        if b.hotBox then b.hotBox:SetScale(b._scale) end
        if b.buffRowBox then b.buffRowBox:SetScale(b._scale) end
        if b.debuffBox then b.debuffBox:SetScale(b._scale) end
    end
end

-- Your class's group buff, shown when this player is MISSING it. Out of combat only:
-- in combat the read is secret, and buffs rarely drop then anyway (death resets it).
local GROUP_BUFF = { DRUID = 1126, MAGE = 1459, PRIEST = 21562, WARRIOR = 6673, SHAMAN = 462854, EVOKER = 364342 }

-- Follower NPCs carry their OWN copy of a group buff (same name, different spell ID:
-- Captain Garrick showed Mark of the Wild on his target frame, but a lookup by 1126
-- found nothing, 2026-10-27). So buffs are matched by NAME out of combat, and any new
-- ID found that way is added to the buff row's whitelist (remembered across sessions).
local buffNames
local function GroupBuffNames()
    if buffNames then return buffNames end
    buffNames = {}
    for id in pairs(GROUP_BUFF_IDS) do
        local n = C_Spell.GetSpellName(id)
        if n then buffNames[n] = true end
    end
    return buffNames
end

local function LearnBuffID(id)
    if GROUP_BUFF_IDS[id] then return end
    GROUP_BUFF_IDS[id] = true
    VoidFramesDB.learnedBuffIDs = VoidFramesDB.learnedBuffIDs or {}
    VoidFramesDB.learnedBuffIDs[id] = true
    for _, bb in pairs(byUnit) do
        if bb.buffRowBox then
            pcall(bb.buffRowBox.SetAuraGroupCandidateFilters, bb.buffRowBox, "main", { includeSpellIDs = GROUP_BUFF_IDS })
        end
    end
end

-- Out of combat: learn follower copies of group buffs; does this unit have a buff named `name`?
local function ScanGroupBuffs(unit, name)
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL")
    if not ok or not list then return nil end
    local names, has = GroupBuffNames(), false
    for _, a in ipairs(list) do
        local n, id = a.name, a.spellId
        if not sec(n) and not sec(id) and n and id and names[n] then
            LearnBuffID(id)
            if n == name then has = true end
        end
    end
    return has
end

local function UpdateGroupBuff(b)
    local _, class = UnitClass("player")
    local id = GROUP_BUFF[class]
    local show = false
    if not InCombatLockdown() and yes(UnitIsVisible(b.unit)) then
        local has = ScanGroupBuffs(b.unit, id and C_Spell.GetSpellName(id))
        show = id ~= nil and has == false and VF:Get("showMissingBuff") ~= false
            and not yes(UnitIsDeadOrGhost(b.unit)) and yes(UnitIsConnected(b.unit))
        if show and not b.missing.set then
            local tex = C_Spell.GetSpellTexture(id)
            if tex then b.missing:SetTexture(tex); b.missing.set = true end
        end
    end
    if b.missing:IsShown() ~= show then
        b.missing:SetShown(show)
        FitName(b)
    end
end

-- Make the aura displays ahead of time, out of combat, for every frame that can fill in
-- this group (party: all 5; raid: as many as the raid has), so a player who joins
-- mid-fight still gets HoTs / debuffs / cleanse (containers can't be made in combat).
function VF:PrepareAuraBoxes()
    if InCombatLockdown() then return end
    if IsInRaid() then
        for i = 1, 40 do   -- all of them: players can join mid-fight
            local b = byUnit["raid" .. i]
            if b then EnsureAuraBoxes(b) end
        end
    else
        for _, u in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
            local b = byUnit[u]
            if b then EnsureAuraBoxes(b) end
        end
    end
end

local function SetBoxEnabled(box, on)
    if box and box._on ~= on then
        box._on = on
        pcall(box.SetEnabled, box, on)
        box:SetShown(on)
    end
end

local function UpdateAuras(b)
    local unit = b.unit
    EnsureAuraBoxes(b)
    if b.hotBox then SetBoxEnabled(b.hotBox, VF:Get("showMyBuffs") and true or false)
    else FillIcons(b.buffs, unit, "HELPFUL|PLAYER", VF:Get("showMyBuffs")) end
    SetBoxEnabled(b.buffRowBox, VF:Get("showGroupBuffs") ~= false)
    if b.debuffBox then SetBoxEnabled(b.debuffBox, VF:Get("showDebuffs") and true or false)
    else FillIcons(b.debuffs, unit, "HARMFUL|RAID_IN_COMBAT", VF:Get("showDebuffs")) end
    -- whole-frame dispel edge: readable out of combat; in combat the debuff icons'
    -- dispel-type borders (drawn by Blizzard) take over
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, "HARMFUL|RAID", 1)
    b.dispelEdge:SetShown(ok and list ~= nil and #list > 0)
    UpdateGroupBuff(b)
end

local function UpdateRange(b)
    if not VF:Get("rangeFade") or b.unit == "player" then b.vis:SetAlpha(1); return end
    local inRange = UnitInRange(b.unit)
    if sec(inRange) then
        b.vis:SetAlphaFromBoolean(inRange, 1, 0.4)
    elseif inRange == false and yes(UnitIsConnected(b.unit)) then
        -- UnitInRange answers false for "not checked" too; only fade group members.
        b.vis:SetAlpha(IsInGroup() and 0.4 or 1)
    else
        b.vis:SetAlpha(1)
    end
end

function VF:UpdateButton(b)
    if not UnitExists(b.unit) then return end
    UpdateHealth(b); UpdateColorAndName(b); UpdateTarget(b)
    UpdateRaidMark(b); UpdateAuras(b); UpdateRange(b)
    -- roster shuffles put a new player on this unit token: let the containers re-read
    if b.hotBox then pcall(b.hotBox.UpdateAllAuras, b.hotBox) end
    if b.debuffBox then pcall(b.debuffBox.UpdateAllAuras, b.debuffBox) end
    if b.buffRowBox then pcall(b.buffRowBox.UpdateAllAuras, b.buffRowBox) end
    if b.cureBox then pcall(b.cureBox.UpdateAllAuras, b.cureBox) end
end

local function ForEachShown(fn)
    for _, b in pairs(byUnit) do if b:IsShown() then fn(b) end end
end

----------------------------------------------------------------------
-- Click bindings -> secure attributes (out of combat only)
----------------------------------------------------------------------
local function ApplyBindingsTo(b, bindings)
    -- Clear everything we might have set before.
    for _, m in ipairs(VF.MODIFIERS) do
        for _, btn in ipairs(VF.BUTTONS) do
            b:SetAttribute(m.id .. "type" .. btn.id, nil)
            b:SetAttribute(m.id .. "spell" .. btn.id, nil)
        end
    end
    for _, m in ipairs(VF.MODIFIERS) do
        for _, btn in ipairs(VF.BUTTONS) do b:SetAttribute(m.id .. "macrotext" .. btn.id, nil) end
    end
    -- Plain left/right fall back to target/menu when unbound -- unless you cleared them.
    local cleared = bindings._cleared or {}
    if not cleared["1"] then b:SetAttribute("type1", "target") end
    if not cleared["2"] then b:SetAttribute("type2", "togglemenu") end
    for key, action in pairs(bindings) do
        local mod, btn = key:match("^(%a*%-?)(%d)$")
        if btn and type(action) == "string" then
            local verb = VF.ACTIONS[action:lower()]
            if verb == "target" then
                -- Blizzard's click handler only lets "target"/"menu" through on a click that
                -- has its own Click Casting interaction (plain left / right by default), so
                -- Alt+click "target" did nothing (Astra review, 2026-10-28). A /target of this
                -- frame's unit works on any button and modifier.
                b:SetAttribute(mod .. "type" .. btn, "macro")
                b:SetAttribute(mod .. "macrotext" .. btn, "/target " .. b.unit)
            elseif verb then
                b:SetAttribute(mod .. "type" .. btn, verb)
            else
                b:SetAttribute(mod .. "type" .. btn, "spell")
                b:SetAttribute(mod .. "spell" .. btn, action)
            end
        end
    end
end

----------------------------------------------------------------------
-- Cleanse button (2026-10-27, the player: "get that icon next to their plate so I
-- can click the debuff directly"). Beside each party frame (inside, centered, on
-- raid frames): Blizzard's aura container draws the FIRST debuff you can dispel on
-- that player (icon, timer, dispel-type border) -- in combat too -- and an invisible
-- secure button on top casts your cleanse on them. The button is always there (secure
-- frames can't show/hide on aura data in combat); with nothing to dispel the click
-- just fails harmlessly.
----------------------------------------------------------------------
-- Spell IDs (healer version first), so it works on any client language.
local CLEANSES = {
    DRUID = { 88423, 2782 },        -- Nature's Cure, Remove Corruption
    PRIEST = { 527, 213634 },       -- Purify, Purify Disease
    PALADIN = { 4987, 213644 },     -- Cleanse, Cleanse Toxins
    SHAMAN = { 77130, 51886 },      -- Purify Spirit, Cleanse Spirit
    MONK = { 115450, 218164 },      -- Detox (Mistweaver), Detox
    EVOKER = { 360823, 365585 },    -- Naturalize, Expunge
    MAGE = { 475 },                 -- Remove Curse
}

-- Localized name of the cleanse this character knows (for the spell attribute).
function VF:CleanseSpell()
    local _, class = UnitClass("player")
    for _, id in ipairs(CLEANSES[class] or {}) do
        if C_SpellBook.IsSpellKnownOrInSpellBook(id) then
            local info = C_Spell.GetSpellInfo(id)
            if info and info.name then return info.name end
        end
    end
end

local function ApplyCleanse(b, spell)
    local c = b.cureBtn
    if not c then return end
    c:SetAttribute("type1", spell and "spell" or nil)
    c:SetAttribute("spell1", spell)
    c:SetShown(spell ~= nil and VF:Get("showCleanse") ~= false)
    if b.cureBox then b.cureBox:SetAlpha((spell and VF:Get("showCleanse") ~= false) and 1 or 0) end
end

function VF:ApplyBindings()
    if InCombatLockdown() then pendingApply = true; return end
    pendingApply = false
    local bindings = self:GetBindings()
    local cleanse = self:CleanseSpell()
    for _, b in pairs(byUnit) do ApplyBindingsTo(b, bindings); ApplyCleanse(b, cleanse) end
end

----------------------------------------------------------------------
-- Layout (out of combat only)
----------------------------------------------------------------------
local function SavePos(box, key)
    local point, _, relPoint, x, y = box:GetPoint()
    VoidFramesDB.pos = VoidFramesDB.pos or {}
    VoidFramesDB.pos[key] = { point, relPoint, x, y }
end

local function PlaceBox(box, key, defPoint, defX, defY)
    local p = VoidFramesDB.pos and VoidFramesDB.pos[key]
    box:ClearAllPoints()
    if p then box:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else box:SetPoint(defPoint, UIParent, defPoint, defX, defY) end
end

local function MakeBox(name, key)
    local box = CreateFrame("Frame", name, UIParent, "SecureHandlerStateTemplate")
    box:SetMovable(true)
    box:SetClampedToScreen(true)
    -- Alt+drag on any frame moves the whole group (out of combat).
    box.StartDrag = function()
        if IsAltKeyDown() and not InCombatLockdown() then box:StartMoving(); box.moving = true end
    end
    -- Only stop a move we started, and never in combat: a mouse drag on a frame that
    -- ended mid-fight hit the protected StopMovingOrSizing (ADDON_ACTION_BLOCKED, 2026-10-27).
    box.StopDrag = function()
        if not box.moving then return end
        -- released after combat started: finish the move once combat ends (PLAYER_REGEN_ENABLED)
        if InCombatLockdown() then VF.pendingDragStop = box; return end
        box.moving = false
        box:StopMovingOrSizing()
        SavePos(box, key)
    end
    return box
end

-- Raid frames shrink as the raid grows (user, 2026-10-26: "frames could be smaller since
-- there are more players"). Party frames always use the full size.
function VF:SizeFactor()
    if not self:Get("autoSize") or not IsInRaid() then return 1 end
    local n = GetNumGroupMembers() or 0
    if n <= 5 then return 1 elseif n <= 10 then return 0.75 elseif n <= 20 then return 0.65 end
    return 0.55
end

-- Text, icons and markers follow the frame size so a small frame stays readable.
local function ScaleButton(b, f)
    local function px(v) return math.max(6, math.floor(v * f + 0.5)) end
    b.name:SetFont(FONT, math.max(8, px(11)), "OUTLINE")
    b._pad = px(4)
    b.status:SetFont(FONT, math.max(8, px(10)), "OUTLINE")
    b.role:SetSize(px(12), px(12))
    b.mark:SetSize(px(14), px(14))
    local bs, ds = px(14), px(16)
    for i, ic in ipairs(b.buffs) do
        ic:SetSize(bs, bs); ic:ClearAllPoints()
        ic:SetPoint("BOTTOMRIGHT", b.hp, "BOTTOMRIGHT", -2 - (i - 1) * (bs + 1), 2)
    end
    for i, ic in ipairs(b.debuffs) do
        ic:SetSize(ds, ds); ic:ClearAllPoints()
        ic:SetPoint("BOTTOMLEFT", b.hp, "BOTTOMLEFT", 2 + (i - 1) * (ds + 1), 2)
    end
    b.missing:SetSize(px(12), px(12))
    FitName(b)
    b._scale = f   -- aura containers (made later) scale with the frame
    if b.hotBox then b.hotBox:SetScale(f) end
    if b.buffRowBox then b.buffRowBox:SetScale(f) end
    if b.debuffBox then b.debuffBox:SetScale(f) end
end

function VF:Relayout()
    if InCombatLockdown() then pendingLayout = true; return end
    pendingLayout = false
    local w, h, gap = self:Get("width"), self:Get("height"), self:Get("spacing")
    local cols = self:Get("raidColumns")
    -- the group-buff row sits ABOVE each frame, so rows get that much extra room
    local row = self:Get("showGroupBuffs") ~= false and (BUFF_ROW_SIZE + 2) or 0

    for i, b in ipairs(party) do
        b:SetSize(w, h)
        ScaleButton(b, 1)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", partyBox, "TOPLEFT", 0, -row - (i - 1) * (h + gap + row))
    end
    partyBox:SetSize(w, 5 * (h + gap + row))

    local f = self:SizeFactor()
    self._sizeFactor = f
    local rw, rh = math.floor(w * f + 0.5), math.floor(h * f + 0.5)
    for i, b in ipairs(raid) do
        b:SetSize(rw, rh)
        ScaleButton(b, f)
        b:ClearAllPoints()
        local col, r = (i - 1) % cols, math.floor((i - 1) / cols)
        local rrow = math.floor(row * f + 0.5)
        b:SetPoint("TOPLEFT", raidBox, "TOPLEFT", col * (rw + gap), -rrow - r * (rh + gap + rrow))
    end
    raidBox:SetSize(cols * (rw + gap), math.ceil(40 / cols) * (rh + gap + math.floor(row * f + 0.5)))
    -- Frame opacity: the whole group (bars, names, icons, cleanse squares); out of range
    -- dims further on top of it.
    local a = (self:Get("opacity") or 100) / 100
    partyBox:SetAlpha(a); raidBox:SetAlpha(a)
    ForEachShown(function(b) VF:UpdateButton(b) end)
    if self.HideBlizzard then self:HideBlizzard() end
end

----------------------------------------------------------------------
-- Hide Blizzard's party/raid frames (option, out of combat only).
-- They're parked on a hidden parent; nothing else about them changes, so
-- turning the option off and reloading gives them back untouched.
----------------------------------------------------------------------
local hider = CreateFrame("Frame")
hider:Hide()
local BLIZZARD_GROUP_FRAMES = { "PartyFrame", "CompactPartyFrame", "CompactRaidFrameContainer", "CompactRaidFrameManager" }
local pendingHide = false

function VF:HideBlizzard()
    if not self:Get("hideBlizzard") then return end
    if InCombatLockdown() then pendingHide = true; return end
    pendingHide = false
    for _, name in ipairs(BLIZZARD_GROUP_FRAMES) do
        local fr = _G[name]
        if fr and fr:GetParent() ~= hider then
            fr:SetParent(hider)
            -- Blizzard re-parents some of these on group/Edit Mode changes; park them again.
            if not fr._voidFramesHooked then
                fr._voidFramesHooked = true
                hooksecurefunc(fr, "SetParent", function(self, parent)
                    if parent ~= hider and VF:Get("hideBlizzard") then
                        C_Timer.After(0, function() VF:HideBlizzard() end)
                    end
                end)
            end
        end
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
local rangeTick, buffTick = 0, 0

local UNIT_EVENTS = {
    UNIT_HEALTH = UpdateHealth, UNIT_MAXHEALTH = UpdateHealth,
    UNIT_AURA = UpdateAuras, UNIT_NAME_UPDATE = UpdateColorAndName,
    UNIT_CONNECTION = UpdateColorAndName, UNIT_FLAGS = UpdateColorAndName,
}

ev:SetScript("OnEvent", function(_, event, unit)
    if UNIT_EVENTS[event] then
        local b = unit and byUnit[unit]
        if b and b:IsShown() then UNIT_EVENTS[event](b) end
    elseif event == "PLAYER_TARGET_CHANGED" then
        ForEachShown(UpdateTarget)
    elseif event == "RAID_TARGET_UPDATE" then
        ForEachShown(UpdateRaidMark)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingApply then VF:ApplyBindings() end
        if pendingLayout then VF:Relayout() end
        if pendingHide then VF:HideBlizzard() end
        if VF.pendingDragStop then
            local bx = VF.pendingDragStop
            VF.pendingDragStop = nil
            bx.StopDrag()
        end
        VF:PrepareAuraBoxes()
        ForEachShown(UpdateAuras)   -- makes any aura containers skipped in combat; group-buff check
    elseif event == "PLAYER_REGEN_DISABLED" then
        ForEachShown(UpdateGroupBuff)   -- hide the out-of-combat-only "missing buff" icons
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if unit == nil or unit == "player" then VF:ApplyBindings() end
    elseif event == "SPELLS_CHANGED" then
        -- a cleanse learned / lost with a talent change: re-pick the cleanse button's spell
        local spell = VF:CleanseSpell()
        if spell ~= VF._cleanseSpell then VF._cleanseSpell = spell; VF:ApplyBindings() end
    else -- roster / login
        VF:HideBlizzard()
        -- raid grew or shrank past a size step: resize (queued to after combat if needed)
        if VF:SizeFactor() ~= VF._sizeFactor then VF:Relayout() end
        VF:PrepareAuraBoxes()
        ForEachShown(function(b) VF:UpdateButton(b) end)
    end
end)

ev:SetScript("OnUpdate", function(_, elapsed)
    rangeTick = rangeTick + elapsed
    if rangeTick < 0.4 then return end
    rangeTick = 0
    ForEachShown(UpdateRange)
    -- players coming into sight have no aura event to tell us: re-check the group buff now and then
    buffTick = buffTick + 1
    if buffTick >= 5 and not InCombatLockdown() then buffTick = 0; ForEachShown(UpdateGroupBuff) end
end)

function VF:Init()
    -- group-buff IDs learned from followers in earlier sessions (see LearnBuffID)
    for id in pairs(VoidFramesDB.learnedBuffIDs or {}) do GROUP_BUFF_IDS[id] = true end
    partyBox = MakeBox("VoidFramesParty", "party")
    raidBox = MakeBox("VoidFramesRaid", "raid")
    PlaceBox(partyBox, "party", "LEFT", 40, 120)
    PlaceBox(raidBox, "raid", "LEFT", 40, 120)

    local units = { "player", "party1", "party2", "party3", "party4" }
    for i, u in ipairs(units) do party[i] = CreateUnitButton("VoidFramesParty" .. i, partyBox, u) end
    for i = 1, 40 do raid[i] = CreateUnitButton("VoidFramesRaid" .. i, raidBox, "raid" .. i) end
    for _, b in pairs(byUnit) do
        b:RegisterForDrag("LeftButton")
        local box = b:GetParent()
        b:SetScript("OnDragStart", box.StartDrag)
        b:SetScript("OnDragStop", box.StopDrag)
    end

    -- Party frames (with you) when not in a raid; raid frames in a raid.
    RegisterStateDriver(partyBox, "visibility", "[group:raid] hide; show")
    RegisterStateDriver(raidBox, "visibility", "[group:raid] show; hide")

    self:Relayout()
    self:ApplyBindings()
    self:HideBlizzard()

    for e in pairs(UNIT_EVENTS) do ev:RegisterEvent(e) end
    for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
        "PLAYER_SPECIALIZATION_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED",
        "PLAYER_ROLES_ASSIGNED" }) do
        ev:RegisterEvent(e)
    end
end
