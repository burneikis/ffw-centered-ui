-- CenteredHUD: moves spell cooldowns and ammo counter next to the crosshair.
-- F8 = reload config.ini and re-apply.

local TAG = "[CenteredHUD] "
print(TAG .. "Loading...\n")

local CONFIG_FILE = "ue4ss\\Mods\\CenteredHUD\\config.ini"

-- Offsets are in DPI-scaled units from screen center. Alignment is the point
-- of the element that sits at (center + offset): 0 = left/top, 0.5 = middle, 1 = right/bottom.
local Config = {
    Enabled       = true,
    SpellsX       = -70,
    SpellsY       = 0,
    SpellsAlignX  = 1.0,
    SpellsAlignY  = 0.5,
    SpellsScale   = 0.9,
    SpellsRowAlign = 3, -- EHorizontalAlignment: 0 fill, 1 left, 2 center, 3 right
    SpellsOutsideRetainer = true, -- move out of RetainerBox_0 (fixes ghosting); positions become raw pixels
    AmmoX         = 70,
    AmmoY         = 0,
    AmmoAlignX    = 0.0,
    AmmoAlignY    = 0.5,
    AmmoScale     = 0.9,
}

local HUD_CLASSES = { "UI_Player_C", "UI_PlayerLobby_C" }

local function LoadConfig()
    local f = io.open(CONFIG_FILE, "r")
    if not f then return end
    for line in f:lines() do
        local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if k and Config[k] ~= nil then
            if type(Config[k]) == "boolean" then
                Config[k] = (v == "1" or v:lower() == "true")
            else
                Config[k] = tonumber(v) or Config[k]
            end
        end
    end
    f:close()
end

local function Safe(fn)
    local ok, v = pcall(fn)
    if ok then return v end
    return nil
end

local function Name(w)
    return Safe(function() return w:GetFName():ToString() end) or "?"
end

-- Depth-first search of a widget tree by widget name.
local function FindByName(root, target, depth)
    depth = depth or 0
    if depth > 30 or not (root and root:IsValid()) then return nil end
    if Name(root) == target then return root end

    local tree = Safe(function() return root.WidgetTree end)
    if tree and tree:IsValid() then
        local r = FindByName(Safe(function() return tree.RootWidget end), target, depth + 1)
        if r then return r end
    end

    local cnt = Safe(function() return root:GetChildrenCount() end) or 0
    for i = 0, cnt - 1 do
        local r = FindByName(Safe(function() return root:GetChildAt(i) end), target, depth + 1)
        if r then return r end
    end
    if cnt == 0 then
        local content = Safe(function() return root:GetContent() end)
        if content then
            local r = FindByName(content, target, depth + 1)
            if r then return r end
        end
    end
    return nil
end

local function CenterSlot(slot, x, y, ax, ay)
    slot:SetAnchors({ Minimum = { X = 0.5, Y = 0.5 }, Maximum = { X = 0.5, Y = 0.5 } })
    slot:SetAlignment({ X = ax, Y = ay })
    slot:SetAutoSize(true)
    slot:SetPosition({ X = x, Y = y })
    slot:SetZOrder(10)
end

local function ApplyTo(hud)
    local canvas = FindByName(hud, "MovingCanvas")
    if not canvas then
        print(TAG .. "MovingCanvas not found in " .. Name(hud) .. "\n")
        return false
    end

    -- outer canvas (parent of the crosshair), outside RetainerBox_0
    local outerCanvas = nil
    local crosshair = FindByName(hud, "Crosshair_Top")
    if crosshair then outerCanvas = Safe(function() return crosshair:GetParent() end) end

    local okSpells = false
    local spells = FindByName(hud, "HB_Spells")
    if spells then
        local ok, err = pcall(function()
            local slot = spells.Slot
            if Config.SpellsOutsideRetainer and outerCanvas and spells:GetParent():GetAddress() ~= outerCanvas:GetAddress() then
                slot = outerCanvas:AddChildToCanvas(spells)
            end
            CenterSlot(slot, Config.SpellsX, Config.SpellsY, Config.SpellsAlignX, Config.SpellsAlignY)
            spells:SetRenderScale({ X = Config.SpellsScale, Y = Config.SpellsScale })
            -- undo the per-spell stagger (0/16/32 px) and center each row in the box
            local cnt = spells:GetChildrenCount()
            for i = 0, cnt - 1 do
                local c = spells:GetChildAt(i)
                if c and c:IsValid() then
                    pcall(function() c:SetRenderTranslation({ X = 0, Y = 0 }) end)
                    pcall(function() c.Slot:SetHorizontalAlignment(Config.SpellsRowAlign) end)
                end
            end
        end)
        okSpells = ok
        if not ok then print(TAG .. "spells error: " .. tostring(err) .. "\n") end
    else
        print(TAG .. "HB_Spells not found\n")
    end

    local okAmmo = false
    local ammo = FindByName(hud, "HB_Ammo")
    if ammo then
        local ok, err = pcall(function()
            local slot = ammo.Slot
            local slotCls = slot:GetClass():GetFName():ToString()
            if slotCls ~= "CanvasPanelSlot" then
                -- reparent from VerticalBox_0 into MovingCanvas
                slot = canvas:AddChildToCanvas(ammo)
            end
            CenterSlot(slot, Config.AmmoX, Config.AmmoY, Config.AmmoAlignX, Config.AmmoAlignY)
            ammo:SetRenderScale({ X = Config.AmmoScale, Y = Config.AmmoScale })
        end)
        okAmmo = ok
        if not ok then print(TAG .. "ammo error: " .. tostring(err) .. "\n") end
    else
        print(TAG .. "HB_Ammo not found\n")
    end

    print(TAG .. string.format("applied to %s (spells=%s ammo=%s)\n", Name(hud), tostring(okSpells), tostring(okAmmo)))
    return okSpells and okAmmo
end

local function ApplyAll()
    if not Config.Enabled then return end
    for _, cls in ipairs(HUD_CLASSES) do
        local list = FindAllOf(cls) or {}
        for _, hud in ipairs(list) do
            if hud:IsValid() and Safe(function() return hud:IsInViewport() end) then
                ApplyTo(hud)
            end
        end
    end
end

-- Retry a few times after a HUD widget appears; its tree may not be built yet.
local function ApplyWithRetry(hud, attempts)
    attempts = attempts or 10
    if attempts <= 0 then return end
    ExecuteWithDelay(300, function()
        ExecuteInGameThread(function()
            if not (hud and hud:IsValid()) then return end
            local inVp = Safe(function() return hud:IsInViewport() end)
            if not inVp or not ApplyTo(hud) then
                ApplyWithRetry(hud, attempts - 1)
            end
        end)
    end)
end

LoadConfig()

NotifyOnNewObject("/Script/UMG.UserWidget", function(w)
    if not Config.Enabled then return end
    local full = Safe(function() return w:GetFullName() end) or ""
    for _, cls in ipairs(HUD_CLASSES) do
        if full:find(cls .. " ", 1, true) or full:find(cls .. "_", 1, true) then
            -- only top-level instances (outer is the GameInstance), not tree templates
            if not full:find(":WidgetTree.", 1, true) then
                ApplyWithRetry(w)
            end
            break
        end
    end
end)

RegisterKeyBindAsync(Key.F8, {}, function()
    LoadConfig()
    ExecuteInGameThread(ApplyAll)
    print(TAG .. "config reloaded\n")
end)

ExecuteInGameThread(ApplyAll)
print(TAG .. "Ready (F8 = reload config)\n")
