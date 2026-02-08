--// ESP Module
--// ใช้กับ executor ที่รองรับ Drawing API + Instance API

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local ESP = {}
ESP.__index = ESP

--// Settings
ESP.Settings = {
    TeamCheck = false,
    MaxDistance = 2000,
    Font = Drawing.Fonts.Plex, -- or UI, System, Monospace
    FontSize = 13,
    OutlineColor = Color3.new(0, 0, 0),
}

--// Storage
local Objects = {} -- [Player] = { drawings/instances }
local Connections = {}
local Enabled = {
    Box = false,
    Name = false,
    HealthBar = false,
    Distance = false,
    Tracer = false,
    Skeleton = false,
    Chams = false,
}

local Colors = {
    Box = Color3.fromRGB(255, 255, 255),
    Name = Color3.fromRGB(255, 255, 255),
    HealthHigh = Color3.fromRGB(0, 255, 0),
    HealthLow = Color3.fromRGB(255, 0, 0),
    Distance = Color3.fromRGB(200, 200, 200),
    Tracer = Color3.fromRGB(255, 255, 255),
    Skeleton = Color3.fromRGB(255, 255, 255),
    ChamsFill = Color3.fromRGB(255, 0, 0),
    ChamsOutline = Color3.fromRGB(255, 255, 255),
}

----------------------------------------------------------------
-- Utilities
----------------------------------------------------------------
local function isAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    return hum and root and hum.Health > 0
end

local function isTeammate(player)
    if not ESP.Settings.TeamCheck then return false end
    return player.Team and player.Team == LocalPlayer.Team
end

local function worldToScreen(pos)
    local vec, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(vec.X, vec.Y), onScreen, vec.Z
end

local function lerpColor(c1, c2, t)
    return Color3.new(
        c1.R + (c2.R - c1.R) * t,
        c1.G + (c2.G - c1.G) * t,
        c1.B + (c2.B - c1.B) * t
    )
end

----------------------------------------------------------------
-- Drawing Helpers
----------------------------------------------------------------
local function newLine(props)
    local l = Drawing.new("Line")
    l.Visible = false
    l.Thickness = props.Thickness or 1
    l.Color = props.Color or Color3.new(1,1,1)
    l.Transparency = 1
    return l
end

local function newText(props)
    local t = Drawing.new("Text")
    t.Visible = false
    t.Center = true
    t.Outline = true
    t.OutlineColor = ESP.Settings.OutlineColor
    t.Size = props.Size or ESP.Settings.FontSize
    t.Font = props.Font or ESP.Settings.Font
    t.Color = props.Color or Color3.new(1,1,1)
    t.Transparency = 1
    return t
end

local function newSquare()
    local s = Drawing.new("Square")
    s.Visible = false
    s.Filled = false
    s.Thickness = 1
    s.Transparency = 1
    return s
end

----------------------------------------------------------------
-- Skeleton Joint Map
----------------------------------------------------------------
local SkeletonPairs = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    -- Arms
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    -- Legs
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

-- R6 fallback
local SkeletonPairsR6 = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"},
}

----------------------------------------------------------------
-- Create / Remove per player
----------------------------------------------------------------
local function createESP(player)
    if Objects[player] then return end

    local obj = {
        -- Box
        BoxOutline = newSquare(),
        Box = newSquare(),
        -- Name
        Name = newText({ Color = Colors.Name }),
        -- Distance
        Distance = newText({ Color = Colors.Distance, Size = ESP.Settings.FontSize - 1 }),
        -- Health bar (line-based)
        HealthBarBG = newLine({ Thickness = 4, Color = Color3.new(0,0,0) }),
        HealthBar = newLine({ Thickness = 2 }),
        HealthText = newText({ Size = ESP.Settings.FontSize - 2 }),
        -- Tracer
        Tracer = newLine({ Thickness = 1, Color = Colors.Tracer }),
        -- Skeleton lines
        SkeletonLines = {},
        -- Chams (Highlight instance)
        Chams = nil,
    }

    -- สร้าง skeleton lines
    for i = 1, #SkeletonPairs do
        obj.SkeletonLines[i] = newLine({ Thickness = 1.5, Color = Colors.Skeleton })
    end

    Objects[player] = obj
