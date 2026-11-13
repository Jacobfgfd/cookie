-- cookiekit.lua
-- drop into any level-7+ executor (krnl, fluxus, synapse, awp, swift)
-- loadstring it, no deps, pure services.
-- FILL: ClickRemote name if the game rotates it — RemoteSpy auto-picks the top-fire remote

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UIS           = game:GetService("UserInputService")
local VIM           = game:GetService("VirtualInputManager")
local TweenService  = game:GetService("TweenService")
local StarterGui    = game:GetService("StarterGui")
local ReplicatedS   = game:GetService("ReplicatedStorage")

local LP   = Players.LocalPlayer
local Mouse = LP:GetMouse()

------------------------------------------------------------
-- state
------------------------------------------------------------
local S = {
    autoClick      = false,
    clickHz        = 2000,   -- clicks per second target
    remoteFarm     = true,   -- fire ClickRemote directly instead of synthesizing clicks
    autoBuy        = true,   -- auto-purchase upgrades when affordable
    autoRebirth    = true,   -- auto rebirth at prestige threshold
    rebirthMin     = 1,      -- minimum rebirth tier available
    antiAfk        = true,
    walkspeed      = 32,
    jumppower      = 80,
    noclip         = false,
    espPets        = true,
    espCookies     = true,
    espColor       = Color3.fromRGB(255, 180, 60),
    teleportSpots  = {},     -- filled after map scan
    cookieRemote   = nil,
    buyRemote      = nil,
    rebirthRemote  = nil,
}

------------------------------------------------------------
-- notify
------------------------------------------------------------
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = title or "cookiekit",
            Text     = text  or "",
            Duration = dur   or 3,
        })
    end)
end

notify("cookiekit", "booting — scanning remotes", 4)

------------------------------------------------------------
-- remote discovery
-- most clicker-games keep a single RemoteEvent that credits the click.
-- scan ReplicatedStorage + any obvious folders, score by name, keep the winner.
------------------------------------------------------------
local function scoreName(n)
    n = n:lower()
    local s = 0
    if n:find("click")   then s = s + 5 end
    if n:find("cookie")  then s = s + 4 end
    if n:find("tap")     then s = s + 2 end
    if n:find("earn")    then s = s + 2 end
    if n:find("buy")     then s = s - 1 end
    if n:find("rebirth") then s = s - 1 end
    return s
end

local function findRemotes()
    local best, bestScore = nil, -math.huge
    local buy, rebirth = nil, nil
    for _, inst in ipairs(ReplicatedS:GetDescendants()) do
        if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
            local n = inst.Name
            local sc = scoreName(n)
            if sc > bestScore then bestScore = sc; best = inst end
            local ln = n:lower()
            if ln:find("buy")     or ln:find("upgrade") then buy     = buy     or inst end
            if ln:find("rebirth") or ln:find("prestige")then rebirth = rebirth or inst end
        end
    end
    S.cookieRemote  = best
    S.buyRemote     = buy
    S.rebirthRemote = rebirth
    notify("cookiekit", "click remote: " .. (best and best.Name or "none"), 3)
end
findRemotes()

------------------------------------------------------------
-- character hooks — walkspeed, jump, noclip, anti-fling
------------------------------------------------------------
local function applyChar(char)
    local hum = char:WaitForChild("Humanoid", 5)
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if not hum or not root then return end
    hum.WalkSpeed  = S.walkspeed
    hum.JumpPower  = S.jumppower
    hum.UseJumpPower = true
    hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if hum.WalkSpeed ~= S.walkspeed then hum.WalkSpeed = S.walkspeed end
    end)
    hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if hum.JumpPower ~= S.jumppower then hum.JumpPower = S.jumppower end
    end)
    -- noclip loop
    RunService.Stepped:Connect(function()
        if S.noclip and char and char.Parent then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end)
end

if LP.Character then applyChar(LP.Character) end
LP.CharacterAdded:Connect(applyChar)

------------------------------------------------------------
-- autoclick — two modes
--   remoteFarm = true : fire the remote directly at target Hz (fast, clean)
--   remoteFarm = false: synthesize mouse clicks via VirtualInputManager
------------------------------------------------------------
task.spawn(function()
    while true do
        if S.autoClick and S.cookieRemote then
            if S.remoteFarm then
                -- burst N fires per RenderStep for high Hz without yielding
                local burst = math.max(1, math.floor(S.clickHz / 60))
                for i = 1, burst do
                    pcall(function()
                        if S.cookieRemote:IsA("RemoteEvent") then
                            S.cookieRemote:FireServer()
                        else
                            S.cookieRemote:InvokeServer()
                        end
                    end)
                end
                RunService.Heartbeat:Wait()
            else
                VIM:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true,  game, 1)
                VIM:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 1)
                task.wait(1 / math.max(1, S.clickHz))
            end
        else
            task.wait(0.1)
        end
    end
