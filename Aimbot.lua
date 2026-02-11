local a=game:GetService"Players"
local b=game:GetService"RunService"
local c=game:GetService"UserInputService"
local d=a.LocalPlayer

local e=Vector2.new local f=
Vector3.new local g=
Color3.new
local h=Color3.fromRGB local i=
math.floor local j=
math.abs local k=
math.clamp
local l=math.huge

if _G.__AIM_CLEANUP then
pcall(_G.__AIM_CLEANUP)
end

local m={"Enabled","FOVCircle","TeamCheck","WallCheck","Prediction","StickyAim","Triggerbot","SnapLine"}
local n={}
for o,p in ipairs(m)do n[p]=true end

if type(_G.__AIM_FLAGS)~="table"then
_G.__AIM_FLAGS={}
end
for o,p in ipairs(m)do
if _G.__AIM_FLAGS[p]==nil then
_G.__AIM_FLAGS[p]=false
end
end
local o=_G.__AIM_FLAGS

if type(_G.__AIM_SETTINGS)~="table"then
_G.__AIM_SETTINGS={}
end
local p=_G.__AIM_SETTINGS

local q={
FOVRadius=120,
Smoothness=5,
AimPart="Head",
FOVColor=h(255,255,255),
FOVThickness=1,
FOVSides=64,
FOVTransparency=0.7,
FOVFilled=false,
SnapLineColor=h(255,0,0),
SnapLineThickness=1,
Keybind=Enum.UserInputType.MouseButton2,
PredictionAmount=0.165,
MaxDistance=2000,
HoldMode=true,
TriggerDelay=0.1,
TriggerRadius=15,
}
for r,s in next,q do
if p[r]==nil then
p[r]=s
end
end

local r=false
local s=0
local t={}
local u
local v=false
local w=false
local x
local y
local z=0

local function safeRemove(A)
if not A then return end
pcall(function()A.Visible=false end)
pcall(function()A:Remove()end)
end

local function safeDisconnect(A)
if not A then return end
pcall(function()A:Disconnect()end)
end

local function createDrawings()
safeRemove(x);safeRemove(y)
x=Drawing.new"Circle"
x.Visible=false;x.NumSides=p.FOVSides
x.Radius=p.FOVRadius;x.Thickness=p.FOVThickness
x.Color=p.FOVColor;x.Transparency=p.FOVTransparency
x.Filled=p.FOVFilled

y=Drawing.new"Line"
y.Visible=false;y.Thickness=p.SnapLineThickness
y.Color=p.SnapLineColor;y.Transparency=1
end

local function isVisible(A,B)
local C=workspace.CurrentCamera
if not C then return false end
local D=RaycastParams.new()
D.FilterType=Enum.RaycastFilterType.Exclude
D.FilterDescendantsInstances={d.Character,C}
local E=C.CFrame.Position
local F=workspace:Raycast(E,B-E,D)
if not F then return true end
return F.Instance:IsDescendantOf(A.Character)
end

local function getAimPos(A)
if not A or not A.Character then return nil end
local B=A.Character
local C=B:FindFirstChild(p.AimPart)or B:FindFirstChild"Head"
if not C then return nil end
local D=C.Position
if o.Prediction then
local E=B:FindFirstChild"HumanoidRootPart"
if E then
D=D+E.AssemblyLinearVelocity*p.PredictionAmount
end
end
return D
end

local function getTarget()
local A=workspace.CurrentCamera
if not A then return nil end
local B=A.ViewportSize
local C=e(B.X*0.5,B.Y*0.5)
local D=l
local E
local F=A.CFrame.Position
local G=d.Team

for H,I in ipairs(a:GetPlayers())do
if I~=d and I.Character then
if not(o.TeamCheck and I.Team and I.Team==G)then
local J=I.Character
local K=J:FindFirstChildOfClass"Humanoid"
local L=J:FindFirstChild(p.AimPart)or J:FindFirstChild"Head"
if K and K.Health>0 and L then
local M=L.Position
if o.Prediction then
local N=J:FindFirstChild"HumanoidRootPart"
if N then
M=M+N.AssemblyLinearVelocity*p.PredictionAmount
end
end
local N=(F-M).Magnitude
if N<=p.MaxDistance then
local O,P=A:WorldToViewportPoint(M)
if P then
local Q=e(O.X,O.Y)
local R=(Q-C).Magnitude
if R<=p.FOVRadius then
if o.WallCheck and not isVisible(I,M)then
continue
end
if R<D then
D=R
E=I
end
end
end
end
end
end
end
end
return E
end

