-- Shox Hub | Cameraman TD + Toilet TD + Smart Learn | v2.3
pcall(function() getgenv().ShoxOff() end)
local HS,UIS,TS,RS=game:GetService("HttpService"),game:GetService("UserInputService"),game:GetService("TweenService"),game:GetService("RunService")
local lp=game:GetService("Players").LocalPlayer
local G=getgenv()
local DIR="ShoxHub"
local GAME={sub="MACRO SUITE",foot="Macro Suite  |  v2.3"} -- wird nach dem Start anhand des Spielnamens gesetzt (nur Anzeige)
local MDIR=DIR.."/music" -- Intro-Datei (.mp3/.ogg) hier oder direkt in ShoxHub/ ablegen
pcall(makefolder,DIR)
pcall(makefolder,MDIR)
-- Intro-Song wird beim ersten Start automatisch geladen und in ShoxHub/music/ gespeichert (nur einmal, danach lokal).
local K={
  IGNORE={}, -- nie aufnehmen: K.IGNORE["RemoteName"]=true
  SKIPB={"towerui","slots","jumpbutton"}, -- beim Abspielen ueberspringen
  DEDUP=0.05,
  ADD="TowerAdd",
  ADDS={TowerAdd=true}, -- Platzier-Remotes (weitere Namen fuer andere Spiele hier eintragen)
  USE={TowerUpgrade=true,TowerSell=true},
  NEAR=12,
  GP="^%x+%-%x+%-%x+%-%x+%-%x+$",
  LRN={add={},use={}}, -- live gelernte Remote-Namen (Smart Learn), pro Game gespeichert
  TRY={},
  TC=nil -- gelernter Tower-Container (Pfad), wenn die Tower-Ids keine GUIDs sind
}
local RUNS,SCALES,SNAME,TRANS={0},{0.85,1,1.2},{"S","M","L"},{0,0.2,0.4} -- RUNS={0}: immer Endless
local cfg={ver=0,theme="Turkey",runs=1,scale=2,trans=1,intro=true,lag=false,slot=1,ap=false,dev=false,smart=true,names={},st={runs=0,time=0,rt=0}}
do
  local ok,j=pcall(function() return HS:JSONDecode(readfile(DIR.."/settings.json")) end)
  if ok and type(j)=="table" then for k,v in pairs(j) do cfg[k]=v end end
  cfg.gap,cfg.moves,cfg.vol=nil,nil,nil
  cfg.theme=({Schwarz="Black",["Weiß"]="White"})[cfg.theme] or cfg.theme
  if cfg.ver~=22 then cfg.ver=22 cfg.theme="Turkey" end -- v2.3: Turkey wird einmalig als Standard gesetzt
  if not RUNS[cfg.runs] then cfg.runs=1 end
  if not SCALES[cfg.scale] then cfg.scale=2 end
  if not TRANS[cfg.trans] then cfg.trans=1 end
  cfg.intro=cfg.intro~=false
  cfg.lag=cfg.lag==true
  cfg.ap=cfg.ap==true
  cfg.dev=cfg.dev==true
  cfg.smart=cfg.smart~=false
  cfg.auto=nil
  cfg.runs=1
  if type(cfg.names)~="table" then cfg.names={} end
  if type(cfg.st)~="table" then cfg.st={} end
  cfg.st.runs=tonumber(cfg.st.runs) or 0
  cfg.st.time=tonumber(cfg.st.time) or 0
  cfg.st.rt=tonumber(cfg.st.rt) or cfg.st.time -- rt = Zeit nur der fertigen Runs (fuer den Durchschnitt)
  if type(cfg.slot)~="number" or cfg.slot<1 or cfg.slot>5 then cfg.slot=1 end