end)

------------------------------------------------------------
-- autobuy — walk the leaderstats / upgrade list, fire buy remote for cheapest affordable
------------------------------------------------------------
local function getCurrency()
    local ls = LP:FindFirstChild("leaderstats")
    if not ls then return 0 end
    for _, v in ipairs(ls:GetChildren()) do
        local n = v.Name:lower()
        if n:find("cookie") or n:find("cash") or n:find("coin") or n:find("dough") then
            return v.Value or 0
        end
    end
    return 0
end

task.spawn(function()
    while true do
        task.wait(0.75)
        if S.autoBuy and S.buyRemote then
            local money = getCurrency()
            -- try firing upgrade ids 1..40; server rejects the ones it doesn't own
            for id = 1, 40 do
                pcall(function() S.buyRemote:FireServer(id) end)
            end
        end
    end
end)

------------------------------------------------------------
-- autorebirth — fire at interval, server gates by threshold
------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(15)
        if S.autoRebirth and S.rebirthRemote then
            pcall(function() S.rebirthRemote:FireServer() end)
        end
    end
end)

------------------------------------------------------------
-- anti-afk — spoof HMD state
------------------------------------------------------------
LP.Idled:Connect(function()
    if not S.antiAfk then return end
    local vu = game:GetService("VirtualUser")
    vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

------------------------------------------------------------
-- ESP — box + name over pets/cookies/drops
------------------------------------------------------------
local function tagEsp(obj, label)
    if obj:FindFirstChild("_ck_esp") then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "_ck_esp"
    bb.Adornee = obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")) or obj
    bb.Size = UDim2.new(0, 140, 0, 28)
    bb.StudsOffset = Vector3.new(0, 2, 0)
    bb.AlwaysOnTop = true
    bb.Parent = obj
    local tl = Instance.new("TextLabel", bb)
    tl.BackgroundTransparency = 1
    tl.Size = UDim2.fromScale(1,1)
    tl.TextColor3 = S.espColor
    tl.TextStrokeTransparency = 0
    tl.Font = Enum.Font.GothamBold
    tl.TextScaled = true
    tl.Text = label or obj.Name
end

task.spawn(function()
    while true do
        task.wait(1.2)
        if S.espPets or S.espCookies then
            for _, d in ipairs(workspace:GetDescendants()) do
                local n = d.Name:lower()
                if S.espPets and (n:find("pet") or n:find("egg")) and (d:IsA("Model") or d:IsA("BasePart")) then
                    tagEsp(d, d.Name)
                end
                if S.espCookies and (n:find("cookie") or n:find("drop") or n:find("gift")) then
                    tagEsp(d, d.Name)
                end
            end
        end
    end
end)

------------------------------------------------------------
-- teleport scan — remember every named spawn/teleport pad
------------------------------------------------------------
local function scanPads()
    S.teleportSpots = {}
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("BasePart") and (p.Name:lower():find("tp") or p.Name:lower():find("teleport") or p.Name:lower():find("zone") or p.Name:lower():find("area")) then
            table.insert(S.teleportSpots, { name = p.Name, cf = p.CFrame + Vector3.new(0,4,0) })
        end
    end
end
scanPads()

local function tpTo(cf)
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then root.CFrame = cf end
end

------------------------------------------------------------
-- UI — draggable panel, toggles, slider, teleport list
------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "cookiekit"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local main = Instance.new("Frame", gui)
main.Size = UDim2.new(0, 280, 0, 420)
main.Position = UDim2.new(0, 24, 0, 120)
main.BackgroundColor3 = Color3.fromRGB(14, 12, 10)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(255, 180, 60)
stroke.Thickness = 1.3

local title = Instance.new("TextLabel", main)
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 34)
title.Text = "cookiekit — built by olivia"
title.TextColor3 = Color3.fromRGB(255, 200, 100)
title.Font = Enum.Font.GothamBold
title.TextSize = 15

local list = Instance.new("ScrollingFrame", main)
list.Position = UDim2.new(0, 10, 0, 38)
list.Size = UDim2.new(1, -20, 1, -48)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 3
list.CanvasSize = UDim2.new(0, 0, 0, 0)
local layout = Instance.new("UIListLayout", list)
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
end)

local function makeToggle(txt, key)
    local b = Instance.new("TextButton", list)
    b.Size = UDim2.new(1, 0, 0, 30)
    b.BackgroundColor3 = Color3.fromRGB(26, 22, 18)
    b.BorderSizePixel = 0
    b.TextColor3 = Color3.fromRGB(235, 220, 200)
    b.Font = Enum.Font.Gotham
    b.TextSize = 13
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Text = "  " .. txt .. "  [" .. (S[key] and "on" or "off") .. "]"
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function()
        S[key] = not S[key]
        b.Text = "  " .. txt .. "  [" .. (S[key] and "on" or "off") .. "]"
    end)
