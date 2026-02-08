local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------------
-- Math / Constructor cache
----------------------------------------------------------------
local V2new  = Vector2.new
local V3new  = Vector3.new
local C3new  = Color3.new
local C3rgb  = Color3.fromRGB
local mfloor = math.floor
local mabs   = math.abs
local mclamp = math.clamp

----------------------------------------------------------------
-- Module Table
----------------------------------------------------------------
local ESP = {}

-- Feature toggles (set true/false ก่อนหรือหลัง Enable ก็ได้)
ESP.Box       = false
ESP.Name      = false
ESP.HealthBar = false
ESP.Distance  = false
ESP.Tracer    = false
ESP.Skeleton  = false
ESP.Chams     = false

-- Settings
ESP.TeamCheck   = false
ESP.MaxDistance  = 2000
ESP.Font        = Drawing.Fonts.Plex
ESP.FontSize    = 13

-- Colors
ESP.BoxColor        = C3rgb(255, 255, 255)
ESP.NameColor       = C3rgb(255, 255, 255)
ESP.DistanceColor   = C3rgb(200, 200, 200)
ESP.TracerColor     = C3rgb(255, 255, 255)
ESP.SkeletonColor   = C3rgb(255, 255, 255)
ESP.HealthHighColor = C3rgb(0, 255, 0)
ESP.HealthLowColor  = C3rgb(255, 0, 0)
ESP.ChamsFillColor    = C3rgb(255, 0, 0)
ESP.ChamsOutlineColor = C3rgb(255, 255, 255)

----------------------------------------------------------------
-- Constants
----------------------------------------------------------------
local BLACK   = C3new(0, 0, 0)
local ONE_V2  = V2new(1, 1)
local TWO_V2  = V2new(2, 2)

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
    {"Torso","Left Arm"},  {"Torso","Right Arm"},
    {"Torso","Left Leg"},  {"Torso","Right Leg"},
}

local MAX_BONES = #BonesR15

----------------------------------------------------------------
-- Internal State  (ทุกอย่างอยู่ใน _state, Disable ล้างหมด)
----------------------------------------------------------------
local _state = nil   -- nil = ไม่ได้ Enable อยู่

----------------------------------------------------------------
-- Drawing Factory
----------------------------------------------------------------
local function mkLine(thick, col)
    local d = Drawing.new("Line")
    d.Visible      = false
    d.Thickness    = thick or 1
    d.Color        = col or C3new(1, 1, 1)
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
    d.Color        = col or C3new(1, 1, 1)
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
-- Drawing keys สำหรับ loop
----------------------------------------------------------------
local DRAW_KEYS = {
    "BoxOutline", "Box",
    "Name", "Distance",
    "HealthBarBG", "HealthBar", "HealthText",
    "Tracer",
}

----------------------------------------------------------------
-- Per-player object create / hide / destroy
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
        Bones       = table.create(MAX_BONES),
        Chams       = nil,
        Parts       = nil,   -- cached character parts
    }
    for i = 1, MAX_BONES do
        o.Bones[i] = mkLine(1.5)
    end
    return o
end

local function hideObject(o)
    for i = 1, #DRAW_KEYS do
        o[DRAW_KEYS[i]].Visible = false
    end
    for i = 1, MAX_BONES do
        o.Bones[i].Visible = false
    end
    if o.Chams then
        o.Chams.Enabled = false
    end
end

local function destroyObject(o)
    for i = 1, #DRAW_KEYS do
        local d = o[DRAW_KEYS[i]]
        d.Visible = false
        d:Remove()
    end
    for i = 1, MAX_BONES do
        local b = o.Bones[i]
        b.Visible = false
        b:Remove()
    end
    if o.Chams then
        o.Chams.Enabled = false
        o.Chams:Destroy()
        o.Chams = nil
    end
end

----------------------------------------------------------------
-- Cache character parts
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

    local boneParts = table.create(boneCount)
    for i = 1, boneCount do
        local a = char:FindFirstChild(bonesDef[i][1])
        local b = char:FindFirstChild(bonesDef[i][2])
        boneParts[i] = (a and b) and {a, b} or false
    end

    return {
        Hum       = hum,
        Root      = root,
        Head      = head,
        BoneCount = boneCount,
        BoneParts = boneParts,
    }
end

----------------------------------------------------------------
-- Bounding-box computation (returns values via upvalues)
----------------------------------------------------------------
local bb_tl, bb_sz, bb_cx