end
local function saveCfg() pcall(writefile,DIR.."/settings.json",HS:JSONEncode(cfg)) end
K.GID=(game.GameId~=0 and game.GameId) or game.PlaceId
K.LFILE=DIR.."/learned_"..tostring(K.GID)..".json"
function K.saveLrn()
  local a,u={},{}
  for n in pairs(K.LRN.add) do a[#a+1]=n end
  for n in pairs(K.LRN.use) do u[#u+1]=n end
  pcall(writefile,K.LFILE,HS:JSONEncode({add=a,use=u,tc=K.TC}))
end
function K.lrnCount()
  local n=0
  for _ in pairs(K.LRN.add) do n+=1 end
  for _ in pairs(K.LRN.use) do n+=1 end
  return n
end
do
  local ok,j=pcall(function() return HS:JSONDecode(readfile(K.LFILE)) end)
  if ok and type(j)=="table" then
    if type(j.add)=="table" then for _,n in ipairs(j.add) do if type(n)=="string" then K.ADDS[n]=true K.LRN.add[n]=true end end end
    if type(j.use)=="table" then for _,n in ipairs(j.use) do if type(n)=="string" then K.USE[n]=true K.LRN.use[n]=true end end end
    if type(j.tc)=="table" and #j.tc>0 then K.TC=j.tc end
  end
end
local function sname(n) return cfg.names[tostring(n)] or "" end
local rec,play,t0,steps,miss,slot,rlog=false,false,0,{},0,cfg.slot,{}
local lastK,lastT=nil,0
local idmap={}
local idloc
local alive,gen=true,0
local runI,runT0,runTot=0,nil,0
local waitEnd=false
local filled={}
local conns={}
local bconns={} -- Button-Verbindungen (hookBtn): werden beim Entfernen des Buttons getrennt
local introS,introG
local function on(sig,fn) local c=sig:Connect(fn) conns[#conns+1]=c return c end
local function mmss(x) x=math.floor(x) return string.format("%d:%02d",x//60,x%60) end
local function isIn(i) return i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 end
-- gehoert dieses Input-Ende zum Input, der den Drag gestartet hat? (Touch: exakt dasselbe Input-Objekt, sonst beendet jeder andere Finger den Drag)
local function sameIn(i,d)
  if i==d then return true end
  return d.UserInputType~=Enum.UserInputType.Touch and i.UserInputType==d.UserInputType
end
local function rname() local t={} for i=1,10 do t[i]=string.char(math.random(97,122)) end return table.concat(t) end

-- Anti-AFK (fest eingebaut): Idled-Verbindungen aus + VirtualUser-Klick + echte Input-Events (Maus + Taste ueber VirtualInputManager, nur ohne Touchscreen)
-- + Mini-Bewegung des Charakters (Sprung und kurzer Schritt hin und zurueck) alle ca. 18-28 s
pcall(function() for _,c in pairs(getconnections(lp.Idled)) do c:Disable() end end)
local VU=game:GetService("VirtualUser")
local VIM
pcall(function() VIM=game:GetService("VirtualInputManager") end)
local function nudge()
  pcall(function() VU:CaptureController() VU:ClickButton2(Vector2.new()) end)
  if VIM and not UIS.TouchEnabled then -- am Handy wuerde Maus/Taste den Joystick ausblenden
    pcall(function()
      local v=workspace.CurrentCamera.ViewportSize
      VIM:SendMouseMoveEvent(v.X/2+math.random(-6,6),v.Y/2+math.random(-6,6),game)
      VIM:SendKeyEvent(true,Enum.KeyCode.RightControl,false,game)
      task.wait(0.05)
      VIM:SendKeyEvent(false,Enum.KeyCode.RightControl,false,game)
    end)
  end
  pcall(function()
    local ch=lp.Character
    local h=ch and ch:FindFirstChildOfClass("Humanoid")
    local r=ch and ch:FindFirstChild("HumanoidRootPart")
    if h and r and h.Health>0 and not h.SeatPart then
      -- Move()/Jump werden vom Roblox-ControlModule jeden Frame ueberschrieben -> echter Sprung ueber State + kleiner Schritt per CFrame
      pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
      r.CFrame=r.CFrame*CFrame.new(0.8,0,0)
      task.wait(0.15)
      if r.Parent then r.CFrame=r.CFrame*CFrame.new(-0.8,0,0) end -- relativ zurueck: kein Rubberband
    end
  end)
end
on(lp.Idled,nudge)
task.spawn(function()
  while alive do
    task.wait(18+math.random()*10)
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
      if G.ShoxAK and s==lp then
        local f=G.ShoxKick
        if f then pcall(f,"Kick() geblockt",...) end
        return
      end
      return k(s,...)
    end))
  end)
end
-- Kick-Logger (unsichtbar): geblockte Kicks + Roblox-Disconnect-Meldungen mit Run/Laufzeit -> Copy Log (ganz unten) + ShoxHub/kicklog.txt
K.KL={}
do
  local ok,d=pcall(readfile,DIR.."/kicklog.txt")
  if ok and type(d)=="string" then
    for l in d:gmatch("[^\n]+") do K.KL[#K.KL+1]=l end
    while #K.KL>30 do table.remove(K.KL,1) end
  end
end
G.ShoxKick=function(why,...)
  local a=table.pack(...)
  local m={}
  for i=1,a.n do m[i]=tostring(a[i]) end
  local l=string.format("%s | %s | run=%s t=%s | %s",os.date("%d.%m %H:%M:%S"),why,tostring(runI),runT0 and (math.floor(os.clock()-runT0).."s") or "-",table.concat(m," "):sub(1,200))
  K.KL[#K.KL+1]=l
  while #K.KL>30 do table.remove(K.KL,1) end
  pcall(writefile,DIR.."/kicklog.txt",table.concat(K.KL,"\n"))
end
pcall(function()
  local GSv=game:GetService("GuiService")
  on(GSv.ErrorMessageChanged,function()
    local m=""
    pcall(function() m=GSv:GetErrorMessage() end)
    if m~="" then G.ShoxKick("Roblox-Fehler",m) end
  end)
end)

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
  for pi,n0 in ipairs(p) do
    local n=n0
    if pi==2 and p[1]=="Players" then n=lp.Name end -- Pfade von anderen Spielern (Export/Import) auf den eigenen Namen umbiegen
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
  elseif t=="EnumItem" then return {t="E",e=(tostring(v.EnumType):gsub("^Enum%.","")),n=v.Name}
  elseif t=="BrickColor" then return {t="BC",n=v.Name}
  elseif t=="UDim2" then return {t="U2",v={v.X.Scale,v.X.Offset,v.Y.Scale,v.Y.Offset}}
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
  elseif t=="N" then
    local x=tonumber(o.s)
    if x then return x end
    if tostring(o.s):find("nan",1,true) then return 0/0 end
    return tostring(o.s):find("-",1,true) and -math.huge or math.huge
  elseif t=="E" then
    local ok,r=pcall(function() return Enum[o.e][o.n] end)
    return ok and r or nil
  elseif t=="BC" then return BrickColor.new(o.n)
  elseif t=="U2" then return UDim2.new(table.unpack(o.v))
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
-- erste Position (Vector3/CFrame) in den Argumenten eines Schritts (fuer unbekannte Spiele)
function K.posOf(s)
  local function f(o,d)
    if type(o)~="table" or d>4 then return nil end
    if (o.t=="V3" or o.t=="CF") and type(o.v)=="table" then return Vector3.new(o.v[1],o.v[2],o.v[3]) end
    if o.t=="T" and type(o.v)=="table" then
      for _,kv in ipairs(o.v) do
        local r=f(kv[2],d+1)
        if r then return r end
      end
    end
  end
  for i=1,s.n do
    local r=f(s.a[i],1)
    if r then return r end
  end
end
-- Tower-Id eines Upgrade/Sell-Schritts: Key "Id" (Cameraman) oder irgendein String-Argument, das eine bekannte Tower-Id ist
function K.uidOf(s)
  local id=tkey(s,"Id")
  if type(id)=="string" then return id end
  local function f(o,d)
    if type(o)=="string" then
      if (K.TIDS and K.TIDS[o]) or o:match(K.GP) then return o end
      return nil
    end
    if type(o)=="table" and o.t=="T" and d<4 and type(o.v)=="table" then
      for _,kv in ipairs(o.v) do
        local r=f(kv[2],d+1)
        if r then return r end
      end
    end
  end
  for i=1,s.n do
    local r=f(s.a[i],1)
    if r then return r end
  end
end
-- Eindeutige Tower-Ids: gleiche Namen (z.B. mehrmals "GingerbreadHouse") bekommen je eine eigene Seriennummer
K.SER=setmetatable({},{__mode="k"})
K.SN=0
function K.sid(x)
  local v=K.SER[x]
  if not v then K.SN+=1 v="T"..K.SN K.SER[x]=v end
  return v
end
-- nur echte Ids (GUID oder Seriennummer) duerfen Argumente ersetzen, sonst wuerde z.B. der Einheitenname "GingerbreadHouse" im Platzier-Aufruf ersetzt
function K.okId(x) return type(x)=="string" and (x:match(K.GP)~=nil or x:match("^T%d+$")~=nil) end
-- Aktions-Code eines Aufrufs (erster String in den Argumenten): ein Remote (z.B. DataRemote) kann mehrere Aktionen tragen
function K.code(s)
  local function f(o,d)
    if type(o)=="string" then return o end
    if type(o)=="table" and o.t=="T" and d<5 and type(o.v)=="table" then
      for _,kv in ipairs(o.v) do
        local r=f(kv[2],d+1)
        if r then return r end
      end
    end
  end
  for i=1,s.n do
    local r=f(s.a[i],1)
    if r then return r end
  end
end
function K.hasInst(s)
  local function f(o,d)
    if type(o)=="table" and o.t=="I" then return true end
    if type(o)=="table" and o.t=="T" and d<5 and type(o.v)=="table" then
      for _,kv in ipairs(o.v) do if f(kv[2],d+1) then return true end end
    end
  end
  for i=1,s.n do if f(s.a[i],1) then return true end end
  return false
end
-- Art eines Schritts pro Aufruf (nicht pro Remote-Name): add = Platzieren, use = Upgrade/Sell
function K.kind(name,s)
  if K.ADDS[name] and (not K.LRN.add[name] or K.posOf(s)) then return "add" end
  if K.USE[name] and (not K.LRN.use[name] or K.hasInst(s) or K.uidOf(s)) then return "use" end
end
local function gather()
  local r={}
  do -- gelernter Container (Smart Learn): jedes direkte Kind ist ein Tower, der Name ist die Id
    local tc=K.TC and find(K.TC)
    if tc then
      for _,x in ipairs(tc:GetChildren()) do
        r[K.sid(x)]=x
        if x:IsA("Model") then
          for _,v in pairs(x:GetAttributes()) do
            if type(v)=="string" and v:match(K.GP) then r[v]=r[v] or x end
          end
        end
      end
      return r
    end
  end
  local g=workspace:FindFirstChild("Game")
  local tf=g and g:FindFirstChild("Towers")
  if tf then -- Tower-Ids sind die Namen der direkten Kinder: kein Durchsuchen aller Unterteile mehr
    for _,x in ipairs(tf:GetChildren()) do
      local n=x.Name
      if n:match(K.GP) then r[n]=x end
      if x:IsA("Model") then
        for _,v in pairs(x:GetAttributes()) do
          if type(v)=="string" and v:match(K.GP) then r[v]=r[v] or x end
        end
      end
    end
    return r
  end
  local nowc=os.clock()
  if K.gc and nowc-K.gct<0.2 then -- Vollscan nur alle 0.2 s
    local c={}
    for k,v in pairs(K.gc) do c[k]=v end
    return c
  end
  local root=workspace
  for _,x in ipairs(root:GetDescendants()) do
    local n=x.Name
    if n:match(K.GP) then r[n]=x end
    if x:IsA("Model") then
      for _,v in pairs(x:GetAttributes()) do
        if type(v)=="string" and v:match(K.GP) then r[v]=r[v] or x end
      end
    end
  end
  K.gc,K.gct=r,os.clock()
  local c={}
  for k,v in pairs(r) do c[k]=v end
  return c
end
-- used (optional, nur beim Abspielen): Ids, die schon einem anderen Tower zugeordnet wurden
local function newId(before,s,used,maxTry)
  local uid=tkey(s,"UnitId")
  local pp=tkey(s,"Pos")
  local pos=(type(pp)=="table" and pp.t=="V3" and pp.v and Vector3.new(table.unpack(pp.v))) or K.posOf(s)
  local n=0
  for i=1,maxTry or 12 do
    task.wait(0.25)
    local c={}
    for g,x in pairs(gather()) do
      if not before[g] and g~=uid and not (used and used[g]) then
        local px=pos and pvOf(x)
        c[#c+1]={g=g,d=px and (px-pos).Magnitude,top=(x.Name==g)}
      end
    end
    n=#c
    if n>0 then
      local best
      for _,e in ipairs(c) do
        if e.d and e.d<=K.NEAR and (not best or (e.top and not best.top) or (e.top==best.top and e.d<best.d)) then best=e end
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

-- Themes: Black, White, Frost, Natural, Lava, Turkey, Gold (kein Lila, kein Pink)
local function C(r,g,b) return Color3.fromRGB(r,g,b) end
local W=C(255,255,255)
local THEMES={
  {"Turkey",{bg=C(26,13,6),btn=C(68,36,15),btxt=C(255,236,204),acc=C(240,136,30),sub=C(214,166,112),rec=C(158,64,16),play=C(184,102,22),del=C(98,44,18),ctxt=W,ron=C(240,112,24),pon=C(255,196,64),onT=C(30,14,0)}},
  {"Black",{bg=C(8,8,8),btn=C(26,26,28),btxt=C(235,235,235),acc=C(255,255,255),sub=C(125,125,130),rec=C(38,38,40),play=C(38,38,40),del=C(26,26,28),ctxt=C(245,245,245),ron=C(255,255,255),pon=C(255,255,255),onT=C(0,0,0)}},
  {"White",{bg=C(250,250,252),btn=C(233,233,237),btxt=C(22,22,24),acc=C(10,10,12),sub=C(115,115,122),rec=C(214,214,220),play=C(214,214,220),del=C(233,233,237),ctxt=C(22,22,24),ron=C(10,10,12),pon=C(10,10,12),onT=C(255,255,255)}},
  {"Frost",{bg=C(10,22,40),btn=C(24,48,80),btxt=C(225,242,255),acc=C(120,200,255),sub=C(170,205,235),rec=C(50,100,160),play=C(60,130,200),del=C(40,70,110),ctxt=W,ron=C(30,140,230),pon=C(30,160,190),onT=W}},
  {"Natural",{bg=C(10,24,14),btn=C(24,52,30),btxt=C(225,245,225),acc=C(90,200,90),sub=C(170,210,170),rec=C(120,80,35),play=C(50,140,70),del=C(90,50,30),ctxt=W,ron=C(200,80,40),pon=C(120,190,60),onT=W}},
  {"Lava",{bg=C(20,8,6),btn=C(52,22,14),btxt=C(255,225,200),acc=C(255,100,20),sub=C(255,190,150),rec=C(150,30,10),play=C(190,65,10),del=C(105,25,15),ctxt=W,ron=C(255,50,20),pon=C(230,140,0),onT=W}},
  {"Gold",{bg=C(16,13,6),btn=C(44,36,14),btxt=C(255,240,205),acc=C(255,200,60),sub=C(210,185,130),rec=C(140,100,10),play=C(170,130,20),del=C(80,62,16),ctxt=W,ron=C(255,180,0),pon=C(255,215,80),onT=C(20,14,0)}},
}
local TM={}
for _,t in ipairs(THEMES) do TM[t[1]]=t[2] end
local T,themeName=TM.Turkey,"Turkey"
local themed={}

-- GUI
local QI=Enum.EasingStyle.Quint
local function tw(o,pr,t,s) TS:Create(o,TweenInfo.new(t or .2,s or QI,Enum.EasingDirection.Out),pr):Play() end
local function mk(c,pr,par) local o=Instance.new(c) for k,v in pairs(pr) do o[k]=v end o.Parent=par return o end
local function reg(o,prop,fn) themed[#themed+1]={o,prop,fn} o[prop]=fn(T) return o end
local F,Z={},{}
F.Bg=function(t) return t.bg end
F.Acc=function(t) return t.acc end
F.Sub=function(t) return t.sub end
F.Btn=function(t) return t.btn end
F.Btxt=function(t) return t.btxt end
F.Del=function(t) return t.del end
F.Ctxt=function(t) return t.ctxt end
F.Line=function(t) return t.btn:Lerp(t.acc,0.3) end
-- Glanz-Verlauf: Grundfarbe -> fast Weiss -> Grundfarbe (wandert ueber Text, die Textfarbe selbst ist Weiss)
local function shineSeq(t)
  local a=t.acc
  local hi=a:Lerp(W,0.88)
  return ColorSequence.new({ColorSequenceKeypoint.new(0,a),ColorSequenceKeypoint.new(0.38,a),ColorSequenceKeypoint.new(0.5,hi),ColorSequenceKeypoint.new(0.62,a),ColorSequenceKeypoint.new(1,a)})
end
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
reg(main,"BackgroundColor3",F.Bg)
mk("UIGradient",{Rotation=90,Color=ColorSequence.new(C(255,255,255),C(185,185,185))},main) -- leichter Tiefen-Verlauf im Hintergrund
local uis=mk("UIScale",{Scale=SCALES[cfg.scale]},main)
mk("UICorner",{CornerRadius=UDim.new(0,14)},main)
-- Rahmen mit rotierendem Farbverlauf
Z.mStroke=mk("UIStroke",{Thickness=2.5,Color=W},main)
local mGrad=mk("UIGradient",{Rotation=0},Z.mStroke)
if type(cfg.pos)=="table" and #cfg.pos==4 then
  pcall(function() main.Position=UDim2.new(cfg.pos[1],cfg.pos[2],cfg.pos[3],cfg.pos[4]) end)
end
Z.hdr=mk("Frame",{Size=UDim2.new(1,-76,0,34),BackgroundTransparency=1},main)
-- Titel: Textfarbe Weiss, der Verlauf (Shiny Text) faerbt ihn ein und ein Glanzstreifen wandert drueber
local title=mk("TextLabel",{Position=UDim2.fromOffset(12,0),Size=UDim2.fromOffset(104,34),Text="Shox Hub",TextColor3=W,TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Font=Enum.Font.GothamBlack,TextSize=18},Z.hdr)
Z.titleG=mk("UIGradient",{Color=shineSeq(T)},title)
Z.titleS=mk("UIStroke",{Thickness=1.4,Transparency=0.8},title)
reg(Z.titleS,"Color",F.Acc)
local status=mk("TextLabel",{Position=UDim2.fromOffset(12,34),Size=UDim2.new(1,-24,0,18),Text="Ready | Anti-AFK on",TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=11,TextTruncate=Enum.TextTruncate.AtEnd},main)
reg(status,"TextColor3",F.Sub)
Z.dragH=mk("TextButton",{Size=UDim2.new(1,-76,0,56),BackgroundTransparency=1,Text="",AutoButtonColor=false,Active=true,ZIndex=2},main)
local div=mk("Frame",{Position=UDim2.fromOffset(12,56),Size=UDim2.new(1,-24,0,2),BorderSizePixel=0},main)
reg(div,"BackgroundColor3",F.Acc)
-- wandernder Lichtstreifen auf der Trennlinie
Z.divG=mk("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0),NumberSequenceKeypoint.new(1,1)})},div)
local body=mk("ScrollingFrame",{Position=UDim2.fromOffset(0,60),Size=UDim2.new(1,0,1,-60),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},main)
reg(body,"ScrollBarImageColor3",F.Acc)
mk("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},body)
mk("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,14),PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,12)},body)
local ord=0
local function row(h) ord+=1 return mk("Frame",{Size=UDim2.new(1,0,0,h),BackgroundTransparency=1,BorderSizePixel=0,LayoutOrder=ord},body) end
local function lbl(t)
  local r=row(14)
  local bar=mk("Frame",{Size=UDim2.fromOffset(3,10),Position=UDim2.fromOffset(0,2),BorderSizePixel=0},r)
  mk("UICorner",{CornerRadius=UDim.new(1,0)},bar)
  reg(bar,"BackgroundColor3",F.Acc)
  reg(mk("TextLabel",{Position=UDim2.fromOffset(9,0),Size=UDim2.new(1,-9,1,0),BackgroundTransparency=1,Text=t,TextXAlignment=Enum.TextXAlignment.Left,Font=Enum.Font.GothamBold,TextSize=10},r),"TextColor3",F.Sub)
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
  mk("UIGradient",{Rotation=90,Color=ColorSequence.new(W,C(205,205,205))},b) -- leichter Glanz von oben nach unten
  local sc=mk("UIScale",{Scale=1},b)
  local sk=mk("UIStroke",{Thickness=1,Transparency=0.55,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},b)
  reg(sk,"Color",F.Line)
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
    tw(sk,{Color=F.Line(T),Thickness=1,Transparency=0.55},.45)
  end)
  return b
end
Z.bRec=btn(row(40),"Record",1,1,nil,nil,15)
Z.bPlay=btn(row(40),"Play",1,1,nil,nil,15)
lbl("SLOTS")
Z.sRow=row(30)
Z.sb={}
for i=1,5 do Z.sb[i]=btn(Z.sRow,tostring(i),i,5,nil,nil,14) end
-- Slot-Name (gehoert zum gewaehlten Slot)
Z.nBox=mk("TextBox",{Size=UDim2.new(1,0,0,28),Text="",PlaceholderText="Slot name...",ClearTextOnFocus=false,MaxVisibleGraphemes=-1,Font=Enum.Font.GothamBold,TextSize=12,BorderSizePixel=0,TextTruncate=Enum.TextTruncate.AtEnd,LayoutOrder=0},row(28))
mk("UICorner",{CornerRadius=UDim.new(0,9)},Z.nBox)
mk("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},Z.nBox)
reg(Z.nBox,"BackgroundColor3",F.Btn) reg(Z.nBox,"TextColor3",F.Btxt) reg(Z.nBox,"PlaceholderColor3",F.Sub)
local function showName() Z.nBox.Text=sname(slot) end
-- Versteckte Reihen (Copy Log, Export/Import): 10 schnelle Taps auf den Header (Shox Hub) schalten sie um (wird gespeichert)
Z.cRow=row(28)
Z.bCopy=btn(Z.cRow,"Copy Log",1,1,function(t) return t.acc:Lerp(t.bg,0.4) end,F.Ctxt,12)
Z.eRow=row(28)
Z.bExp=btn(Z.eRow,"Export Slot",1,2,function(t) return t.acc:Lerp(t.bg,0.4) end,F.Ctxt,12)
Z.bImp=btn(Z.eRow,"Import Slot",2,2,function(t) return t.acc:Lerp(t.bg,0.4) end,F.Ctxt,12)
Z.pRow=row(28)
Z.pBox=mk("TextBox",{Size=UDim2.new(1,0,1,0),Text="",PlaceholderText="Paste slot code here...",ClearTextOnFocus=true,Font=Enum.Font.GothamBold,TextSize=12,BorderSizePixel=0,TextTruncate=Enum.TextTruncate.AtEnd,TextXAlignment=Enum.TextXAlignment.Left},Z.pRow)
mk("UICorner",{CornerRadius=UDim.new(0,9)},Z.pBox)
mk("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},Z.pBox)
reg(Z.pBox,"BackgroundColor3",F.Btn) reg(Z.pBox,"TextColor3",F.Btxt) reg(Z.pBox,"PlaceholderColor3",F.Sub)
local function showCopy()
  Z.cRow.Visible=cfg.dev
  Z.eRow.Visible=cfg.dev
  Z.pRow.Visible=cfg.dev
end
Z.dRow=row(28)
Z.bDelCur=btn(Z.dRow,"Delete Current",1,2,F.Del,F.Ctxt,12)
Z.bDelSlot=btn(Z.dRow,"Delete Slot",2,2,F.Del,F.Ctxt,12)
lbl("STATS")
Z.stLbl=mk("TextLabel",{Size=UDim2.new(1,0,0,32),BackgroundTransparency=1,Text="",TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Font=Enum.Font.Gotham,TextSize=11,TextWrapped=true},row(32))
reg(Z.stLbl,"TextColor3",F.Btxt)
Z.bStR=btn(row(26),"Reset Stats",1,1,F.Del,F.Ctxt,12)
function Z.hms(x) x=math.floor(x) return string.format("%d:%02d:%02d",x//3600,(x%3600)//60,x%60) end
local function statsTxt()
  local s=cfg.st
  Z.stLbl.Text="Runs: "..s.runs.."  |  Avg: "..mmss(s.runs>0 and s.rt/s.runs or 0).."\nTotal time: "..Z.hms(s.time)
end
lbl("OPTIONS")
Z.o1=row(28)
Z.bRuns=btn(Z.o1,"",1,2,F.Btn,F.Btxt,12)
Z.bSize=btn(Z.o1,"",2,2,F.Btn,F.Btxt,12)
Z.o2=row(28)
Z.bTrans=btn(Z.o2,"",1,2,F.Btn,F.Btxt,12)
Z.bTheme=btn(Z.o2,"",2,2,F.Btn,F.Btxt,12)
Z.o3=row(28)
Z.bLag=btn(Z.o3,"",1,2,F.Btn,F.Btxt,12)
Z.bIntro=btn(Z.o3,"",2,2,F.Btn,F.Btxt,12)
Z.o4=row(28)
Z.bSmart=btn(Z.o4,"",1,2,F.Btn,F.Btxt,12)
Z.bForget=btn(Z.o4,"Forget Learned",2,2,F.Del,F.Ctxt,12)
Z.DDROWS=math.ceil(#THEMES/2)
Z.DDH=Z.DDROWS*32-6+8
local ddRow=row(0)
ddRow.ClipsDescendants=true
mk("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4),PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,4)},ddRow)
Z.foot=row(14)
Z.footL=mk("TextLabel",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=GAME.foot,TextXAlignment=Enum.TextXAlignment.Left,Font=Enum.Font.GothamBold,TextSize=10},Z.foot)
reg(Z.footL,"TextColor3",F.Sub)
Z.foot2=row(14)
reg(mk("TextLabel",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="Shox Hub | Anti-AFK on",TextXAlignment=Enum.TextXAlignment.Left,Font=Enum.Font.Gotham,TextSize=10},Z.foot2),"TextColor3",F.Sub)
-- Spielerkennung (nur Anzeige: Footer, Intro, Copy Log). Aendert keine Remotes und kein Verhalten.
task.spawn(function()
  pcall(function()
    local ok,i=pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
    local n=(ok and type(i)=="table" and tostring(i.Name or "")) or ""
    if n=="" then n=tostring(game.Name) end
    GAME.full=n
    local l=n:lower()
    local tag,short
    if l:find("cameraman",1,true) then tag,short="CAMERAMAN TD","Cameraman TD"
    elseif l:find("toilet",1,true) then tag,short="TOILET TD","Toilet TD"
    else
      local c=n:gsub("%b[]",""):gsub("%b()",""):gsub("[^%w%s%-:'!&%.]",""):gsub("%s+"," ")
      c=c:gsub("^%s+",""):gsub("%s+$","")
      if c~="" then
        short=c:sub(1,22)
        tag=c:upper():sub(1,20)
      end
    end
    if tag then
      GAME.sub=tag.."  ·  MACRO SUITE"
      GAME.foot=short.."  |  v2.3"
      pcall(function() if alive then Z.footL.Text=GAME.foot end end)
    end
  end)
  GAME.done=true
end)

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
  for n=1,5 do
    local b=Z.sb[n]
    local sel=n==slot
    tw(b,{BackgroundColor3=sel and T.acc or T.btn,TextColor3=sel and T.bg or (filled[n] and T.btxt or T.sub)},.25)
  end
end
local function ui()
  Z.bRec.Text=rec and recTxt() or "Record"
  tw(Z.bRec,{BackgroundColor3=rec and T.ron or T.rec,TextColor3=rec and T.onT or T.ctxt},.3)
  Z.bPlay.Text=play and "Stop" or "Play"
  tw(Z.bPlay,{BackgroundColor3=play and T.pon or T.play,TextColor3=play and T.onT or T.ctxt},.3)
  updateSlots()
end
local function optTxt()
  Z.bRuns.Text="Auto S"..slot..": "..(cfg.ap and "On" or "Off")
  Z.bSize.Text="Size: "..SNAME[cfg.scale]
  Z.bTrans.Text="Opacity: "..math.floor((1-TRANS[cfg.trans])*100+0.5).."%"
  Z.bTheme.Text="Theme: "..themeName
  Z.bLag.Text="Anti-Lag: "..(cfg.lag and "On" or "Off")
  Z.bIntro.Text="Intro: "..(cfg.intro and "On" or "Off")
  local lc=K.lrnCount()
  Z.bSmart.Text="Smart: "..(cfg.smart and "On" or "Off")..(lc>0 and (" ("..lc..")") or "")
end

-- Drag + Minimize
local bnd,clampMain
do
local dIn,dStart,dPos,dLast,dBase
local tapN,tapLast,tapT=0,0,0
-- AbsolutePosition rechnet ohne die Roblox-Leiste oben (GuiInset): Fenster darf bis zum echten Bildschirmrand hoch
local GS=game:GetService("GuiService")
function bnd()
  local v=workspace.CurrentCamera.ViewportSize
  local ok,ti=pcall(function() return GS:GetGuiInset() end)
  local ins=ok and typeof(ti)=="Vector2" and math.clamp(ti.Y,0,100) or 0
  return v,-ins,v.Y-ins-40
end
function clampMain()
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
on(Z.dragH.InputBegan,function(i)
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
  if dIn and isIn(i) and sameIn(i,dIn) then
    dIn=nil
    local p=main.Position
    cfg.pos={p.X.Scale,p.X.Offset,p.Y.Scale,p.Y.Offset}
    -- 10 schnelle Taps (kaum Bewegung, kurz gedrueckt) auf den Header: versteckte Reihen ein/aus
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
end
Z.bMin=mk("TextButton",{Text="-",Position=UDim2.new(1,-66,0,5),Size=UDim2.fromOffset(26,24),Font=Enum.Font.GothamBold,TextSize=16,AutoButtonColor=false,BorderSizePixel=0},main)
mk("UICorner",{CornerRadius=UDim.new(0,8)},Z.bMin)
Z.minSc=mk("UIScale",{Scale=1},Z.bMin)
reg(Z.bMin,"BackgroundColor3",F.Btn) reg(Z.bMin,"TextColor3",F.Btxt)
on(Z.bMin.InputBegan,function(x) if isIn(x) then tw(Z.minSc,{Scale=0.85},.08) end end)
on(Z.bMin.InputEnded,function(x) if isIn(x) then tw(Z.minSc,{Scale=1},.3,Enum.EasingStyle.Back) end end)
local mini=false
on(Z.bMin.MouseButton1Click,function()
  mini=not mini
  Z.bMin.Text=mini and "+" or "-"
  tw(main,{Size=UDim2.fromOffset(220,mini and 34 or WIN_H)},.45,Enum.EasingStyle.Quint)
  task.delay(.5,clampMain)
end)
-- X-Button: schliesst das ganze Fenster, der Menu-Button (Quadrat, verschiebbar) oeffnet es wieder
Z.bX=mk("TextButton",{Text="X",Position=UDim2.new(1,-36,0,5),Size=UDim2.fromOffset(26,24),Font=Enum.Font.GothamBold,TextSize=14,AutoButtonColor=false,BorderSizePixel=0},main)
mk("UICorner",{CornerRadius=UDim.new(0,8)},Z.bX)
Z.xSc=mk("UIScale",{Scale=1},Z.bX)
reg(Z.bX,"BackgroundColor3",F.Btn) reg(Z.bX,"TextColor3",F.Btxt)
on(Z.bX.InputBegan,function(x) if isIn(x) then tw(Z.xSc,{Scale=0.85},.08) end end)
on(Z.bX.InputEnded,function(x) if isIn(x) then tw(Z.xSc,{Scale=1},.3,Enum.EasingStyle.Back) end end)
local MB=40
local mbtn=mk("TextButton",{Text="",Size=UDim2.fromOffset(MB,MB),Position=main.Position,AutoButtonColor=false,BorderSizePixel=0,Visible=false,Active=true,ZIndex=3},gui)
if type(cfg.mpos)=="table" and #cfg.mpos==4 then
  pcall(function() mbtn.Position=UDim2.new(cfg.mpos[1],cfg.mpos[2],cfg.mpos[3],cfg.mpos[4]) end)
end
mk("UICorner",{CornerRadius=UDim.new(0,10)},mbtn)
reg(mbtn,"BackgroundColor3",F.Bg)
Z.mbS=mk("UIStroke",{Thickness=2.5,Color=W,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},mbtn)
local mbGrad=mk("UIGradient",{Rotation=0},Z.mbS)
local mbSc=mk("UIScale",{Scale=1},mbtn)
for n=0,2 do
  local bar=mk("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,(n-1)*7),Size=UDim2.fromOffset(18,3),BorderSizePixel=0,ZIndex=4},mbtn)
  mk("UICorner",{CornerRadius=UDim.new(1,0)},bar)
  reg(bar,"BackgroundColor3",F.Acc)
end
local function setOpen(open)
  if open then
    mbtn.Visible=false
    main.Visible=true
    main.Size=UDim2.fromOffset(220,0)
    tw(main,{Size=UDim2.fromOffset(220,mini and 34 or WIN_H)},.45,Enum.EasingStyle.Back)
    task.delay(.5,clampMain)
  else
    if not cfg.mpos then mbtn.Position=main.Position end
    tw(main,{Size=UDim2.fromOffset(220,0)},.3)
    task.delay(.32,function() if mbtn.Visible then main.Visible=false end end)
    mbtn.Visible=true
    mbSc.Scale=0
    tw(mbSc,{Scale=1},.45,Enum.EasingStyle.Back)
  end
end
on(Z.bX.MouseButton1Click,function() setOpen(false) end)
do
local mIn,mStart,mBase,mAbs,mLast,mMoved
on(mbtn.InputBegan,function(i)
  if isIn(i) then
    mIn,mStart,mBase,mAbs,mLast,mMoved=i,i.Position,mbtn.Position,mbtn.AbsolutePosition,i.Position,false
    tw(mbSc,{Scale=0.9},.08)
  end
end)
on(UIS.InputChanged,function(i)
  if not mIn then return end
  if mIn.UserInputState==Enum.UserInputState.End or mIn.UserInputState==Enum.UserInputState.Cancel then
    mIn=nil
    tw(mbSc,{Scale=1},.3,Enum.EasingStyle.Back)
    return
  end
  local ok=i==mIn or i.UserInputType==Enum.UserInputType.MouseMovement
  if not ok and i.UserInputType==Enum.UserInputType.Touch and mIn.UserInputType==Enum.UserInputType.Touch and (i.Position-mLast).Magnitude<120 then ok=true end
  if not ok then return end
  mLast=i.Position
  local d=i.Position-mStart
  if d.Magnitude>8 then mMoved=true end
  if not mMoved then return end
  local v,minY,maxY=bnd()
  local dx=math.clamp(mAbs.X+d.X,0,v.X-MB)-mAbs.X
  local dy=math.clamp(mAbs.Y+d.Y,minY,maxY)-mAbs.Y
  mbtn.Position=UDim2.new(mBase.X.Scale,mBase.X.Offset+dx,mBase.Y.Scale,mBase.Y.Offset+dy)
end)
on(UIS.InputEnded,function(i)
  if mIn and isIn(i) and sameIn(i,mIn) then
    local moved=mMoved
    mIn=nil
    tw(mbSc,{Scale=1},.3,Enum.EasingStyle.Back)
    if moved then
      local p=mbtn.Position
      cfg.mpos={p.X.Scale,p.X.Offset,p.Y.Scale,p.Y.Offset}
      saveCfg()
    else
      setOpen(true)
    end
  end
end)
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
  tw(ddRow,{Size=UDim2.new(1,0,0,open and Z.DDH or 0)},open and .5 or .3,QI)
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
  mGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.acc),ColorSequenceKeypoint.new(0.5,T.acc:Lerp(T.bg,0.75)),ColorSequenceKeypoint.new(1,T.acc)})
  mbGrad.Color=mGrad.Color
  Z.titleG.Color=shineSeq(T)
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
on(Z.bTheme.MouseButton1Click,function() setDD(not ddOpen) end)

local alRun,alRestore
-- Anti-Lag (FPS-Boost, vollstaendig rueckgaengig machbar)
-- Aus: Partikel/Trails/Beams/Feuer/Rauch, Post-Effekte, Schatten (global + pro Part), Reflexionen, Terrain-Deko/Wellen.
-- Ruckelfrei: Aenderungen laufen in einer Warteschlange mit festem Zeitbudget pro Frame (max. ca. 2 ms).
do
local LS=game:GetService("Lighting")
local AL={on=false,orig=setmetatable({},{__mode="k"}),q={},qi=1,conn=nil,hb=nil,env=nil,rest={},ri=1}
local FX={ParticleEmitter=true,Trail=true,Beam=true,Smoke=true,Fire=true,Sparkles=true,PointLight=true,SpotLight=true,SurfaceLight=true,BloomEffect=true,BlurEffect=true,ColorCorrectionEffect=true,DepthOfFieldEffect=true,SunRaysEffect=true}
local function alApply(x)
  if FX[x.ClassName] then
    if AL.orig[x]==nil then
      if x.ClassName=="ParticleEmitter" then AL.orig[x]={x.Enabled,x.Lifetime} else AL.orig[x]=x.Enabled end
    end
    x.Enabled=false
    if x.ClassName=="ParticleEmitter" then x.Lifetime=NumberRange.new(0) end -- :Emit() ignoriert Enabled
  elseif x:IsA("BasePart") and not x:IsA("Terrain") then
    if x.CastShadow or x.Reflectance>0 then
      if AL.orig[x]==nil then AL.orig[x]={x.Reflectance,x.CastShadow} end
      x.Reflectance=0
      x.CastShadow=false
    end
  end
end
local function alStep(budget)
  local t=os.clock()
  local q=AL.q
  while AL.qi<=#q do
    local x=q[AL.qi]
    q[AL.qi]=false
    AL.qi+=1
    if x and x.Parent then pcall(alApply,x) end
    if os.clock()-t>budget then break end
  end
  if AL.qi>#q then AL.q={} AL.qi=1 end
end
function alRestore(budget)
  local t=os.clock()
  local r=AL.rest
  while AL.ri<=#r do
    local e=r[AL.ri]
    r[AL.ri]=false
    AL.ri+=1
    if e then
      local x,v=e[1],e[2]
      pcall(function()
        if x.Parent then
          if type(v)=="table" then
            if typeof(v[2])=="NumberRange" then x.Enabled,x.Lifetime=v[1],v[2] else x.Reflectance,x.CastShadow=v[1],v[2] end
          else x.Enabled=v end
        end
      end)
      AL.orig[x]=nil
    end
    if os.clock()-t>budget then break end
  end
  return AL.ri>#r
end
alRun=function(enable)
  AL.on=enable
  if AL.hb then AL.hb:Disconnect() AL.hb=nil end
  if AL.conn then AL.conn:Disconnect() AL.conn=nil end
  if AL.conn2 then AL.conn2:Disconnect() AL.conn2=nil end
  if enable then
    if not AL.env then
      local e={gs=LS.GlobalShadows}
      pcall(function() local t=workspace.Terrain e.dec,e.ww,e.ws=t.Decoration,t.WaterWaveSize,t.WaterWaveSpeed end)
      AL.env=e
    end
    pcall(function() LS.GlobalShadows=false end)
    pcall(function() local t=workspace.Terrain t.Decoration=false t.WaterWaveSize=0 t.WaterWaveSpeed=0 end)
    for _,x in ipairs(LS:GetChildren()) do pcall(alApply,x) end
    AL.q=workspace:GetDescendants()
    AL.qi=1
    AL.conn=on(workspace.DescendantAdded,function(x) AL.q[#AL.q+1]=x end)
    AL.conn2=on(LS.DescendantAdded,function(x) AL.q[#AL.q+1]=x end) -- Post-Effekte, die spaeter in Lighting dazukommen
    AL.hb=on(RS.Heartbeat,function() alStep(0.002) end)
  else
    local e=AL.env
    if e then
      AL.env=nil
      pcall(function() LS.GlobalShadows=e.gs end)
      pcall(function() local t=workspace.Terrain t.Decoration,t.WaterWaveSize,t.WaterWaveSpeed=e.dec,e.ww,e.ws end)
    end
    local list={}
    for x,v in pairs(AL.orig) do list[#list+1]={x,v} end
    AL.rest,AL.ri=list,1
    AL.q,AL.qi={},1
    AL.hb=on(RS.Heartbeat,function()
      if alRestore(0.002) and AL.hb then
        AL.hb:Disconnect()
        AL.hb=nil
      end
    end)
  end
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
cyc(Z.bSize,"scale",SCALES,function() tw(uis,{Scale=SCALES[cfg.scale]},.4,Enum.EasingStyle.Back) task.delay(.5,clampMain) end)
cyc(Z.bTrans,"trans",TRANS,function() tw(main,{BackgroundTransparency=TRANS[cfg.trans]},.3) end)
on(Z.bLag.MouseButton1Click,function()
  cfg.lag=not cfg.lag
  alRun(cfg.lag)
  optTxt() saveCfg()
  st(cfg.lag and "Anti-Lag on" or "Anti-Lag off")
end)
on(Z.bIntro.MouseButton1Click,function()
  cfg.intro=not cfg.intro
  if not cfg.intro then
    if introS then pcall(function() introS:Stop() introS:Destroy() end) introS=nil end
    if introG then pcall(function() introG:Destroy() end) introG=nil end
  end
  optTxt() saveCfg()
end)

-- Intro-Song: einmal beim Start (Datei .mp3/.ogg in ShoxHub/music/ oder ShoxHub/, Name mit "intro" wird bevorzugt)
local idbg,ilog,playIntro,ensureIntro
do
local INTRO_URL="https://raw.githubusercontent.com/ShoxHub/Shox-Hub-Ctd/main/intro.ogg"
local INTRO_URL2="https://files.catbox.moe/j5p4sg.ogg"
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

-- Beat-Intro v2.3: Zeitplan in Sekunden ab Songstart (abgestimmt auf die 5,06-s-Intro-Datei)
-- {Zeit, Staerke, Art}: a = SHOX knallt rein, b = HUB knallt rein, drop = Drop, end = Finale
-- Neu: Glanz-Text, Glut-Funken, Vignette, Glitch-Balken, Boot-Overlay mit Ladebalken, Schockwellen, Blitz-Flash beim Drop
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
  mk("UIGradient",{Rotation=90,Color=ColorSequence.new(T.bg:Lerp(T.acc,0.2),T.bg)},bg)
  -- grosses pulsierendes Leuchten hinter dem Logo
  local glow=mk("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(620*base,620*base),BackgroundColor3=T.acc,BackgroundTransparency=0.92,BorderSizePixel=0},ig)
  mk("UICorner",{CornerRadius=UDim.new(1,0)},glow)
  local lay=mk("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0,ClipsDescendants=true},ig) -- Ebene fuer Glut/Blaetter, liegt hinter dem Logo
  local stage=mk("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0},ig)
  local sc=mk("UIScale",{Scale=base},stage)
  local L={}
  local shine=shineSeq(T)
  for i,ch in ipairs(LET) do
    local x=-163+(i-1)*50+(i>=5 and 26 or 0)
    local w=mk("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,x,.5,-10),Size=UDim2.fromOffset(50,80),BackgroundTransparency=1,BorderSizePixel=0},stage)
    local us=mk("UIScale",{Scale=1},w)
    local lb=mk("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text=ch,Font=Enum.Font.GothamBlack,TextSize=76,TextColor3=W,TextTransparency=1},w)
    local lg=mk("UIGradient",{Color=shine},lb) -- Shiny Text: Glanzstreifen laeuft ueber alle Buchstaben
    local lsk=mk("UIStroke",{Thickness=1,Color=T.acc,Transparency=1},lb) -- Glow, flackert bei jedem Beat auf
    L[i]={w=w,us=us,lb=lb,lg=lg,sk=lsk,x=x,hit=-10,amp=0,rev=math.huge}
  end
  local line=mk("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,52),Size=UDim2.fromOffset(0,4),BackgroundColor3=T.acc,BorderSizePixel=0},stage)
  local sub=mk("TextLabel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,80),Size=UDim2.fromOffset(376,22),BackgroundTransparency=1,Text=GAME.sub,Font=Enum.Font.GothamBold,TextSize=15,TextColor3=T.sub,TextTransparency=1,TextTruncate=Enum.TextTruncate.AtEnd},stage)
  -- Boot-Overlay oben + Ladebalken unten
  local tag=mk("TextLabel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.1,0),Size=UDim2.fromOffset(360,20),BackgroundTransparency=1,Text="",Font=Enum.Font.Code,TextSize=14,TextColor3=T.acc,TextTransparency=1,ZIndex=6},ig)
  local barBg=mk("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.9,0),Size=UDim2.fromOffset(260,5),BackgroundColor3=T.btn,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=6},ig)
  mk("UICorner",{CornerRadius=UDim.new(1,0)},barBg)
  local barFill=mk("Frame",{Size=UDim2.fromScale(0,1),BackgroundColor3=T.acc,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=7},barBg)
  mk("UICorner",{CornerRadius=UDim.new(1,0)},barFill)
  local pct=mk("TextLabel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.9,16),Size=UDim2.fromOffset(260,16),BackgroundTransparency=1,Text="",Font=Enum.Font.Code,TextSize=12,TextColor3=T.sub,TextTransparency=1,ZIndex=6},ig)
  local fl=mk("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=T.acc,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=5},ig)
  -- Skip-Button oben rechts (Theme-Look wie die Buttons im Hub)
  local skip=mk("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,0,14),Size=UDim2.fromOffset(78,32),BackgroundColor3=T.btn,Text="Skip",TextColor3=T.btxt,Font=Enum.Font.GothamBold,TextSize=14,AutoButtonColor=false,BorderSizePixel=0,ZIndex=10},ig)
  mk("UICorner",{CornerRadius=UDim.new(0,9)},skip)
  local skS=mk("UIStroke",{Color=T.acc,Thickness=1,Transparency=0.55,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},skip)
  local skU=mk("UIScale",{Scale=1},skip)
  on(skip.InputBegan,function(x) if isIn(x) then tw(skU,{Scale=0.93},.08) end end)
  on(skip.InputEnded,function(x) if isIn(x) then tw(skU,{Scale=1},.3,Enum.EasingStyle.Back) end end)
  local PAL={T.acc,T.pon,W,T.acc:Lerp(W,0.5)}
  local function spark(n,wide)
    for _=1,n do
      local a=math.random()*math.pi*2
      local d=(wide and 300 or 140)*(0.4+math.random()*0.8)
      local sx=L[math.random(1,#L)].x
      local sz=math.random(4,9)
      local p=mk("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,sx,.5,-10),Size=UDim2.fromOffset(sz,sz),Rotation=math.random(0,90),BackgroundColor3=PAL[math.random(1,#PAL)],BorderSizePixel=0},stage)
      tw(p,{Position=UDim2.new(.5,sx+math.cos(a)*d,.5,-10+math.sin(a)*d),BackgroundTransparency=1,Size=UDim2.fromOffset(2,2),Rotation=p.Rotation+math.random(-200,200)},0.6)
      task.delay(0.65,function() p:Destroy() end)
    end
  end
  local function ring(th,col)
    local r=mk("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.5,-10),Size=UDim2.fromOffset(40,40),BackgroundTransparency=1,BorderSizePixel=0},stage)
    mk("UICorner",{CornerRadius=UDim.new(1,0)},r)
    local sk=mk("UIStroke",{Thickness=th,Color=col or T.acc},r)
    tw(r,{Size=UDim2.fromOffset(900,900)},0.7)
    tw(sk,{Transparency=1},0.7)
    task.delay(0.8,function() r:Destroy() end)
  end
  -- Glitch: kurze waagerechte Balken blitzen quer ueber den Bildschirm
  local function glitch(n)
    for _=1,n do
      local h=math.random(3,28)
      local gw=math.random(20,55)/100
      local gb=mk("Frame",{Position=UDim2.new(0.06+math.random()*(0.88-gw),0,0.06+math.random()*0.88,0),Size=UDim2.new(gw,0,0,h),BackgroundColor3=PAL[math.random(1,3)],BackgroundTransparency=0.45+math.random()*0.3,BorderSizePixel=0,ZIndex=4},ig)
      task.delay(0.05+math.random()*0.09,function() gb:Destroy() end)
    end
  end
  local tl,bi,pulse,shake,flashA,ul,subA=0,1,0,0,0,0,0
  local leafT,emT,tagT=0,0,0
  local LEAF={C(214,90,20),C(240,170,40),C(150,60,20),C(190,120,30)}
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
    shake=math.max(shake,7*s)
    flashA=math.max(flashA,math.min(0.12*s,0.4))
    fl.BackgroundColor3=T.acc
    local a,z,amp=1,#L,0.3*s
    if kind=="a" then a,z,amp=1,4,1.7 elseif kind=="b" then a,z,amp=5,7,1.7 end
    for i=a,z do
      local e=L[i]
      e.hit=tl+(i-a)*0.035
      e.amp=amp
      if amp>1 then e.rev=e.hit end
    end
    if kind=="drop" then
      -- Schock-Moment: Weiss-Blitz, Zoom-Punch, starkes Zittern, Glitch-Gewitter, doppelte Schockwelle
      pulse=0.6 shake=40 flashA=1
      fl.BackgroundColor3=W
      ring(7) task.delay(0.1,function() ring(4,W) end) task.delay(0.22,function() ring(2) end)
      spark(36,true)
      glitch(14)
      for k=1,4 do task.delay(k*0.06,function() if not done then glitch(5) end end) end
    elseif kind=="end" then
      pulse=0.38 shake=24 flashA=0.8
      ring(5) ring(2,W) spark(26,true)
      glitch(7)
    else
      spark(math.floor(5*s)+2,false)
      if s>=0.9 and math.random()<0.6 then glitch(2) end
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
    glow.BackgroundTransparency=math.max(0.93-pulse*0.9-flashA*0.4,0)*(1-f)+f
    glow.Size=UDim2.fromOffset((620+pulse*500)*base,(620+pulse*500)*base)
    local swp=(tl*0.85)%2.4-1.2 -- Glanzstreifen: laeuft von links nach rechts ueber das Wort
    for i,e in ipairs(L) do
      local age=tl-e.hit
      e.lb.TextTransparency=(tl>=e.rev) and f or 1
      local d=age>=0 and math.exp(-age*5.5) or 0
      e.w.Position=UDim2.new(.5,e.x,.5,-10-(age>=0 and math.abs(math.sin(age*12))*22*d or 0))
      e.w.Rotation=age>=0 and math.sin(age*10)*7*d*(i%2==0 and 1 or -1) or 0
      e.us.Scale=1+(age>=0 and e.amp*math.exp(-age*8) or 0)
      local gl=(age>=0 and tl>=e.rev) and math.exp(-age*6) or 0
      e.sk.Thickness=1+gl*3.5
      e.sk.Transparency=1-0.9*gl*(1-e.lb.TextTransparency)
      e.lg.Offset=Vector2.new(math.clamp(swp-(i-1)*0.16+gl*0.6,-1,1),0)
    end
    if tl>=0.84 then ul=math.min(1,ul+dt*3.5) end
    line.Size=UDim2.fromOffset(376*ul,4)
    line.BackgroundTransparency=f
    if tl>=3.15 then
      subA=math.min(1,subA+dt*5)
      if sub.Text~=GAME.sub then sub.Text=GAME.sub end
    end
    sub.TextTransparency=math.max(1-subA,f)
    skip.BackgroundTransparency=f
    skip.TextTransparency=f
    skS.Transparency=math.max(0.55,f)
    -- Boot-Overlay: Text wechselt mit dem Song, flackert, beim Drop "ACCESS GRANTED"
    tagT-=dt
    if tagT<=0 then
      tagT=0.06
      local txt
      if tl<0.8 then txt="BOOTING SHOX CORE"
      elseif tl<1.7 then txt="LOADING MODULES"
      elseif tl<2.48 then txt="INJECTING PAYLOAD"
      elseif tl<3.6 then txt="ACCESS GRANTED"
      else txt="WELCOME BACK" end
      tag.Text=txt
      tag.TextColor3=(tl>=2.48 and tl<3.6) and T.pon or T.acc
      local fk=(tl<2.48 and math.random()<0.25) and 0.55 or 0.05
      tag.TextTransparency=math.max(1-math.min(tl*6,1)+fk*(tl<0.4 and 0 or 1),f)
    end
    local prog=math.clamp(tl/(FADE0-0.1),0,1)
    local ba=math.max(1-math.min(tl*6,1),f)
    barBg.BackgroundTransparency=math.max(ba,0.35*0+ (ba<1 and 0.35 or 1))
    barFill.BackgroundTransparency=ba
    barFill.Size=UDim2.fromScale(prog,1)
    pct.Text=string.format("%d%%",math.floor(prog*100))
    pct.TextTransparency=math.max(ba,f)
    -- Glut-Funken und Blaetter fliegen aus dem Logo heraus (nicht vom Bildschirmrand)
    emT-=dt
    if emT<=0 and tl<FADE0 then
      emT=0.03
      local es=math.random(3,7)
      local sx=L[math.random(1,#L)].x
      local ang=-math.pi/2+(math.random()-.5)*1.7
      local dist=90+math.random()*170
      local em=mk("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,sx,.5,-10),Size=UDim2.fromOffset(es,es),BackgroundColor3=PAL[math.random(1,2)],BorderSizePixel=0,Rotation=math.random(0,90),ZIndex=0},stage)
      mk("UICorner",{CornerRadius=UDim.new(1,0)},em)
      local ed=0.8+math.random()*0.9
      tw(em,{Position=UDim2.new(.5,sx+math.cos(ang)*dist,.5,-10+math.sin(ang)*dist),BackgroundTransparency=1,Size=UDim2.fromOffset(1,1)},ed,Enum.EasingStyle.Sine)
      task.delay(ed+0.1,function() em:Destroy() end)
    end
    if themeName=="Turkey" and tl<FADE0 then
      leafT-=dt
      if leafT<=0 then
        leafT=0.09
        local a2=math.random()*math.pi*2
        local dd=150+math.random()*190
        local sx=L[math.random(1,#L)].x
        local lf=mk("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,sx,.5,-10),Size=UDim2.fromOffset(math.random(8,14),math.random(5,8)),Rotation=math.random(0,360),BackgroundColor3=LEAF[math.random(1,#LEAF)],BorderSizePixel=0,ZIndex=0},stage)
        mk("UICorner",{CornerRadius=UDim.new(1,0)},lf)
        local dur=1.0+math.random()*0.9
        tw(lf,{Position=UDim2.new(.5,sx+math.cos(a2)*dd,.5,-10+math.sin(a2)*dd+70),Rotation=lf.Rotation+math.random(-360,360),BackgroundTransparency=1},dur,Enum.EasingStyle.Sine)
        task.delay(dur+0.1,function() lf:Destroy() end)
      end
    end
    if tl>=FADE1 then finish(false) end
  end)
end
function playIntro()
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
idbg={}
function ilog(s) idbg[#idbg+1]=os.date("%H:%M:%S").." "..s end
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
function ensureIntro()
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
end

G.ShoxOff=function()
  alive=false rec,play=false,false gen+=1
  G.ShoxH=nil
  G.ShoxAK=false
  pcall(saveCfg)
  pcall(function() if introS then introS:Stop() introS:Destroy() end end)
  pcall(function() if introG then introG:Destroy() end end)
  pcall(alRun,false)
  pcall(alRestore,1e9)
  for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
  for b,e in pairs(bconns) do pcall(function() e[1]:Disconnect() e[2]:Disconnect() end) bconns[b]=nil end
  gui:Destroy()
end

-- Aufnahme
local function add(tt,k,p,m,a)
  if #steps>=15000 then return end
  local e={}
  for i=1,a.n do e[i]=enc(a[i]) end
  if k=="R" or k=="B" then
    local key=k..HS:JSONEncode({p,tostring(m),e})
    if key==lastK and tt-lastT<K.DEDUP then return end
    lastK,lastT=key,tt
  end
  local s={t=tt,k=k,p=p,m=m,a=e,n=a.n}
  steps[#steps+1]=s
  return s
end
-- Smart Learn: unbekannte Remotes (z.B. neue Spiele) live einordnen, ohne dass Namen bekannt sein muessen.
--  Platzieren = Remote mit Position, danach erscheint innerhalb von 2,5 s ein neuer Tower (Model) nahe dieser Position.
--  Upgrade/Sell = ein Argument ist eine bekannte Tower-Id (Name eines Towers im Container) oder ein Tower-Instance.
-- Pro Remote-Name max. 6 Versuche, Ergebnis wird pro Game gespeichert (ShoxHub/learned_<GameId>.json).
function K.argHit(v,d,ids)
  local t=typeof(v)
  if t=="string" then return ids[v] and v or nil end
  if t=="Instance" then
    for id,x in pairs(ids) do
      if v==x or v:IsDescendantOf(x) then return id end
    end
  elseif t=="table" and d<3 then
    for _,x in pairs(v) do
      local r=K.argHit(x,d+1,ids)
      if r then return r end
    end
  end
end
function K.learn(s,remote,a)
  local nm=remote.Name
  local tk=nm..":"..tostring(K.code(s) or "")
  K.TRY[tk]=(K.TRY[tk] or 0)+1
  if K.TRY[tk]>6 then return end
  local pos=K.posOf(s)
  if pos then
    local added,set={},{}
    local c=workspace.DescendantAdded:Connect(function(x) added[#added+1]=x set[x]=true end)
    task.wait(2.5)
    c:Disconnect()
    local Plrs=game:GetService("Players")
    local best,bd
    for _,x in ipairs(added) do
      if x.Parent and not set[x.Parent] and x:IsA("PVInstance") and not x:IsA("Terrain") then
        local anc=x:FindFirstAncestorWhichIsA("Model")
        local chr=(x:IsA("Model") and Plrs:GetPlayerFromCharacter(x)) or (anc and Plrs:GetPlayerFromCharacter(anc))
        local px=pv(x)
        if not chr and px and not x:IsDescendantOf(workspace.CurrentCamera) then
          local d=(px-pos).Magnitude
          if d<=K.NEAR then
            local isM=x:IsA("Model")
            if not best or (isM and not best:IsA("Model")) or (isM==best:IsA("Model") and d<bd) then best,bd=x,d end
          end
        end
      end
    end
    if best then
      K.ADDS[nm]=true K.LRN.add[nm]=true
      if not K.TC and best.Parent then K.TC=path(best.Parent) end
      s.tid=best.Name
      K.saveLrn()
      pcall(optTxt)
    end
    return -- Remotes mit Position werden nie als Upgrade/Sell eingestuft
  end
  local ids=gather()
  if next(ids)==nil then return end
  for i=1,a.n do
    if K.argHit(a[i],1,ids) then
      K.USE[nm]=true K.LRN.use[nm]=true
      K.saveLrn()
      pcall(optTxt)
      return
    end
  end
end
G.ShoxH=function(self,m,...)
  if not (alive and rec) then return end
  local tt,a=os.clock()-t0,table.pack(...)
  task.spawn(pcall,function()
    if typeof(self)=="Instance" and not K.IGNORE[self.Name] then
      local s=add(tt,"R",path(self),m,a)
      local kd=s and K.kind(self.Name,s)
      if s and kd=="add" then
        local bf=gather()
        local id,n=newId(bf,s)
        if id then s.tid=id st("Tower-Id "..id:sub(1,8).." ("..n..")")
        else st("Tower-Id: none ("..n..")") end
      elseif s and kd=="use" then
        if not idloc then
          idloc=true
          s.loc=locate(K.uidOf(s))
        end
      elseif s and cfg.smart then
        K.learn(s,self,a)
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
      if G.ShoxAK and self==lp and type(m)=="string" and m:lower()=="kick" then
        local f=G.ShoxKick
        if f then pcall(f,"Kick (namecall) geblockt",...) end
        return
      end
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
local pg=lp:WaitForChild("PlayerGui")
local function unhookBtn(b)
  local e=bconns[b]
  if e then
    pcall(function() e[1]:Disconnect() e[2]:Disconnect() end)
    bconns[b]=nil
  end
  hooked[b]=nil
end
local function hookBtn(b)
  if b:IsA("GuiButton") and not hooked[b] and not b:IsDescendantOf(gui) and not (introG and b:IsDescendantOf(introG)) then
    hooked[b]=true
    local c1=b.Activated:Connect(function()
      if rec then add(os.clock()-t0,"B",path(b),b:IsA("TextButton") and b.Text or "",{n=0}) end
    end)
    -- Verbindung wird getrennt, sobald der Button aus dem PlayerGui verschwindet
    local c2=b.AncestryChanged:Connect(function()
      if not b:IsDescendantOf(pg) then unhookBtn(b) end
    end)
    bconns[b]={c1,c2}
  end
end
for _,o in ipairs(pg:GetDescendants()) do hookBtn(o) end
on(pg.DescendantAdded,hookBtn)

-- Effekte pro Frame (Rahmen-Rotation, Titel-Glanz, Puls bei Record/Play) + Anzeige alle 0.5s
-- Stats: Gesamtzeit laeuft live mit und wird alle 15 s gespeichert (bleibt auch bei Rejoin/Kick erhalten)
local pulsers={{Z.bRec,function() return rec end},{Z.bPlay,function() return play end}}
local ac2,rot,stSave=0,0,0
on(RS.Heartbeat,function(dt)
  local c=os.clock()
  rot=(rot+dt*((rec or play) and 140 or 50))%360
  mGrad.Rotation=rot
  mbGrad.Rotation=rot
  Z.titleG.Offset=Vector2.new((c*0.7)%2.6-1.3,0) -- Shiny Text: Glanzstreifen wandert ueber den Titel
  Z.divG.Offset=Vector2.new((c*0.4)%2-1,0)
  local a=(math.sin(c*5)+1)/2
  Z.titleS.Transparency=0.55+0.35*((math.sin(c*2)+1)/2)
  for _,p in ipairs(pulsers) do
    local sk=skm[p[1]]
    if p[2]() then
      p.on=true
      sk.Color=T.acc sk.Thickness=1.5+a*2 sk.Transparency=0.5*(1-a)
    elseif p.on then
      p.on=false
      sk.Color=F.Line(T) sk.Thickness=1 sk.Transparency=0.55
    end
  end
  if play and runT0 then
    cfg.st.time+=dt
    stSave+=dt
    if stSave>=15 then stSave=0 saveCfg() end
  end
  ac2+=dt
  if ac2<0.5 then return end
  ac2=0
  if rec then Z.bRec.Text=recTxt()
  elseif play and runT0 then
    statsTxt()
    local lim=RUNS[cfg.runs]
    if waitEnd then stq("Run "..runI.." | waiting for Play Again...")
    else stq("Run "..runI..(lim>0 and ("/"..lim) or "").." | "..mmss(os.clock()-runT0).." / "..mmss(runTot)) end
  end
end)

-- Abspielen
local function lg(e) if #rlog<300 then rlog[#rlog+1]=e end end
local function binfo(o) -- nur fuers Copy Log: Zustand eines Buttons (Text/Farben)
  local t={}
  local function one(x)
    local e=x.Name..":"..x.ClassName
    pcall(function()
      if x:IsA("TextLabel") or x:IsA("TextButton") then e=e.." t='"..x.Text.."'" end
      if x:IsA("GuiObject") then
        local c=x.BackgroundColor3
        e=e..string.format(" bg=%d,%d,%d v=%s",math.floor(c.R*255),math.floor(c.G*255),math.floor(c.B*255),tostring(x.Visible))
      end
      if x:IsA("ImageLabel") or x:IsA("ImageButton") then
        local c=x.ImageColor3
        e=e..string.format(" im=%d,%d,%d",math.floor(c.R*255),math.floor(c.G*255),math.floor(c.B*255))
      end
    end)
    t[#t+1]=e
  end
  one(o)
  local n=0
  for _,x in ipairs(o:GetDescendants()) do
    n+=1
    if n>6 then break end
    one(x)
  end
  return table.concat(t," | ")
end
local function skipB(s)
  local nm=(table.concat(s.p,"."):gsub("\1","#")..tostring(s.m)):lower()
  for _,w in ipairs(K.SKIPB) do if nm:find(w,1,true) then return true end end
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
  -- map/used/pend: Platzieren + Id-Zuordnung laufen parallel zum Zeitplan (blockieren ihn nicht mehr)
  local map,used,pend=idmap,{},0
  local ordl,inOrd,oi={},{},0
  local hasRPA=false
  local tset,orph={},{}
  for _,s in ipairs(steps) do if s.tid then tset[s.tid]=true end end
  K.TIDS=tset
  for _,s in ipairs(steps) do
    if s.k=="R" then
      if K.kind((s.p[#s.p]:gsub("\1%d+$","")),s)=="use" then
        local id=K.uidOf(s)
        if type(id)=="string" and not inOrd[id] then inOrd[id]=true ordl[#ordl+1]=id end
      end
      if isEnd(s) then hasRPA=true end
    end
  end
  for _,id in ipairs(ordl) do if not tset[id] then orph[#orph+1]=id end end
  local base,pk,pt=os.clock(),nil,0
  local paAt,fired=-10,false
  for _,s0 in ipairs(steps) do -- Anker: ohne sichtbaren Start-/Vote-Button wuerde der Klick ins Leere gehen und alles danach waere zu frueh
    if not (s0.k=="B" and skipB(s0)) and not isEnd(s0) then
      if s0.k=="B" then
        local w0,got=os.clock(),false
        while play and gen==my and os.clock()-w0<60 do
          local ob=find(s0.p)
          if ob and vis(ob) then got=true break end
          task.wait(0.25)
        end
        if not (play and gen==my) then return end
        if got then base=os.clock()-s0.t end
      end
      break
    end
  end
  runT0,runTot=base,(steps[#steps] and steps[#steps].t or 0)
  for idx,s in ipairs(steps) do
    if not play or gen~=my then return end
    local key=s.k..HS:JSONEncode({s.p,tostring(s.m),s.a})
    if key==pk and s.t-pt<K.DEDUP then pt=s.t continue end
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
        if not ex and os.clock()>base+s.t+60 then break end -- kein Play-Again-Text auffindbar: nach Aufnahmezeit+60s trotzdem
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
    local w=base+s.t-os.clock()
    while w>0 and play and gen==my do
      if w>0.06 then task.wait(math.min(w-0.04,0.25)) else RS.Heartbeat:Wait() end -- kurz vorher aufwachen, dann auf den Frame genau
      w=base+s.t-os.clock()
    end
    if not play or gen~=my then return end
    local late=math.floor((os.clock()-(base+s.t))*100)/100 -- Verspaetung gegenueber dem Zeitplan (nur im Copy Log)
    local o=find(s.p)
    if not o then
      miss+=1
      lg({i=idx,nf=table.concat(s.p,"/")})
    elseif s.k=="R" and K.kind(o.Name,s)=="add" then
      -- Orphan-Zuordnung (Tower ohne eigenes Platzieren im Slot) bleibt in Reihenfolge, daher hier im Hauptlauf
      local oid
      if not (s.tid and inOrd[s.tid]) then
        oi+=1
        oid=orph[oi]
      end
      local myoi=oi
      pend+=1
      task.spawn(function()
        local ok,res,id,n,via=false,nil,nil,0,nil
        local f0=os.clock()
        local tries=0
        local pok,perr=pcall(function()
          local a=decArgs(s)
          local bf=gather()
          while true do
            tries+=1
            ok,res=pcall(function()
              if s.m=="FireServer" then return o:FireServer(table.unpack(a,1,s.n)) end
              return o:InvokeServer(table.unpack(a,1,s.n))
            end)
            id,n=newId(bf,s,used)
            if id or tries>=(K.LRN.add[o.Name] and 3 or 10) or not (play and gen==my) then break end
            id,n=newId(bf,s,used,1) -- kurz nachpruefen, damit ein spaeter Tower nicht doppelt gesetzt wird
            if id then break end
          end
        end)
        if not pok then ok,res=false,perr end
        if id then
          used[id]=true
          if s.tid and K.okId(s.tid) then map[s.tid]=id via="tid" end
          if oid and K.okId(oid) and not map[oid] then
            map[oid]=id via=(via and via.."+" or "").."ord"..myoi
          end
        end
        pend-=1
        lg({i=idx,n=o.Name,ok=ok,e=(not ok) and tostring(res) or nil,neu=n,via=via,got=id and id:sub(1,8),late=late,wt=math.floor((os.clock()-f0)*100)/100,tr=tries})
      end)
    else
      task.spawn(function()
        if s.k=="R" then
          if K.kind(o.Name,s)=="use" then
            -- Upgrade/Sell: kurz auf laufende Platzierungen warten, bis die neue Tower-Id zugeordnet ist
            local uid=K.uidOf(s)
            local w0=os.clock()
            while play and gen==my and not (uid and map[uid]) and pend>0 and os.clock()-w0<45 do task.wait(0.05) end
            if not (play and gen==my) then return end
            if uid and not map[uid] then
              lg({i=idx,n=o.Name,nomap=tostring(uid):sub(1,8),late=late})
              return
            end
          end
          local a=decArgs(s)
          local ok,res=pcall(function()
            if s.m=="FireServer" then return o:FireServer(table.unpack(a,1,s.n)) end
            return o:InvokeServer(table.unpack(a,1,s.n))
          end)
          if (not ok) or K.USE[o.Name] or s.m=="InvokeServer" then
            lg({i=idx,n=o.Name,ok=ok,e=(not ok) and tostring(res) or nil,r=(ok and s.m=="InvokeServer") and tostring(res):sub(1,40) or nil,id=K.USE[o.Name] and tostring(type(a[1])=="table" and a[1].Id):sub(1,8) or nil,late=late})
          end
        elseif firesignal then
          local isAS=table.concat(s.p,"."):lower():find("autoskip",1,true)
          if isAS then pcall(function() lg({i=idx,as0=binfo(o.Parent or o):sub(1,190)}) end) end
          local ok,e=pcall(firesignal,o.Activated)
          if not ok then lg({i=idx,b=o.Name,ok=ok,e=tostring(e)}) end
          if isAS then
            task.wait(0.7)
            pcall(function() lg({i=idx,as1=binfo(o.Parent or o):sub(1,190)}) end)
          end
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
  put("Shox Hub Slot "..slot.." | "..stats().." | runs="..RUNS[cfg.runs].." lag="..tostring(cfg.lag))
  put("Game: PlaceId="..tostring(game.PlaceId).." GameId="..tostring(game.GameId).." Name="..tostring(GAME.full))
  do
    local la,lu={},{}
    for n in pairs(K.LRN.add) do la[#la+1]=n end
    for n in pairs(K.LRN.use) do lu[#lu+1]=n end
    put("Learned: add="..(#la>0 and table.concat(la,",") or "-").." use="..(#lu>0 and table.concat(lu,",") or "-").." tc="..(K.TC and pstr(K.TC) or "-").." smart="..tostring(cfg.smart))
    if K.WARN then put(K.WARN) end
  end
  do -- welche Remotes wurden in diesem Slot aufgenommen
    local rc,ro={},{}
    for _,s in ipairs(steps) do
      if s.k=="R" then
        local nm=(s.p[#s.p]:gsub("\1%d+$",""))
        if not rc[nm] then rc[nm]=0 ro[#ro+1]=nm end
        rc[nm]+=1
      end
    end
    for i,nm in ipairs(ro) do ro[i]=nm.."x"..rc[nm] end
    put("Remotes: "..(#ro>0 and table.concat(ro,", ") or "-"))
  end
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
  put("--- KICK ---")
  for _,l in ipairs(K.KL) do put(l) end
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
on(Z.bRec.MouseButton1Click,function()
  if play then return end
  if rec then
    rec=false
    if #steps==0 then loadSlot(slot) st("Nothing recorded, slot "..slot.." unchanged") return end
    local ok,e=pcall(function() writefile(file(slot),HS:JSONEncode(steps)) end)
    if ok then filled[slot]=true pcall(writefile,DIR.."/slot"..slot..".gid",tostring(K.GID)) end
    st(ok and ("Slot "..slot.." saved: "..stats()) or ("Save error: "..tostring(e)))
    ui()
    return
  end
  if (#steps>0 or filled[slot]) and not armRec then
    armRec=true Z.bRec.Text="Overwrite slot?"
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
  K.WARN=nil
  do -- Check: wurde der Slot in einem anderen Game aufgenommen? (nur Copy Log, keine Anzeige)
    local okg,g=pcall(readfile,DIR.."/slot"..slot..".gid")
    if okg and type(g)=="string" and g~="" and g~=tostring(K.GID) then
      K.WARN="WARN: Slot "..slot.." aufgenommen in GameId "..g..", jetzt GameId "..tostring(K.GID)
    end
  end
  play=true gen+=1
  local my=gen
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
      cfg.st.runs+=1 cfg.st.rt+=took -- Gesamtzeit (st.time) zaehlt schon live im Heartbeat
      saveCfg() statsTxt()
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
on(Z.bPlay.MouseButton1Click,function()
  if rec then return end
  if play then
    play=false gen+=1 runT0=nil waitEnd=false
    cfg.ap=false -- Stop schaltet Auto-Play mit aus, sonst startet es nach dem naechsten Rejoin trotzdem wieder
    optTxt() saveCfg() statsTxt() st("Stopped") ui()
    return
  end
  startPlay()
end)
for i=1,5 do
  on(Z.sb[i].MouseButton1Click,function()
    if rec or play then return end
    armRec=false slot=i cfg.slot=i saveCfg() loadSlot(i) optTxt()
    -- kleiner Pop auf dem gewaehlten Slot
    local sc=scl[Z.sb[i]]
    tw(sc,{Scale=1.12},.1)
    task.delay(.1,function() tw(sc,{Scale=1},.4,Enum.EasingStyle.Back) end)
  end)
end
-- Auto-Play: an = spielt den gewaehlten Slot endlos und startet nach jedem Rejoin/Serverwechsel automatisch (per Auto-Execute)
on(Z.bRuns.MouseButton1Click,function()
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
on(Z.bSmart.MouseButton1Click,function()
  cfg.smart=not cfg.smart
  saveCfg() optTxt()
  st(cfg.smart and "Smart Learn on" or "Smart Learn off")
end)
confirm(Z.bForget,"Forget Learned",function()
  for n in pairs(K.LRN.add) do K.ADDS[n]=nil end
  for n in pairs(K.LRN.use) do K.USE[n]=nil end
  K.LRN={add={},use={}}
  K.TC=nil
  K.TRY={}
  pcall(delfile,K.LFILE)
  optTxt()
  st("Learned data cleared")
end)
local copyTok=0
on(Z.bCopy.MouseButton1Click,function()
  local ok=pcall(function() setclipboard(summary()) end)
  st(ok and "Log copied" or "Copy not possible")
  copyTok+=1
  local my=copyTok
  Z.bCopy.Text=ok and "Copied!" or "Error"
  task.delay(1.2,function() if copyTok==my then Z.bCopy.Text="Copy Log" end end)
end)
-- Export: aktuellen Slot als Text in die Zwischenablage (zusaetzlich als Datei ShoxHub/export_slotN.txt)
local expTok=0
on(Z.bExp.MouseButton1Click,function()
  if rec then return st("Stop recording first") end
  if #steps==0 then return st("Slot "..slot.." is empty") end
  local okj,js=pcall(function() return HS:JSONEncode(steps) end)
  if not okj then return st("Export failed") end
  local ok=pcall(setclipboard,js)
  pcall(writefile,DIR.."/export_slot"..slot..".txt",js)
  st(ok and ("Slot "..slot.." exported (copied)") or "Copy not possible")
  expTok+=1
  local my=expTok
  Z.bExp.Text=ok and "Copied!" or "Error"
  task.delay(1.2,function() if expTok==my then Z.bExp.Text="Export Slot" end end)
end)
-- Import: Code aus dem Textfeld (oder Datei ShoxHub/import.txt, wenn das Feld leer ist) in den gewaehlten Slot
confirm(Z.bImp,"Import Slot",function()
  if rec or play then return st("Stop first") end
  local txt=Z.pBox.Text or ""
  txt=txt:gsub("^%s+",""):gsub("%s+$","")
  if txt=="" then
    local okf,d=pcall(readfile,DIR.."/import.txt")
    if okf and type(d)=="string" then txt=d end
  end
  if txt=="" then return st("Paste a slot code first") end
  local ok,r=pcall(function() return HS:JSONDecode(txt) end)
  local new={}
  if ok and type(r)=="table" then
    for _,s in ipairs(r) do
      if #new>=15000 then break end
      if type(s)=="table" and (s.k=="R" or s.k=="B") and type(s.p)=="table" and type(s.t)=="number" and type(s.n)=="number" and type(s.a)=="table" and type(s.m)=="string" then
        new[#new+1]=s
      end
    end
  end
  if #new==0 then return st("Import failed: invalid code") end
  local okw=pcall(writefile,file(slot),HS:JSONEncode(new))
  if not okw then return st("Import failed: cannot save") end
  Z.pBox.Text=""
  loadSlot(slot)
  st("Slot "..slot.." imported: "..stats())
end)
confirm(Z.bDelCur,"Delete Current",function()
  rec,play=false,false
  gen+=1 runT0=nil waitEnd=false
  loadSlot(slot) -- Speicher wieder mit der gespeicherten Slot-Datei abgleichen
  st("Current recording discarded") ui()
end)
on(Z.nBox.FocusLost,function()
  local t=Z.nBox.Text:gsub("^%s+",""):gsub("%s+$","")
  t=t:sub(1,20)
  cfg.names[tostring(slot)]=(t~="") and t or nil
  Z.nBox.Text=t
  saveCfg()
  st(t~="" and ("Slot "..slot.." named: "..t) or ("Slot "..slot.." name cleared"))
end)
confirm(Z.bStR,"Reset Stats",function()
  cfg.st={runs=0,time=0,rt=0}
  saveCfg() statsTxt()
  st("Stats reset")
end)
confirm(Z.bDelSlot,"Delete Slot",function()
  if rec or play then return st("Stop first") end
  pcall(delfile,file(slot))
  steps={} filled[slot]=false
  st("Slot "..slot.." deleted") ui()
end)

-- Start
for n=1,5 do
  local ok,r=pcall(isfile,file(n))
  filled[n]=ok and r==true
end
applyTheme(TM[cfg.theme] and cfg.theme or "Turkey",true)
showCopy()
tw(main,{Size=UDim2.fromOffset(220,WIN_H),BackgroundTransparency=TRANS[cfg.trans]},.7,Enum.EasingStyle.Back)
task.delay(0.9,clampMain)
statsTxt()
loadSlot(slot)
task.spawn(function() ensureIntro() local w=os.clock() while alive and not GAME.done and os.clock()-w<3 do task.wait(0.05) end playIntro() ilog("playIntro returned, intro running="..tostring(introS~=nil)) end)
task.spawn(function()
  if not game:IsLoaded() then game.Loaded:Wait() end
  if alive and cfg.lag then alRun(true) end
  if alive and cfg.ap then
    local w0=os.clock()
    while alive and not (lp.Character and lp.Character.Parent) and os.clock()-w0<20 do task.wait(0.25) end -- erst starten, wenn der Charakter da ist
    task.wait(4) -- UI/Charakter/Spiel kurz laden lassen
    if alive and cfg.ap and not rec and not play then
      st("Auto-Play: starting Slot "..slot)
      startPlay()
    end
  end
end)
