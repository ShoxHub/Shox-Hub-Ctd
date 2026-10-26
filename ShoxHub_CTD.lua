-- Shox Hub | Cameraman TD Macro Recorder + Beat-Intro | v7.16
pcall(function() getgenv().ShoxOff() end)
local HS,UIS,TS,RS=game:GetService("HttpService"),game:GetService("UserInputService"),game:GetService("TweenService"),game:GetService("RunService")
local lp=game:GetService("Players").LocalPlayer
local G=getgenv()
local DIR="ShoxHub"
local DISCORD="https://discord.gg/EA7xS26mA9"
local MDIR=DIR.."/music" -- Intro-Datei (.mp3/.ogg) hier oder direkt in ShoxHub/ ablegen
pcall(makefolder,DIR)
pcall(makefolder,MDIR)
-- Intro-Song wird beim ersten Start automatisch geladen und in ShoxHub/music/ gespeichert (nur einmal, danach lokal).
-- INTRO_URL: GitHub raw (intro.ogg im Repo-Root). INTRO_URL2: Reserve (catbox liefert in Delta teils leere Antworten).
local INTRO_URL="https://raw.githubusercontent.com/ShoxHub/Shox-Hub-Ctd/main/intro.ogg"
local INTRO_URL2="https://files.catbox.moe/j5p4sg.ogg"
local IGNORE={} -- nie aufnehmen: IGNORE["RemoteName"]=true
local SKIPB={"towerui","slots","jumpbutton"} -- beim Abspielen ueberspringen
local DEDUP=0.05
local ADD="TowerAdd"
local USE={TowerUpgrade=true,TowerSell=true}
local NEAR=12
local GP="^%x+%-%x+%-%x+%-%x+%-%x+$"
local RUNS,SCALES,SNAME,TRANS={0},{0.85,1,1.2},{"S","M","L"},{0,0.2,0.4} -- RUNS={0}: immer Endless
local NSLOTS=10
local SPEEDS,SPNAME={0.75,1,1.25,1.5,2},{"0.75x","1x","1.25x","1.5x","2x"}
local cfg={theme="Black",runs=1,scale=2,trans=1,intro=true,lag=false,slot=1,ap=false,dev=false,speed=2,rainbow=false,hookOn=false,hook="",names={},st={runs=0,time=0,best=0,last=0,hist={}}}
do
  local ok,j=pcall(function() return HS:JSONDecode(readfile(DIR.."/settings.json")) end)
  if ok and type(j)=="table" then for k,v in pairs(j) do cfg[k]=v end end
  cfg.gap,cfg.moves,cfg.vol=nil,nil,nil
  cfg.theme=({Schwarz="Black",["Weiß"]="White"})[cfg.theme] or cfg.theme
  if not RUNS[cfg.runs] then cfg.runs=1 end
  if not SCALES[cfg.scale] then cfg.scale=2 end
  if not TRANS[cfg.trans] then cfg.trans=1 end
  if not SPEEDS[cfg.speed] then cfg.speed=2 end
  cfg.intro=cfg.intro~=false
  cfg.lag=cfg.lag==true
  cfg.ap=cfg.ap==true
  cfg.dev=cfg.dev==true
  cfg.rainbow=cfg.rainbow==true
  cfg.hookOn=cfg.hookOn==true
  if type(cfg.hook)~="string" then cfg.hook="" end
  cfg.auto=nil
  cfg.runs=1
  if type(cfg.names)~="table" then cfg.names={} end
  if type(cfg.st)~="table" then cfg.st={} end
  cfg.st.runs=tonumber(cfg.st.runs) or 0
  cfg.st.time=tonumber(cfg.st.time) or 0
  cfg.st.best=tonumber(cfg.st.best) or 0
  cfg.st.last=tonumber(cfg.st.last) or 0
  if type(cfg.st.hist)~="table" then cfg.st.hist={} end
  if type(cfg.slot)~="number" or cfg.slot<1 or cfg.slot>NSLOTS then cfg.slot=1 end
