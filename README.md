# Example Use
## Load module
```lua
loadstring(game:HttpGet("RAW_URL_HERE"))()
```
## Aimbot
```lua
--// Aimbot functions
Enabled = true
FOVCircle = true
TeamCheck = true
WallCheck = true
Prediction = true
StickyAim = true
Triggerbot = true
SnapLine = true

--// Aimbot configs
FOVRadius = 120
Smoothness = 5
AimPart = "Head"
FOVColor = h(255,255,255)
FOVThickness = 1
FOVSides = 64
FOVTransparency = 0.7
FOVFilled = false
SnapLineColor = h(255,0,0)
SnapLineThickness = 1
Keybind = Enum.UserInputType.MouseButton2
PredictionAmount = 0.165
MaxDistance = 2000
HoldMode = true
TriggerDelay = 0.1
TriggerRadius = 15
```
## Esp
```lua
--// ESP functions
Box = true
Name = true
HealthBar = true
Distance = true
Trace = true
Skeleton = true
Chams = true

--// ESP configs
TeamCheck = false
MaxDistance = 2000
Font = Drawing.Fonts.Plex
FontSize = 13
BoxColor = g(255,255,255)
NameColor = g(255,255,255)
DistanceColor = g(200,200,200)
TracerColor = g(255,255,255)
SkeletonColor = g(255,255,255)
HealthHighColor = g(0,255,0)
HealthLowColor = g(255,0,0)
ChamsFillColor = g(255,0,0)
ChamsOutlineColor = g(255,255,255)
