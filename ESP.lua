local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local V2new  = Vector2.new
local V3new  = Vector3.new
local C3new  = Color3.new
local C3rgb  = Color3.fromRGB
local mfloor = math.floor
local mabs   = math.abs
local mclamp = math.clamp

if _G.__ESP_CLEANUP then
    pcall(_G.__ESP_CLEANUP)
end

local FEATURE_LIST = {"Box","Name","HealthBar","Distance","Tracer","Skeleton","Chams"}
local IS_FLAG = {}
for _, k in ipairs(FEATURE_LIST) do IS_FLAG[k] = true end

if type(_G.__ESP_FLAGS) ~= "table" then
    _G.__ESP_FLAGS = {}
end
for _, k in ipairs(FEATURE_LIST) do
    if _G.__ESP_FLAGS[k] == nil then
        _G.__ESP_FLAGS[k] = false
    end
end
local _flags = _G.__ESP_FLAGS

if type(_G.__ESP_SETTINGS) ~= "table" then
    _G.__ESP_SETTINGS = {}
end
local _settings = _G.__ESP_SETTINGS

local DEFAULTS = {
    TeamCheck         = false,
    MaxDistance        = 2000,
    Font              = Drawing.Fonts.Plex,
    FontSize          = 13,
    BoxColor          = C3rgb(255,255,255),
    NameColor         = C3rgb(255,255,255),
    DistanceColor     = C3rgb(200,200,200),
    TracerColor       = C3rgb(255,255,255),
    SkeletonColor     = C3rgb(255,255,255),
    HealthHighColor   = C3rgb(0,255,0),
    HealthLowColor    = C3rgb(255,0,0),
    ChamsFillColor    = C3rgb(255,0,0),
    ChamsOutlineColor = C3rgb(255,255,255),
}
for k, v in next, DEFAULTS do
    if _settings[k] == nil then
        _settings[k] = v
    end
end

local BLACK  = C3new(0,0,0)
local ONE_V2 = V2new(1,1)
local TWO_V2 = V2new(2,2)

local BonesR15 = {
    {"Head","UpperTorso"},
    {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},  {"LeftUpperArm","LeftLowerArm"},   {"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},  {"LeftUpperLeg","LeftLowerLeg"},   {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"},
}
local BonesR6 = {
    {"Head","Torso"},
    {"Torso","Left Arm"}, {"Torso","Right Arm"},
    {"Torso","Left Leg"}, {"Torso","Right Leg"},
}
local MAX_BONES = #BonesR15

local _active      = false
local _genID       = 0
local _pool        = {}
local _charConns   = {}
local _globalConns = {}

local function safeRemove(d)
    if not d then return end
    pcall(function() d.Visible = false end)
    pcall(function() d:Remove() end)
end

local function safeDestroy(inst)
    if not inst then return end
    pcall(function() inst.Enabled = false end)
    pcall(function() inst:Destroy() end)
end

local function safeDisconnect(c)
    if not c then return end
    pcall(function() c:Disconnect() end)
end

local function mkLine(thick, col)
    local d = Drawing.new("Line")
    d.Visible = false; d.Thickness = thick or 1
    d.Color = col or C3new(1,1,1); d.Transparency = 1
    return d
end

local function mkText(size, col)
    local d = Drawing.new("Text")
    d.Visible = false; d.Center = true; d.Outline = true
    d.OutlineColor = BLACK
    d.Size = size or _settings.FontSize
    d.Font = _settings.Font
    d.Color = col or C3new(1,1,1); d.Transparency = 1
    return d
end

local function mkSquare()
    local d = Drawing.new("Square")
    d.Visible = false; d.Filled = false
    d.Thickness = 1; d.Transparency = 1
    return d
end

local DRAW_KEYS = {"BoxOutline","Box","Name","Distance","HealthBarBG","HealthBar","HealthText","Tracer"}

