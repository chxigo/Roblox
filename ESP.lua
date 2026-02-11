local a=game:GetService"Players"
local b=game:GetService"RunService"
game:GetService"UserInputService"
local c=a.LocalPlayer

local d=Vector2.new
local e=Vector3.new
local f=Color3.new
local g=Color3.fromRGB local h=
CFrame.lookAt
local i=math.floor
local j=math.abs
local k=math.clamp

if _G.__ESP_CLEANUP then
pcall(_G.__ESP_CLEANUP)
end

local l={
"Box","Name","HealthBar","Distance","Tracer","Skeleton","Chams",
"Aimbot","AimbotShowFOV",
}
local m={}
for n,o in ipairs(l)do m[o]=true end

if type(_G.__ESP_FLAGS)~="table"then _G.__ESP_FLAGS={}end
for n,o in ipairs(l)do
if _G.__ESP_FLAGS[o]==nil then _G.__ESP_FLAGS[o]=false end
end
local n=_G.__ESP_FLAGS

if type(_G.__ESP_SETTINGS)~="table"then _G.__ESP_SETTINGS={}end
local o=_G.__ESP_SETTINGS

local p={

TeamCheck=false,
MaxDistance=2000,
Font=Drawing.Fonts.Plex,
FontSize=13,
BoxColor=g(255,255,255),
NameColor=g(255,255,255),
DistanceColor=g(200,200,200),
TracerColor=g(255,255,255),
SkeletonColor=g(255,255,255),
HealthHighColor=g(0,255,0),
HealthLowColor=g(255,0,0),
ChamsFillColor=g(255,0,0),
ChamsOutlineColor=g(255,255,255),

AimbotFOVRadius=200,
AimbotSmooth=5,
AimbotPart="Head",
AimbotKey=Enum.UserInputType.MouseButton2,
AimbotFOVColor=g(255,255,255),
AimbotWallCheck=false,
AimbotFOVSides=60,
AimbotFOVThickness=1,
AimbotFOVFilled=false,
}
for q,r in next,p do
if o[q]==nil then o[q]=r end
end

local q=f(0,0,0)
local r=d(1,1)
local s=d(2,2)

