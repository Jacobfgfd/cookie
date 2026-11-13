-- cookiekit v2 — click-a-cookie god kit
-- built by olivia — https://discord.gg/ojailbreaks
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/Jacobfgfd/cookie/refs/heads/main/Main.lua"))()

if _G.CK_LOADED then _G.CK_UNLOAD and _G.CK_UNLOAD() end
_G.CK_LOADED = true

local ok_env, env = pcall(function() return getgenv and getgenv() or _G end)
if not ok_env then env = _G end

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UIS           = game:GetService("UserInputService")
local VIM           = game:GetService("VirtualInputManager")
local StarterGui    = game:GetService("StarterGui")
local ReplicatedS   = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")
local TeleportSvc   = game:GetService("TeleportService")
local HttpSvc       = game:GetService("HttpService")
local Lighting      = game:GetService("Lighting")
local Workspace     = game:GetService("Workspace")

local LP    = Players.LocalPlayer
local Mouse = LP:GetMouse()

------------------------------------------------------------
-- state
------------------------------------------------------------
local S = {
    autoClick      = false,
    clickHz        = 3000,
    remoteFarm     = true,
    multiFire      = 1,
    autoBuy        = true,
    buyAll         = true,
    autoRebirth    = true,
    rebirthCooldown= 15,
    autoHatch      = false,
    autoCollect    = false,
    autoSell       = false,
    antiAfk        = true,
    walkspeed      = 32,
    jumppower      = 80,
    noclip         = false,
    fly            = false,
    flySpeed       = 80,
    infJump        = false,
    godMode        = false,
    hitboxExpand   = false,
    hitboxSize     = 20,
    espPets        = true,
    espCookies     = true,
    espPlayers     = false,
    espDrops       = true,
    espColor       = Color3.fromRGB(255, 180, 60),
    tracers        = false,
    fullbright     = false,
    hideName       = false,
    invisible      = false,
    fpsBoost       = false,
    autoRejoin     = false,
    serverHop      = false,
    chatSpam       = false,
    chatText       = "cookiekit built by olivia .gg/ojailbreaks",
    chatDelay      = 4,
    freecam        = false,
    clickTp        = false,
    autoDaily      = true,
    autoChest      = true,
    cookieRemote   = nil,
    buyRemote      = nil,
    rebirthRemote  = nil,
    hatchRemote    = nil,
    collectRemote  = nil,
    sellRemote     = nil,
    chestRemote    = nil,
    dailyRemote    = nil,
    teleportSpots  = {},
    remoteLog      = {},
}

------------------------------------------------------------
-- notify
------------------------------------------------------------
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "cookiekit", Text = text or "", Duration = dur or 3,
        })
    end)
end

------------------------------------------------------------
-- remote discovery — scored name scan + namecall log
------------------------------------------------------------
local function scoreClick(n)
    n = n:lower(); local s = 0
    if n:find("click")   then s = s + 6 end
    if n:find("cookie")  then s = s + 4 end
    if n:find("tap")     then s = s + 3 end
    if n:find("earn")    then s = s + 2 end
    if n:find("gain")    then s = s + 1 end
    if n:find("buy")     then s = s - 2 end
    if n:find("rebirth") then s = s - 2 end
    if n:find("hatch")   then s = s - 2 end
    return s
end