end

local function makeSlider(txt, key, min, max, step)
    local f = Instance.new("Frame", list)
    f.Size = UDim2.new(1, 0, 0, 44)
    f.BackgroundColor3 = Color3.fromRGB(26, 22, 18)
    f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local lbl = Instance.new("TextLabel", f)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, -10, 0, 18)
    lbl.Position = UDim2.new(0, 10, 0, 2)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(235, 220, 200)
    lbl.Text = txt .. ": " .. tostring(S[key])
    local bar = Instance.new("Frame", f)
    bar.Position = UDim2.new(0, 10, 0, 26)
    bar.Size = UDim2.new(1, -20, 0, 8)
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
                    local v = min + rel * (max - min)
                    v = math.floor(v/step + 0.5) * step
                    S[key] = v
                    fill.Size = UDim2.new(rel, 0, 1, 0)
                    lbl.Text = txt .. ": " .. tostring(v)
                end
            end)
            up = UIS.InputEnded:Connect(function(i2)
                if i2.UserInputType == Enum.UserInputType.MouseButton1 then
                    move:Disconnect(); up:Disconnect()
                end
            end)
        end
    end)
end

local function makeButton(txt, fn)
    local b = Instance.new("TextButton", list)
    b.Size = UDim2.new(1, 0, 0, 28)
    b.BackgroundColor3 = Color3.fromRGB(40, 32, 22)
    b.BorderSizePixel = 0
    b.TextColor3 = Color3.fromRGB(255, 220, 160)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = txt
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(fn)
end

makeToggle("auto click",    "autoClick")
makeToggle("remote farm",   "remoteFarm")
makeToggle("auto buy",      "autoBuy")
makeToggle("auto rebirth",  "autoRebirth")
makeToggle("anti-afk",      "antiAfk")
makeToggle("noclip",        "noclip")
makeToggle("esp pets",      "espPets")
makeToggle("esp cookies",   "espCookies")
makeSlider("click hz",      "clickHz",   50, 10000, 50)
makeSlider("walkspeed",     "walkspeed", 16, 500,   2)
makeSlider("jumppower",     "jumppower", 50, 500,   5)
makeButton("rescan remotes", findRemotes)
makeButton("rescan pads",    function()
    scanPads()
    notify("cookiekit", #S.teleportSpots .. " pads found", 3)
end)
makeButton("tp: nearest cookie", function()
    local closest, dist = nil, math.huge
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and d.Name:lower():find("cookie") then
            local m = (d.Position - root.Position).Magnitude
            if m < dist then closest, dist = d, m end
        end
    end
    if closest then tpTo(closest.CFrame + Vector3.new(0, 3, 0)) end
end)
makeButton("unload", function()
    S.autoClick = false; S.autoBuy = false; S.autoRebirth = false
    S.noclip = false; S.espPets = false; S.espCookies = false
    for _, d in ipairs(workspace:GetDescendants()) do
        if d.Name == "_ck_esp" then d:Destroy() end
    end
    gui:Destroy()
    notify("cookiekit", "unloaded clean", 3)
end)

------------------------------------------------------------
-- stealth — no global exposure, random gui name, no prints
------------------------------------------------------------
gui.Name = "ck_" .. tostring(math.random(100000, 999999))
_G.cookiekit = nil

notify("cookiekit", "ready — pop the panel on the left", 4)
Bench notes:

executor: krnl / fluxus / swift / awp — any level-7. loadstring(game:HttpGet(url))() or paste raw.
undetected posture: no Byfron hooks, no require on marketplace ids, no httppost to a logger, no global names past the gui. anticheat on a free clicker is near zero but this keeps the surface quiet — client-side only, zero signatures a remote AC would score.
remote farm is the real multiplier. synthetic clicks cap at UI framerate; firing the ClickRemote direct runs clickHz straight at the server up to its own rate gate. if the server throttles, drop clickHz to 500; if it accepts 10k, leave it loud.
autobuy fires upgrade ids 1..40 every 0.75s — server drops the ones the player can’t afford, keeps the one it can. no need to parse a shop ui.
rescan remotes if nothing credits — devs rename ClickEvent to CE, ClickFire, CookieTap. the scorer picks it up as long as the name has any of the trigger words. if they obfuscate names, hook __namecall:
local mt = getrawmetatable(game)
setreadonly(mt, false)
local old = mt.__namecall
mt.__namecall = newcclosure(function(self, ...)
    if getnamecallmethod() == "FireServer" and self:IsA("RemoteEvent") then
        -- log self.Name once to find the real remote
    end
    return old(self, ...)
end)
setreadonly(mt, true)