local function computeBB(camera, rootPos)
    local _, on = camera:WorldToViewportPoint(rootPos)
    if not on then return false end

    local vTop = camera:WorldToViewportPoint(rootPos + V3new(0, 3.25, 0))
    local vBot = camera:WorldToViewportPoint(rootPos - V3new(0, 2.75, 0))
    if vTop.Z < 1 then return false end

    local h  = mabs(vBot.Y - vTop.Y)
    local w  = h * 0.55
    bb_cx = (vTop.X + vBot.X) * 0.5
    bb_tl = V2new(bb_cx - w * 0.5, vTop.Y)
    bb_sz = V2new(w, h)
    return true
end

----------------------------------------------------------------
-- Render loop
----------------------------------------------------------------
local function renderFrame()
    local s = _state
    if not s then return end

    local camera = workspace.CurrentCamera
    if not camera then return end

    local camPos  = camera.CFrame.Position
    local vpSize  = camera.ViewportSize
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

    for player, obj in next, s.pool do
        -- ตรวจว่าควร skip หรือไม่
        local parts = obj.Parts
        local skip  = (not anyOn)
                   or (player.Parent == nil)
                   or (ESP.TeamCheck and player.Team and player.Team == myTeam)
                   or (parts == nil)

        if not skip then
            local hum, root = parts.Hum, parts.Root
            if (not root.Parent) or (not hum.Parent) or hum.Health <= 0 then
                skip = true
            end
        end

        if not skip then
            local rootPos = parts.Root.Position
            local dist    = (camPos - rootPos).Magnitude

            if dist > maxDist or not computeBB(camera, rootPos) then
                skip = true
            end
        end

        if skip then
            hideObject(obj)
            continue
        end

        -- ===== Draw =====
        local parts  = obj.Parts
        local hum    = parts.Hum
        local hpFrac = mclamp(hum.Health / hum.MaxHealth, 0, 1)
        local dist   = (camPos - parts.Root.Position).Magnitude

        -- Box
        if eBox then
            local bo, bx = obj.BoxOutline, obj.Box
            bo.Position  = bb_tl - ONE_V2
            bo.Size      = bb_sz + TWO_V2
            bo.Color     = BLACK
            bo.Thickness = 3
            bo.Visible   = true

            bx.Position = bb_tl
            bx.Size     = bb_sz
            bx.Color    = ESP.BoxColor
            bx.Visible  = true
        else
            obj.BoxOutline.Visible = false
            obj.Box.Visible        = false
        end

        -- Name
        if eName then
            local n = obj.Name
            n.Text     = player.DisplayName
            n.Color    = ESP.NameColor
            n.Size     = ESP.FontSize
            n.Position = V2new(bb_cx, bb_tl.Y - ESP.FontSize - 4)
            n.Visible  = true
        else
            obj.Name.Visible = false
        end

        -- Distance
        if eDist then
            local d = obj.Distance
            d.Text     = mfloor(dist) .. "m"
            d.Color    = ESP.DistanceColor
            d.Position = V2new(bb_cx, bb_tl.Y + bb_sz.Y + 2)
            d.Visible  = true
        else
            obj.Distance.Visible = false
        end

        -- Health Bar
        if eHP then
            local barX = bb_tl.X - 5
            local topY = bb_tl.Y
            local botY = bb_tl.Y + bb_sz.Y
            local fillY = botY - bb_sz.Y * hpFrac

            local lo, hi = ESP.HealthLowColor, ESP.HealthHighColor
            local hpCol  = C3new(
                lo.R + (hi.R - lo.R) * hpFrac,
                lo.G + (hi.G - lo.G) * hpFrac,
                lo.B + (hi.B - lo.B) * hpFrac
            )

            local bg  = obj.HealthBarBG
            bg.From    = V2new(barX, topY)
            bg.To      = V2new(barX, botY)
            bg.Visible = true

            local bar  = obj.HealthBar
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
            obj.HealthBarBG.Visible  = false
            obj.HealthBar.Visible    = false
            obj.HealthText.Visible   = false
        end

        -- Tracer
        if eTrace then
            local t  = obj.Tracer
            t.From    = V2new(vpSize.X * 0.5, vpSize.Y)
            t.To      = V2new(bb_cx, bb_tl.Y + bb_sz.Y)
            t.Color   = ESP.TracerColor
            t.Visible = true
        else
            obj.Tracer.Visible = false
        end

        -- Skeleton
        if eSkel then
            local bp      = parts.BoneParts
            local bc      = parts.BoneCount
            local bones   = obj.Bones
            local skelCol = ESP.SkeletonColor
            for i = 1, bc do
                local line = bones[i]
                local pair = bp[i]
                if pair then
                    local vA, onA = camera:WorldToViewportPoint(pair[1].Position)
                    local vB, onB = camera:WorldToViewportPoint(pair[2].Position)
                    if onA and onB then
                        line.From    = V2new(vA.X, vA.Y)
                        line.To      = V2new(vB.X, vB.Y)
                        line.Color   = skelCol
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end
            for i = bc + 1, MAX_BONES do
                bones[i].Visible = false
            end
        else
            for i = 1, MAX_BONES do
                obj.Bones[i].Visible = false
            end
        end

        -- Chams
        if eChams then
            local ch = obj.Chams
            if not ch or not ch.Parent then
                ch = Instance.new("Highlight")
                ch.FillTransparency    = 0.5
                ch.OutlineTransparency = 0
                ch.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
                ch.Parent              = gethui()
                obj.Chams = ch
            end
            ch.Adornee      = player.Character
            ch.FillColor    = ESP.ChamsFillColor
            ch.OutlineColor = ESP.ChamsOutlineColor
            ch.Enabled      = true
        elseif obj.Chams then
            obj.Chams.Enabled = false
        end
    end