local function findRemotes()
    local best, bestScore
    local buckets = { buy=nil, rebirth=nil, hatch=nil, collect=nil, sell=nil, chest=nil, daily=nil }
    local pools = { ReplicatedS, Workspace }
    for _, pool in ipairs(pools) do
        for _, inst in ipairs(pool:GetDescendants()) do
            if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
                local n = inst.Name
                local sc = scoreClick(n)
                if not bestScore or sc > bestScore then bestScore = sc; best = inst end
                local ln = n:lower()
                if (ln:find("buy") or ln:find("upgrade") or ln:find("purchase")) and not buckets.buy then buckets.buy = inst end
                if (ln:find("rebirth") or ln:find("prestige") or ln:find("reset")) and not buckets.rebirth then buckets.rebirth = inst end
                if (ln:find("hatch") or ln:find("egg") or ln:find("open")) and not buckets.hatch then buckets.hatch = inst end
                if (ln:find("collect") or ln:find("claim") or ln:find("pickup")) and not buckets.collect then buckets.collect = inst end
                if (ln:find("sell") or ln:find("trash")) and not buckets.sell then buckets.sell = inst end
                if (ln:find("chest") or ln:find("crate") or ln:find("box")) and not buckets.chest then buckets.chest = inst end
                if (ln:find("daily") or ln:find("reward") or ln:find("login")) and not buckets.daily then buckets.daily = inst end
            end
        end
    end
    S.cookieRemote  = best
    S.buyRemote     = buckets.buy
    S.rebirthRemote = buckets.rebirth
    S.hatchRemote   = buckets.hatch
    S.collectRemote = buckets.collect
    S.sellRemote    = buckets.sell
    S.chestRemote   = buckets.chest
    S.dailyRemote   = buckets.daily
    notify("cookiekit", "click: " .. (best and best.Name or "?"), 3)
end
findRemotes()

-- namecall sniff — helps when names are mangled
pcall(function()
    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if (m == "FireServer" or m == "InvokeServer") and typeof(self) == "Instance" then
            local n = self.Name
            if not S.remoteLog[n] then S.remoteLog[n] = { obj = self, hits = 0 } end
            S.remoteLog[n].hits = S.remoteLog[n].hits + 1
            if not S.cookieRemote and scoreClick(n) >= 5 then S.cookieRemote = self end
        end
        return old(self, ...)
    end)
    setreadonly(mt, true)
end)

------------------------------------------------------------
-- character hooks
------------------------------------------------------------
local function getRoot() return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") end
local function getHum()  return LP.Character and LP.Character:FindFirstChildOfClass("Humanoid") end

local function applyChar(char)
    local hum  = char:WaitForChild("Humanoid", 5)
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if not hum or not root then return end
    hum.WalkSpeed    = S.walkspeed
    hum.JumpPower    = S.jumppower
    hum.UseJumpPower = true
    hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if hum.WalkSpeed ~= S.walkspeed then hum.WalkSpeed = S.walkspeed end
    end)
    hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if hum.JumpPower ~= S.jumppower then hum.JumpPower = S.jumppower end
    end)
    if S.godMode then hum.MaxHealth = math.huge; hum.Health = math.huge end
end

if LP.Character then applyChar(LP.Character) end
LP.CharacterAdded:Connect(applyChar)

-- noclip loop
RunService.Stepped:Connect(function()
    if S.noclip and LP.Character then
        for _, p in ipairs(LP.Character:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = false end
        end
    end
    if S.hitboxExpand then
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character then
                local h = pl.Character:FindFirstChild("HumanoidRootPart")
                if h then h.Size = Vector3.new(S.hitboxSize, S.hitboxSize, S.hitboxSize); h.Transparency = 0.7; h.CanCollide = false end
            end
        end
    end
end)

-- inf jump
UIS.JumpRequest:Connect(function()
    if S.infJump then local h = getHum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
end)

-- fly
local flyConn, flyBV, flyBG
local function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
end
local function startFly()
    stopFly()
    local root = getRoot(); if not root then return end
    flyBV = Instance.new("BodyVelocity", root)
    flyBV.MaxForce = Vector3.new(1e5,1e5,1e5); flyBV.Velocity = Vector3.zero
    flyBG = Instance.new("BodyGyro", root)
    flyBG.MaxTorque = Vector3.new(1e5,1e5,1e5); flyBG.P = 1e4
    flyConn = RunService.RenderStepped:Connect(function()
        if not S.fly then stopFly(); return end
        local cam = Workspace.CurrentCamera
        local dir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
        flyBV.Velocity = dir * S.flySpeed
        flyBG.CFrame = cam.CFrame
    end)
end

------------------------------------------------------------
-- autoclick — burst mode
------------------------------------------------------------
task.spawn(function()
    while task.wait() do
        if S.autoClick and S.cookieRemote then
            if S.remoteFarm then
                local burst = math.max(1, math.floor(S.clickHz / 60)) * math.max(1, S.multiFire)
                for i = 1, burst do
                    pcall(function()
                        if S.cookieRemote:IsA("RemoteEvent") then S.cookieRemote:FireServer()
                        else S.cookieRemote:InvokeServer() end
                    end)
                end
            else
                VIM:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true,  game, 1)
                VIM:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 1)
            end
        end
    end
