-- HUDDump: dumps all live UserWidgets and their widget trees to a file.
-- Press F7 in game. Output: ue4ss/Mods/HUDDump/dump.txt (also echoed to UE4SS.log).

local TAG = "[HUDDump] "
print(TAG .. "Loading...\n")

local OUT_CANDIDATES = {
    "ue4ss\\Mods\\HUDDump\\dump.txt",
    "Mods\\HUDDump\\dump.txt",
    "dump.txt",
}

local SlateLib = nil
local function GetSlateLib()
    if SlateLib and SlateLib:IsValid() then return SlateLib end
    SlateLib = StaticFindObject("/Script/UMG.Default__SlateBlueprintLibrary")
    return SlateLib
end

local function OpenOutput()
    for _, p in ipairs(OUT_CANDIDATES) do
        local f = io.open(p, "w")
        if f then return f, p end
    end
    return nil
end

local function Safe(fn, default)
    local ok, v = pcall(fn)
    if ok then return v end
    return default
end

local function ClassName(obj)
    return Safe(function() return obj:GetClass():GetFName():ToString() end, "?")
end

local function ObjName(obj)
    return Safe(function() return obj:GetFName():ToString() end, "?")
end

local function Vec2(v)
    if not v then return "nil" end
    return string.format("(%.1f, %.1f)", v.X or 0, v.Y or 0)
end

local function SlotInfo(w)
    local s = Safe(function() return w.Slot end)
    if not (s and s:IsValid()) then return "" end
    local cls = ClassName(s)
    local parts = { "slot=" .. cls }
    if cls == "CanvasPanelSlot" then
        local anc = Safe(function() return s:GetAnchors() end)
        if anc then
            parts[#parts + 1] = string.format("anchors=[%.2f,%.2f]-[%.2f,%.2f]",
                anc.Minimum.X, anc.Minimum.Y, anc.Maximum.X, anc.Maximum.Y)
        end
        local off = Safe(function() return s:GetOffsets() end)
        if off then
            parts[#parts + 1] = string.format("offsets=L%.1f T%.1f R%.1f B%.1f",
                off.Left, off.Top, off.Right, off.Bottom)
        end
        parts[#parts + 1] = "align=" .. Vec2(Safe(function() return s:GetAlignment() end))
        parts[#parts + 1] = "autosize=" .. tostring(Safe(function() return s:GetAutoSize() end, "?"))
        parts[#parts + 1] = "z=" .. tostring(Safe(function() return s:GetZOrder() end, "?"))
    elseif cls == "OverlaySlot" or cls == "HorizontalBoxSlot" or cls == "VerticalBoxSlot" then
        local ha = Safe(function() return s.HorizontalAlignment end)
        local va = Safe(function() return s.VerticalAlignment end)
        parts[#parts + 1] = "halign=" .. tostring(ha) .. " valign=" .. tostring(va)
    end
    return table.concat(parts, " ")
end

local function GeomInfo(w)
    local lib = GetSlateLib()
    if not (lib and lib:IsValid()) then return "" end
    return Safe(function()
        local geom = w:GetCachedGeometry()
        local size = lib:GetLocalSize(geom)
        local abs = lib:LocalToAbsolute(geom, { X = 0, Y = 0 })
        if size.X == 0 and size.Y == 0 then return "" end
        return string.format("abs=%s size=%s", Vec2(abs), Vec2(size))
    end, "")
end

local function VisInfo(w)
    local vis = Safe(function() return w:GetVisibility() end, "?")
    local isVis = Safe(function() return w:IsVisible() end, "?")
    return "vis=" .. tostring(vis) .. "/" .. tostring(isVis)
end

local function RenderInfo(w)
    return Safe(function()
        local t = w.RenderTransform
        return string.format("rt.trans=%s rt.scale=%s pivot=%s",
            Vec2(t.Translation), Vec2(t.Scale), Vec2(w.RenderTransformPivot))
    end, "")
end

local function WriteLine(f, depth, text)
    local line = string.rep("  ", depth) .. text
    f:write(line .. "\n")
end

local visited = {}

local function DumpWidget(f, w, depth)
    if not (w and w:IsValid()) then return end
    local addr = Safe(function() return w:GetAddress() end, tostring(w))
    if visited[addr] then
        WriteLine(f, depth, "(already dumped) " .. ObjName(w))
        return
    end
    visited[addr] = true

    local cls = ClassName(w)
    WriteLine(f, depth, string.format("%s [%s] %s %s %s %s",
        ObjName(w), cls, VisInfo(w), SlotInfo(w), GeomInfo(w), RenderInfo(w)))

    -- UserWidget: descend into its own tree
    local tree = Safe(function() return w.WidgetTree end)
    if tree and tree:IsValid() then
        local root = Safe(function() return tree.RootWidget end)
        if root and root:IsValid() then
            DumpWidget(f, root, depth + 1)
        end
    end

    -- Panel widget: descend into children
    local cnt = Safe(function() return w:GetChildrenCount() end, 0)
    for i = 0, cnt - 1 do
        local c = Safe(function() return w:GetChildAt(i) end)
        if c and c:IsValid() then
            DumpWidget(f, c, depth + 1)
        end
    end

    -- ContentWidget (Border, SizeBox, ScaleBox, etc.)
    if cnt == 0 then
        local content = Safe(function() return w:GetContent() end)
        if content and content:IsValid() then
            DumpWidget(f, content, depth + 1)
        end
    end
end

local function DoDump()
    local f, path = OpenOutput()
    if not f then
        print(TAG .. "ERROR: could not open output file\n")
        return
    end
    visited = {}

    local all = FindAllOf("UserWidget") or {}
    f:write("HUDDump - " .. os.date() .. " - " .. #all .. " UserWidgets\n\n")

    -- Section 1: flat list of all UserWidgets
    f:write("=== USERWIDGET LIST ===\n")
    local top = {}
    for _, w in ipairs(all) do
        if w:IsValid() then
            local full = Safe(function() return w:GetFullName() end, "?")
            local inVp = Safe(function() return w:IsInViewport() end, "?")
            local outer = Safe(function() return w:GetOuter() end)
            local outerCls = outer and outer:IsValid() and ClassName(outer) or "?"
            f:write(string.format("%s  inViewport=%s  outer=%s  %s  %s\n",
                full, tostring(inVp), outerCls, VisInfo(w), GeomInfo(w)))
            if inVp == true then top[#top + 1] = w end
        end
    end

    -- Section 2: full tree for each widget that is directly in the viewport
    f:write("\n=== VIEWPORT WIDGET TREES ===\n")
    for _, w in ipairs(top) do
        f:write("\n--- " .. Safe(function() return w:GetFullName() end, "?") .. "\n")
        DumpWidget(f, w, 0)
    end

    -- Section 3: any remaining UI_* UserWidgets not reached above
    f:write("\n=== OTHER UI_ WIDGET TREES (not in viewport) ===\n")
    for _, w in ipairs(all) do
        if w:IsValid() then
            local full = Safe(function() return w:GetFullName() end, "")
            local addr = Safe(function() return w:GetAddress() end, tostring(w))
            if full:find("UI_", 1, true) and not visited[addr] then
                f:write("\n--- " .. full .. "\n")
                DumpWidget(f, w, 0)
            end
        end
    end

    f:close()
    print(TAG .. "Wrote " .. #all .. " widgets to " .. path .. "\n")
end

RegisterKeyBindAsync(Key.F7, {}, function()
    ExecuteInGameThread(DoDump)
end)

print(TAG .. "Ready. Press F7 in game to dump widgets.\n")