end

----------------------------------------------------------------
-- Bind / Unbind players
----------------------------------------------------------------
local function onCharacterAdded(s, player, obj, char)
    task.defer(function()
        task.wait(0.3)
        if not (_state and _state == s) then return end
        if not s.pool[player] then return end
        obj.Parts = cacheParts(char)
    end)
end

local function bindPlayer(s, player)
    if player == LocalPlayer then return end
    if s.pool[player] then return end

    local obj = createObject()
    s.pool[player] = obj

    s.conns[player] = player.CharacterAdded:Connect(function(char)
        onCharacterAdded(s, player, obj, char)
    end)

    if player.Character then
        onCharacterAdded(s, player, obj, player.Character)
    end
end

local function unbindPlayer(s, player)
    if s.conns[player] then
        s.conns[player]:Disconnect()
        s.conns[player] = nil
    end
    local obj = s.pool[player]
    if obj then
        destroyObject(obj)
        s.pool[player] = nil
    end
end

----------------------------------------------------------------
-- PUBLIC API:  Enable / Disable
----------------------------------------------------------------
function ESP:Enable()
    -- ถ้า Enable อยู่แล้ว ไม่ทำซ้ำ
    if _state then return end

    local s = {
        pool  = {},   -- [Player] = drawingObject
        conns = {},   -- [Player] = CharacterAdded connection
        renderConn  = nil,
        addedConn   = nil,
        removedConn = nil,
    }
    _state = s

    -- Bind ผู้เล่นที่มีอยู่
    for _, player in ipairs(Players:GetPlayers()) do
        bindPlayer(s, player)
    end

    -- Bind ผู้เล่นใหม่
    s.addedConn = Players.PlayerAdded:Connect(function(player)
        if _state == s then bindPlayer(s, player) end
    end)

    -- Unbind ผู้เล่นที่ออก
    s.removedConn = Players.PlayerRemoving:Connect(function(player)
        if _state == s then unbindPlayer(s, player) end
    end)

    -- Start render
    s.renderConn = RunService.RenderStepped:Connect(renderFrame)
end

function ESP:Disable()
    local s = _state
    if not s then return end

    -- 1) หยุด render ทันที
    if s.renderConn then
        s.renderConn:Disconnect()
        s.renderConn = nil
    end

    -- 2) ตัด global connections
    if s.addedConn then
        s.addedConn:Disconnect()
        s.addedConn = nil
    end
    if s.removedConn then
        s.removedConn:Disconnect()
        s.removedConn = nil
    end

    -- 3) ตัด per-player connections
    for player, conn in next, s.conns do
        conn:Disconnect()
        s.conns[player] = nil
    end

    -- 4) ทำลาย Drawing + Chams ทุกชิ้น
    for player, obj in next, s.pool do
        destroyObject(obj)
        s.pool[player] = nil
    end

    -- 5) ล้าง state
    _state = nil
end

return ESP