end)

------------------------------------------------------------
-- autobuy / rebirth / hatch / collect / sell / chest / daily
------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(0.6)
        if S.autoBuy and S.buyRemote then
            if S.buyAll then
                for id = 1, 60 do pcall(function() S.buyRemote:FireServer(id) end) end
            else
                pcall(function() S.buyRemote:FireServer(1) end)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(S.rebirthCooldown)
        if S.autoRebirth and S.rebirthRemote then
            pcall(function() S.rebirthRemote:FireServer() end)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1.2)
        if S.autoHatch and S.hatchRemote then
            for id = 1, 10 do pcall(function() S.hatchRemote:FireServer(id) end) end
        end
        if S.autoCollect and S.collectRemote then
            pcall(function() S.collectRemote:FireServer() end)
        end
        if S.autoSell and S.sellRemote then
            pcall(function() S.sellRemote:FireServer() end)
        end
        if S.autoChest and S.chestRemote then
            for id = 1, 5 do pcall(function() S.chestRemote:FireServer(id) end) end
        end
        if S.autoDaily and S.dailyRemote then
            pcall(function() S.dailyRemote:FireServer() end)
        end
    end
end)

------------------------------------------------------------
-- anti-afk
------------------------------------------------------------
LP.Idled:Connect(function()
    if not S.antiAfk then return end
    local vu = game:GetService("VirtualUser")
    vu:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
    task.wait(1)
    vu:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
end)

------------------------------------------------------------
-- chat spam
------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(S.chatDelay)
        if S.chatSpam then
            pcall(function()
                local evt = ReplicatedS:FindFirstChild("DefaultChatSystemChatEvents")
                if evt then
                    local se = evt:FindFirstChild("SayMessageRequest")
                    if se then se:FireServer(S.chatText, "All") end
                else
                    (LP.Chatted or Instance.new("BindableEvent")):Fire(S.chatText)
                end
            end)
        end
    end
end)

------------------------------------------------------------
-- ESP
------------------------------------------------------------
local function tagEsp(obj, label, color)
    if obj:FindFirstChild("_ck_esp") then return end
    local adornee = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
    if not adornee then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "_ck_esp"; bb.Adornee = adornee
    bb.Size = UDim2.new(0, 160, 0, 30); bb.StudsOffset = Vector3.new(0, 2.4, 0)
    bb.AlwaysOnTop = true; bb.Parent = obj
    local tl = Instance.new("TextLabel", bb)
    tl.BackgroundTransparency = 1; tl.Size = UDim2.fromScale(1,1)
    tl.TextColor3 = color or S.espColor; tl.TextStrokeTransparency = 0
    tl.Font = Enum.Font.GothamBold; tl.TextScaled = true
    tl.Text = label or obj.Name
    if S.tracers then
        local h = Instance.new("Highlight", obj)
        h.Name = "_ck_hl"; h.FillTransparency = 0.6
        h.FillColor = color or S.espColor
        h.OutlineColor = color or S.espColor
    end
end

task.spawn(function()
    while true do
        task.wait(1.0)
        if S.espPets or S.espCookies or S.espDrops then
            for _, d in ipairs(Workspace:GetDescendants()) do
                local n = d.Name:lower()
                if S.espPets and (n:find("pet") or n:find("egg")) and (d:IsA("Model") or d:IsA("BasePart")) then
                    tagEsp(d, d.Name, Color3.fromRGB(120, 220, 255))
                end
                if S.espCookies and (n:find("cookie")) then
                    tagEsp(d, "cookie", Color3.fromRGB(255, 180, 60))
                end
                if S.espDrops and (n:find("drop") or n:find("gift") or n:find("coin") or n:find("gem")) then
                    tagEsp(d, d.Name, Color3.fromRGB(180, 255, 140))
                end
            end
        end
        if S.espPlayers then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP and pl.Character then
                    tagEsp(pl.Character, pl.Name, Color3.fromRGB(255, 80, 80))
                end
            end
        end
    end
end)

