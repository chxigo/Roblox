local a=game:GetService"Players"
local b=game:GetService"RunService"
local c=a.LocalPlayer

local d=Vector2.new
local e=Vector3.new
local f=Color3.new
local g=Color3.fromRGB
local h=math.floor
local i=math.abs
local j=math.clamp

if _G.__ESP_CLEANUP then
pcall(_G.__ESP_CLEANUP)
end

local k={"Box","Name","HealthBar","Distance","Tracer","Skeleton","Chams"}
local l={}
for m,n in ipairs(k)do l[n]=true end

if type(_G.__ESP_FLAGS)~="table"then
_G.__ESP_FLAGS={}
end
for m,n in ipairs(k)do
if _G.__ESP_FLAGS[n]==nil then
_G.__ESP_FLAGS[n]=false
end
end
local m=_G.__ESP_FLAGS

if type(_G.__ESP_SETTINGS)~="table"then
_G.__ESP_SETTINGS={}
end
local n=_G.__ESP_SETTINGS

local o={
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
}
for p,q in next,o do
if n[p]==nil then
n[p]=q
end
end

local p=f(0,0,0)
local q=d(1,1)
local r=d(2,2)

local s={
{"Head","UpperTorso"},
{"UpperTorso","LowerTorso"},
{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local t={
{"Head","Torso"},
{"Torso","Left Arm"},{"Torso","Right Arm"},
{"Torso","Left Leg"},{"Torso","Right Leg"},
}
local u=#s

local v=false
local w=0
local x={}
local y={}
local z={}

local function safeRemove(A)
if not A then return end
pcall(function()A.Visible=false end)
pcall(function()A:Remove()end)
end

local function safeDestroy(A)
if not A then return end
pcall(function()A.Enabled=false end)
pcall(function()A:Destroy()end)
end

local function safeDisconnect(A)
if not A then return end
pcall(function()A:Disconnect()end)
end

local function mkLine(A,B)
local C=Drawing.new"Line"
C.Visible=false;C.Thickness=A or 1
C.Color=B or f(1,1,1);C.Transparency=1
return C
end

local function mkText(A,B)
local C=Drawing.new"Text"
C.Visible=false;C.Center=true;C.Outline=true
C.OutlineColor=p
C.Size=A or n.FontSize
C.Font=n.Font
C.Color=B or f(1,1,1);C.Transparency=1
return C
end

local function mkSquare()
local A=Drawing.new"Square"
A.Visible=false;A.Filled=false
A.Thickness=1;A.Transparency=1
return A
end

local A={"BoxOutline","Box","Name","Distance","HealthBarBG","HealthBar","HealthText","Tracer"}

local function createObject()
local B={
BoxOutline=mkSquare(),
Box=mkSquare(),
Name=mkText(n.FontSize),
Distance=mkText(n.FontSize-1),
HealthBarBG=mkLine(4,p),
HealthBar=mkLine(2),
HealthText=mkText(n.FontSize-2),
Tracer=mkLine(1),
Bones={},
Chams=nil,
Parts=nil,
}
for C=1,u do
B.Bones[C]=mkLine(1.5)
end
return B
end

local function hideObject(B)
for C=1,#A do
pcall(function()B[A[C] ].Visible=false end)
end
for C=1,u do
if B.Bones[C]then pcall(function()B.Bones[C].Visible=false end)end
end
if B.Chams then pcall(function()B.Chams.Enabled=false end)end
end

local function destroyObject(B)
for C=1,#A do safeRemove(B[A[C] ])end
for C=1,u do safeRemove(B.Bones[C])end
safeDestroy(B.Chams)
B.Chams=nil;B.Parts=nil
end

local function cacheParts(B)
if not B then return nil end
local C=B:FindFirstChildOfClass"Humanoid"
local D=B:FindFirstChild"HumanoidRootPart"
local E=B:FindFirstChild"Head"
if not(C and D and E)then return nil end

local F=(C.RigType==Enum.HumanoidRigType.R15)
local G=F and s or t
local H=#G
local I={}
for J=1,H do
local K=B:FindFirstChild(G[J][1])
local L=B:FindFirstChild(G[J][2])
I[J]=(K and L)and{K,L}or false
end
return{Hum=C,Root=D,Head=E,BoneCount=H,BoneParts=I}
end

local B,C,D

local function computeBB(E,F)local
G, H=E:WorldToViewportPoint(F)
if not H then return false end
local I=E:WorldToViewportPoint(F+e(0,3.25,0))
local J=E:WorldToViewportPoint(F-e(0,2.75,0))
if I.Z<1 then return false end
local K=i(J.Y-I.Y)
local L=K*0.55
D=(I.X+J.X)0.5
B=d(D-L0.5,I.Y)
C=d(L,K)
return true
end

local function renderFrame()
if not v then return end
local E=workspace.CurrentCamera
if not E then return end

local F=E.CFrame.Position
local G=E.ViewportSize
local H=n.MaxDistance
local I=c.Team

local J=m.Box
local K=m.Name
local L=m.HealthBar
local M=m.Distance
local N=m.Tracer
local O=m.Skeleton
local P=m.Chams

for Q,R in next,x do
local S=false
local T=R.Parts

if Q.Parent~=nil and T~=nil then
if not(n.TeamCheck and Q.Team and Q.Team==I)then
local U=T.Hum
local V=T.Root
if V and V.Parent and U and U.Parent and U.Health>0 then
local W=V.Position
local X=(F-W).Magnitude
if X<=H and computeBB(E,W)then
S=true
local Y=j(U.Health/U.MaxHealth,0,1)

if J then
R.BoxOutline.Position=B-q
R.BoxOutline.Size=C+r
R.BoxOutline.Color=p
R.BoxOutline.Thickness=3
R.BoxOutline.Visible=true
R.Box.Position=B
R.Box.Size=C
R.Box.Color=n.BoxColor
R.Box.Visible=true
else
R.BoxOutline.Visible=false
R.Box.Visible=false
end

if K then
R.Name.Text=Q.DisplayName
R.Name.Color=n.NameColor
R.Name.Size=n.FontSize
R.Name.Font=n.Font
R.Name.Position=d(D,B.Y-n.FontSize-4)
R.Name.Visible=true
else
R.Name.Visible=false
end

if M then
R.Distance.Text=h(X).."m"
R.Distance.Color=n.DistanceColor
R.Distance.Size=n.FontSize-1
R.Distance.Font=n.Font
R.Distance.Position=d(D,B.Y+C.Y+2)
R.Distance.Visible=true
else
R.Distance.Visible=false
end

if L then
local Z=B.X-5
local =B.Y
local aa=B.Y+C.Y
local ab=aa-C.Y*Y
local ac=n.HealthLowColor
local ad=n.HealthHighColor
local ae=f(
ac.R+(ad.R-ac.R)*Y,
ac.G+(ad.G-ac.G)*Y,
ac.B+(ad.B-ac.B)*Y
)
R.HealthBarBG.From=d(Z,)
R.HealthBarBG.To=d(Z,aa)
R.HealthBarBG.Visible=true
R.HealthBar.From=d(Z,ab)
R.HealthBar.To=d(Z,aa)
R.HealthBar.Color=ae
R.HealthBar.Visible=true
if Y<1 then
R.HealthText.Text=tostring(h(U.Health))
R.HealthText.Color=ae
R.HealthText.Position=d(Z,ab-n.FontSize+2)
R.HealthText.Visible=true
else
R.HealthText.Visible=false
end
else
R.HealthBarBG.Visible=false
R.HealthBar.Visible=false
R.HealthText.Visible=false
end

if N then
R.Tracer.From=d(G.X*0.5,G.Y)
R.Tracer.To=d(D,B.Y+C.Y)
R.Tracer.Color=n.TracerColor
R.Tracer.Visible=true
else
R.Tracer.Visible=false
end

if O then
local aa=T.BoneParts
local ab=T.BoneCount
local ac=R.Bones
local ad=n.SkeletonColor
for ae=1,ab do
local Z=ac[ae]
local =aa[ae]
if _ then
local af,ag=E:WorldToViewportPoint([1].Position)
local ah,ai=E:WorldToViewportPoint(_[2].Position)
if ag and ai then
Z.From=d(af.X,af.Y)
Z.To=d(ah.X,ah.Y)
Z.Color=ad
Z.Visible=true
else
Z.Visible=false
end
else
Z.Visible=false
end
end
for ae=ab+1,u do
if ac[ae]then ac[ae].Visible=false end
end
else
for aa=1,u do
if R.Bones[aa]then R.Bones[aa].Visible=false end
end
end

if P then
local aa=R.Chams
if not aa or not aa.Parent then
aa=Instance.new"Highlight"
aa.FillTransparency=0.5
aa.OutlineTransparency=0
aa.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
local ab=pcall(function()aa.Parent=gethui()end)
if not ab then
pcall(function()aa.Parent=game:GetService"CoreGui"end)
end
R.Chams=aa
end
aa.Adornee=Q.Character
aa.FillColor=n.ChamsFillColor
aa.OutlineColor=n.ChamsOutlineColor
aa.Enabled=true
else
if R.Chams then R.Chams.Enabled=false end
end
end
end
end
end

if not S then
hideObject(R)
end
end
end

local function bindPlayer(aa,ab)
if aa==c then return end
if not v or ab~=w then return end
if x[aa]then return end

local ac=createObject()
x[aa]=ac

y[aa]=aa.CharacterAdded:Connect(function(ad)
if not v or ab~=w then return end
task.defer(function()
task.wait(0.3)
if not v or ab~=w then return end
if not x[aa]then return end
ac.Parts=cacheParts(ad)
end)
end)

if aa.Character then
task.defer(function()
task.wait(0.3)
if not v or ab~=w then return end
if not x[aa]then return end
ac.Parts=cacheParts(aa.Character)
end)
end
end

local function startInternal()
if v then return end
v=true
w=w+1
local aa=w

x={}
y={}
z={}

for ab,ac in ipairs(a:GetPlayers())do
bindPlayer(ac,aa)
end

z[#z+1]=a.PlayerAdded:Connect(function(ab)
if v and aa==w then bindPlayer(ab,aa)end
end)

z[#z+1]=a.PlayerRemoving:Connect(function(ab)
if not v or aa~=w then return end
safeDisconnect(y[ab]);y[ab]=nil
local ac=x[ab]
if ac then destroyObject(ac)end
x[ab]=nil
end)

z[#z+1]=b.RenderStepped:Connect(renderFrame)
end

local function stopInternal()
if not v then return end
v=false
w=w+1

for aa=1,#z do safeDisconnect(z[aa])end
z={}

for aa,ab in next,y do safeDisconnect(ab)end
y={}

local aa={}
for ab in next,x do aa[#aa+1]=ab end
for ab=1,#aa do
local ac=x[aa[ab] ]
if ac then destroyObject(ac)end
x[aa[ab] ]=nil
end
x={}
end

local function anyFlagOn()
for aa,ab in ipairs(k)do
if m[ab]then return true end
end
return false
end

local function autoManage()
local aa=anyFlagOn()
if aa and not v then
startInternal()
elseif not aa and v then
stopInternal()
end
end

local aa=setmetatable({},{
__newindex=function(aa,ab,ac)
if l[ab]then
m[ab]=ac
autoManage()
else
n[ab]=ac
end
end,
__index=function(aa,ab)
if l[ab]then
return m[ab]
end
return n[ab]
end,
})

_G.__ESP_CLEANUP=function()
stopInternal()
end
if anyFlagOn()then
startInternal()
end

return aa