local function validateTarget()
if not u then return false end
if not u.Parent then return false end
if not u.Character then return false end
local A=u.Character:FindFirstChildOfClass"Humanoid"
if not A or A.Health<=0 then return false end
local B=workspace.CurrentCamera
if not B then return false end
local C=getAimPos(u)
if not C then return false end
local D=(B.CFrame.Position-C).Magnitude
if D>p.MaxDistance then return false end
local E,F=B:WorldToViewportPoint(C)
if not F then return false end
local G=B.ViewportSize
local H=e(G.X*0.5,G.Y*0.5)
if(e(E.X,E.Y)-H).Magnitude>p.FOVRadius*2.5 then return false end
if o.WallCheck and not isVisible(u,C)then return false end
return true
end

local function isKeybind(A)
local B=p.Keybind
if typeof(B)~="EnumItem"then return false end
if B.EnumType==Enum.UserInputType then
return A.UserInputType==B
elseif B.EnumType==Enum.KeyCode then
return A.KeyCode==B
end
return false
end

local function renderFrame()
if not r then return end
local A=workspace.CurrentCamera
if not A then return end
local B=A.ViewportSize
local C=e(B.X*0.5,B.Y*0.5)

if o.FOVCircle and x then
x.Position=C
x.Radius=p.FOVRadius
x.Color=p.FOVColor
x.Thickness=p.FOVThickness
x.NumSides=p.FOVSides
x.Transparency=p.FOVTransparency
x.Filled=p.FOVFilled
x.Visible=true
elseif x then
x.Visible=false
end

local D=false
if o.Enabled then
if p.HoldMode then
D=v
else
D=w
end
end

if not iswindowactive()then D=false end

if D then
if o.StickyAim and u then
if not validateTarget()then u=nil end
end
if not u or not o.StickyAim then
u=getTarget()
end
if u then
local E=getAimPos(u)
if E then
local F,G=A:WorldToViewportPoint(E)
if G then
local H=e(F.X,F.Y)
local I=H-C
local J=p.Smoothness
if J<1 then J=1 end
mousemoverel(I.X/J,I.Y/J)

if o.SnapLine and y then
y.From=e(C.X,B.Y)
y.To=H
y.Color=p.SnapLineColor
y.Thickness=p.SnapLineThickness
y.Visible=true
elseif y then
y.Visible=false
end

if o.Triggerbot then
local K=tick()
if K-z>=p.TriggerDelay then
if I.Magnitude<=p.TriggerRadius then
z=K
task.spawn(mouse1click)
end
end
end
else
if y then y.Visible=false end
u=nil
end
else
if y then y.Visible=false end
u=nil
end
else
if y then y.Visible=false end
end
else
if not v and p.HoldMode then u=nil end
if y then y.Visible=false end
end
end

local function startInternal()
if r then return end
r=true;s=s+1
t={};u=nil;v=false;w=false;z=0

createDrawings()

t[#t+1]=c.InputBegan:Connect(function(A,B)
if B then return end
if isKeybind(A)then
v=true
if not p.HoldMode then w=not w end
end
end)

t[#t+1]=c.InputEnded:Connect(function(A)
if isKeybind(A)then
v=false
if p.HoldMode then u=nil end
end
end)

t[#t+1]=b.RenderStepped:Connect(renderFrame)

t[#t+1]=d.CharacterAdded:Connect(function()
u=nil
end)
end

local function stopInternal()
if not r then return end
r=false;s=s+1

for A=1,#t do safeDisconnect(t[A])end
t={}

u=nil;v=false;w=false

safeRemove(x);x=nil
safeRemove(y);y=nil
end

local function anyFlagOn()
for A,B in ipairs(m)do
if o[B]then return true end
end
return false
end

local function autoManage()
local A=anyFlagOn()
if A and not r then
startInternal()
elseif not A and r then
stopInternal()
end
end

local A=setmetatable({},{
__newindex=function(A,B,C)
if n[B]then
o[B]=C
autoManage()
else
p[B]=C
end
end,
__index=function(A,B)
if n[B]then
return o[B]
end
return p[B]
end,
})

_G.__AIM_CLEANUP=function()
stopInternal()
end

if anyFlagOn()then
startInternal()
end

return A