------------------------------------------------------------
-- fullbright / fps boost / hide name / invisible
------------------------------------------------------------
local brightState = {}
local function toggleBright(on)
    if on then
        brightState.brightness = Lighting.Brightness
        brightState.clockTime  = Lighting.ClockTime
        brightState.fogEnd     = Lighting.FogEnd
        brightState.globalShadows = Lighting.GlobalShadows
        Lighting.Brightness = 3; Lighting.ClockTime = 14
        Lighting.FogEnd = 1e5; Lighting.GlobalShadows = false
    else
        Lighting.Brightness = brightState.brightness or 2
        Lighting.ClockTime  = brightState.clockTime or 14
        Lighting.FogEnd     = brightState.fogEnd or 1e5
        Lighting.GlobalShadows = brightState.globalShadows ~= false
    end
end

local function toggleFps(on)
    if on then
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") or v:IsA("Trail") then
                v.Enabled = false
            elseif v:IsA("BasePart") and v.Material == Enum.Material.Grass then
                v.Material = Enum.Material.SmoothPlastic
            end
        end
        Lighting.GlobalShadows = false
        settings().Rendering.QualityLevel = 1
    end
end

------------------------------------------------------------
-- rejoin / server hop
------------------------------------------------------------
local function rejoin()
    TeleportSvc:Teleport(game.PlaceId, LP)
end
local function serverHop()
    local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok then return end
    local data = HttpSvc:JSONDecode(body)
    for _, srv in ipairs(data.data or {}) do
        if srv.playing and srv.playing < srv.maxPlayers and srv.id ~= game.JobId then
            TeleportSvc:TeleportToPlaceInstance(game.PlaceId, srv.id, LP); return
        end
    end
end

------------------------------------------------------------
-- click-tp
------------------------------------------------------------
Mouse.Button1Down:Connect(function()
    if S.clickTp and Mouse.Hit then
        local root = getRoot(); if root then root.CFrame = Mouse.Hit + Vector3.new(0, 3, 0) end
    end
end)

------------------------------------------------------------
-- teleport scan
------------------------------------------------------------
local function scanPads()
    S.teleportSpots = {}
    for _, p in ipairs(Workspace:GetDescendants()) do
        if p:IsA("BasePart") then
            local n = p.Name:lower()
            if n:find("tp") or n:find("teleport") or n:find("zone") or n:find("area") or n:find("spawn") or n:find("island") or n:find("world") then
                table.insert(S.teleportSpots, { name = p.Name, cf = p.CFrame + Vector3.new(0,4,0) })
            end
        end
    end
end
scanPads()

local function tpTo(cf)
    local root = getRoot(); if root then root.CFrame = cf end
end

------------------------------------------------------------
-- UI — tabbed, draggable, dark cocoa gold
------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ck_" .. tostring(math.random(100000, 999999))
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 520, 0, 460)
main.Position = UDim2.new(0.5, -260, 0.5, -230)
main.BackgroundColor3 = Color3.fromRGB(12, 10, 9)
main.BorderSizePixel = 0
main.Active = true; main.Draggable = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(255, 180, 60); stroke.Thickness = 1.5
local grad = Instance.new("UIGradient", main)
grad.Rotation = 90
grad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 14, 10)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 7, 6)),
}