end

local function removeESP(player)
    local obj = Objects[player]
    if not obj then return end

    -- Remove drawings
    for k, v in pairs(obj) do
        if typeof(v) == "table" and k == "SkeletonLines" then
            for _, line in ipairs(v) do
                line:Remove()
            end
        elseif type(v) ~= "nil" and type(v) ~= "boolean" then
            if typeof(v) == "Instance" then
                v:Destroy()
            elseif type(v) == "userdata" and v.Remove then
                pcall(v.Remove, v)
            end
        end
    end

    Objects[player] = nil
end

local function hideAll(obj)
    for k, v in pairs(obj) do
        if k == "SkeletonLines" then
            for _, line in ipairs(v) do
                line.Visible = false
            end
        elseif k == "Chams" then
            if v then v.Enabled = false end
        elseif type(v) == "userdata" and pcall(function() return v.Visible end) then
            v.Visible = false
        end
    end
end

----------------------------------------------------------------
-- Bounding Box from Character
----------------------------------------------------------------
local function getBoundingBox(character, rootPos)
    local rootScreenPos, onScreen, depth = worldToScreen(rootPos)
    if not onScreen or depth < 1 then return nil end

    -- ประมาณขนาด box จาก depth + humanoid
    local hum = character:FindFirstChildOfClass("Humanoid")
    local hipHeight = hum and hum.HipHeight or 2
    local bodyHeight = 5.5 -- ประมาณสำหรับ R15 (head to foot)

    local topPos = worldToScreen(rootPos + Vector3.new(0, bodyHeight / 2 + 0.5, 0))
    local botPos = worldToScreen(rootPos - Vector3.new(0, bodyHeight / 2, 0))

    local height = math.abs(botPos.Y - topPos.Y)
    local width = height * 0.55

    local center = Vector2.new((topPos.X + botPos.X) / 2, (topPos.Y + botPos.Y) / 2)

    return {
        TopLeft = Vector2.new(center.X - width / 2, topPos.Y),
        Size = Vector2.new(width, height),
        Top = topPos,
        Bottom = botPos,
        Center = center,
        OnScreen = true,
    }
end