end
local function saveCfg() pcall(writefile,DIR.."/settings.json",HS:JSONEncode(cfg)) end
local function sname(n) return cfg.names[tostring(n)] or "" end
local rec,play,t0,steps,miss,slot,rlog=false,false,0,{},0,cfg.slot,{}
local paused=false
local sess0,coin0
local lastK,lastT=nil,0
local idmap={}
local idloc
local alive,gen=true,0
local runI,runT0,runTot=0,nil,0
local waitEnd=false
local filled={}
local conns={}
local introS,introG
local function on(sig,fn) local c=sig:Connect(fn) conns[#conns+1]=c return c end
local function mmss(x) x=math.floor(x) return string.format("%d:%02d",x//60,x%60) end
local function isIn(i) return i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 end
local function rname() local t={} for i=1,10 do t[i]=string.char(math.random(97,122)) end return table.concat(t) end

-- Anti-AFK (fest eingebaut): Idled-Verbindungen aus + VirtualUser-Klick + Mini-Sprung des Charakters alle ca. 25-35 s
-- (der Sprung ist echte Bewegung: faengt auch Spiele ab, die AFK ueber Charakter-Bewegung erkennen)
pcall(function() for _,c in pairs(getconnections(lp.Idled)) do c:Disable() end end)
local VU=game:GetService("VirtualUser")
local function nudge()
  pcall(function() VU:CaptureController() VU:ClickButton2(Vector2.new()) end)
  pcall(function()
    local ch=lp.Character
    local h=ch and ch:FindFirstChildOfClass("Humanoid")
    if h and h.Health>0 then h.Jump=true end
  end)
end
on(lp.Idled,nudge)
task.spawn(function()
  while alive do
    task.wait(25+math.random()*10)
    if not alive then break end
    nudge()
  end
end)

-- Anti-Kick (fest eingebaut): blockt lp:Kick() vom Client aus (Namecall-Hook + hookfunction)
-- Serverseitige Kicks/Bans (Anti-Cheat des Spiels) kann kein Client-Skript verhindern.
G.ShoxAK=true
if not G.ShoxKF then
  G.ShoxKF=pcall(function()
    local k
    k=hookfunction(lp.Kick,newcclosure(function(s,...)
      if G.ShoxAK and s==lp then return end
      return k(s,...)
    end))
  end)
end

-- Pfade
local function path(i)
  local p={}
  while i and i~=game do
    local n,par=i.Name,i.Parent
    if par then
      local k,c=0,0
      for _,x in ipairs(par:GetChildren()) do
        if x.Name==n then c+=1 if x==i then k=c end end
      end
      if c>1 then n=n.."\1"..k end
    end
    table.insert(p,1,n)
    i=par
  end
  return p
end
local function find(p)
  local o=game
  for _,n in ipairs(p) do
    if not o then return nil end
    local name,k=n:match("^(.*)\1(%d+)$")
    if name then
      local c,r=0,nil
      for _,x in ipairs(o:GetChildren()) do
        if x.Name==name then c+=1 if c==tonumber(k) then r=x break end end
      end
      o=r
    else o=o:FindFirstChild(n) end
  end
  return o
end
local function pv(x)
  if not x:IsA("PVInstance") then return nil end
  local ok,c=pcall(function() return x:GetPivot().Position end)
  return ok and c or nil
end
local function pvOf(x)
  local c=pv(x)
  if c then return c end
  local m=x:FindFirstAncestorWhichIsA("Model")
  return m and pv(m)
end
local function resolve(o)
  local r=find(o.p)
  if not o.q then return r end
  local q=Vector3.new(table.unpack(o.q))
  local c=r and pv(r)
  if c and (c-q).Magnitude<3 then return r end
  local par=find({table.unpack(o.p,1,#o.p-1)})
  if par then
    local best,bd=nil,3
    for _,x in ipairs(par:GetChildren()) do
      local cx=pv(x)
      if cx and (cx-q).Magnitude<bd then best,bd=x,(cx-q).Magnitude end
    end
    if best then return best end
  end
  return r
end

-- Serialisierung
local function enc(v,d)
  d=d or 0
  local t=typeof(v)
  if t=="number" then
    if v~=v or math.abs(v)==math.huge then return {t="N",s=tostring(v)} end
    return v
  elseif t=="string" or t=="boolean" then return v
  elseif t=="nil" then return {t="nil"}
  elseif t=="Vector3" then return {t="V3",v={v.X,v.Y,v.Z}}
  elseif t=="Vector2" then return {t="V2",v={v.X,v.Y}}
  elseif t=="CFrame" then return {t="CF",v={v:GetComponents()}}
  elseif t=="Color3" then return {t="C3",v={v.R,v.G,v.B}}
  elseif t=="Instance" then
    local c=pv(v)
    return {t="I",p=path(v),q=c and {c.X,c.Y,c.Z} or nil}
  elseif t=="table" and d<4 then
    local o={}
    for k,x in pairs(v) do o[#o+1]={enc(k,d+1),enc(x,d+1)} end
    return {t="T",v=o}
  end
  return {t="S",s=tostring(v)}
end
local function dec(o)
  if type(o)~="table" then return (type(o)=="string" and idmap[o]) or o end
  local t=o.t
  if t=="V3" then return Vector3.new(table.unpack(o.v))
  elseif t=="V2" then return Vector2.new(table.unpack(o.v))
  elseif t=="CF" then return CFrame.new(table.unpack(o.v))
  elseif t=="C3" then return Color3.new(table.unpack(o.v))
  elseif t=="I" then local r=resolve(o) if not r then miss+=1 end return r
  elseif t=="N" then return tonumber(o.s)
  elseif t=="S" then return o.s
  elseif t=="T" then
    local r={}
    for _,kv in ipairs(o.v) do
      local k=dec(kv[1])
      if k~=nil then r[k]=dec(kv[2]) end
    end
    return r
  end
end
local function decArgs(s)
  local a
  for try=1,15 do
    local b=miss
    a={}
    for i=1,s.n do a[i]=dec(s.a[i]) end
    if miss==b or try==15 then break end
    miss=b
    task.wait(0.2)
  end
  return a
end

-- Tower-Id Erkennung
local function tkey(s,key)
  local a=s.a and s.a[1]
  if type(a)=="table" and a.t=="T" then
    for _,kv in ipairs(a.v) do if kv[1]==key then return kv[2] end end
  end
end
local function gather()
  local r={}
  local g=workspace:FindFirstChild("Game")
  local root=(g and g:FindFirstChild("Towers")) or workspace
  for _,x in ipairs(root:GetDescendants()) do
    local n=x.Name
    if n:match(GP) then r[n]=x end
    if x:IsA("Model") then
      for _,v in pairs(x:GetAttributes()) do
        if type(v)=="string" and v:match(GP) then r[v]=r[v] or x end
      end
    end
  end
  return r
end
local function newId(before,s)
  local uid=tkey(s,"UnitId")
  local pp=tkey(s,"Pos")
  local pos=type(pp)=="table" and pp.v and Vector3.new(table.unpack(pp.v))
  local n=0
  for i=1,12 do
    task.wait(0.25)
    local c={}
    for g,x in pairs(gather()) do
      if not before[g] and g~=uid then
        local px=pos and pvOf(x)
        c[#c+1]={g=g,d=px and (px-pos).Magnitude}
      end
    end
    n=#c
    if n>0 then
      local best
      for _,e in ipairs(c) do
        if e.d and e.d<=NEAR and (not best or e.d<best.d) then best=e end
      end
      if best then return best.g,n end
      if n==1 and not c[1].d then return c[1].g,n end
    end
  end
  return nil,n
end
local function locate(id)
  if type(id)~="string" then return "?" end
  local r={}
  for _,x in ipairs(workspace:GetDescendants()) do
    if x.Name==id then r[#r+1]=x:GetFullName():sub(1,80).." (Name)" end
    for k,v in pairs(x:GetAttributes()) do
      if v==id then r[#r+1]=x.ClassName..":"..x:GetFullName():sub(1,60).." @"..k end
    end
    if #r>=3 then break end
  end
  return #r>0 and table.concat(r," | ") or "nicht im Workspace"
end

-- Themes: Black, White, Frost, Natural, Lava, Violet, Sakura, Gold, Ocean
local function C(r,g,b) return Color3.fromRGB(r,g,b) end
local W=C(255,255,255)
local THEMES={
  {"Black",{bg=C(8,8,8),btn=C(26,26,28),btxt=C(235,235,235),acc=C(255,255,255),sub=C(125,125,130),rec=C(38,38,40),play=C(38,38,40),del=C(26,26,28),ctxt=C(245,245,245),ron=C(255,255,255),pon=C(255,255,255),onT=C(0,0,0)}},
  {"White",{bg=C(250,250,252),btn=C(233,233,237),btxt=C(22,22,24),acc=C(10,10,12),sub=C(115,115,122),rec=C(214,214,220),play=C(214,214,220),del=C(233,233,237),ctxt=C(22,22,24),ron=C(10,10,12),pon=C(10,10,12),onT=C(255,255,255)}},
  {"Frost",{bg=C(10,22,40),btn=C(24,48,80),btxt=C(225,242,255),acc=C(120,200,255),sub=C(170,205,235),rec=C(50,100,160),play=C(60,130,200),del=C(40,70,110),ctxt=W,ron=C(30,140,230),pon=C(30,160,190),onT=W}},
  {"Natural",{bg=C(10,24,14),btn=C(24,52,30),btxt=C(225,245,225),acc=C(90,200,90),sub=C(170,210,170),rec=C(120,80,35),play=C(50,140,70),del=C(90,50,30),ctxt=W,ron=C(200,80,40),pon=C(120,190,60),onT=W}},
  {"Lava",{bg=C(20,8,6),btn=C(52,22,14),btxt=C(255,225,200),acc=C(255,100,20),sub=C(255,190,150),rec=C(150,30,10),play=C(190,65,10),del=C(105,25,15),ctxt=W,ron=C(255,50,20),pon=C(230,140,0),onT=W}},
  {"Violet",{bg=C(16,8,30),btn=C(40,24,72),btxt=C(238,228,255),acc=C(180,120,255),sub=C(185,165,225),rec=C(90,50,150),play=C(110,60,190),del=C(70,34,100),ctxt=W,ron=C(150,70,255),pon=C(200,90,255),onT=W}},
  {"Sakura",{bg=C(30,10,20),btn=C(70,28,48),btxt=C(255,230,240),acc=C(255,130,180),sub=C(240,180,205),rec=C(150,50,90),play=C(190,70,120),del=C(100,34,64),ctxt=W,ron=C(255,70,140),pon=C(255,150,190),onT=W}},
  {"Gold",{bg=C(16,13,4),btn=C(44,36,10),btxt=C(255,242,200),acc=C(255,200,50),sub=C(220,195,130),rec=C(120,90,20),play=C(160,120,20),del=C(80,60,14),ctxt=W,ron=C(255,190,30),pon=C(255,215,80),onT=C(20,14,0)}},
  {"Ocean",{bg=C(5,20,24),btn=C(12,52,60),btxt=C(215,250,250),acc=C(40,220,200),sub=C(150,215,210),rec=C(20,100,110),play=C(20,140,140),del=C(14,70,80),ctxt=W,ron=C(0,200,180),pon=C(40,230,160),onT=C(0,20,20)}},
}
local TM={}
for _,t in ipairs(THEMES) do TM[t[1]]=t[2] end
local T,themeName=TM.Black,"Black"
local themed={}

-- GUI
local QI=Enum.EasingStyle.Quint
local function tw(o,pr,t,s) TS:Create(o,TweenInfo.new(t or .2,s or QI,Enum.EasingDirection.Out),pr):Play() end
local function mk(c,pr,par) local o=Instance.new(c) for k,v in pairs(pr) do o[k]=v end o.Parent=par return o end
local function reg(o,prop,fn) themed[#themed+1]={o,prop,fn} o[prop]=fn(T) return o end
local fBg=function(t) return t.bg end
local fAcc=function(t) return t.acc end
local fSub=function(t) return t.sub end
local fBtn=function(t) return t.btn end
local fBtxt=function(t) return t.btxt end
local fDel=function(t) return t.del end
local fCtxt=function(t) return t.ctxt end
local fLine=function(t) return t.btn:Lerp(t.acc,0.3) end
-- GUI-Container: zufaelliger Name, in gethui()/CoreGui wenn moeglich (nicht im PlayerGui sichtbar)
local function guiParent()
  local ok,h=pcall(function() return gethui and gethui() end)
  if ok and h then return h end
  local ok2,cg=pcall(function() return game:GetService("CoreGui") end)
  if ok2 and cg then return cg end
  return lp:WaitForChild("PlayerGui")
end
local gui=mk("ScreenGui",{ResetOnSpawn=false,IgnoreGuiInset=true,Name=rname()},guiParent())
pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
local WIN_H=300
local DEFPOS=UDim2.new(0,10,0.08,0)
local main=mk("Frame",{Size=UDim2.fromOffset(220,0),Position=DEFPOS,ClipsDescendants=true,BorderSizePixel=0,BackgroundTransparency=1},gui)
reg(main,"BackgroundColor3",fBg)
local uis=mk("UIScale",{Scale=SCALES[cfg.scale]},main)
mk("UICorner",{CornerRadius=UDim.new(0,14)},main)
-- Rahmen mit rotierendem Farbverlauf
local mStroke=mk("UIStroke",{Thickness=2,Color=W},main)
local mGrad=mk("UIGradient",{Rotation=0},mStroke)
if type(cfg.pos)=="table" and #cfg.pos==4 then
  pcall(function() main.Position=UDim2.new(cfg.pos[1],cfg.pos[2],cfg.pos[3],cfg.pos[4]) end)
end
local hdr=mk("Frame",{Size=UDim2.new(1,-44,0,34),BackgroundTransparency=1},main)
local title=mk("TextLabel",{Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-12,1,0),Text="Shox Hub",TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Font=Enum.Font.GothamBlack,TextSize=17},hdr)
reg(title,"TextColor3",fAcc)
-- Glanz-Effekt ueber dem Titel (Titel bleibt immer gut lesbar)
local titleG=mk("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.25),NumberSequenceKeypoint.new(0.5,0),NumberSequenceKeypoint.new(1,0.25)})},title)
local status=mk("TextLabel",{Position=UDim2.fromOffset(12,34),Size=UDim2.new(1,-24,0,18),Text="Ready | Anti-AFK on",TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd},main)
reg(status,"TextColor3",fSub)
local dragH=mk("TextButton",{Size=UDim2.new(1,-44,0,56),BackgroundTransparency=1,Text="",AutoButtonColor=false,Active=true,ZIndex=2},main)
local div=mk("Frame",{Position=UDim2.fromOffset(12,56),Size=UDim2.new(1,-24,0,1),BorderSizePixel=0},main)
reg(div,"BackgroundColor3",fBtn)
local body=mk("ScrollingFrame",{Position=UDim2.fromOffset(0,60),Size=UDim2.new(1,0,1,-60),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},main)
reg(body,"ScrollBarImageColor3",fAcc)
mk("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},body)
mk("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,14),PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,12)},body)
local ord=0
local function row(h) ord+=1 return mk("Frame",{Size=UDim2.new(1,0,0,h),BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=ord},body) end
local function lbl(t)
  local r=row(14)
  local bar=mk("Frame",{Size=UDim2.fromOffset(3,10),Position=UDim2.fromOffset(0,2),BorderSizePixel=0},r)
  mk("UICorner",{CornerRadius=UDim.new(1,0)},bar)
  reg(bar,"BackgroundColor3",fAcc)
  reg(mk("TextLabel",{Position=UDim2.fromOffset(9,0),Size=UDim2.new(1,-9,1,0),BackgroundTransparency=1,Text=t,TextXAlignment=Enum.TextXAlignment.Left,Font=Enum.Font.GothamBold,TextSize=10},r),"TextColor3",fSub)
  return r
end
-- Klick-Welle
local function ripple(b,x)
  local s=uis.Scale
  local px=(x.Position.X-b.AbsolutePosition.X)/s
  local py=(x.Position.Y-b.AbsolutePosition.Y)/s
  local d=math.max(b.AbsoluteSize.X,b.AbsoluteSize.Y)/s*2.2
  local r=mk("Frame",{BackgroundColor3=T.acc,BackgroundTransparency=0.7,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(px,py),Size=UDim2.fromOffset(0,0),ZIndex=3},b)
  mk("UICorner",{CornerRadius=UDim.new(1,0)},r)
  tw(r,{Size=UDim2.fromOffset(d,d),BackgroundTransparency=1},.55)
  task.delay(.6,function() r:Destroy() end)
end
local scl,skm={},{}
local function btn(par,txt,i,n,bgf,txf,ts)
  local g=6
  local b=mk("TextButton",{Text=txt,Position=UDim2.new((i-1)/n,(i-1)*g/n,0,0),Size=UDim2.new(1/n,-(n-1)*g/n,1,0),Font=Enum.Font.GothamBold,TextSize=ts or 13,TextScaled=true,AutoButtonColor=false,BorderSizePixel=0,ClipsDescendants=true},par)
  mk("UICorner",{CornerRadius=UDim.new(0,9)},b)
  mk("UITextSizeConstraint",{MaxTextSize=ts or 13,MinTextSize=8},b)
  mk("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4)},b)
  local sc=mk("UIScale",{Scale=1},b)
  local sk=mk("UIStroke",{Thickness=1,Transparency=0.55,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},b)
  reg(sk,"Color",fLine)
  scl[b],skm[b]=sc,sk
  if bgf then reg(b,"BackgroundColor3",bgf) end
  if txf then reg(b,"TextColor3",txf) end
  on(b.InputBegan,function(x)
    if not isIn(x) then return end
    tw(sc,{Scale=0.93},.08)
    tw(sk,{Color=T.acc,Thickness=2,Transparency=0},.08)
    ripple(b,x)
  end)
  on(b.InputEnded,function(x)
    if not isIn(x) then return end
    tw(sc,{Scale=1},.35,Enum.EasingStyle.Back)
    tw(sk,{Color=fLine(T),Thickness=1,Transparency=0.55},.45)
  end)
  return b
end
local bRec=btn(row(40),"Record",1,1,nil,nil,15)
local pRow=row(40)
local bPlay=btn(pRow,"Play",1,2,nil,nil,15)
local bPause=btn(pRow,"Pause",2,2,fBtn,fBtxt,14)
lbl("SLOTS")
local sRow=row(30)
local sRow2=row(30)
local sb={}
for i=1,5 do sb[i]=btn(sRow,tostring(i),i,5,nil,nil,14) end
for i=6,NSLOTS do sb[i]=btn(sRow2,tostring(i),i-5,5,nil,nil,14) end
-- Slot-Name (gehoert zum gewaehlten Slot)
local nBox=mk("TextBox",{Size=UDim2.new(1,0,0,28),Text="",PlaceholderText="Slot name...",ClearTextOnFocus=false,MaxVisibleGraphemes=-1,Font=Enum.Font.GothamBold,TextSize=12,BorderSizePixel=0,TextTruncate=Enum.TextTruncate.AtEnd,LayoutOrder=0},row(28))
mk("UICorner",{CornerRadius=UDim.new(0,9)},nBox)
mk("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},nBox)
reg(nBox,"BackgroundColor3",fBtn) reg(nBox,"TextColor3",fBtxt) reg(nBox,"PlaceholderColor3",fSub)
local function showName() nBox.Text=sname(slot) end
-- Copy Log: versteckt; 10 schnelle Taps auf den Header (Shox Hub) schalten ihn um (wird gespeichert)
local cRow=row(28)
local bCopy=btn(cRow,"Copy Log",1,1,function(t) return t.acc:Lerp(t.bg,0.4) end,fCtxt,12)
local function showCopy()
  cRow.Visible=cfg.dev
  cRow.Size=UDim2.new(1,0,0,cfg.dev and 28 or 0)
end
local dRow=row(28)
local bDelCur=btn(dRow,"Delete Current",1,2,fDel,fCtxt,12)
local bDelSlot=btn(dRow,"Delete Slot",2,2,fDel,fCtxt,12)
lbl("STATS")
local stLbl=mk("TextLabel",{Size=UDim2.new(1,0,0,58),BackgroundTransparency=1,Text="",TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Font=Enum.Font.Gotham,TextSize=11,TextWrapped=true},row(58))
reg(stLbl,"TextColor3",fBtxt)
-- Verlauf: Balken der letzten 10 Runs (neuester rechts)
local histRow=row(30)
local hbars={}
for i=1,10 do
  local f=mk("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.new((i-1)/10,0,1,0),Size=UDim2.new(0.1,-2,0,2),BorderSizePixel=0},histRow)
  mk("UICorner",{CornerRadius=UDim.new(0,2)},f)
  reg(f,"BackgroundColor3",fAcc)
  hbars[i]=f
end
local bStR=btn(row(26),"Reset Stats",1,1,fDel,fCtxt,12)
local function hms(x) x=math.floor(x) return string.format("%d:%02d:%02d",x//3600,(x%3600)//60,x%60) end
local function drawHist()
  local h=cfg.st.hist
  local mx=0
  for _,v in ipairs(h) do if v>mx then mx=v end end
  local off=10-#h
  for i=1,10 do
    local v=h[i-off]
    local px=(v and mx>0) and math.max(4,math.floor(v/mx*28)) or 2
    tw(hbars[i],{Size=UDim2.new(0.1,-2,0,px),BackgroundTransparency=v and 0 or 0.8},.3)
  end
end
-- Coins: nur wenn das Spiel einen Wert mit coin/cash/money in leaderstats hat, sonst bleibt die Zeile weg
local function coinStat()
  local ls=lp:FindFirstChild("leaderstats")
  if not ls then return nil end
  for _,v in ipairs(ls:GetChildren()) do
    if v:IsA("IntValue") or v:IsA("NumberValue") then
      local n=v.Name:lower()
      if n:find("coin",1,true) or n:find("cash",1,true) or n:find("money",1,true) then return v end
    end
  end
end
local function statsTxt()
  local s=cfg.st
  local avg=s.runs>0 and s.time/s.runs or 0
  local ph=s.time>0 and s.runs/(s.time/3600) or 0
  local l="Runs: "..s.runs.."  |  Avg: "..mmss(avg).."\nBest: "..mmss(s.best).."  |  Last: "..mmss(s.last).."\nTotal: "..hms(s.time).."  |  "..string.format("%.1f",ph).." runs/h"
  local cv=coinStat()
  if cv and coin0 then
    local gain=cv.Value-coin0
    local el=sess0 and (os.clock()-sess0) or 0
    l=l.."\nCoins: +"..math.floor(gain).."  ("..math.floor(el>60 and gain/(el/3600) or 0).."/h)"
  end
  stLbl.Text=l
  drawHist()
end
lbl("OPTIONS")
local o1=row(28)
local bRuns=btn(o1,"",1,2,fBtn,fBtxt,12)
local bSize=btn(o1,"",2,2,fBtn,fBtxt,12)
local o2=row(28)
local bTrans=btn(o2,"",1,2,fBtn,fBtxt,12)
local bTheme=btn(o2,"",2,2,fBtn,fBtxt,12)
local o3=row(28)
local bLag=btn(o3,"",1,2,fBtn,fBtxt,12)
local bIntro=btn(o3,"",2,2,fBtn,fBtxt,12)
local o4=row(28)
local bSpeed=btn(o4,"",1,2,fBtn,fBtxt,12)
local bRainbow=btn(o4,"",2,2,fBtn,fBtxt,12)
local DDROWS=math.ceil(#THEMES/2)
local DDH=DDROWS*32-6+8
local ddRow=row(0)
ddRow.ClipsDescendants=true
mk("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4),PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,4)},ddRow)
lbl("DISCORD WEBHOOK")
local hookBox=mk("TextBox",{Size=UDim2.new(1,0,1,0),Text="",PlaceholderText="Webhook URL...",ClearTextOnFocus=true,Font=Enum.Font.GothamBold,TextSize=12,BorderSizePixel=0,TextTruncate=Enum.TextTruncate.AtEnd},row(28))
mk("UICorner",{CornerRadius=UDim.new(0,9)},hookBox)
mk("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},hookBox)
reg(hookBox,"BackgroundColor3",fBtn) reg(hookBox,"TextColor3",fBtxt) reg(hookBox,"PlaceholderColor3",fSub)
local hRow=row(28)
local bHook=btn(hRow,"",1,2,fBtn,fBtxt,12)
local bHookT=btn(hRow,"Test",2,2,fBtn,fBtxt,12)
local bDisc=btn(row(28),"Copy Discord Link",1,1,function(t) return t.acc:Lerp(t.bg,0.4) end,fCtxt,12)
local foot=row(14)
reg(mk("TextLabel",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=DISCORD,TextXAlignment=Enum.TextXAlignment.Left,Font=Enum.Font.Gotham,TextSize=10},foot),"TextColor3",fSub)
local foot2=row(14)
reg(mk("TextLabel",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="Shox Hub | Anti-AFK on",TextXAlignment=Enum.TextXAlignment.Left,Font=Enum.Font.Gotham,TextSize=10},foot2),"TextColor3",fSub)

-- Status: animiert nur bei echter Aenderung; stq = ohne Animation (Ticker)
local function st(t)
  if status.Text==t then return end
  status.Text=t
  status.TextTransparency=0.7
  tw(status,{TextTransparency=0},.3)
end
local function stq(t) status.Text=t end
local function recTxt() return "Stop  "..mmss(os.clock()-t0).."  ("..#steps..")" end
local function updateSlots()
  for n=1,NSLOTS do
    local b=sb[n]
    local sel=n==slot
    tw(b,{BackgroundColor3=sel and T.acc or T.btn,TextColor3=sel and T.bg or (filled[n] and T.btxt or T.sub)},.25)
  end
end
local function ui()
  if not play then paused=false end
  bRec.Text=rec and recTxt() or "Record"
  tw(bRec,{BackgroundColor3=rec and T.ron or T.rec,TextColor3=rec and T.onT or T.ctxt},.3)
  bPlay.Text=play and "Stop" or "Play"
  tw(bPlay,{BackgroundColor3=play and T.pon or T.play,TextColor3=play and T.onT or T.ctxt},.3)
  bPause.Text=paused and "Resume" or "Pause"
  updateSlots()
end
local function optTxt()
  bRuns.Text="Auto S"..slot..": "..(cfg.ap and "On" or "Off")
  bSize.Text="Size: "..SNAME[cfg.scale]
  bTrans.Text="Opacity: "..math.floor((1-TRANS[cfg.trans])*100+0.5).."%"
  bTheme.Text="Theme: "..themeName
  bLag.Text="Anti-Lag: "..(cfg.lag and "On" or "Off")
  bIntro.Text="Intro: "..(cfg.intro and "On" or "Off")
  bSpeed.Text="Speed: "..SPNAME[cfg.speed]
  bRainbow.Text="Rainbow: "..(cfg.rainbow and "On" or "Off")
  bHook.Text="Webhook: "..(cfg.hookOn and "On" or "Off")
end

-- Drag + Minimize
local dIn,dStart,dPos,dLast,dBase
local tapN,tapLast,tapT=0,0,0
-- AbsolutePosition rechnet ohne die Roblox-Leiste oben (GuiInset): Fenster darf bis zum echten Bildschirmrand hoch
local GS=game:GetService("GuiService")
local function bnd()
  local v=workspace.CurrentCamera.ViewportSize
  local ok,ti=pcall(function() return GS:GetGuiInset() end)
  local ins=ok and typeof(ti)=="Vector2" and math.clamp(ti.Y,0,100) or 0
  return v,-ins,v.Y-ins-40
end
local function clampMain()
  pcall(function()
    local v,minY,maxY=bnd()
    local sz,ap=main.AbsoluteSize,main.AbsolutePosition
    local x=math.clamp(ap.X,-sz.X+90,v.X-90)
    local y=math.clamp(ap.Y,minY,maxY)
    if x~=ap.X or y~=ap.Y then
      local p=main.Position
      main.Position=UDim2.new(p.X.Scale,p.X.Offset+(x-ap.X),p.Y.Scale,p.Y.Offset+(y-ap.Y))
    end
  end)
end
on(dragH.InputBegan,function(i)
  if isIn(i) then dIn,dStart,dPos,dLast,dBase=i,i.Position,main.AbsolutePosition,i.Position,main.Position tapT=os.clock() end
end)
on(UIS.InputChanged,function(i)
  if not dIn then return end
  if dIn.UserInputState==Enum.UserInputState.End or dIn.UserInputState==Enum.UserInputState.Cancel then dIn=nil return end -- haengende Eingabe (verpasstes Ende) verwerfen
  local ok=i==dIn or i.UserInputType==Enum.UserInputType.MouseMovement
  if not ok and i.UserInputType==Enum.UserInputType.Touch and dIn.UserInputType==Enum.UserInputType.Touch and (i.Position-dLast).Magnitude<120 then ok=true end
  if not ok then return end
  dLast=i.Position
  local d=i.Position-dStart
  local v,minY,maxY=bnd()
  local sz=main.AbsoluteSize
  local dx=math.clamp(dPos.X+d.X,-sz.X+90,v.X-90)-dPos.X
  local dy=math.clamp(dPos.Y+d.Y,minY,maxY)-dPos.Y
  main.Position=UDim2.new(dBase.X.Scale,dBase.X.Offset+dx,dBase.Y.Scale,dBase.Y.Offset+dy)
end)
on(UIS.InputEnded,function(i)
  if dIn and isIn(i) and (i==dIn or i.UserInputType==dIn.UserInputType) then
    dIn=nil
    local p=main.Position
    cfg.pos={p.X.Scale,p.X.Offset,p.Y.Scale,p.Y.Offset}
    -- 10 schnelle Taps (kaum Bewegung, kurz gedrueckt) auf den Header: Copy Log ein/aus
    if (i.Position-dStart).Magnitude<12 and os.clock()-tapT<0.6 then
      if os.clock()-tapLast>1.5 then tapN=0 end
      tapLast=os.clock()
      tapN+=1
      if tapN>=10 then
        tapN=0
        cfg.dev=not cfg.dev
        showCopy()
      end
    end
    saveCfg()
  end
end)
pcall(function() on(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),clampMain) end)
local bMin=mk("TextButton",{Text="-",Position=UDim2.new(1,-36,0,5),Size=UDim2.fromOffset(26,24),Font=Enum.Font.GothamBold,TextSize=16,AutoButtonColor=false,BorderSizePixel=0},main)
mk("UICorner",{CornerRadius=UDim.new(0,8)},bMin)
local minSc=mk("UIScale",{Scale=1},bMin)
reg(bMin,"BackgroundColor3",fBtn) reg(bMin,"TextColor3",fBtxt)
on(bMin.InputBegan,function(x) if isIn(x) then tw(minSc,{Scale=0.85},.08) end end)
on(bMin.InputEnded,function(x) if isIn(x) then tw(minSc,{Scale=1},.3,Enum.EasingStyle.Back) end end)
local mini=false
on(bMin.MouseButton1Click,function()
  mini=not mini
  bMin.Text=mini and "+" or "-"
  tw(main,{Size=UDim2.fromOffset(220,mini and 34 or WIN_H)},.45,Enum.EasingStyle.Quint)
  task.delay(.5,clampMain)
end)

-- Rahmen-Farbe: Theme-Verlauf oder Regenbogen
local RAINBOW=ColorSequence.new({
  ColorSequenceKeypoint.new(0,C(255,60,60)),
  ColorSequenceKeypoint.new(0.17,C(255,200,40)),
  ColorSequenceKeypoint.new(0.34,C(80,255,80)),
  ColorSequenceKeypoint.new(0.5,C(40,220,255)),
  ColorSequenceKeypoint.new(0.67,C(80,100,255)),
  ColorSequenceKeypoint.new(0.84,C(255,70,220)),
  ColorSequenceKeypoint.new(1,C(255,60,60)),
})
local function borderFx()
  if cfg.rainbow then
    mGrad.Color=RAINBOW
  else
    mGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.acc),ColorSequenceKeypoint.new(0.5,T.acc:Lerp(T.bg,0.75)),ColorSequenceKeypoint.new(1,T.acc)})
  end
end

-- Theme-Dropdown (gleitet auf/zu, Eintraege blenden gestaffelt ein)
local applyTheme
local ddOpen=false
local ddItems={}
local function follow(t)
  task.spawn(function()
    local e=os.clock()
    while alive and os.clock()-e<t do
      body.CanvasPosition=Vector2.new(0,99999)
      RS.Heartbeat:Wait()
    end
  end)
end
local function setDD(open)
  ddOpen=open
  tw(ddRow,{Size=UDim2.new(1,0,0,open and DDH or 0)},open and .5 or .3,QI)
  for i,e in ipairs(ddItems) do
    local it,sk=e[1],e[2]
    if open then it.BackgroundTransparency=1 it.TextTransparency=1 sk.Transparency=1 end
    task.delay(open and i*0.05 or 0,function()
      local v=open and 0 or 1
      tw(it,{BackgroundTransparency=v,TextTransparency=v},.3)
      tw(sk,{Transparency=v},.3)
    end)
  end
  if open then follow(.55) end
end
for idx,th in ipairs(THEMES) do
  local col,rw=(idx-1)%2,(idx-1)//2
  local p=th[2]
  local full=(idx==#THEMES and #THEMES%2==1)
  local it=mk("TextButton",{Text=th[1],Position=full and UDim2.new(0,0,0,rw*32) or UDim2.new(col*0.5,col==1 and 3 or 0,0,rw*32),Size=full and UDim2.new(1,0,0,26) or UDim2.new(0.5,-3,0,26),BackgroundColor3=p.bg,TextColor3=p.acc,Font=Enum.Font.GothamBold,TextSize=12,AutoButtonColor=false,BorderSizePixel=0},ddRow)
  mk("UICorner",{CornerRadius=UDim.new(0,8)},it)
  local isc=mk("UIScale",{Scale=1},it)
  local sk=mk("UIStroke",{Color=p.acc,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},it)
  ddItems[idx]={it,sk,th[1]}
  on(it.InputBegan,function(x) if isIn(x) then tw(isc,{Scale=0.94},.08) end end)
  on(it.InputEnded,function(x) if isIn(x) then tw(isc,{Scale=1},.3,Enum.EasingStyle.Back) end end)
  on(it.MouseButton1Click,function() applyTheme(th[1]) setDD(false) end)
end
applyTheme=function(name,quick)
  if not TM[name] then return end
  T,themeName=TM[name],name
  cfg.theme=name
  borderFx()
  for _,e in ipairs(themed) do
    local v=e[3](T)
    if quick then e[1][e[2]]=v else tw(e[1],{[e[2]]=v},.4) end
  end
  for _,e in ipairs(ddItems) do
    local sel=e[3]==name
    if quick then e[2].Thickness=sel and 3 or 1 else tw(e[2],{Thickness=sel and 3 or 1},.3) end
  end
  optTxt()
  ui()
  if not quick then saveCfg() end
end
on(bTheme.MouseButton1Click,function() setDD(not ddOpen) end)

local alRun
-- Anti-Lag (casual FPS boost, vollstaendig rueckgaengig machbar)
-- Aus: Partikel/Trails/Beams/Feuer/Rauch, Post-Effekte (Bloom, Blur, SunRays, DoF, ColorCorrection), Schatten, Reflexionen, Materialien -> SmoothPlastic, Qualitaet Level01, Terrain-Deko/Wellen
local LS=game:GetService("Lighting")
local AL={on=false,gen=0,orig=setmetatable({},{__mode="k"}),conn=nil,env=nil}
local FX={ParticleEmitter=true,Trail=true,Beam=true,Smoke=true,Fire=true,Sparkles=true,BloomEffect=true,BlurEffect=true,ColorCorrectionEffect=true,DepthOfFieldEffect=true,SunRaysEffect=true}
local function alApply(x)
  if FX[x.ClassName] then
    if AL.orig[x]==nil then AL.orig[x]=x.Enabled end
    x.Enabled=false
  elseif x:IsA("BasePart") and not x:IsA("Terrain") and x.Material~=Enum.Material.Neon then
    if AL.orig[x]==nil then AL.orig[x]={x.Material,x.Reflectance,x.CastShadow} end
    x.Material=Enum.Material.SmoothPlastic
    x.Reflectance=0
    x.CastShadow=false
  end
end
alRun=function(enable)
  AL.gen+=1
  local my=AL.gen
  AL.on=enable
  if AL.conn then AL.conn:Disconnect() AL.conn=nil end
  if enable then
    if not AL.env then
      local e={gs=LS.GlobalShadows}
      pcall(function() e.q=settings().Rendering.QualityLevel end)
      pcall(function() local t=workspace.Terrain e.dec,e.ww,e.ws=t.Decoration,t.WaterWaveSize,t.WaterWaveSpeed end)
      AL.env=e
    end
    pcall(function() LS.GlobalShadows=false end)
    pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Level01 end)
    pcall(function() local t=workspace.Terrain t.Decoration=false t.WaterWaveSize=0 t.WaterWaveSpeed=0 end)
    for _,x in ipairs(LS:GetChildren()) do pcall(alApply,x) end
    AL.conn=on(workspace.DescendantAdded,function(x) if AL.on then pcall(alApply,x) end end)
    task.spawn(function()
      local n=0
      for _,x in ipairs(workspace:GetDescendants()) do
        if AL.gen~=my then return end
        pcall(alApply,x)
        n+=1
        if n%400==0 then task.wait() end
      end
    end)
  else
    local e=AL.env
    if e then
      AL.env=nil
      pcall(function() LS.GlobalShadows=e.gs end)
      pcall(function() if e.q then settings().Rendering.QualityLevel=e.q end end)
      pcall(function() local t=workspace.Terrain t.Decoration,t.WaterWaveSize,t.WaterWaveSpeed=e.dec,e.ww,e.ws end)
    end
    local list={}
    for x,v in pairs(AL.orig) do list[#list+1]={x,v} end
    task.spawn(function()
      for i,e2 in ipairs(list) do
        if AL.gen~=my then return end
        local x,v=e2[1],e2[2]
        pcall(function()
          if x.Parent then
            if type(v)=="table" then x.Material,x.Reflectance,x.CastShadow=v[1],v[2],v[3] else x.Enabled=v end
          end
        end)
        AL.orig[x]=nil
        if i%400==0 then task.wait() end
      end
    end)
  end
end

-- Optionen
local function cyc(b,key,list,after)
  on(b.MouseButton1Click,function()
    cfg[key]=cfg[key]%#list+1
    if after then after() end
    optTxt() saveCfg()
  end)
end
cyc(bSize,"scale",SCALES,function() tw(uis,{Scale=SCALES[cfg.scale]},.4,Enum.EasingStyle.Back) task.delay(.5,clampMain) end)
cyc(bTrans,"trans",TRANS,function() tw(main,{BackgroundTransparency=TRANS[cfg.trans]},.3) end)
cyc(bSpeed,"speed",SPEEDS)
on(bRainbow.MouseButton1Click,function()
  cfg.rainbow=not cfg.rainbow
  borderFx()
  optTxt() saveCfg()
end)
on(bLag.MouseButton1Click,function()
  cfg.lag=not cfg.lag
  alRun(cfg.lag)
  optTxt() saveCfg()
  st(cfg.lag and "Anti-Lag on" or "Anti-Lag off")
end)
on(bIntro.MouseButton1Click,function()
  cfg.intro=not cfg.intro
  if not cfg.intro then
    if introS then pcall(function() introS:Stop() introS:Destroy() end) introS=nil end
    if introG then pcall(function() introG:Destroy() end) introG=nil end
  end
  optTxt() saveCfg()
end)

-- Intro-Song: einmal beim Start (Datei .mp3/.ogg in ShoxHub/music/ oder ShoxHub/, Name mit "intro" wird bevorzugt)
local function findIntro()
  for _,d in ipairs({MDIR,DIR}) do
    local ok,l=pcall(listfiles,d)
    if ok and type(l)=="table" then
      local first
      for _,f in ipairs(l) do
        local e=f:match("%.(%w+)$")
        e=e and e:lower()
        if e=="mp3" or e=="ogg" then
          if f:lower():find("intro",1,true) then return f end
          first=first or f
        end
      end
      if first then return first end
    end
  end
end

-- Beat-Intro: Zeitplan in Sekunden ab Songstart (abgestimmt auf die 5,06-s-Intro-Datei)
-- {Zeit, Staerke, Art}: a = SHOX knallt rein, b = HUB knallt rein, drop = Drop, end = Finale
local LET={"S","H","O","X","H","U","B"}
local BEATS={{0.05,1,"a"},{0.52,1,"b"},{0.84,0.6},{1.28,0.9},{1.58,0.5},{1.88,0.9},{2.11,0.6},{2.48,2.2,"drop"},{3.15,1},{3.74,1},{4.34,1.2},{4.75,1.7,"end"}}
local FADE0,FADE1=4.95,5.5
local function introFx(snd)
  local ig=mk("ScreenGui",{ResetOnSpawn=false,IgnoreGuiInset=true,Name=rname(),DisplayOrder=999},guiParent())
  pcall(function() if syn and syn.protect_gui then syn.protect_gui(ig) end end)
  introG=ig
  local vp=workspace.CurrentCamera.ViewportSize
  local base=math.clamp(math.min(vp.X*0.6/376,vp.Y*0.4/80),0.5,3)
  local bg=mk("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=T.bg,BorderSizePixel=0},ig)
  local stage=mk("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0},ig)
  local sc=mk("UIScale",{Scale=base},stage)
  local L={}
  for i,ch in ipairs(LET) do
    local x=-163+(i-1)*50+(i>=5 and 26 or 0)
    local w=mk("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,x,.5,-10),Size=UDim2.fromOffset(50,80),BackgroundTransparency=1,BorderSizePixel=0},stage)
    local us=mk("UIScale",{Scale=1},w)
    local lb=mk("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text=ch,Font=Enum.Font.GothamBlack,TextSize=76,TextColor3=T.acc,TextTransparency=1},w)
    L[i]={w=w,us=us,lb=lb,x=x,hit=-10,amp=0,rev=math.huge}
  end
  local line=mk("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,52),Size=UDim2.fromOffset(0,4),BackgroundColor3=T.acc,BorderSizePixel=0},stage)
  local sub=mk("TextLabel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,80),Size=UDim2.fromOffset(376,22),BackgroundTransparency=1,Text=DISCORD,Font=Enum.Font.GothamBold,TextSize=17,TextColor3=T.sub,TextTransparency=1},stage)
  local fl=mk("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=T.acc,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=5},ig)
  -- Skip-Button oben rechts (Theme-Look wie die Buttons im Hub)
  local skip=mk("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,0,14),Size=UDim2.fromOffset(78,32),BackgroundColor3=T.btn,Text="Skip",TextColor3=T.btxt,Font=Enum.Font.GothamBold,TextSize=14,AutoButtonColor=false,BorderSizePixel=0,ZIndex=10},ig)
  mk("UICorner",{CornerRadius=UDim.new(0,9)},skip)
  local skS=mk("UIStroke",{Color=T.acc,Thickness=1,Transparency=0.55,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},skip)
  local skU=mk("UIScale",{Scale=1},skip)
  on(skip.InputBegan,function(x) if isIn(x) then tw(skU,{Scale=0.93},.08) end end)
  on(skip.InputEnded,function(x) if isIn(x) then tw(skU,{Scale=1},.3,Enum.EasingStyle.Back) end end)
  local function spark(n,wide)
    for _=1,n do
      local a=math.random()*math.pi*2
      local d=(wide and 260 or 130)*(0.4+math.random()*0.8)
      local sx=L[math.random(1,#L)].x
      local p=mk("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,sx,.5,-10),Size=UDim2.fromOffset(6,6),Rotation=math.random(0,90),BackgroundColor3=T.acc,BorderSizePixel=0},stage)
      tw(p,{Position=UDim2.new(.5,sx+math.cos(a)*d,.5,-10+math.sin(a)*d),BackgroundTransparency=1,Size=UDim2.fromOffset(2,2)},0.55)
      task.delay(0.6,function() p:Destroy() end)
    end
  end
  local function ring(th)
    local r=mk("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,-10),Size=UDim2.fromOffset(40,40),BackgroundTransparency=1,BorderSizePixel=0},stage)
    mk("UICorner",{CornerRadius=UDim.new(1,0)},r)
    local sk=mk("UIStroke",{Thickness=th,Color=T.acc},r)
    tw(r,{Size=UDim2.fromOffset(820,820)},0.7)
    tw(sk,{Transparency=1},0.7)
    task.delay(0.8,function() r:Destroy() end)
  end
  local tl,bi,pulse,shake,flashA,ul,subA=0,1,0,0,0,0,0
  local done,hb=false,nil
  local function finish(stop)
    if done then return end
    done=true
    if hb then hb:Disconnect() end
    if stop then
      pcall(function() snd:Stop() snd:Destroy() end)
      if introS==snd then introS=nil end
    end
    if introG==ig then introG=nil end
    ig:Destroy()
  end
  on(skip.MouseButton1Click,function() finish(true) end)
  local function fire(b)
    local s,kind=b[2],b[3]
    pulse=math.max(pulse,0.05+0.06*s)
    shake=math.max(shake,6*s)
    flashA=math.max(flashA,math.min(0.1*s,0.35))
    local a,z,amp=1,#L,0.3*s
    if kind=="a" then a,z,amp=1,4,1.6 elseif kind=="b" then a,z,amp=5,7,1.6 end
    for i=a,z do
      local e=L[i]
      e.hit=tl+(i-a)*0.035
      e.amp=amp
      if amp>1 then e.rev=e.hit end
    end
    if kind=="drop" then
      pulse=0.35 shake=26 flashA=0.75
      ring(6) task.delay(0.12,function() ring(3) end)
      spark(24,true)
    elseif kind=="end" then
      pulse=0.3 shake=20 flashA=0.6
      ring(5) spark(18,true)
    else
      spark(math.floor(4*s)+2,false)
    end
  end
  hb=on(RS.Heartbeat,function(dt)
    if done then return end
    if snd.IsPlaying then tl=snd.TimePosition else tl+=dt end
    while BEATS[bi] and tl>=BEATS[bi][1] do fire(BEATS[bi]) bi+=1 end
    local f=math.clamp((tl-FADE0)/(FADE1-FADE0),0,1)
    pulse*=math.exp(-dt*7) shake*=math.exp(-dt*9) flashA*=math.exp(-dt*8)
    local sh=shake>0.3 and shake or 0
    stage.Position=UDim2.new(.5,(math.random()-.5)*2*sh,.5,(math.random()-.5)*2*sh)
    stage.Rotation=(math.random()-.5)*0.3*sh
    sc.Scale=base*(1+pulse)*(1+f*0.5)
    fl.BackgroundTransparency=1-flashA
    bg.BackgroundTransparency=f
    for i,e in ipairs(L) do
      local age=tl-e.hit
      e.lb.TextTransparency=(tl>=e.rev) and f or 1
      local d=age>=0 and math.exp(-age*5.5) or 0
      e.w.Position=UDim2.new(.5,e.x,.5,-10-(age>=0 and math.abs(math.sin(age*12))*22*d or 0))
      e.w.Rotation=age>=0 and math.sin(age*10)*7*d*(i%2==0 and 1 or -1) or 0
      e.us.Scale=1+(age>=0 and e.amp*math.exp(-age*8) or 0)
    end
    if tl>=0.84 then ul=math.min(1,ul+dt*3.5) end
    line.Size=UDim2.fromOffset(376*ul,4)
    line.BackgroundTransparency=f
    if tl>=3.15 then subA=math.min(1,subA+dt*5) end
    sub.TextTransparency=math.max(1-subA,f)
    skip.BackgroundTransparency=f
    skip.TextTransparency=f
    skS.Transparency=math.max(0.55,f)
    if tl>=FADE1 then finish(false) end
  end)
end
local function playIntro()
  if not cfg.intro then return end
  if not (listfiles and getcustomasset) then st("Intro: listfiles/getcustomasset missing") return end
  local f=findIntro()
  if not f then st("Intro: no file in "..MDIR) return end
  local ok,id=pcall(getcustomasset,f)
  if not ok or not id then st("Intro: load error") return end
  local s=Instance.new("Sound")
  s.Volume=0.6 s.SoundId=id s.Looped=false
  s.Parent=game:GetService("SoundService")
  introS=s
  on(s.Ended,function() if introS==s then introS=nil end s:Destroy() end)
  s:Play()
  local w=os.clock()
  while alive and s.Parent and not s.IsPlaying and os.clock()-w<8 do task.wait(0.05) end
  if not alive or not cfg.intro then return end
  if not s.IsPlaying and not s.IsLoaded then
    s:Destroy() if introS==s then introS=nil end
    st("Intro: failed to load (format?)")
    return
  end
  introFx(s)
end

-- Auto-Download des Intro-Songs (findIntro/introFx/playIntro bleiben unveraendert)
-- Probiert INTRO_URL (GitHub raw), danach INTRO_URL2 (Reserve). Jede Antwort wird per Dateikopf (OggS/ID3/MP3) geprueft.
local idbg={}
local function ilog(s) idbg[#idbg+1]=os.date("%H:%M:%S").." "..s end
local function audioExt(b)
  if type(b)~="string" or #b<1000 then return nil end
  local h=b:sub(1,4)
  if h=="OggS" then return "ogg" end
  if h:sub(1,3)=="ID3" or b:byte(1)==255 then return "mp3" end
end
local function dlData(url)
  local rq=request or http_request or (syn and syn.request)
  if rq then
    local ok,r=pcall(rq,{Url=url,Method="GET"})
    if ok and type(r)=="table" then
      ilog("request status="..tostring(r.StatusCode).." len="..tostring(type(r.Body)=="string" and #r.Body or "-"))
      local ext=audioExt(r.Body)
      if ext then return r.Body,ext end
      if type(r.Body)=="string" then ilog("request body head="..(r.Body:sub(1,4):gsub("[^%w]","?"))) end
    else ilog("request failed: "..tostring(r)) end
  else ilog("no request function") end
  local ok,b=pcall(function() return game:HttpGet(url) end)
  if ok then
    ilog("HttpGet len="..tostring(type(b)=="string" and #b or "-"))
    local ext=audioExt(b)
    if ext then return b,ext end
  else ilog("HttpGet failed: "..tostring(b)) end
end
local function ensureIntro()
  if not cfg.intro then return end
  if not (writefile and listfiles and getcustomasset) then ilog("executor lacks writefile/listfiles/getcustomasset") return end
  local f=findIntro()
  if f then ilog("intro file exists: "..tostring(f)) return end
  st("Intro: downloading...")
  local data,ext
  for n,u in ipairs({INTRO_URL,INTRO_URL2}) do
    if u~="" then
      ilog("try url"..n..": "..u)
      data,ext=dlData(u)
      if data then ilog("url"..n.." ok, len="..#data) break end
    end
  end
  if not data then st("Intro: download failed (Copy Log)") ilog("download failed") return end
  local p=MDIR.."/intro."..ext
  local okw,e=pcall(writefile,p,data)
  ilog("writefile ok="..tostring(okw).." err="..tostring(e).." len="..#data)
  if not okw then st("Intro: could not save file") return end
  local okr,back=pcall(readfile,p)
  ilog("readback len="..tostring(okr and #back or back))
  ilog("findIntro now: "..tostring(findIntro()))
end

G.ShoxOff=function()
  alive=false rec,play=false,false gen+=1
  G.ShoxH=nil
  G.ShoxAK=false
  pcall(function() if introS then introS:Stop() introS:Destroy() end end)
  pcall(function() if introG then introG:Destroy() end end)
  pcall(alRun,false)
  for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
  gui:Destroy()
end

-- Aufnahme
local function add(tt,k,p,m,a)
  if #steps>=15000 then return end
  local e={}
  for i=1,a.n do e[i]=enc(a[i]) end
  if k=="R" or k=="B" then
    local key=k..HS:JSONEncode({p,tostring(m),e})
    if key==lastK and tt-lastT<DEDUP then return end
    lastK,lastT=key,tt
  end
  local s={t=tt,k=k,p=p,m=m,a=e,n=a.n}
  steps[#steps+1]=s
  return s
end
G.ShoxH=function(self,m,...)
  if not (alive and rec) then return end
  local tt,a=os.clock()-t0,table.pack(...)
  task.spawn(pcall,function()
    if typeof(self)=="Instance" and not IGNORE[self.Name] then
      local s=add(tt,"R",path(self),m,a)
      if s and self.Name==ADD then
        local bf=gather()
        local id,n=newId(bf,s)
        if id then s.tid=id st("Tower-Id "..id:sub(1,8).." ("..n..")")
        else st("Tower-Id: none ("..n..")") end
      elseif s and USE[self.Name] and not idloc then
        idloc=true
        s.loc=locate(tkey(s,"Id"))
      end
    end
  end)
end
-- Namecall-Hook: Anti-Kick (lp:Kick) + Remote-Aufnahme. Wird pro Session nur einmal installiert.
if not G.ShoxHook then
  G.ShoxHook=pcall(function()
    local o
    o=hookmetamethod(game,"__namecall",newcclosure(function(self,...)
      local m=getnamecallmethod()
      if G.ShoxAK and self==lp and type(m)=="string" and m:lower()=="kick" then return end
      local h=G.ShoxH
      if h and (m=="FireServer" or m=="InvokeServer") and not checkcaller() then
        pcall(h,self,m,...)
        pcall(setnamecallmethod,m)
      end
      return o(self,...)
    end))
  end)
end
if not G.ShoxHook then st("hookmetamethod missing: no remotes, no anti-kick!") end
local hooked=setmetatable({},{__mode="k"})
local function hookBtn(b)
  if b:IsA("GuiButton") and not hooked[b] and not b:IsDescendantOf(gui) and not (introG and b:IsDescendantOf(introG)) then
    hooked[b]=true
    on(b.Activated,function()
      if rec then add(os.clock()-t0,"B",path(b),b:IsA("TextButton") and b.Text or "",{n=0}) end
    end)
  end
end
local pg=lp:WaitForChild("PlayerGui")
for _,o in ipairs(pg:GetDescendants()) do hookBtn(o) end
on(pg.DescendantAdded,hookBtn)

-- Effekte pro Frame (Rahmen-Rotation, Titel-Glanz, Puls bei Record/Play) + Anzeige alle 0.5s
local pulsers={{bRec,function() return rec end},{bPlay,function() return play end}}
local ac2,ac3=0,0
on(RS.Heartbeat,function(dt)
  local c=os.clock()
  mGrad.Rotation=(c*50)%360
  titleG.Offset=Vector2.new((c*0.5)%2-1,0)
  local a=(math.sin(c*5)+1)/2
  for _,p in ipairs(pulsers) do
    local sk=skm[p[1]]
    if p[2]() then
      p.on=true
      sk.Color=T.acc sk.Thickness=1.5+a*2 sk.Transparency=0.5*(1-a)
    elseif p.on then
      p.on=false
      sk.Color=fLine(T) sk.Thickness=1 sk.Transparency=0.55
    end
  end
  ac2+=dt
  if ac2<0.5 then return end
  ac2=0
  -- minimiert: Titel zeigt Run-Zeit bzw. Aufnahmezeit
  local ttl="Shox Hub"
  if mini then
    if play and runT0 then ttl="Run "..runI.." | "..mmss(os.clock()-runT0)
    elseif rec then ttl="Rec "..mmss(os.clock()-t0) end
  end
  if title.Text~=ttl then title.Text=ttl end
  if rec then bRec.Text=recTxt()
  elseif play and runT0 then
    local lim=RUNS[cfg.runs]
    if paused then stq("Paused | Run "..runI)
    elseif waitEnd then stq("Run "..runI.." | waiting for Play Again...")
    else stq("Run "..runI..(lim>0 and ("/"..lim) or "").." | "..mmss(os.clock()-runT0).." / "..mmss(runTot)) end
  end
  if play then
    ac3+=1
    if ac3>=10 then ac3=0 pcall(statsTxt) end
  end
end)

-- Abspielen
local function lg(e) if #rlog<300 then rlog[#rlog+1]=e end end
local function skipB(s)
  local nm=(table.concat(s.p,"."):gsub("\1","#")..tostring(s.m)):lower()
  for _,w in ipairs(SKIPB) do if nm:find(w,1,true) then return true end end
end
-- Pause: haelt den Ablauf an und gibt die Pausenzeit zurueck (Zeitplan wird entsprechend verschoben)
local function pauseGate(my)
  local p=0
  while paused and play and gen==my do
    local p0=os.clock()
    task.wait(0.2)
    p+=os.clock()-p0
  end
  return p
end
-- Ende-Erkennung: "Play Again" wird erst ausgefuehrt, wenn der Endbildschirm wirklich sichtbar ist
local function vis(x)
  local o=x
  while o and o~=pg do
    if o:IsA("GuiObject") and not o.Visible then return false end
    if o:IsA("LayerCollector") and not o.Enabled then return false end
    o=o.Parent
  end
  if o~=pg then return false end
  if (x:IsA("TextLabel") or x:IsA("TextButton")) and x.TextTransparency>=0.99 then return false end
  local sz,ps=x.AbsoluteSize,x.AbsolutePosition
  local v=workspace.CurrentCamera.ViewportSize
  return sz.X>0 and sz.Y>0 and ps.X<v.X and ps.Y<v.Y and ps.X+sz.X>0 and ps.Y+sz.Y>0
end
local function paScan() -- sichtbarer Button, ob ueberhaupt ein "Play Again"-Text existiert
  local ex
  for _,x in ipairs(pg:GetDescendants()) do
    if (x:IsA("TextButton") or x:IsA("TextLabel")) and not x:IsDescendantOf(gui) and x.Text:lower():find("play again",1,true) then
      ex=true
      if vis(x) then return (x:IsA("GuiButton") and x) or x:FindFirstAncestorWhichIsA("GuiButton") or x,true end
    end
  end
  return nil,ex
end
local function isEnd(s)
  local nm=(table.concat(s.p,"."):gsub("\1%d+","")..tostring(s.m)):lower()
  return nm:find("playagain",1,true) or nm:find("play again",1,true)
end
local function runOnce(my)
  idmap={}
  local sp=SPEEDS[cfg.speed] or 1
  local ordl,inOrd,oi={},{},0
  local hasRPA=false
  for _,s in ipairs(steps) do
    if s.k=="R" then
      if USE[(s.p[#s.p]:gsub("\1%d+$",""))] then
        local id=tkey(s,"Id")
        if type(id)=="string" and not inOrd[id] then inOrd[id]=true ordl[#ordl+1]=id end
      end
      if isEnd(s) then hasRPA=true end
    end
  end
  local tset,orph={},{}
  for _,s in ipairs(steps) do if s.tid then tset[s.tid]=true end end
  for _,id in ipairs(ordl) do if not tset[id] then orph[#orph+1]=id end end
  local base,pk,pt=os.clock(),nil,0
  local paAt,fired=-10,false
  runT0,runTot=base,(steps[#steps] and steps[#steps].t or 0)/sp
  for idx,s in ipairs(steps) do
    if not play or gen~=my then return end
    base+=pauseGate(my)
    if not play or gen~=my then return end
    local tt=s.t/sp
    local key=s.k..HS:JSONEncode({s.p,tostring(s.m),s.a})
    if key==pk and s.t-pt<DEDUP then pt=s.t continue end
    pk,pt=key,s.t
    if s.k=="B" and skipB(s) then continue end
    if isEnd(s) then
      if s.k=="B" and hasRPA then continue end -- Remote PlayAgain uebernimmt
      waitEnd=true
      local t=os.clock()
      local b,ex
      while play and gen==my do
        b,ex=paScan()
        if b then break end
        if not ex and os.clock()>base+tt+60 then break end -- kein Play-Again-Text auffindbar: nach Aufnahmezeit+60s trotzdem
        if os.clock()-t>900 then break end
        task.wait(0.5)
      end
      waitEnd=false
      if not play or gen~=my then return end
      task.wait(0.4)
      local info={i=idx,pa=math.floor(os.clock()-t),btn=b and b.Name or "keiner"}
      if os.clock()-paAt<3 then
        info.skip=1
      elseif s.k=="R" then
        local o=find(s.p)
        if o then
          local a=decArgs(s)
          local ok,res=pcall(function()
            if s.m=="FireServer" then return o:FireServer(table.unpack(a,1,s.n)) end
            return o:InvokeServer(table.unpack(a,1,s.n))
          end)
          info.ok=ok
          if not ok then info.e=tostring(res) end
        else info.nf=1 end
        paAt=os.clock() fired=true
      else
        local bb=b or find(s.p)
        if bb and bb:IsA("GuiButton") then
          pcall(firesignal,bb.Activated)
          pcall(firesignal,bb.MouseButton1Click)
          info.ok=true
        else info.nf=1 end
        paAt=os.clock() fired=true
      end
      lg(info)
      continue
    end
    local w=base+tt-os.clock()
    while w>0 and play and gen==my do
      task.wait(math.min(w,0.25))
      base+=pauseGate(my)
      w=base+tt-os.clock()
    end
    if not play or gen~=my then return end
    local o=find(s.p)
    if not o then
      miss+=1
      lg({i=idx,nf=table.concat(s.p,"/")})
    elseif s.k=="R" and USE[o.Name] and not idmap[tkey(s,"Id")] then
      lg({i=idx,n=o.Name,nomap=tostring(tkey(s,"Id")):sub(1,8)})
    elseif s.k=="R" and o.Name==ADD then
      local a=decArgs(s)
      local bf=gather()
      local ok,res=pcall(function()
        if s.m=="FireServer" then return o:FireServer(table.unpack(a,1,s.n)) end
        return o:InvokeServer(table.unpack(a,1,s.n))
      end)
      local id,n=newId(bf,s)
      local via
      if s.tid and id then idmap[s.tid]=id via="tid" end
      if not (s.tid and inOrd[s.tid]) then
        oi+=1
        local oid=orph[oi]
        if id and oid and not idmap[oid] then
          idmap[oid]=id via=(via and via.."+" or "").."ord"..oi
        end
      end
      lg({i=idx,n=o.Name,ok=ok,e=(not ok) and tostring(res) or nil,neu=n,via=via,got=id and id:sub(1,8)})
    else
      task.spawn(function()
        if s.k=="R" then
          local a=decArgs(s)
          local ok,res=pcall(function()
            if s.m=="FireServer" then return o:FireServer(table.unpack(a,1,s.n)) end
            return o:InvokeServer(table.unpack(a,1,s.n))
          end)
          if (not ok) or USE[o.Name] then
            lg({i=idx,n=o.Name,ok=ok,e=(not ok) and tostring(res) or nil,id=USE[o.Name] and tostring(type(a[1])=="table" and a[1].Id):sub(1,8) or nil})
          end
        elseif firesignal then
          local ok,e=pcall(firesignal,o.Activated)
          if not ok then lg({i=idx,b=o.Name,ok=ok,e=tostring(e)}) end
        end
      end)
    end
  end
  if fired then -- naechster Run erst, wenn der Endbildschirm weg ist (max. 60 s)
    waitEnd=true
    local t=os.clock()
    while play and gen==my and os.clock()-t<60 and paScan() do task.wait(0.5) end
    waitEnd=false
  end
end

-- Discord-Webhook: Meldung nach jedem Run (nur wenn eingeschaltet und gueltige URL gesetzt)
local function hookUrl()
  local u=cfg.hook
  if type(u)~="string" then return nil end
  if u:find("^https://discord.com/api/webhooks/") or u:find("^https://discordapp.com/api/webhooks/") or u:find("^https://canary.discord.com/api/webhooks/") or u:find("^https://ptb.discord.com/api/webhooks/") then return u end
  return nil
end
local function sendHook(ttl,fields)
  local u=hookUrl()
  local rq=request or http_request or (syn and syn.request)
  if not u or not rq then return false end
  local ok,r=pcall(rq,{
    Url=u,Method="POST",Headers={["Content-Type"]="application/json"},
    Body=HS:JSONEncode({username="Shox Hub",embeds={{title=ttl,color=5793266,fields=fields,footer={text="Shox Hub v7.16"}}}})
  })
  if not ok or type(r)~="table" then return false end
  local sc=r.StatusCode
  return sc==nil or (sc>=200 and sc<300)
end
local function sendReport(i,took)
  local s=cfg.st
  local nm=sname(slot)
  local f={
    {name="Run",value=tostring(i),inline=true},
    {name="Time",value=mmss(took),inline=true},
    {name="Slot",value=tostring(slot)..(nm~="" and (" ("..nm..")") or ""),inline=true},
    {name="Total runs",value=tostring(s.runs),inline=true},
    {name="Avg",value=mmss(s.runs>0 and s.time/s.runs or 0),inline=true},
    {name="Runs/h",value=string.format("%.1f",s.time>0 and s.runs/(s.time/3600) or 0),inline=true},
  }
  local cv=coinStat()
  if cv and coin0 then f[#f+1]={name="Coins",value="+"..math.floor(cv.Value-coin0),inline=true} end
  return sendHook("Run "..i.." done",f)
end
local function showHook() hookBox.Text=hookUrl() and "Webhook saved" or "" end

-- Slots + Zusammenfassung
local function file(n) return DIR.."/slot"..n..".json" end
local function stats()
  local c={R=0,B=0}
  for _,s in ipairs(steps) do if c[s.k] then c[s.k]+=1 end end
  return c.R.."R "..c.B.."B"
end
local function pstr(p) return (table.concat(p,"."):gsub("\1","#")) end
local function fl(a) local r={} for i,x in ipairs(a) do r[i]=string.format("%.1f",x) end return table.concat(r,",") end
local function show(o)
  if type(o)~="table" then return type(o)=="string" and ("'"..o.."'") or tostring(o) end
  local t=o.t
  if t=="V3" or t=="V2" or t=="C3" then return t.."("..fl(o.v)..")"
  elseif t=="CF" then return "CF("..fl({o.v[1],o.v[2],o.v[3]})..")"
  elseif t=="I" then return "<"..pstr(o.p)..">"
  elseif t=="T" then
    local p={}
    for _,kv in ipairs(o.v) do p[#p+1]=show(kv[1]).."="..show(kv[2]) end
    return "{"..table.concat(p,",").."}"
  end
  return tostring(o.s or t)
end
local function summary()
  local L={}
  local function put(l) L[#L+1]=l:sub(1,220) end
  put("Shox Hub Slot "..slot.." | "..stats().." | runs="..RUNS[cfg.runs].." lag="..tostring(cfg.lag).." speed="..SPNAME[cfg.speed])
  for _,s in ipairs(steps) do
    if s.loc then L[#L+1]=("IdLoc: "..s.loc):sub(1,400) break end
  end
  for _,s in ipairs(steps) do
    if s.k=="R" then
      local a={}
      for i=1,s.n do a[i]=show(s.a[i]) end
      put(string.format("%.2f R %s %s(%s)%s",s.t,s.m=="InvokeServer" and "Inv" or "Fire",pstr(s.p),table.concat(a,", "),s.tid and (" tid="..s.tid:sub(1,8)) or ""))
    elseif s.k=="B" then put(string.format("%.2f B %s '%s'",s.t,pstr(s.p),tostring(s.m))) end
  end
  put("--- LOG ---")
  for _,l in ipairs(rlog) do pcall(function() put(HS:JSONEncode(l)) end) end
  put("--- INTRO ---")
  for _,l in ipairs(idbg) do put(l) end
  return table.concat(L,"\n")
end
local function loadSlot(n)
  local ok,r=pcall(function() return HS:JSONDecode(readfile(file(n))) end)
  steps={}
  if ok and type(r)=="table" then
    for _,s in ipairs(r) do if s.k=="R" or s.k=="B" then steps[#steps+1]=s end end -- alte Move-Schritte raus
  end
  filled[n]=#steps>0
  showName()
  local nm=sname(n)
  local lab="Slot "..n..(nm~="" and (" ("..nm..")") or "")
  st(#steps>0 and (lab..": "..stats()) or (lab.." is empty"))
  ui()
end
local function confirm(b,txt,fn)
  local armed,tok=false,0
  on(b.MouseButton1Click,function()
    tok+=1
    if not armed then
      armed=true
      local my=tok
      b.Text="Sure?"
      task.delay(2,function() if tok==my then armed=false b.Text=txt end end)
      return
    end
    armed=false b.Text=txt fn()
  end)
end

-- Record: bei belegtem Slot erst bestaetigen
local armRec=false
on(bRec.MouseButton1Click,function()
  if play then return end
  if rec then
    rec=false
    if #steps==0 then loadSlot(slot) st("Nothing recorded, slot "..slot.." unchanged") return end
    local ok,e=pcall(function() writefile(file(slot),HS:JSONEncode(steps)) end)
    if ok then filled[slot]=true end
    st(ok and ("Slot "..slot.." saved: "..stats()) or ("Save error: "..tostring(e)))
    ui()
    return
  end
  if (#steps>0 or filled[slot]) and not armRec then
    armRec=true bRec.Text="Overwrite slot?"
    task.delay(2.5,function() armRec=false if not rec then ui() end end)
    return
  end
  armRec=false
  steps,rec,t0,lastK,idloc={},true,os.clock(),nil,nil
  st("Recording...")
  ui()
end)
local function startPlay()
  if rec or play then return end
  local act=false
  for _,s in ipairs(steps) do if s.k=="R" or s.k=="B" then act=true break end end
  if not act then return st("Slot has no actions, record first") end
  play=true paused=false gen+=1
  local my=gen
  if not sess0 then
    sess0=os.clock()
    local cv=coinStat()
    coin0=cv and cv.Value or nil
  end
  ui()
  task.spawn(function()
    local i=0
    local lim=RUNS[cfg.runs]
    while play and gen==my do
      i+=1 miss,rlog=0,{} runI=i
      runOnce(my)
      local took=runT0 and (os.clock()-runT0) or 0
      runT0=nil
      if not (play and gen==my) then break end
      local s=cfg.st
      s.runs+=1 s.time+=took s.last=took
      if s.best==0 or took<s.best then s.best=took end
      s.hist[#s.hist+1]=took
      while #s.hist>10 do table.remove(s.hist,1) end
      saveCfg() statsTxt()
      if cfg.hookOn and hookUrl() then
        task.spawn(function() pcall(sendReport,i,took) end)
      end
      local e=0
      for _,l in ipairs(rlog) do if l.ok==false then e+=1 end end
      st("Run "..i.." done | "..miss.." missing, "..e.." errors")
      if lim>0 and i>=lim then break end
      task.wait(1) -- feste Mini-Wartezeit zwischen Runs
    end
    waitEnd=false
    if gen==my then play=false ui() end
  end)
end
on(bPlay.MouseButton1Click,function()
  if rec then return end
  if play then play=false gen+=1 runT0=nil waitEnd=false st("Stopped") ui() return end
  startPlay()
end)
on(bPause.MouseButton1Click,function()
  if rec or not play then return end
  paused=not paused
  ui()
  st(paused and "Paused" or "Resumed")
end)
for i=1,NSLOTS do
  on(sb[i].MouseButton1Click,function()
    if rec or play then return end
    armRec=false slot=i cfg.slot=i saveCfg() loadSlot(i) optTxt()
  end)
end
-- Auto-Play: an = spielt den gewaehlten Slot endlos und startet nach jedem Rejoin/Serverwechsel automatisch (per Auto-Execute)
on(bRuns.MouseButton1Click,function()
  cfg.ap=not cfg.ap
  saveCfg() optTxt()
  if cfg.ap then
    if not rec and not play then startPlay() end
    st("Auto-Play on (Slot "..slot..")")
  else
    if play then play=false gen+=1 runT0=nil waitEnd=false ui() end
    st("Auto-Play off")
  end
end)
local copyTok=0
on(bCopy.MouseButton1Click,function()
  local ok=pcall(function() setclipboard(summary()) end)
  st(ok and "Log copied" or "Copy not possible")
  copyTok+=1
  local my=copyTok
  bCopy.Text=ok and "Copied!" or "Error"
  task.delay(1.2,function() if copyTok==my then bCopy.Text="Copy Log" end end)
end)
local discTok=0
on(bDisc.MouseButton1Click,function()
  local ok=pcall(function() setclipboard(DISCORD) end)
  st(ok and "Discord link copied" or "Copy not possible")
  discTok+=1
  local my=discTok
  bDisc.Text=ok and "Copied!" or "Error"
  task.delay(1.2,function() if discTok==my then bDisc.Text="Copy Discord Link" end end)
end)
-- Webhook-Bedienung
on(hookBox.FocusLost,function()
  local t=hookBox.Text:gsub("^%s+",""):gsub("%s+$","")
  if t~="" and t~="Webhook saved" then
    local old=cfg.hook
    cfg.hook=t
    if hookUrl() then
      saveCfg()
      st("Webhook saved")
    else
      cfg.hook=old
      st("Invalid webhook URL")
    end
  end
  showHook()
end)
on(bHook.MouseButton1Click,function()
  if not cfg.hookOn and not hookUrl() then st("Set a webhook URL first") return end
  cfg.hookOn=not cfg.hookOn
  optTxt() saveCfg()
  st(cfg.hookOn and "Webhook on" or "Webhook off")
end)
local hookBusy=false
on(bHookT.MouseButton1Click,function()
  if hookBusy then return end
  if not hookUrl() then st("Set a webhook URL first") return end
  hookBusy=true
  task.spawn(function()
    local ok=false
    pcall(function() ok=sendHook("Shox Hub test",{{name="Status",value="Webhook works",inline=true}}) end)
    st(ok and "Webhook test sent" or "Webhook test failed")
    hookBusy=false
  end)
end)
confirm(bDelCur,"Delete Current",function()
  rec,play,steps=false,false,{}
  gen+=1 runT0=nil waitEnd=false
  st("Current recording discarded") ui()
end)
on(nBox.FocusLost,function()
  local t=nBox.Text:gsub("^%s+",""):gsub("%s+$","")
  t=t:sub(1,20)
  cfg.names[tostring(slot)]=(t~="") and t or nil
  nBox.Text=t
  saveCfg()
  st(t~="" and ("Slot "..slot.." named: "..t) or ("Slot "..slot.." name cleared"))
end)
confirm(bStR,"Reset Stats",function()
  cfg.st={runs=0,time=0,best=0,last=0,hist={}}
  sess0,coin0=nil,nil
  if play then
    sess0=os.clock()
    local cv=coinStat()
    coin0=cv and cv.Value or nil
  end
  saveCfg() statsTxt()
  st("Stats reset")
end)
confirm(bDelSlot,"Delete Slot",function()
  if rec or play then return st("Stop first") end
  pcall(delfile,file(slot))
  steps={} filled[slot]=false
  st("Slot "..slot.." deleted") ui()
end)

-- Start
for n=1,NSLOTS do
  local ok,r=pcall(isfile,file(n))
  filled[n]=ok and r==true
end
applyTheme(TM[cfg.theme] and cfg.theme or "Black",true)
showCopy()
showHook()
tw(main,{Size=UDim2.fromOffset(220,WIN_H),BackgroundTransparency=TRANS[cfg.trans]},.7,Enum.EasingStyle.Back)
task.delay(0.9,clampMain)
statsTxt()
loadSlot(slot)
task.spawn(function() ensureIntro() playIntro() ilog("playIntro returned, intro running="..tostring(introS~=nil)) end)
task.spawn(function()
  if not game:IsLoaded() then game.Loaded:Wait() end
  if alive and cfg.lag then alRun(true) end
  if alive and cfg.ap then
    task.wait(4) -- UI/Charakter/Spiel kurz laden lassen
    if alive and cfg.ap and not rec and not play then
      st("Auto-Play: starting Slot "..slot)
      startPlay()
    end
  end
end)
