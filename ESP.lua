--// ESP Module (Optimized)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

--// Localize hot globals
local V2new = Vector2.new
local V3new = Vector3.new
local C3new = Color3.new
local C3rgb = Color3.fromRGB
local mfloor = math.floor
local mabs = math.abs
local mclamp = math.clamp
local tostring = tostring
local ipairs = ipairs
local next = next

local ESP = {}

--// Settings & Colors (direct access, no nesting overhead)
ESP.TeamCheck = false
ESP.MaxDistance = 2000
ESP.Font = Drawing.Fonts.Plex
ESP.FontSize = 13

local Enabled = { Box=false, Name=false, HealthBar=false, Distance=false, Tracer=false, Skeleton=false, Chams=false }
local Colors = {
    Box=C3rgb(255,255,255), Name=C3rgb(255,255,255), Distance=C3rgb(200,200,200),
    Tracer=C3rgb(255,255,255), Skeleton=C3rgb(255,255,255),
    HealthHigh=C3rgb(0,255,0), HealthLow=C3rgb(255,0,0),
    ChamsFill=C3rgb(255,0,0), ChamsOutline=C3rgb(255,255,255),
}

local BLACK = C3new(0,0,0)
local ONE_V2 = V2new(1,1)
local TWO_V2 = V2new(2,2)