-- header
local header = Instance.new("Frame", main)
header.Size = UDim2.new(1, 0, 0, 42)
header.BackgroundTransparency = 1
local title = Instance.new("TextLabel", header)
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 16, 0, 0); title.Size = UDim2.new(1, -120, 1, 0)
title.Text = "  cookiekit v2  —  built by olivia"
title.TextColor3 = Color3.fromRGB(255, 200, 110)
title.Font = Enum.Font.GothamBold; title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size = UDim2.new(0, 28, 0, 28); closeBtn.Position = UDim2.new(1, -36, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(80, 24, 24); closeBtn.BorderSizePixel = 0
closeBtn.Text = "x"; closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local minBtn = Instance.new("TextButton", header)
minBtn.Size = UDim2.new(0, 28, 0, 28); minBtn.Position = UDim2.new(1, -70, 0, 7)
minBtn.BackgroundColor3 = Color3.fromRGB(50, 42, 30); minBtn.BorderSizePixel = 0
minBtn.Text = "-"; minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 16
minBtn.TextColor3 = Color3.fromRGB(255, 220, 160)
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

-- tab strip
local tabStrip = Instance.new("Frame", main)
tabStrip.Position = UDim2.new(0, 10, 0, 46); tabStrip.Size = UDim2.new(0, 130, 1, -56)
tabStrip.BackgroundColor3 = Color3.fromRGB(18, 15, 12); tabStrip.BorderSizePixel = 0
Instance.new("UICorner", tabStrip).CornerRadius = UDim.new(0, 8)
local tabLayout = Instance.new("UIListLayout", tabStrip)
tabLayout.Padding = UDim.new(0, 4); tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
local tabPad = Instance.new("UIPadding", tabStrip)
tabPad.PaddingTop = UDim.new(0, 8); tabPad.PaddingLeft = UDim.new(0, 6); tabPad.PaddingRight = UDim.new(0, 6)

-- body
local body = Instance.new("Frame", main)
body.Position = UDim2.new(0, 148, 0, 46); body.Size = UDim2.new(1, -158, 1, -56)
body.BackgroundColor3 = Color3.fromRGB(16, 13, 10); body.BorderSizePixel = 0
Instance.new("UICorner", body).CornerRadius = UDim.new(0, 8)

local pages = {}
local function makePage(name)
    local p = Instance.new("ScrollingFrame", body)
    p.Size = UDim2.new(1, -12, 1, -12); p.Position = UDim2.new(0, 6, 0, 6)
    p.BackgroundTransparency = 1; p.BorderSizePixel = 0
    p.ScrollBarThickness = 3; p.CanvasSize = UDim2.new(0, 0, 0, 0)
    p.Visible = false
    local lay = Instance.new("UIListLayout", p)
    lay.Padding = UDim.new(0, 6); lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        p.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 8)
    end)
    pages[name] = p
    return p
end

local activeTab
local tabButtons = {}
local function makeTabBtn(name)
    local b = Instance.new("TextButton", tabStrip)
    b.Size = UDim2.new(1, 0, 0, 30)
    b.BackgroundColor3 = Color3.fromRGB(26, 22, 18); b.BorderSizePixel = 0
    b.TextColor3 = Color3.fromRGB(220, 200, 170); b.Font = Enum.Font.GothamBold; b.TextSize = 12
    b.Text = name
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    tabButtons[name] = b
    b.MouseButton1Click:Connect(function()
        for n, pg in pairs(pages) do pg.Visible = (n == name) end
        for n, btn in pairs(tabButtons) do
            btn.BackgroundColor3 = (n == name) and Color3.fromRGB(60, 46, 28) or Color3.fromRGB(26, 22, 18)
        end
        activeTab = name
    end)
end

local function toggleRow(page, txt, key, callback)
    local b = Instance.new("TextButton", page)
    b.Size = UDim2.new(1, -4, 0, 30)
    b.BackgroundColor3 = Color3.fromRGB(26, 22, 18); b.BorderSizePixel = 0
    b.TextColor3 = Color3.fromRGB(235, 220, 200)
    b.Font = Enum.Font.Gotham; b.TextSize = 13
    b.TextXAlignment = Enum.TextXAlignment.Left
    local function render() b.Text = (S[key] and "  ●  " or "  ○  ") .. txt end
    render()
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    local dot = Instance.new("Frame", b)
    dot.Size = UDim2.new(0, 6, 1, -12); dot.Position = UDim2.new(1, -12, 0, 6)
    dot.BackgroundColor3 = Color3.fromRGB(255, 180, 60); dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    local function sync() dot.BackgroundColor3 = S[key] and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(80, 60, 50) end
    sync()
    b.MouseButton1Click:Connect(function()
        S[key] = not S[key]; render(); sync()
        if callback then callback(S[key]) end
    end)