----------------------------------------------------------------
-- Update Loop
----------------------------------------------------------------
local function updateESP()
    for player, obj in pairs(Objects) do
        if player == LocalPlayer or not player.Parent then
            hideAll(obj)
            continue
        end

        if isTeammate(player) then
            hideAll(obj)
            continue
        end

        if not isAlive(player) then
            hideAll(obj)
            continue
        end

        local character = player.Character
        local root = character:FindFirstChild("HumanoidRootPart")
        local hum = character:FindFirstChildOfClass("Humanoid")
        local head = character:FindFirstChild("Head")

        if not root or not hum or not head then
            hideAll(obj)
            continue
        end

        local rootPos = root.Position
        local dist = (Camera.CFrame.Position - rootPos).Magnitude

        if dist > ESP.Settings.MaxDistance then
            hideAll(obj)
            continue
        end

        local bb = getBoundingBox(character, rootPos)
        if not bb then
            hideAll(obj)
            continue
        end

        local healthFrac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)

        -------------------------
        -- Box
        -------------------------
        if Enabled.Box then
            obj.BoxOutline.Visible = true
            obj.BoxOutline.Position = bb.TopLeft - Vector2.new(1, 1)
            obj.BoxOutline.Size = bb.Size + Vector2.new(2, 2)
            obj.BoxOutline.Color = Color3.new(0, 0, 0)
            obj.BoxOutline.Thickness = 3

            obj.Box.Visible = true
            obj.Box.Position = bb.TopLeft
            obj.Box.Size = bb.Size
            obj.Box.Color = Colors.Box
            obj.Box.Thickness = 1
        else
            obj.Box.Visible = false
            obj.BoxOutline.Visible = false
        end

        -------------------------
        -- Name
        -------------------------
        if Enabled.Name then
            obj.Name.Visible = true
            obj.Name.Position = Vector2.new(bb.Center.X, bb.TopLeft.Y - ESP.Settings.FontSize - 4)
            obj.Name.Text = player.DisplayName
            obj.Name.Color = Colors.Name
        else
            obj.Name.Visible = false
        end

        -------------------------
        -- Distance
        -------------------------
        if Enabled.Distance then
            obj.Distance.Visible = true
            local offsetY = 2
            obj.Distance.Position = Vector2.new(bb.Center.X, bb.TopLeft.Y + bb.Size.Y + offsetY)
            obj.Distance.Text = string.format("[%dm]", math.floor(dist))
            obj.Distance.Color = Colors.Distance
        else
            obj.Distance.Visible = false
        end

        -------------------------
        -- Health Bar (left side)
        -------------------------
        if Enabled.HealthBar then
            local barX = bb.TopLeft.X - 5
            local topY = bb.TopLeft.Y
            local botY = topY + bb.Size.Y
            local filledY = botY - (bb.Size.Y * healthFrac)

            obj.HealthBarBG.Visible = true
            obj.HealthBarBG.From = Vector2.new(barX, topY)
            obj.HealthBarBG.To = Vector2.new(barX, botY)

            obj.HealthBar.Visible = true
            obj.HealthBar.From = Vector2.new(barX, filledY)
            obj.HealthBar.To = Vector2.new(barX, botY)
            obj.HealthBar.Color = lerpColor(Colors.HealthLow, Colors.HealthHigh, healthFrac)

            if healthFrac < 1 then
                obj.HealthText.Visible = true
                obj.HealthText.Position = Vector2.new(barX, filledY - ESP.Settings.FontSize + 2)
                obj.HealthText.Text = tostring(math.floor(hum.Health))
                obj.HealthText.Color = obj.HealthBar.Color
            else
                obj.HealthText.Visible = false
            end
        else
            obj.HealthBarBG.Visible = false
            obj.HealthBar.Visible = false
            obj.HealthText.Visible = false
        end

        -------------------------
        -- Tracer
        -------------------------
        if Enabled.Tracer then
            local viewportSize = Camera.ViewportSize
            obj.Tracer.Visible = true
            obj.Tracer.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
            obj.Tracer.To = Vector2.new(bb.Center.X, bb.TopLeft.Y + bb.Size.Y)
            obj.Tracer.Color = Colors.Tracer
        else
            obj.Tracer.Visible = false
        end

        -------------------------
        -- Skeleton
        -------------------------
        if Enabled.Skeleton then
            local isR15 = hum.RigType == Enum.HumanoidRigType.R15
            local pairs_ = isR15 and SkeletonPairs or SkeletonPairsR6

            for i, pair in ipairs(pairs_) do
                local line = obj.SkeletonLines[i]
                if not line then
                    obj.SkeletonLines[i] = newLine({ Thickness = 1.5, Color = Colors.Skeleton })
                    line = obj.SkeletonLines[i]
                end

                local partA = character:FindFirstChild(pair[1])
                local partB = character:FindFirstChild(pair[2])

                if partA and partB then
                    local posA, onA = worldToScreen(partA.Position)
                    local posB, onB = worldToScreen(partB.Position)

                    if onA and onB then
                        line.Visible = true
                        line.From = posA
                        line.To = posB
                        line.Color = Colors.Skeleton
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end

            -- ซ่อน lines ที่เกินจำนวน pairs
            for i = #pairs_ + 1, #obj.SkeletonLines do
                obj.SkeletonLines[i].Visible = false
            end
        else
            for _, line in ipairs(obj.SkeletonLines) do
                line.Visible = false
            end
        end

        -------------------------
        -- Chams (Highlight)
        -------------------------
        if Enabled.Chams then
            if not obj.Chams or not obj.Chams.Parent then
                local hl = Instance.new("Highlight")
                hl.FillColor = Colors.ChamsFill
                hl.OutlineColor = Colors.ChamsOutline
                hl.FillTransparency = 0.5
                hl.OutlineTransparency = 0
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Adornee = character
                hl.Parent = gethui() -- executor hidden UI
                obj.Chams = hl
            else
                obj.Chams.Adornee = character
                obj.Chams.Enabled = true
                obj.Chams.FillColor = Colors.ChamsFill
                obj.Chams.OutlineColor = Colors.ChamsOutline
            end
        else
            if obj.Chams then
                obj.Chams.Enabled = false
            end
        end
    end