local t={
{"Head","UpperTorso"},
{"UpperTorso","LowerTorso"},
{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local u={
{"Head","Torso"},
{"Torso","Left Arm"},{"Torso","Right Arm"},
{"Torso","Left Leg"},{"Torso","Right Leg"},
}
local v=#t

local w=false
local x=0
local y={}
local z={}
local A={}
local B
local C

local function safeRemove(D)
if not D then return end
pcall(function()D.Visible=false end)
pcall(function()D:Remove()end)
end

local function safeDestroy(D)
if not D then return end
pcall(function()D.Enabled=false end)
pcall(function()D:Destroy()end)
end

local function safeDisconnect(D)
if not D then return end
pcall(function()D:Disconnect()end)
end

local function mkLine(D,E)
local F=Drawing.new"Line"
F.Visible=false;F.Thickness=D or 1
F.Color=E or f(1,1,1);F.Transparency=1
return F
end

local function mkText(D,E)
local F=Drawing.new"Text"
F.Visible=false;F.Center=true;F.Outline=true
F.OutlineColor=q
F.Size=D or o.FontSize
F.Font=o.Font
F.Color=E or f(1,1,1);F.Transparency=1
return F
end

local function mkSquare()
local D=Drawing.new"Square"
D.Visible=false;D.Filled=false
D.Thickness=1;D.Transparency=1
return D
end

local D={"BoxOutline","Box","Name","Distance","HealthBarBG","HealthBar","HealthText","Tracer"}

local function createObject()
local E={
BoxOutline=mkSquare(),
Box=mkSquare(),
Name=mkText(o.FontSize),
Distance=mkText(o.FontSize-1),
HealthBarBG=mkLine(4,q),
HealthBar=mkLine(2),
HealthText=mkText(o.FontSize-2),
Tracer=mkLine(1),
Bones={},
Chams=nil,
Parts=nil,
}
for F=1,v do E.Bones[F]=mkLine(1.5)end
return E
end

local function hideObject(E)
for F=1,#D do
pcall(function()E[D[F] ].Visible=false end)
end
for F=1,v do
if E.Bones[F]then pcall(function()E.Bones[F].Visible=false end)end
end
if E.Chams then pcall(function()E.Chams.Enabled=false end)end
end

local function destroyObject(E)
for F=1,#D do safeRemove(E[D[F] ])end
for F=1,v do safeRemove(E.Bones[F])end
safeDestroy(E.Chams)
E.Chams=nil;E.Parts=nil
end

local function cacheParts(E)
if not E then return nil end
local F=E:FindFirstChildOfClass"Humanoid"
local G=E:FindFirstChild"HumanoidRootPart"
local H=E:FindFirstChild"Head"
if not(F and G and H)then return nil end

local I=(F.RigType==Enum.HumanoidRigType.R15)
local J=I and t or u
local K=#J
local L={}
for M=1,K do
local N=E:FindFirstChild(J[M][1])
local O=E:FindFirstChild(J[M][2])
L[M]=(N and O)and{N,O}or false
end
return{Hum=F,Root=G,Head=H,BoneCount=K,BoneParts=L}
end

local E,F,G

local function computeBB(H,I)local
J, K=H:WorldToViewportPoint(I)
if not K then return false end
local L=H:WorldToViewportPoint(I+e(0,3.25,0))
local M=H:WorldToViewportPoint(I-e(0,2.75,0))
if L.Z<1 then return false end
local N=j(M.Y-L.Y)
local O=N*0.55
G=(L.X+M.X)*0.5
E=d(G-O*0.5,L.Y)
F=d(O,N)
return true
end














local function destroyFOVCircle()
safeRemove(B)
B=nil
end




































































































































local function renderFrame()
if not w then return end
local H=workspace.CurrentCamera
if not H then return end

local I=H.CFrame.Position
local J=H.ViewportSize
local K=o.MaxDistance
local L=c.Team

local M=n.Box
local N=n.Name
local O=n.HealthBar
local P=n.Distance
local Q=n.Tracer
local R=n.Skeleton
local S=n.Chams

for T,U in next,y do
local V=false
local W=U.Parts

if T.Parent~=nil and W~=nil then
if not(o.TeamCheck and T.Team and T.Team==L)then
local X=W.Hum
local Y=W.Root
if Y and Y.Parent and X and X.Parent and X.Health>0 then
local Z=Y.Position
local _=(I-Z).Magnitude
if _<=K and computeBB(H,Z)then
V=true
local aa=k(X.Health/X.MaxHealth,0,1)

if M then
U.BoxOutline.Position=E-r
U.BoxOutline.Size=F+s
U.BoxOutline.Color=q
U.BoxOutline.Thickness=3
U.BoxOutline.Visible=true
U.Box.Position=E
U.Box.Size=F
U.Box.Color=o.BoxColor
U.Box.Visible=true
else
U.BoxOutline.Visible=false
U.Box.Visible=false
end

if N then
U.Name.Text=T.DisplayName
U.Name.Color=o.NameColor
U.Name.Size=o.FontSize
U.Name.Font=o.Font
U.Name.Position=d(G,E.Y-o.FontSize-4)
U.Name.Visible=true
else
U.Name.Visible=false
end


if P then
U.Distance.Text=i(_).."m"
U.Distance.Color=o.DistanceColor
U.Distance.Size=o.FontSize-1
U.Distance.Font=o.Font
U.Distance.Position=d(G,E.Y+F.Y+2)
U.Distance.Visible=true
else
U.Distance.Visible=false
end

if O then
local ab=E.X-5
local ac=E.Y
local ad=E.Y+F.Y
local ae=ad-F.Y*aa
local af=o.HealthLowColor
local ag=o.HealthHighColor
local ah=f(
af.R+(ag.R-af.R)*aa,
af.G+(ag.G-af.G)*aa,
af.B+(ag.B-af.B)*aa
)
U.HealthBarBG.From=d(ab,ac)
U.HealthBarBG.To=d(ab,ad)
U.HealthBarBG.Visible=true
U.HealthBar.From=d(ab,ae)
U.HealthBar.To=d(ab,ad)
U.HealthBar.Color=ah
U.HealthBar.Visible=true
if aa<1 then
U.HealthText.Text=tostring(i(X.Health))
U.HealthText.Color=ah
U.HealthText.Position=d(ab,ae-o.FontSize+2)
U.HealthText.Visible=true
else
U.HealthText.Visible=false
end
else
U.HealthBarBG.Visible=false
U.HealthBar.Visible=false
U.HealthText.Visible=false
end


if Q then
U.Tracer.From=d(J.X*0.5,J.Y)
U.Tracer.To=d(G,E.Y+F.Y)
U.Tracer.Color=o.TracerColor
U.Tracer.Visible=true
else
U.Tracer.Visible=false
end

if R then
local ab=W.BoneParts
local ac=W.BoneCount
local ad=U.Bones
local ae=o.SkeletonColor
for af=1,ac do
local ag=ad[af]
local ah=ab[af]
if ah then
local ai,aj=H:WorldToViewportPoint(ah[1].Position)
local ak,al=H:WorldToViewportPoint(ah[2].Position)
if aj and al then
ag.From=d(ai.X,ai.Y)
ag.To=d(ak.X,ak.Y)
ag.Color=ae
ag.Visible=true
else
ag.Visible=false
end
else
ag.Visible=false
end
end
for af=ac+1,v do
if ad[af]then ad[af].Visible=false end
end
else
for ab=1,v do
if U.Bones[ab]then U.Bones[ab].Visible=false end
end
end

if S then
local ab=U.Chams
if not ab or not ab.Parent then
ab=Instance.new"Highlight"
ab.FillTransparency=0.5
ab.OutlineTransparency=0
ab.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
local ac=pcall(function()ab.Parent=gethui()end)
if not ac then
pcall(function()ab.Parent=game:GetService"CoreGui"end)
end
U.Chams=ab
end
ab.Adornee=T.Character
ab.FillColor=o.ChamsFillColor
ab.OutlineColor=o.ChamsOutlineColor
ab.Enabled=true
else
if U.Chams then U.Chams.Enabled=false end
end
end
end
end
end

if not V then
hideObject(U)
end
end

end

local function bindPlayer(aa,ab)
if aa==c then return end
if not w or ab~=x then return end
if y[aa]then return end

local ac=createObject()
y[aa]=ac

z[aa]=aa.CharacterAdded:Connect(function(ad)
if not w or ab~=x then return end
task.defer(function()
task.wait(0.3)
if not w or ab~=x then return end
if not y[aa]then return end
ac.Parts=cacheParts(ad)
end)
end)

if aa.Character then
task.defer(function()
task.wait(0.3)
if not w or ab~=x then return end
if not y[aa]then return end
ac.Parts=cacheParts(aa.Character)
end)
end
end

local function startInternal()
if w then return end
w=true
x=x+1
local aa=x

y={}
z={}
A={}

for ab,ac in ipairs(a:GetPlayers())do
bindPlayer(ac,aa)
end

A[#A+1]=a.PlayerAdded:Connect(function(ab)
if w and aa==x then bindPlayer(ab,aa)end
end)

A[#A+1]=a.PlayerRemoving:Connect(function(ab)
if not w or aa~=x then return end
safeDisconnect(z[ab]);z[ab]=nil
local ac=y[ab]
if ac then destroyObject(ac)end
y[ab]=nil
end)

A[#A+1]=b.RenderStepped:Connect(renderFrame)
end

local function stopInternal()
if not w then return end
w=false
x=x+1
C=nil

for aa=1,#A do safeDisconnect(A[aa])end
A={}

for aa,ab in next,z do safeDisconnect(ab)end
z={}

local aa={}
for ab in next,y do aa[#aa+1]=ab end
for ab=1,#aa do
local ac=y[aa[ab] ]
if ac then destroyObject(ac)end
y[aa[ab] ]=nil
end
y={}

destroyFOVCircle()
end

local function anyFlagOn()
for aa,ab in ipairs(l)do
if n[ab]then return true end
end
return false
end

local function autoManage()
local aa=anyFlagOn()
if aa and not w then
startInternal()
elseif not aa and w then
stopInternal()
end
end

local aa=setmetatable({},{
__newindex=function(aa,ab,ac)
if m[ab]then
n[ab]=ac
autoManage()
else
o[ab]=ac
end
end,
__index=function(aa,ab)
if m[ab]then
return n[ab]
end
return o[ab]
end,
})

_G.__ESP_CLEANUP=function()
stopInternal()
end

if anyFlagOn()then
startInternal()
end

return aa