local function createObject()
    local o = {
        BoxOutline  = mkSquare(),
        Box         = mkSquare(),
        Name        = mkText(_settings.FontSize),
        Distance    = mkText(_settings.FontSize - 1),
        HealthBarBG = mkLine(4, BLACK),
        HealthBar   = mkLine(2),
        HealthText  = mkText(_settings.FontSize - 2),
        Tracer      = mkLine(1),
        Bones       = {},
        Chams       = nil,
        Parts       = nil,
    }
    for i = 1, MAX_BONES do
        o.Bones[i] = mkLine(1.5)
    end
    return o
end

local function hideObject(o)
    for i = 1, #DRAW_KEYS do
        pcall(function() o[DRAW_KEYS[i]].Visible = false end)
    end
    for i = 1, MAX_BONES do
        if o.Bones[i] then pcall(function() o.Bones[i].Visible = false end) end
    end
    if o.Chams then pcall(function() o.Chams.Enabled = false end) end
end

local function destroyObject(o)
    for i = 1, #DRAW_KEYS do safeRemove(o[DRAW_KEYS[i]]) end
    for i = 1, MAX_BONES do safeRemove(o.Bones[i]) end
    safeDestroy(o.Chams)
    o.Chams = nil; o.Parts = nil
end

local function cacheParts(char)
    if not char then return nil end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not (hum and root and head) then return nil end

    local isR15 = (hum.RigType == Enum.HumanoidRigType.R15)
    local defs  = isR15 and BonesR15 or BonesR6
    local count = #defs
    local bp    = {}
    for i = 1, count do
        local a = char:FindFirstChild(defs[i][1])
        local b = char:FindFirstChild(defs[i][2])
        bp[i] = (a and b) and {a, b} or false
    end
    return { Hum = hum, Root = root, Head = head, BoneCount = count, BoneParts = bp }
end

local bb_tl, bb_sz, bb_cx

local function computeBB(cam, rootPos)
    local _, on = cam:WorldToViewportPoint(rootPos)
    if not on then return false end
    local vT = cam:WorldToViewportPoint(rootPos + V3new(0, 3.25, 0))
    local vB = cam:WorldToViewportPoint(rootPos - V3new(0, 2.75, 0))
    if vT.Z < 1 then return false end
    local h = mabs(vB.Y - vT.Y)
    local w = h * 0.55
    bb_cx = (vT.X + vB.X) * 0.5
    bb_tl = V2new(bb_cx - w * 0.5, vT.Y)
    bb_sz = V2new(w, h)
    return true
end