end

----------------------------------------------------------------
-- Player Handling
----------------------------------------------------------------
local function onPlayerAdded(player)
    if player == LocalPlayer then return end
    createESP(player)

    Connections[player] = player.CharacterAdded:Connect(function()
        task.wait(0.5)
        -- Chams ต้อง re-adornee
        local obj = Objects[player]
        if obj and obj.Chams then
            obj.Chams.Adornee = player.Character
        end
    end)
end

local function onPlayerRemoving(player)
    removeESP(player)
    if Connections[player] then
        Connections[player]:Disconnect()
        Connections[player] = nil
    end
end

----------------------------------------------------------------
-- Module Sub-Objects (ESP.box, ESP.name, etc.)
----------------------------------------------------------------
local function makeToggle(key)
    return {
        Enable = function()
            Enabled[key] = true
        end,
        Disable = function()
            Enabled[key] = false
        end,
        Toggle = function()
            Enabled[key] = not Enabled[key]
        end,
        IsEnabled = function()
            return Enabled[key]
        end,
        SetColor = function(_, color)
            Colors[key] = color
        end,
    }
end

ESP.box = makeToggle("Box")
ESP.name = makeToggle("Name")
ESP.healthbar = makeToggle("HealthBar")
ESP.distance = makeToggle("Distance")
ESP.tracer = makeToggle("Tracer")
ESP.skeleton = makeToggle("Skeleton")
ESP.chams = makeToggle("Chams")

-- Color setters เฉพาะทาง
function ESP.chams:SetFillColor(c)     Colors.ChamsFill = c end
function ESP.chams:SetOutlineColor(c)  Colors.ChamsOutline = c end
function ESP.healthbar:SetHighColor(c) Colors.HealthHigh = c end
function ESP.healthbar:SetLowColor(c)  Colors.HealthLow = c end

----------------------------------------------------------------
-- Master Controls
----------------------------------------------------------------
local mainConnection = nil

function ESP:Start()
    if mainConnection then return end

    for _, player in ipairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end

    Connections["_added"] = Players.PlayerAdded:Connect(onPlayerAdded)
    Connections["_removing"] = Players.PlayerRemoving:Connect(onPlayerRemoving)

    mainConnection = RunService.RenderStepped:Connect(function()
        updateESP()
    end)
end

function ESP:Stop()
    if mainConnection then
        mainConnection:Disconnect()
        mainConnection = nil
    end

    for key, conn in pairs(Connections) do
        conn:Disconnect()
        Connections[key] = nil
    end

    for player, _ in pairs(Objects) do
        removeESP(player)
    end
end

function ESP:EnableAll()
    for key in pairs(Enabled) do
        Enabled[key] = true
    end
end

function ESP:DisableAll()
    for key in pairs(Enabled) do
        Enabled[key] = false
    end
end

function ESP:SetMaxDistance(d)
    ESP.Settings.MaxDistance = d
end

function ESP:SetTeamCheck(bool)
    ESP.Settings.TeamCheck = bool
end

return ESP