----------------------------------------------------------------
-- Skeleton Bone Maps (frozen)
----------------------------------------------------------------
local BonesR15 = {
    {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"},
}
local BonesR6 = {
    {"Head","Torso"}, {"Torso","Left Arm"}, {"Torso","Right Arm"},
    {"Torso","Left Leg"}, {"Torso","Right Leg"},
}
local MAX_BONES = #BonesR15

----------------------------------------------------------------
-- Drawing Factory (minimal property sets)
----------------------------------------------------------------
local function mkLine(thick, col)
    local d = Drawing.new("Line")
    d.Visible, d.Thickness, d.Color, d.Transparency = false, thick or 1, col or C3new(1,1,1), 1
    return d
end

local function mkText(size, col)
    local d = Drawing.new("Text")
    d.Visible, d.Center, d.Outline, d.OutlineColor = false, true, true, BLACK
    d.Size, d.Font, d.Color, d.Transparency = size or ESP.FontSize, ESP.Font, col or C3new(1,1,1), 1
    return d
end

local function mkSquare()
    local d = Drawing.new("Square")
    d.Visible, d.Filled, d.Thickness, d.Transparency = false, false, 1, 1
    return d
end

----------------------------------------------------------------
-- Per-Player ESP Object
----------------------------------------------------------------
local Pool = {}    -- [Player] = esp data
local Conns = {}   -- [Player] = connection

-- Flat list of all drawing keys for fast hide/remove
local DRAW_KEYS = {"BoxOutline","Box","Name","Distance","HealthBarBG","HealthBar","HealthText","Tracer"}

local function createObj()
    local o = {
        BoxOutline = mkSquare(), Box = mkSquare(),
        Name = mkText(ESP.FontSize, Colors.Name),
        Distance = mkText(ESP.FontSize - 1, Colors.Distance),
        HealthBarBG = mkLine(4, BLACK), HealthBar = mkLine(2), HealthText = mkText(ESP.FontSize - 2),
        Tracer = mkLine(1, Colors.Tracer),
        Bones = table.create(MAX_BONES),
        Chams = nil,
        -- Part cache (ลด FindFirstChild ทุก frame)
        _parts = nil, -- populated on char load
    }
    for i = 1, MAX_BONES do
        o.Bones[i] = mkLine(1.5, Colors.Skeleton)
    end
    return o
end

local function hideObj(o)
    -- Drawing keys (ไม่มี pcall, ไม่มี type check)
    for i = 1, #DRAW_KEYS do
        o[DRAW_KEYS[i]].Visible = false
    end
    local bones = o.Bones
    for i = 1, MAX_BONES do
        bones[i].Visible = false
    end
    if o.Chams then o.Chams.Enabled = false end
end

local function destroyObj(o)
    for i = 1, #DRAW_KEYS do
        local d = o[DRAW_KEYS[i]]
        d.Visible = false          -- ★ ซ่อนก่อน
        d:Remove()
    end
    for i = 1, MAX_BONES do
        o.Bones[i].Visible = false -- ★ ซ่อนก่อน
        o.Bones[i]:Remove()
    end
    if o.Chams then
        o.Chams.Enabled = false    -- ★ ซ่อนก่อน
        o.Chams:Destroy()
        o.Chams = nil
    end
end

-- Cache character parts เมื่อ spawn (ไม่ต้อง FindFirstChild ทุก frame)
local function cacheParts(char)
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not (hum and root and head) then return nil end

    local isR15 = hum.RigType == Enum.HumanoidRigType.R15
    local bones = isR15 and BonesR15 or BonesR6
    local boneCount = #bones

    -- Pre-resolve all bone parts
    local boneParts = table.create(boneCount)
    for i = 1, boneCount do
        local b = bones[i]
        local a, bPart = char:FindFirstChild(b[1]), char:FindFirstChild(b[2])
        boneParts[i] = (a and bPart) and {a, bPart} or false
    end

    return {
        Hum = hum, Root = root, Head = head,
        IsR15 = isR15, BoneCount = boneCount, BoneParts = boneParts,
    }
end

----------------------------------------------------------------
-- Core Update (hot path — ทุกอย่าง inline/localized)
----------------------------------------------------------------
local Camera -- refreshed per frame

local bb_tl, bb_sz, bb_top, bb_bot, bb_cx, bb_cy -- reused bounding box vars (no table alloc)

local function computeBB(rootPos)
    local v, on = Camera:WorldToViewportPoint(rootPos)
    if not on or v.Z < 1 then return false end

    local vTop, _ = Camera:WorldToViewportPoint(rootPos + V3new(0, 3.25, 0))
    local vBot, _ = Camera:WorldToViewportPoint(rootPos - V3new(0, 2.75, 0))

    local h = mabs(vBot.Y - vTop.Y)
    local w = h * 0.55
    bb_cx = (vTop.X + vBot.X) * 0.5
    bb_cy = (vTop.Y + vBot.Y) * 0.5
    bb_tl = V2new(bb_cx - w * 0.5, vTop.Y)
    bb_sz = V2new(w, h)
    bb_top = V2new(vTop.X, vTop.Y)
    bb_bot = V2new(vBot.X, vBot.Y)
    return true
end

local function updateESP()
    Camera = workspace.CurrentCamera
    if not Camera then return end

    local camPos = Camera.CFrame.Position
    local vpSize = Camera.ViewportSize
    local maxDist = ESP.MaxDistance
    local teamCheck = ESP.TeamCheck
    local myTeam = LocalPlayer.Team

    local eBox, eName, eHP, eDist, eTracer, eSkel, eChams =
        Enabled.Box, Enabled.Name, Enabled.HealthBar,
        Enabled.Distance, Enabled.Tracer, Enabled.Skeleton, Enabled.Chams

    local anyEnabled = eBox or eName or eHP or eDist or eTracer or eSkel or eChams

    for player, obj in next, Pool do
        -- Early exit chain (single branch path)
        local parts = obj._parts
        local skip = not anyEnabled
            or player.Parent == nil
            or (teamCheck and player.Team and player.Team == myTeam)
            or parts == nil

        if not skip then
            local hum, root = parts.Hum, parts.Root
            skip = (not root.Parent) or (not hum.Parent) or hum.Health <= 0
        end

        if not skip then
            local rootPos = parts.Root.Position
            local dist = (camPos - rootPos).Magnitude
            skip = dist > maxDist or not computeBB(rootPos)

            if not skip then
                local hum = parts.Hum
                local hpFrac = mclamp(hum.Health / hum.MaxHealth, 0, 1)

                -- Box
                if eBox then
                    local bo, bx = obj.BoxOutline, obj.Box
                    bo.Visible, bo.Position, bo.Size, bo.Color, bo.Thickness = true, bb_tl - ONE_V2, bb_sz + TWO_V2, BLACK, 3
                    bx.Visible, bx.Position, bx.Size, bx.Color = true, bb_tl, bb_sz, Colors.Box
                else
                    obj.BoxOutline.Visible, obj.Box.Visible = false, false
                end

                -- Name
                if eName then
                    local n = obj.Name
                    n.Visible, n.Text, n.Color = true, player.DisplayName, Colors.Name
                    n.Position = V2new(bb_cx, bb_tl.Y - ESP.FontSize - 4)
                else
                    obj.Name.Visible = false
                end

                -- Distance
                if eDist then
                    local d = obj.Distance
                    d.Visible, d.Color = true, Colors.Distance
                    d.Position = V2new(bb_cx, bb_tl.Y + bb_sz.Y + 2)
                    d.Text = mfloor(dist) .. "m"
                else
                    obj.Distance.Visible = false
                end

                -- HealthBar
                if eHP then
                    local barX = bb_tl.X - 5
                    local topY, botY = bb_tl.Y, bb_tl.Y + bb_sz.Y
                    local filledY = botY - bb_sz.Y * hpFrac
                    local hpCol = C3new(
                        Colors.HealthLow.R + (Colors.HealthHigh.R - Colors.HealthLow.R) * hpFrac,
                        Colors.HealthLow.G + (Colors.HealthHigh.G - Colors.HealthLow.G) * hpFrac,
                        Colors.HealthLow.B + (Colors.HealthHigh.B - Colors.HealthLow.B) * hpFrac
                    )

                    local bg, bar = obj.HealthBarBG, obj.HealthBar
                    bg.Visible, bg.From, bg.To = true, V2new(barX, topY), V2new(barX, botY)
                    bar.Visible, bar.From, bar.To, bar.Color = true, V2new(barX, filledY), V2new(barX, botY), hpCol

                    local ht = obj.HealthText
                    if hpFrac < 1 then
                        ht.Visible, ht.Color = true, hpCol
                        ht.Position = V2new(barX, filledY - ESP.FontSize + 2)
                        ht.Text = tostring(mfloor(hum.Health))
                    else
                        ht.Visible = false
                    end
                else
                    obj.HealthBarBG.Visible, obj.HealthBar.Visible, obj.HealthText.Visible = false, false, false
                end

                -- Tracer
                if eTracer then
                    local t = obj.Tracer
                    t.Visible, t.Color = true, Colors.Tracer
                    t.From = V2new(vpSize.X * 0.5, vpSize.Y)
                    t.To = V2new(bb_cx, bb_tl.Y + bb_sz.Y)
                else
                    obj.Tracer.Visible = false
                end

                -- Skeleton
                if eSkel then
                    local bp = parts.BoneParts
                    local bc = parts.BoneCount
                    local bones = obj.Bones
                    local skelCol = Colors.Skeleton

                    for i = 1, bc do
                        local line = bones[i]
                        local pair = bp[i]
                        if pair then
                            local vA, onA = Camera:WorldToViewportPoint(pair[1].Position)
                            local vB, onB = Camera:WorldToViewportPoint(pair[2].Position)
                            if onA and onB then
                                line.From = V2new(vA.X, vA.Y)
                                line.To = V2new(vB.X, vB.Y)
                                line.Color = skelCol
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
                    local bones = obj.Bones
                    for i = 1, MAX_BONES do bones[i].Visible = false end
                end

                -- Chams
                if eChams then
                    local ch = obj.Chams
                    if not ch or not ch.Parent then
                        ch = Instance.new("Highlight")
                        ch.FillTransparency, ch.OutlineTransparency = 0.5, 0
                        ch.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        ch.Parent = gethui()
                        obj.Chams = ch
                    end
                    ch.Adornee = player.Character
                    ch.FillColor, ch.OutlineColor, ch.Enabled = Colors.ChamsFill, Colors.ChamsOutline, true
                elseif obj.Chams then
                    obj.Chams.Enabled = false
                end

                continue -- skip hideAll
            end
        end

        -- ถ้าถึงตรงนี้ = skip
        hideObj(obj)
    end
end

----------------------------------------------------------------
-- Player lifecycle
----------------------------------------------------------------
local function bindPlayer(player)
    if player == LocalPlayer then return end
    local obj = createObj()
    Pool[player] = obj

    local function onChar(char)
        task.defer(function()
            task.wait(0.3)
            if not Pool[player] then return end
            obj._parts = cacheParts(char)
        end)
    end

    Conns[player] = player.CharacterAdded:Connect(onChar)
    if player.Character then onChar(player.Character) end
end

local function unbindPlayer(player)
    if Conns[player] then Conns[player]:Disconnect(); Conns[player] = nil end
    local obj = Pool[player]
    if obj then destroyObj(obj); Pool[player] = nil end
end

----------------------------------------------------------------
-- Toggle API (generated, zero boilerplate)
----------------------------------------------------------------
local function makeToggle(key)
    return setmetatable({}, {__index = {
        Enable  = function() Enabled[key] = true end,
        Disable = function() Enabled[key] = false end,
        Toggle  = function() Enabled[key] = not Enabled[key] end,
        IsEnabled = function() return Enabled[key] end,
        SetColor = function(_, c) Colors[key] = c end,
    }})
end

ESP.box       = makeToggle("Box")
ESP.name      = makeToggle("Name")
ESP.healthbar = makeToggle("HealthBar")
ESP.distance  = makeToggle("Distance")
ESP.tracer    = makeToggle("Tracer")
ESP.skeleton  = makeToggle("Skeleton")
ESP.chams     = makeToggle("Chams")

function ESP.chams:SetFillColor(c)     Colors.ChamsFill = c end
function ESP.chams:SetOutlineColor(c)  Colors.ChamsOutline = c end
function ESP.healthbar:SetHighColor(c) Colors.HealthHigh = c end
function ESP.healthbar:SetLowColor(c)  Colors.HealthLow = c end

----------------------------------------------------------------
-- Master controls
----------------------------------------------------------------
local renderConn

function ESP:Start()
    if renderConn then return end
    for _, p in ipairs(Players:GetPlayers()) do bindPlayer(p) end
    Conns._add = Players.PlayerAdded:Connect(bindPlayer)
    Conns._rem = Players.PlayerRemoving:Connect(unbindPlayer)
    renderConn = RunService.RenderStepped:Connect(updateESP)
end

function ESP:Stop()
    if renderConn then renderConn:Disconnect(); renderConn = nil end
    for k, c in next, Conns do c:Disconnect(); Conns[k] = nil end

    -- ★ collect ก่อน iterate เพื่อไม่แก้ table ระหว่าง loop
    local players = {}
    for p in next, Pool do players[#players + 1] = p end
    for _, p in ipairs(players) do
        unbindPlayer(p)
    end
end

function ESP:EnableAll()  for k in next, Enabled do Enabled[k] = true end end
function ESP:DisableAll() for k in next, Enabled do Enabled[k] = false end for _, obj in next, Pool do hideObj(obj) end end
function ESP:SetMaxDistance(d) ESP.MaxDistance = d end
function ESP:SetTeamCheck(v) ESP.TeamCheck = v end

return ESP