local function renderFrame()
    if not _active then return end
    local cam = workspace.CurrentCamera
    if not cam then return end

    local camPos  = cam.CFrame.Position
    local vpSize  = cam.ViewportSize
    local maxDist = _settings.MaxDistance
    local myTeam  = LocalPlayer.Team

    local eBox   = _flags.Box
    local eName  = _flags.Name
    local eHP    = _flags.HealthBar
    local eDist  = _flags.Distance
    local eTrace = _flags.Tracer
    local eSkel  = _flags.Skeleton
    local eChams = _flags.Chams

    for player, obj in next, _pool do
        local shouldDraw = false
        local parts = obj.Parts

        if player.Parent ~= nil and parts ~= nil then
            if not (_settings.TeamCheck and player.Team and player.Team == myTeam) then
                local hum  = parts.Hum
                local root = parts.Root
                if root and root.Parent and hum and hum.Parent and hum.Health > 0 then
                    local rootPos = root.Position
                    local dist    = (camPos - rootPos).Magnitude
                    if dist <= maxDist and computeBB(cam, rootPos) then
                        shouldDraw = true
                        local hpFrac = mclamp(hum.Health / hum.MaxHealth, 0, 1)

                        if eBox then
                            obj.BoxOutline.Position  = bb_tl - ONE_V2
                            obj.BoxOutline.Size      = bb_sz + TWO_V2
                            obj.BoxOutline.Color     = BLACK
                            obj.BoxOutline.Thickness = 3
                            obj.BoxOutline.Visible   = true
                            obj.Box.Position = bb_tl
                            obj.Box.Size     = bb_sz
                            obj.Box.Color    = _settings.BoxColor
                            obj.Box.Visible  = true
                        else
                            obj.BoxOutline.Visible = false
                            obj.Box.Visible = false
                        end

                        if eName then
                            obj.Name.Text     = player.DisplayName
                            obj.Name.Color    = _settings.NameColor
                            obj.Name.Size     = _settings.FontSize
                            obj.Name.Font     = _settings.Font
                            obj.Name.Position = V2new(bb_cx, bb_tl.Y - _settings.FontSize - 4)
                            obj.Name.Visible  = true
                        else
                            obj.Name.Visible = false
                        end

                        if eDist then
                            obj.Distance.Text     = mfloor(dist) .. "m"
                            obj.Distance.Color    = _settings.DistanceColor
                            obj.Distance.Size     = _settings.FontSize - 1
                            obj.Distance.Font     = _settings.Font
                            obj.Distance.Position = V2new(bb_cx, bb_tl.Y + bb_sz.Y + 2)
                            obj.Distance.Visible  = true
                        else
                            obj.Distance.Visible = false
                        end

                        if eHP then
                            local barX  = bb_tl.X - 5
                            local topY  = bb_tl.Y
                            local botY  = bb_tl.Y + bb_sz.Y
                            local fillY = botY - bb_sz.Y * hpFrac
                            local lo    = _settings.HealthLowColor
                            local hi    = _settings.HealthHighColor
                            local hpCol = C3new(
                                lo.R + (hi.R - lo.R) * hpFrac,
                                lo.G + (hi.G - lo.G) * hpFrac,
                                lo.B + (hi.B - lo.B) * hpFrac
                            )
                            obj.HealthBarBG.From    = V2new(barX, topY)
                            obj.HealthBarBG.To      = V2new(barX, botY)
                            obj.HealthBarBG.Visible = true
                            obj.HealthBar.From      = V2new(barX, fillY)
                            obj.HealthBar.To        = V2new(barX, botY)
                            obj.HealthBar.Color     = hpCol
                            obj.HealthBar.Visible   = true
                            if hpFrac < 1 then
                                obj.HealthText.Text     = tostring(mfloor(hum.Health))
                                obj.HealthText.Color    = hpCol
                                obj.HealthText.Position = V2new(barX, fillY - _settings.FontSize + 2)
                                obj.HealthText.Visible  = true
                            else
                                obj.HealthText.Visible = false
                            end
                        else
                            obj.HealthBarBG.Visible = false
                            obj.HealthBar.Visible   = false
                            obj.HealthText.Visible  = false
                        end

                        if eTrace then
                            obj.Tracer.From    = V2new(vpSize.X * 0.5, vpSize.Y)
                            obj.Tracer.To      = V2new(bb_cx, bb_tl.Y + bb_sz.Y)
                            obj.Tracer.Color   = _settings.TracerColor
                            obj.Tracer.Visible = true
                        else
                            obj.Tracer.Visible = false
                        end

                        if eSkel then
                            local bp    = parts.BoneParts
                            local bc    = parts.BoneCount
                            local bones = obj.Bones
                            local sCol  = _settings.SkeletonColor
                            for i = 1, bc do
                                local line = bones[i]
                                local pair = bp[i]
                                if pair then
                                    local vA, onA = cam:WorldToViewportPoint(pair[1].Position)
                                    local vB, onB = cam:WorldToViewportPoint(pair[2].Position)
                                    if onA and onB then
                                        line.From    = V2new(vA.X, vA.Y)
                                        line.To      = V2new(vB.X, vB.Y)
                                        line.Color   = sCol
                                        line.Visible = true
                                    else
                                        line.Visible = false
                                    end
                                else
                                    line.Visible = false
                                end
                            end
                            for i = bc + 1, MAX_BONES do
                                if bones[i] then bones[i].Visible = false end
                            end
                        else
                            for i = 1, MAX_BONES do
                                if obj.Bones[i] then obj.Bones[i].Visible = false end
                            end
                        end

                        if eChams then
                            local ch = obj.Chams
                            if not ch or not ch.Parent then
                                ch = Instance.new("Highlight")
                                ch.FillTransparency    = 0.5
                                ch.OutlineTransparency = 0
                                ch.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
                                local ok = pcall(function() ch.Parent = gethui() end)
                                if not ok then
                                    pcall(function() ch.Parent = game:GetService("CoreGui") end)
                                end
                                obj.Chams = ch
                            end
                            ch.Adornee      = player.Character
                            ch.FillColor    = _settings.ChamsFillColor
                            ch.OutlineColor = _settings.ChamsOutlineColor
                            ch.Enabled      = true
                        else
                            if obj.Chams then obj.Chams.Enabled = false end
                        end
                    end
                end
            end
        end

        if not shouldDraw then
            hideObject(obj)
        end
    end
