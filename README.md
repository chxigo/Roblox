# Example Use
## Load module
```lua
local Variable = loadstring(game:HttpGet("RAW_URL_HERE"))()
```
## Aimbot
```lua
--// Aimbot functions
Variable.Enabled = true
Variable.FOVCircle = true
Variable.TeamCheck = true
Variable.WallCheck = true
Variable.Prediction = true
Variable.StickyAim = true
Variable.Triggerbot = true
Variable.SnapLine = true

--// Aimbot configs
Variable.FOVRadius = 120
Variable.Smoothness = 5
Variable.AimPart = "Head"
Variable.FOVColor = h(255,255,255)
Variable.FOVThickness = 1
Variable.FOVSides = 64
Variable.FOVTransparency = 0.7
Variable.FOVFilled = false
Variable.SnapLineColor = h(255,0,0)
Variable.SnapLineThickness = 1
Variable.Keybind = Enum.UserInputType.MouseButton2
Variable.PredictionAmount = 0.165
Variable.MaxDistance = 2000
Variable.HoldMode = true
Variable.TriggerDelay = 0.1
Variable.TriggerRadius = 15
```
## Esp
```lua
--// ESP functions
Variable.Box = true
Variable.Name = true
Variable.HealthBar = true
Variable.Distance = true
Variable.Trace = true
Variable.Skeleton = true
Variable.Chams = true

--// ESP configs
Variable.TeamCheck = false
Variable.MaxDistance = 2000
Variable.Font = Drawing.Fonts.Plex
Variable.FontSize = 13
Variable.BoxColor = g(255,255,255)
Variable.NameColor = g(255,255,255)
Variable.DistanceColor = g(200,200,200)
Variable.TracerColor = g(255,255,255)
Variable.SkeletonColor = g(255,255,255)
HealthHighColor = g(0,255,0)
HealthLowColor = g(255,0,0)
ChamsFillColor = g(255,0,0)
ChamsOutlineColor = g(255,255,255)