end

local function sliderRow(page, txt, key, min, max, step)
    local f = Instance.new("Frame", page)
    f.Size = UDim2.new(1, -4, 0, 44)
    f.BackgroundColor3 = Color3.fromRGB(26, 22, 18); f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local lbl = Instance.new("TextLabel", f)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -10, 0, 18); lbl.Position = UDim2.new(0, 10, 0, 2)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(235, 220, 200)
    lbl.Text = txt .. ": " .. tostring(S[key])
    local bar = Instance.new("Frame", f)
    bar.Position = UDim2.new(0, 10, 0, 26); bar.Size = UDim2.new(1, -20, 0, 8)
    bar.BackgroundColor3 = Color3.fromRGB(60, 50, 40)
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame", bar)
    fill.BackgroundColor3 = Color3.fromRGB(255, 180, 60)
    fill.Size = UDim2.new((S[key]-min)/(max-min), 0, 1, 0)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    bar.InputBegan:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 then
            local move, up
            move = UIS.InputChanged:Connect(function(i2)
                if i2.UserInputType == Enum.UserInputType.MouseMovement then
                    local rel = math.clamp((i2.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
                    local v = min + rel * (max - min); v = math.floor(v/step + 0.5) * step
                    S[key] = v; fill.Size = UDim2.new(rel, 0, 1, 0)
                    lbl.Text = txt .. ": " .. tostring(v)
                end
            end)
            up = UIS.InputEnded:Connect(function(i2)
                if i2.UserInputType == Enum.UserInputType.MouseButton1 then move:Disconnect(); up:Disconnect() end
            end)
        end
    end)
end

local function buttonRow(page, txt, fn)
    local b = Instance.new("TextButton", page)
    b.Size = UDim2.new(1, -4, 0, 28)
    b.BackgroundColor3 = Color3.fromRGB(40, 30, 18); b.BorderSizePixel = 0
    b.TextColor3 = Color3.fromRGB(255, 220, 160)
    b.Font = Enum.Font.GothamBold; b.TextSize = 12; b.Text = txt
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(fn)
end

local function inputRow(page, txt, key)
    local f = Instance.new("Frame", page)
    f.Size = UDim2.new(1, -4, 0, 34)
    f.BackgroundColor3 = Color3.fromRGB(26, 22, 18); f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local lbl = Instance.new("TextLabel", f)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0, 90, 1, 0); lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(235, 220, 200); lbl.Text = txt
    local tb = Instance.new("TextBox", f)
    tb.Size = UDim2.new(1, -108, 1, -8); tb.Position = UDim2.new(0, 100, 0, 4)
    tb.BackgroundColor3 = Color3.fromRGB(14, 12, 10); tb.BorderSizePixel = 0
    tb.TextColor3 = Color3.fromRGB(255, 220, 160)
    tb.Font = Enum.Font.Gotham; tb.TextSize = 12
    tb.PlaceholderText = tostring(S[key]); tb.Text = tostring(S[key])
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 4)
    tb.FocusLost:Connect(function()
        if type(S[key]) == "number" then
            local n = tonumber(tb.Text); if n then S[key] = n end
        else
            S[key] = tb.Text
        end
    end)
end

------------------------------------------------------------
-- build pages
------------------------------------------------------------
makeTabBtn("Farm")
makeTabBtn("Auto")
makeTabBtn("Player")
makeTabBtn("Visual")
makeTabBtn("World")
makeTabBtn("Teleport")
makeTabBtn("Misc")

local pFarm    = makePage("Farm")
toggleRow(pFarm, "auto click",         "autoClick")
toggleRow(pFarm, "remote farm",        "remoteFarm")
sliderRow(pFarm, "click hz",           "clickHz",    50, 20000, 50)
sliderRow(pFarm, "multi fire x",       "multiFire",  1,  20,    1)
buttonRow(pFarm, "rescan remotes",     findRemotes)
buttonRow(pFarm, "dump remote log",    function()
    local lines = {}
    for n, info in pairs(S.remoteLog) do table.insert(lines, n .. "  x" .. info.hits) end
    table.sort(lines)
    notify("remote log", table.concat(lines, "  |  "):sub(1,220), 8)
end)

