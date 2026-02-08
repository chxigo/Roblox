--// ESP Module v3 — Bulletproof Enable/Disable
--// API: ESP:Enable() / ESP:Disable() เท่านั้น

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local V2new  = Vector2.new
local V3new  = Vector3.new
local C3new  = Color3.new
local C3rgb  = Color3.fromRGB
local mfloor = math.floor
local mabs   = math.abs
local mclamp = math.clamp

----------------------------------------------------------------
-- Module
----------------------------------------------------------------
local ESP = {}

ESP.Box       = false
ESP.Name      = false
ESP.HealthBar = false
ESP.Distance  = false
ESP.Tracer    = false
ESP.Skeleton  = false
ESP.Chams     = false

ESP.TeamCheck   = false
ESP.MaxDistance  = 2000
ESP.Font        = Drawing.Fonts.Plex
ESP.FontSize    = 13

ESP.BoxColor          = C3rgb(255,255,255)
ESP.NameColor         = C3rgb(255,255,255)
ESP.DistanceColor     = C3rgb(200,200,200)
ESP.TracerColor       = C3rgb(255,255,255)
ESP.SkeletonColor     = C3rgb(255,255,255)
ESP.HealthHighColor   = C3rgb(0,255,0)
ESP.HealthLowColor    = C3rgb(255,0,0)
ESP.ChamsFillColor    = C3rgb(255,0,0)
ESP.ChamsOutlineColor = C3rgb(255,255,255)

----------------------------------------------------------------
-- Constants
----------------------------------------------------------------
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

----------------------------------------------------------------
-- Internal State
----------------------------------------------------------------
local _active    = false
local _genID     = 0        -- generation ID ป้องกัน stale callback
local _pool      = {}       -- [Player] = object
local _charConns = {}       -- [Player] = connection
local _globalConns = {}     -- array ของ connection ทั้งหมด
local _renderConn  = nil

----------------------------------------------------------------
-- Safe remove drawing
----------------------------------------------------------------
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

----------------------------------------------------------------
-- Drawing Factory
----------------------------------------------------------------
local function mkLine(thick, col)
    local d = Drawing.new("Line")
    d.Visible      = false
    d.Thickness    = thick or 1
    d.Color        = col or C3new(1,1,1)
    d.Transparency = 1
    return d
end

local function mkText(size, col)
    local d = Drawing.new("Text")
    d.Visible      = false
    d.Center       = true
    d.Outline      = true
    d.OutlineColor = BLACK
    d.Size         = size or ESP.FontSize
    d.Font         = ESP.Font
    d.Color        = col or C3new(1,1,1)
    d.Transparency = 1
    return d
end

local function mkSquare()
    local d = Drawing.new("Square")
    d.Visible      = false
    d.Filled       = false
    d.Thickness    = 1
    d.Transparency = 1
    return d
end

