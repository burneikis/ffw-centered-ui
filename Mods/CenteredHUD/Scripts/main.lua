-- CenteredHUD: moves HUD widgets next to the crosshair.
-- Fully driven by config.ini; F8 = reload config and re-apply.

local TAG = "[CenteredHUD] "
print(TAG .. "Loading...\n")

local CONFIG_FILE = "ue4ss\\Mods\\CenteredHUD\\config.ini"
local HUD_CLASSES = { "UI_Player_C", "UI_PlayerLobby_C" }

local General = { Enabled = true, Verbose = true }
local Elements = {}

-- Defaults for every element section.
local ELEMENT_DEFAULTS = {
    Widget            = "",
    Enabled           = true,
    X                 = 0,
    Y                 = 0,
    AlignX            = 0.5,
    AlignY            = 0.5,
    Scale             = 1.0,
    ZOrder            = 10,
    Reparent          = "none", -- none | canvas | outer | auto
    RowAlign          = -1,     -- -1 leave alone, 0 fill, 1 left, 2 center, 3 right
    ResetChildOffsets = false,
}

local function toBool(v)
    v = tostring(v):lower()
    return v == "1" or v == "true" or v == "yes" or v == "on"
end

local function LoadConfig()
    General = { Enabled = true, Verbose = true }
    Elements = {}

    local f = io.open(CONFIG_FILE, "r")
    if not f then
        print(TAG .. "config.ini not found, using built-in defaults\n")
        return
    end

    local current = nil -- nil = [General], table = element section
    for raw in f:lines() do
        local line = raw:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and not line:match("^[;#]") then
            local section = line:match("^%[(.-)%]$")
            if section then
                if section:lower() == "general" then
                    current = nil
                else
                    current = { Name = section }
                    for k, v in pairs(ELEMENT_DEFAULTS) do current[k] = v end
                    Elements[#Elements + 1] = current
                end
            else
                local k, v = line:match("^([%w_]+)%s*=%s*(.-)$")
                if k then
                    local target = current or General
                    local ref
                    if current then ref = ELEMENT_DEFAULTS[k] else ref = General[k] end
                    if ref ~= nil then
                        if type(ref) == "boolean" then
                            target[k] = toBool(v)
                        elseif type(ref) == "number" then
                            target[k] = tonumber(v) or target[k]
                        else
                            target[k] = v
                        end
                    end
                end
            end
        end
    end
    f:close()

    -- Drop sections without a widget name.
    local valid = {}
    for _, e in ipairs(Elements) do
        if e.Widget ~= "" then valid[#valid + 1] = e end
    end
    Elements = valid
    print(TAG .. string.format("config loaded: %d element(s)\n", #Elements))
    if #Elements == 0 then
        print(TAG .. "WARNING: no [Section] entries found. Old config.ini format?" ..
            " Reinstall with KEEP_CONFIG=0 ./install.sh\n")
    end
end

local function Log(fmt, ...)
    if General.Verbose then print(TAG .. string.format(fmt, ...) .. "\n") end
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

local function CenterSlot(slot, e)
    slot:SetAnchors({ Minimum = { X = 0.5, Y = 0.5 }, Maximum = { X = 0.5, Y = 0.5 } })
    slot:SetAlignment({ X = e.AlignX, Y = e.AlignY })
    slot:SetAutoSize(true)
    slot:SetPosition({ X = e.X, Y = e.Y })
    slot:SetZOrder(e.ZOrder)
end

local function PickSlot(widget, e, canvas, outerCanvas)
    local mode = tostring(e.Reparent):lower()
    if mode == "outer" and outerCanvas then
        local parent = Safe(function() return widget:GetParent() end)
        if parent and parent:GetAddress() ~= outerCanvas:GetAddress() then
            return outerCanvas:AddChildToCanvas(widget)
        end
        return widget.Slot
    elseif mode == "canvas" and canvas then
        local parent = Safe(function() return widget:GetParent() end)
        if parent and parent:GetAddress() ~= canvas:GetAddress() then
            return canvas:AddChildToCanvas(widget)
        end
        return widget.Slot
    elseif mode == "auto" and canvas then
        local slot = widget.Slot
        local cls = Safe(function() return slot:GetClass():GetFName():ToString() end)
        if cls ~= "CanvasPanelSlot" then
            return canvas:AddChildToCanvas(widget)
        end
        return slot
    end
    return widget.Slot
end

local function ApplyElement(hud, e, canvas, outerCanvas)
    if not e.Enabled then return true end

    local widget = FindByName(hud, e.Widget)
    if not widget then
        Log("%s: widget '%s' not found", e.Name, e.Widget)
        return false
    end

    local ok, err = pcall(function()
        CenterSlot(PickSlot(widget, e, canvas, outerCanvas), e)
        widget:SetRenderScale({ X = e.Scale, Y = e.Scale })

        if e.ResetChildOffsets or e.RowAlign >= 0 then
            local cnt = widget:GetChildrenCount()
            for i = 0, cnt - 1 do
                local c = widget:GetChildAt(i)
                if c and c:IsValid() then
                    if e.ResetChildOffsets then
                        pcall(function() c:SetRenderTranslation({ X = 0, Y = 0 }) end)
                    end
                    if e.RowAlign >= 0 then
                        pcall(function() c.Slot:SetHorizontalAlignment(e.RowAlign) end)
                    end
                end
            end
        end
    end)

    if not ok then Log("%s: error: %s", e.Name, tostring(err)) end
    return ok
end

local function ApplyTo(hud)
    local canvas = FindByName(hud, "MovingCanvas")
    if not canvas then
        Log("MovingCanvas not found in %s", Name(hud))
        return false
    end

    -- outer canvas (parent of the crosshair), outside RetainerBox_0
    local outerCanvas = nil
    local crosshair = FindByName(hud, "Crosshair_Top")
    if crosshair then outerCanvas = Safe(function() return crosshair:GetParent() end) end

    local all = true
    for _, e in ipairs(Elements) do
        if not ApplyElement(hud, e, canvas, outerCanvas) then all = false end
    end

    Log("applied to %s (all=%s)", Name(hud), tostring(all))
    return all
end

local function ApplyAll()
    if not General.Enabled then return end
    for _, cls in ipairs(HUD_CLASSES) do
        local list = FindAllOf(cls) or {}
        for _, hud in ipairs(list) do
            if hud:IsValid() and Safe(function() return hud:IsInViewport() end) then
                ApplyTo(hud)
            end
        end
    end
end

-- Delayed callbacks must run on the game thread. ExecuteWithDelay runs its
-- callback on a worker thread, which touches the Lua state concurrently with
-- the game thread and corrupts it (crash in the Lua VM). Use the delayed
-- action API instead, falling back only on older UE4SS builds.
local DelayInGameThread = ExecuteInGameThreadWithDelay
    or function(ms, fn) ExecuteWithDelay(ms, function() ExecuteInGameThread(fn) end) end

-- Retry a few times after a HUD widget appears; its tree may not be built yet.
local function ApplyWithRetry(hud, attempts)
    attempts = attempts or 10
    if attempts <= 0 then return end
    DelayInGameThread(300, function()
        if not (hud and hud:IsValid()) then return end
        local inVp = Safe(function() return hud:IsInViewport() end)
        if not inVp or not ApplyTo(hud) then
            ApplyWithRetry(hud, attempts - 1)
        end
    end)
end

LoadConfig()

NotifyOnNewObject("/Script/UMG.UserWidget", function(w)
    if not General.Enabled then return end
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