local pAuto    = makePage("Auto")
toggleRow(pAuto, "auto buy",           "autoBuy")
toggleRow(pAuto, "buy all upgrades",   "buyAll")
toggleRow(pAuto, "auto rebirth",       "autoRebirth")
sliderRow(pAuto, "rebirth cooldown s", "rebirthCooldown", 2, 120, 1)
toggleRow(pAuto, "auto hatch eggs",    "autoHatch")
toggleRow(pAuto, "auto collect drops", "autoCollect")
toggleRow(pAuto, "auto sell",          "autoSell")
toggleRow(pAuto, "auto chests",        "autoChest")
toggleRow(pAuto, "auto daily reward",  "autoDaily")

local pPlayer  = makePage("Player")
sliderRow(pPlayer, "walkspeed",        "walkspeed", 16, 500, 2)
sliderRow(pPlayer, "jumppower",        "jumppower", 50, 500, 5)
toggleRow(pPlayer, "noclip",           "noclip")
toggleRow(pPlayer, "inf jump",         "infJump")
toggleRow(pPlayer, "fly (wasd+space)", "fly", function(on) if on then startFly() else stopFly() end end)
sliderRow(pPlayer, "fly speed",        "flySpeed", 20, 500, 5)
toggleRow(pPlayer, "god mode",         "godMode", function(on)
    local h = getHum(); if h then h.MaxHealth = on and math.huge or 100; h.Health = h.MaxHealth end
end)
buttonRow(pPlayer, "reset character",  function() local h = getHum(); if h then h.Health = 0 end end)
buttonRow(pPlayer, "sit",              function() local h = getHum(); if h then h.Sit = true end end)
toggleRow(pPlayer, "hitbox expand (others)", "hitboxExpand")
sliderRow(pPlayer, "hitbox size",      "hitboxSize", 5, 80, 1)

