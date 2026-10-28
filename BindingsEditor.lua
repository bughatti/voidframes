----------------------------------------------------------------------
-- VoidFrames — click bindings editor.
--
-- A grid of mouse buttons x modifiers. Each box takes a spell name, or one
-- of: target, focus, menu, assist. Drag a spell from your spellbook onto a
-- box to fill it. Saved per character and spec.
----------------------------------------------------------------------
local _, VF = ...

local editor
local CELL_W, CELL_H, LABEL_W = 150, 22, 70

local function SpecLabel()
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local spec = getSpec and getSpec()
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    local name = spec and getInfo and select(2, getInfo(spec))
    return (UnitName("player") or "") .. (name and (" - " .. name) or "")
end

local function Commit(box)
    VF:SetBinding(box.key, box:GetText())
    box:ClearFocus()
    if InCombatLockdown() then
        editor.note:SetText("|cFFFFD100Saved - applies when combat ends.|r")
    else
        editor.note:SetText("|cFF00FF00Saved.|r")
    end
end

local function SpellFromCursor()
    local kind, _, _, spellID = GetCursorInfo()
    if kind == "spell" and spellID then
        return C_Spell.GetSpellName(spellID)
    end
end

local function Build()
    local f = CreateFrame("Frame", "VoidFramesBindingsEditor", UIParent, "BackdropTemplate")
    f:SetSize(LABEL_W + #VF.MODIFIERS * (CELL_W + 6) + 24, 110 + #VF.BUTTONS * (CELL_H + 6))
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0.04, 0.04, 0.06, 0.95)
    f:SetBackdropBorderColor(0, 0.78, 1, 0.6)
    tinsert(UISpecialFrames, "VoidFramesBindingsEditor")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("|cFF00C7FFVoidFrames|r click bindings")
    f.spec = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.spec:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    local help = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("BOTTOMLEFT", 12, 10)
    help:SetPoint("RIGHT", -12, 0)
    help:SetJustifyH("LEFT")
    help:SetText("Type a spell name, or target / focus / menu / assist. Drag a spell from your spellbook onto a box. Press Enter to save; empty = unbound.")

    f.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.note:SetPoint("TOPRIGHT", -34, -14)

    local top = -62
    for c, m in ipairs(VF.MODIFIERS) do
        local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", 12 + LABEL_W + (c - 1) * (CELL_W + 6), top)
        h:SetText(m.label)
    end

    f.boxes = {}
    for r, btn in ipairs(VF.BUTTONS) do
        local y = top - 18 - (r - 1) * (CELL_H + 6)
        local lab = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        lab:SetPoint("TOPLEFT", 12, y - 4)
        lab:SetText(btn.label)
        for c, m in ipairs(VF.MODIFIERS) do
            local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
            box:SetSize(CELL_W - 8, CELL_H)
            box:SetPoint("TOPLEFT", 12 + LABEL_W + (c - 1) * (CELL_W + 6) + 6, y)
            box:SetAutoFocus(false)
            box.key = m.id .. btn.id
            box:SetScript("OnEnterPressed", Commit)
            box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); VF:RefreshBindingsEditor() end)
            box:SetScript("OnReceiveDrag", function(self)
                local name = SpellFromCursor()
                if name then
                    ClearCursor()
                    self:SetText(name)
                    Commit(self)
                end
            end)
            box:SetScript("OnMouseUp", function(self)
                local name = SpellFromCursor()
                if name then
                    ClearCursor()
                    self:SetText(name)
                    Commit(self)
                end
            end)
            f.boxes[#f.boxes + 1] = box
        end
    end
    f:Hide()
    return f
end

function VF:RefreshBindingsEditor()
    if not editor then return end
    local b = self:GetBindings()
    editor.spec:SetText(SpecLabel())
    for _, box in ipairs(editor.boxes) do
        box:SetText(b[box.key] or "")
        box:SetCursorPosition(0)
    end
end

function VF:OpenBindingsEditor()
    editor = editor or Build()
    editor.note:SetText("")
    self:RefreshBindingsEditor()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    editor:Show()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:SetScript("OnEvent", function()
    if editor and editor:IsShown() then VF:RefreshBindingsEditor() end
end)