----------------------------------------------------------------
-- Per-player object
----------------------------------------------------------------
local function createObject()
    local o = {
        BoxOutline  = mkSquare(),
        Box         = mkSquare(),
        Name        = mkText(ESP.FontSize),
        Distance    = mkText(ESP.FontSize - 1),
        HealthBarBG = mkLine(4, BLACK),
        HealthBar   = mkLine(2),
        HealthText  = mkText(ESP.FontSize - 2),
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

local DRAW_KEYS = {
    "BoxOutline","Box","Name","Distance",
    "HealthBarBG","HealthBar","HealthText","Tracer"
}

local function hideObject(o)
    for i = 1, #DRAW_KEYS do
        pcall(function() o[DRAW_KEYS[i]].Visible = false end)
    end
    for i = 1, MAX_BONES do
        if o.Bones[i] then
            pcall(function() o.Bones[i].Visible = false end)
        end
    end
    if o.Chams then
        pcall(function() o.Chams.Enabled = false end)
    end
end

local function destroyObject(o)
    for i = 1, #DRAW_KEYS do
        safeRemove(o[DRAW_KEYS[i]])
        o[DRAW_KEYS[i]] = nil
    end
    for i = 1, MAX_BONES do
        safeRemove(o.Bones[i])
        o.Bones[i] = nil
    end
    if o.Chams then
        safeDestroy(o.Chams)
        o.Chams = nil
    end
    o.Parts = nil
end

----------------------------------------------------------------
-- Cache parts
----------------------------------------------------------------
local function cacheParts(char)
    if not char then return nil end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not (hum and root and head) then return nil end

    local isR15     = (hum.RigType == Enum.HumanoidRigType.R15)
    local bonesDef  = isR15 and BonesR15 or BonesR6
    local boneCount = #bonesDef
    local boneParts = {}

    for i = 1, boneCount do
        local a = char:FindFirstChild(bonesDef[i][1])
        local b = char:FindFirstChild(bonesDef[i][2])
        if a and b then
            boneParts[i] = {a, b}
        else
            boneParts[i] = false
        end
    end

    return {
        Hum = hum, Root = root, Head = head,
        BoneCount = boneCount, BoneParts = boneParts,
    }
end

----------------------------------------------------------------
-- Bounding Box
----------------------------------------------------------------
local bb_tl, bb_sz, bb_cx

local function computeBB(cam, rootPos)
    local _, onScreen = cam:WorldToViewportPoint(rootPos)
    if not onScreen then return false end

    local vTop = cam:WorldToViewportPoint(rootPos + V3new(0, 3.25, 0))
    local vBot = cam:WorldToViewportPoint(rootPos - V3new(0, 2.75, 0))
    if vTop.Z < 1 then return false end

    local h = mabs(vBot.Y - vTop.Y)
    local w = h * 0.55
    bb_cx = (vTop.X + vBot.X) * 0.5
    bb_tl = V2new(bb_cx - w * 0.5, vTop.Y)
    bb_sz = V2new(w, h)
    return true
end

----------------------------------------------------------------
-- Render Loop (ไม่ใช้ continue)
----------------------------------------------------------------
local function renderFrame()
    if not _active then return end

    local cam = workspace.CurrentCamera
    if not cam then return end

    local camPos  = cam.CFrame.Position
    local vpSize  = cam.ViewportSize
    local maxDist = ESP.MaxDistance
    local myTeam  = LocalPlayer.Team

    local eBox   = ESP.Box
    local eName  = ESP.Name
    local eHP    = ESP.HealthBar
    local eDist  = ESP.Distance
    local eTrace = ESP.Tracer
    local eSkel  = ESP.Skeleton
    local eChams = ESP.Chams
    local anyOn  = eBox or eName or eHP or eDist or eTrace or eSkel or eChams

    for player, obj in next, _pool do
        local shouldDraw = false
        local parts = obj.Parts

        if anyOn and player.Parent ~= nil and parts ~= nil then
            if not (ESP.TeamCheck and player.Team and player.Team == myTeam) then
                local hum  = parts.Hum
                local root = parts.Root
                if root and root.Parent and hum and hum.Parent and hum.Health > 0 then
                    local rootPos = root.Position
                    local dist    = (camPos - rootPos).Magnitude
                    if dist <= maxDist and computeBB(cam, rootPos) then
                        shouldDraw = true

                        local hpFrac = mclamp(hum.Health / hum.MaxHealth, 0, 1)

                        -- BOX
                        if eBox then
                            local bo = obj.BoxOutline
                            bo.Position  = bb_tl - ONE_V2
                            bo.Size      = bb_sz + TWO_V2
                            bo.Color     = BLACK
                            bo.Thickness = 3
                            bo.Visible   = true

                            local bx = obj.Box
                            bx.Position = bb_tl
                            bx.Size     = bb_sz
                            bx.Color    = ESP.BoxColor
                            bx.Visible  = true
                        else
                            obj.BoxOutline.Visible = false
                            obj.Box.Visible        = false
                        end

                        -- NAME
                        if eName then
                            local n = obj.Name
                            n.Text     = player.DisplayName
                            n.Color    = ESP.NameColor
                            n.Size     = ESP.FontSize
                            n.Font     = ESP.Font
                            n.Position = V2new(bb_cx, bb_tl.Y - ESP.FontSize - 4)
                            n.Visible  = true
                        else
                            obj.Name.Visible = false
                        end

                        -- DISTANCE
                        if eDist then
                            local d = obj.Distance
                            d.Text     = mfloor(dist) .. "m"
                            d.Color    = ESP.DistanceColor
                            d.Size     = ESP.FontSize - 1
                            d.Font     = ESP.Font
                            d.Position = V2new(bb_cx, bb_tl.Y + bb_sz.Y + 2)
                            d.Visible  = true
                        else
                            obj.Distance.Visible = false
                        end

                        -- HEALTH BAR
                        if eHP then
                            local barX = bb_tl.X - 5
                            local topY = bb_tl.Y
                            local botY = bb_tl.Y + bb_sz.Y
                            local fillY = botY - bb_sz.Y * hpFrac

                            local lo = ESP.HealthLowColor
                            local hi = ESP.HealthHighColor
                            local hpCol = C3new(
                                lo.R + (hi.R - lo.R) * hpFrac,
                                lo.G + (hi.G - lo.G) * hpFrac,
                                lo.B + (hi.B - lo.B) * hpFrac
                            )

                            local bg = obj.HealthBarBG
                            bg.From    = V2new(barX, topY)
                            bg.To      = V2new(barX, botY)
                            bg.Visible = true

                            local bar = obj.HealthBar
                            bar.From    = V2new(barX, fillY)
                            bar.To      = V2new(barX, botY)
                            bar.Color   = hpCol
                            bar.Visible = true

                            local ht = obj.HealthText
                            if hpFrac < 1 then
                                ht.Text     = tostring(mfloor(hum.Health))
                                ht.Color    = hpCol
                                ht.Position = V2new(barX, fillY - ESP.FontSize + 2)
                                ht.Visible  = true
                            else
                                ht.Visible = false
                            end
                        else
                            obj.HealthBarBG.Visible = false
                            obj.HealthBar.Visible   = false
                            obj.HealthText.Visible  = false
                        end

                        -- TRACER
                        if eTrace then
                            local t = obj.Tracer
                            t.From    = V2new(vpSize.X * 0.5, vpSize.Y)
                            t.To      = V2new(bb_cx, bb_tl.Y + bb_sz.Y)
                            t.Color   = ESP.TracerColor
                            t.Visible = true
                        else
                            obj.Tracer.Visible = false
                        end

                        -- SKELETON
                        if eSkel then
                            local bp    = parts.BoneParts
                            local bc    = parts.BoneCount
                            local bones = obj.Bones
                            local sCol  = ESP.SkeletonColor
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
                                if bones[i] then
                                    bones[i].Visible = false
                                end
                            end
                        else
                            for i = 1, MAX_BONES do
                                if obj.Bones[i] then
                                    obj.Bones[i].Visible = false
                                end
                            end
                        end

                        -- CHAMS
                        if eChams then
                            local ch = obj.Chams
                            if not ch or not ch.Parent then
                                ch = Instance.new("Highlight")
                                ch.FillTransparency    = 0.5
                                ch.OutlineTransparency = 0
                                ch.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
                                pcall(function()
                                    ch.Parent = gethui()
                                end)
                                if not ch.Parent then
                                    ch.Parent = game:GetService("CoreGui")
                                end
                                obj.Chams = ch
                            end
                            ch.Adornee      = player.Character
                            ch.FillColor    = ESP.ChamsFillColor
                            ch.OutlineColor = ESP.ChamsOutlineColor
                            ch.Enabled      = true
                        else
                            if obj.Chams then
                                obj.Chams.Enabled = false
                            end
                        end
                    end
                end
            end
        end

        -- ถ้าไม่ draw → ซ่อนทุกอย่าง
        if not shouldDraw then
            hideObject(obj)
        end
    end
end

----------------------------------------------------------------
-- Bind / Unbind
----------------------------------------------------------------
local function bindPlayer(player, gen)
    if player == LocalPlayer then return end
    if not _active then return end
    if gen ~= _genID then return end
    if _pool[player] then return end

    local obj = createObject()
    _pool[player] = obj

    local conn = player.CharacterAdded:Connect(function(char)
        if not _active or gen ~= _genID then return end
        task.defer(function()
            task.wait(0.3)
            if not _active or gen ~= _genID then return end
            if not _pool[player] then return end
            obj.Parts = cacheParts(char)
        end)
    end)
    _charConns[player] = conn

    if player.Character then
        task.defer(function()
            task.wait(0.3)
            if not _active or gen ~= _genID then return end
            if not _pool[player] then return end
            obj.Parts = cacheParts(player.Character)
        end)
    end
end

----------------------------------------------------------------
-- ENABLE
----------------------------------------------------------------
function ESP:Enable()
    if _active then return end

    _active = true
    _genID  = _genID + 1
    local gen = _genID

    _pool       = {}
    _charConns  = {}
    _globalConns = {}

    for _, p in ipairs(Players:GetPlayers()) do
        bindPlayer(p, gen)
    end

    local addConn = Players.PlayerAdded:Connect(function(p)
        if _active and gen == _genID then
            bindPlayer(p, gen)
        end
    end)
    _globalConns[#_globalConns + 1] = addConn

    local remConn = Players.PlayerRemoving:Connect(function(p)
        if not _active or gen ~= _genID then return end
        if _charConns[p] then
            _charConns[p]:Disconnect()
            _charConns[p] = nil
        end
        local obj = _pool[p]
        if obj then
            destroyObject(obj)
            _pool[p] = nil
        end
    end)
    _globalConns[#_globalConns + 1] = remConn

    _renderConn = RunService.RenderStepped:Connect(renderFrame)
    _globalConns[#_globalConns + 1] = _renderConn
end

----------------------------------------------------------------
-- DISABLE  (ลบทุกอย่างออกจากหน้าจอ)
----------------------------------------------------------------
function ESP:Disable()
    if not _active then return end

    -- 1) ปิด flag ทันที → renderFrame จะ return ทันที
    _active = false
    _genID  = _genID + 1

    -- 2) ตัด render + global connections
    for i = 1, #_globalConns do
        local c = _globalConns[i]
        if c then
            pcall(function() c:Disconnect() end)
        end
    end
    _globalConns = {}
    _renderConn  = nil

    -- 3) ตัด per-player connections
    for p, c in next, _charConns do
        if c then
            pcall(function() c:Disconnect() end)
        end
    end
    _charConns = {}

    -- 4) เก็บ player list ก่อน (ไม่แก้ table ระหว่าง iterate)
    local playerList = {}
    for p in next, _pool do
        playerList[#playerList + 1] = p
    end

    -- 5) ทำลาย Drawing ทุกชิ้นของทุกคน
    for i = 1, #playerList do
        local p   = playerList[i]
        local obj = _pool[p]
        if obj then
            destroyObject(obj)
        end
        _pool[p] = nil
    end

    _pool = {}
end

return ESP