local pVisual  = makePage("Visual")
toggleRow(pVisual, "esp cookies",      "espCookies")
toggleRow(pVisual, "esp pets/eggs",    "espPets")
toggleRow(pVisual, "esp drops",        "espDrops")
toggleRow(pVisual, "esp players",      "espPlayers")
toggleRow(pVisual, "tracers/highlights","tracers")
toggleRow(pVisual, "fullbright",       "fullbright", toggleBright)
toggleRow(pVisual, "fps boost",        "fpsBoost", toggleFps)
toggleRow(pVisual, "invisible",        "invisible", function(on)
    if LP.Character then
        for _, p in ipairs(LP.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.Transparency = on and 1 or 0 end
            if p:IsA("Decal") then p.Transparency = on and 1 or 0 end
        end
    end
end)
toggleRow(pVisual, "hide nametag",     "hideName", function(on)
    if LP.Character then
        local h = LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.NameDisplayDistance = on and 0 or 100; h.HealthDisplayDistance = on and 0 or 100 end
    end
end)

local pWorld   = makePage("World")
toggleRow(pWorld, "anti-afk",          "antiAfk")
toggleRow(pWorld, "click teleport",    "clickTp")
toggleRow(pWorld, "chat spam",         "chatSpam")
inputRow(pWorld,  "chat text",         "chatText")
sliderRow(pWorld, "chat delay s",      "chatDelay", 1, 30, 1)
buttonRow(pWorld, "rejoin server",     rejoin)
buttonRow(pWorld, "server hop",        serverHop)
buttonRow(pWorld, "respawn",           function() local h = getHum(); if h then h:ChangeState(Enum.HumanoidStateType.Dead) end end)

local pTp      = makePage("Teleport")
buttonRow(pTp, "rescan pads", function()
    scanPads()
    for _, child in ipairs(pTp:GetChildren()) do
        if child:IsA("TextButton") and child.Name == "_padbtn" then child:Destroy() end
    end
    for _, spot in ipairs(S.teleportSpots) do
        local b = Instance.new("TextButton", pTp)
        b.Name = "_padbtn"
        b.Size = UDim2.new(1, -4, 0, 26); b.BackgroundColor3 = Color3.fromRGB(32, 26, 18)
        b.BorderSizePixel = 0; b.TextColor3 = Color3.fromRGB(240, 220, 180)
        b.Font = Enum.Font.Gotham; b.TextSize = 12; b.Text = "tp → " .. spot.name
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseButton1Click:Connect(function() tpTo(spot.cf) end)
    end
    notify("cookiekit", #S.teleportSpots .. " pads", 3)
end)
buttonRow(pTp, "tp: nearest cookie", function()
    local closest, dist = nil, math.huge
    local root = getRoot(); if not root then return end
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart") and d.Name:lower():find("cookie") then
            local m = (d.Position - root.Position).Magnitude
            if m < dist then closest, dist = d, m end
        end
    end
    if closest then tpTo(closest.CFrame + Vector3.new(0, 3, 0)) end
end)
buttonRow(pTp, "tp: nearest drop", function()
    local closest, dist = nil, math.huge
    local root = getRoot(); if not root then return end
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("BasePart") and (d.Name:lower():find("drop") or d.Name:lower():find("gift")) then
            local m = (d.Position - root.Position).Magnitude
            if m < dist then closest, dist = d, m end
        end
    end
    if closest then tpTo(closest.CFrame + Vector3.new(0, 3, 0)) end
end)

local pMisc    = makePage("Misc")
buttonRow(pMisc, "copy jobid",         function()
    if setclipboard then setclipboard(game.JobId) end
    notify("cookiekit", "job id copied", 3)
end)
buttonRow(pMisc, "print services tree", function()
    local out = {}
    for _, inst in ipairs(ReplicatedS:GetChildren()) do table.insert(out, inst.ClassName .. "  " .. inst.Name) end
    notify("ReplicatedStorage", table.concat(out, " | "):sub(1,220), 8)
end)
buttonRow(pMisc, "fling local",        function()
    local root = getRoot(); if root then root.Velocity = Vector3.new(1e5,1e5,1e5) end
end)
buttonRow(pMisc, "credits",            function()
    notify("cookiekit v2", "built by olivia — discord.gg/ojailbreaks", 6)
end)

-- open default tab
tabButtons.Farm.BackgroundColor3 = Color3.fromRGB(60, 46, 28)
pages.Farm.Visible = true; activeTab = "Farm"

------------------------------------------------------------
-- minimize + close + hotkey
------------------------------------------------------------
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        TweenService:Create(main, TweenInfo.new(0.2), {Size = UDim2.new(0, 520, 0, 42)}):Play()
        tabStrip.Visible = false; body.Visible = false
    else
        TweenService:Create(main, TweenInfo.new(0.2), {Size = UDim2.new(0, 520, 0, 460)}):Play()
        task.wait(0.21); tabStrip.Visible = true; body.Visible = true
    end
end)

local function unload()
    S.autoClick = false; S.autoBuy = false; S.autoRebirth = false
    S.autoHatch = false; S.autoCollect = false; S.autoSell = false
    S.noclip = false; S.fly = false; S.godMode = false
    S.espPets = false; S.espCookies = false; S.espPlayers = false; S.espDrops = false
    S.hitboxExpand = false; S.chatSpam = false; S.fullbright = false
    stopFly()
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d.Name == "_ck_esp" or d.Name == "_ck_hl" then d:Destroy() end
    end
    gui:Destroy()
    _G.CK_LOADED = nil
    notify("cookiekit", "unloaded clean", 3)
end
env.CK_UNLOAD = unload
closeBtn.MouseButton1Click:Connect(unload)

UIS.InputBegan:Connect(function(io, gp)
    if gp then return end
    if io.KeyCode == Enum.KeyCode.RightShift then main.Visible = not main.Visible end
end)

notify("cookiekit v2", "ready — RSHIFT to hide", 4)