end

local function bindPlayer(player, gen)
    if player == LocalPlayer then return end
    if not _active or gen ~= _genID then return end
    if _pool[player] then return end

    local obj = createObject()
    _pool[player] = obj

    _charConns[player] = player.CharacterAdded:Connect(function(char)
        if not _active or gen ~= _genID then return end
        task.defer(function()
            task.wait(0.3)
            if not _active or gen ~= _genID then return end
            if not _pool[player] then return end
            obj.Parts = cacheParts(char)
        end)
    end)

    if player.Character then
        task.defer(function()
            task.wait(0.3)
            if not _active or gen ~= _genID then return end
            if not _pool[player] then return end
            obj.Parts = cacheParts(player.Character)
        end)
    end
end

local function startInternal()
    if _active then return end
    _active = true
    _genID  = _genID + 1
    local gen = _genID

    _pool        = {}
    _charConns   = {}
    _globalConns = {}

    for _, p in ipairs(Players:GetPlayers()) do
        bindPlayer(p, gen)
    end

    _globalConns[#_globalConns + 1] = Players.PlayerAdded:Connect(function(p)
        if _active and gen == _genID then bindPlayer(p, gen) end
    end)

    _globalConns[#_globalConns + 1] = Players.PlayerRemoving:Connect(function(p)
        if not _active or gen ~= _genID then return end
        safeDisconnect(_charConns[p]); _charConns[p] = nil
        local obj = _pool[p]
        if obj then destroyObject(obj) end
        _pool[p] = nil
    end)

    _globalConns[#_globalConns + 1] = RunService.RenderStepped:Connect(renderFrame)
end

local function stopInternal()
    if not _active then return end
    _active = false
    _genID  = _genID + 1

    for i = 1, #_globalConns do safeDisconnect(_globalConns[i]) end
    _globalConns = {}

    for _, c in next, _charConns do safeDisconnect(c) end
    _charConns = {}

    local list = {}
    for p in next, _pool do list[#list + 1] = p end
    for i = 1, #list do
        local obj = _pool[list[i]]
        if obj then destroyObject(obj) end
        _pool[list[i]] = nil
    end
    _pool = {}
end

local function anyFlagOn()
    for _, k in ipairs(FEATURE_LIST) do
        if _flags[k] then return true end
    end
    return false
end

local function autoManage()
    local on = anyFlagOn()
    if on and not _active then
        startInternal()
    elseif not on and _active then
        stopInternal()
    end
end

local ESP = setmetatable({}, {
    __newindex = function(_, key, value)
        if IS_FLAG[key] then
            _flags[key] = value
            autoManage()
        else
            _settings[key] = value
        end
    end,
    __index = function(_, key)
        if IS_FLAG[key] then
            return _flags[key]
        end
        return _settings[key]
    end,
})

_G.__ESP_CLEANUP = function()
    stopInternal()
end
if anyFlagOn() then
    startInternal()
end

return ESP
