local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Window = Fluent:CreateWindow({
    Title = "MoonFling",
    SubTitle = "FTAP v1.0",
    TabWidth = 160,
    Size = UDim2.fromOffset(620, 520),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Fling = Window:AddTab({ Title = "Fling", Icon = "bomb" }),
    Movement = Window:AddTab({ Title = "Movement", Icon = "move" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Player = Window:AddTab({ Title = "Player", Icon = "user" }),
    Utility = Window:AddTab({ Title = "Utility", Icon = "compass" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

do
    Fluent:Notify({ Title = "MoonFling", Content = "Loaded! FTAP ready", Duration = 4 })
end

local function getCharacter()
    return LocalPlayer.Character
end
local function getHumanoid()
    local c = getCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
    local c = getCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getPlayerHRP(plr)
    local c = plr and plr.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

------------------------------------------------
-- FLING CORE
------------------------------------------------
local superStrengthEnabled = false
local superPower = 10
local flingAuraEnabled = false
local flingAuraRadius = 20
local flingAuraDelay = 0.15
local flingPower = 100
local spinEnabled = false
local spinSpeed = 400
local gravityEnabled = false
local gravityForce = 6000
local zeroGEnabled = false
local zeroGForce = 40000
local boomerangEnabled = false
local boomerangTime = 5
local antiFlingEnabled = false
local hitboxEnabled = false
local hitboxSize = 12
local grabAuraEnabled = false
local selectedFlingTarget = nil

local activeForces = {}
local spinningItems = {}
local frozenParts = {}
local auraConn
local lastFling = 0

local function clearForces(part)
    if not part or not part.Parent then return end
    spinningItems[part] = nil
    activeForces[part] = nil
    frozenParts[part] = nil
    for _,v in ipairs(part:GetChildren()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyForce") or v:IsA("BodyAngularVelocity") or v:IsA("BodyGyro") or v:IsA("BodyPosition") then
            pcall(function() v:Destroy() end)
        end
    end
end

local function applyFling(part, power)
    if not part or not part.Parent then return end
    if not part:IsA("BasePart") then return end
    clearForces(part)
    local dir = (part.Position - getRoot().Position).Unit
    if dir.Magnitude == 0 then dir = Vector3.new(0,1,0) end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(9e9,9e9,9e9)
    bv.Velocity = dir * power + Vector3.new(0, power*0.35, 0)
    bv.Parent = part
    Debris:AddItem(bv, 0.45)
    if spinEnabled then
        local bav = Instance.new("BodyAngularVelocity")
        bav.MaxTorque = Vector3.new(9e9,9e9,9e9)
        bav.AngularVelocity = Vector3.new(0, spinSpeed, 0)
        bav.Parent = part
        Debris:AddItem(bav, 0.6)
        spinningItems[part] = true
    end
    if gravityEnabled then
        local bf = Instance.new("BodyForce")
        bf.Force = Vector3.new(0, gravityForce, 0)
        bf.Parent = part
        Debris:AddItem(bf, 0.5)
    end
    if zeroGEnabled then
        local bf2 = Instance.new("BodyForce")
        bf2.Force = Vector3.new(0, zeroGForce, 0)
        bf2.Parent = part
        Debris:AddItem(bf2, 0.5)
    end
    if boomerangEnabled then
        task.delay(boomerangTime, function()
            if part.Parent and getRoot() then
                local bv2 = Instance.new("BodyVelocity")
                bv2.MaxForce = Vector3.new(9e9,9e9,9e9)
                bv2.Velocity = (getRoot().Position - part.Position).Unit * (power*0.9)
                bv2.Parent = part
                Debris:AddItem(bv2, 0.45)
            end
        end)
    end
end

local function getClosestInRadius(radius)
    local root = getRoot()
    if not root then return {} end
    local out = {}
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = plr.Character.HumanoidRootPart
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local d = (hrp.Position - root.Position).Magnitude
                if d <= radius then table.insert(out, {plr=plr, hrp=hrp, dist=d}) end
            end
        end
    end
    table.sort(out, function(a,b) return a.dist < b.dist end)
    return out
end

local function flingTargetsInRadius()
    if tick() - lastFling < flingAuraDelay then return end
    lastFling = tick()
    local targets = getClosestInRadius(flingAuraRadius)
    for _,t in ipairs(targets) do
        pcall(applyFling, t.hrp, flingPower*4)
        for _,part in ipairs(t.plr.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    local dir = (part.Position - getRoot().Position).Unit
                    part.AssemblyLinearVelocity = dir * flingPower + Vector3.new(0, flingPower*0.5, 0)
                end)
            end
        end
    end
end

local function flingAll()
    local root = getRoot()
    if not root then return end
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local hrp = getPlayerHRP(plr)
            if hrp then pcall(applyFling, hrp, flingPower*5) end
        end
    end
    for _,obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not obj.Anchored and not obj:IsDescendantOf(getCharacter()) then
            local d = (obj.Position - root.Position).Magnitude
            if d <= flingAuraRadius*2 then pcall(applyFling, obj, flingPower*3) end
        end
    end
end

Workspace.ChildAdded:Connect(function(m)
    if m.Name == "GrabParts" then
        task.wait()
        pcall(function()
            local gp = m:FindFirstChild("GrabPart")
            if not gp then return end
            local wc = gp:FindFirstChild("WeldConstraint")
            local part = wc and wc.Part1
            if not part then
                for _,v in ipairs(m:GetDescendants()) do
                    if v:IsA("WeldConstraint") and v.Part1 then part = v.Part1 break end
                end
            end
            if not part then return end
            if superStrengthEnabled then
                local vel = part.AssemblyLinearVelocity
                if vel.Magnitude < 5 then vel = (part.Position - getRoot().Position).Unit * 10 end
                part.AssemblyLinearVelocity = vel * superPower
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(9e9,9e9,9e9)
                bv.Velocity = vel.Unit * flingPower * (superPower*0.6)
                bv.Parent = part
                Debris:AddItem(bv, 0.35)
            end
            if spinEnabled and part then
                local bav = Instance.new("BodyAngularVelocity")
                bav.MaxTorque = Vector3.new(9e9,9e9,9e9)
                bav.AngularVelocity = Vector3.new(math.random(-spinSpeed,spinSpeed), spinSpeed, math.random(-spinSpeed,spinSpeed))
                bav.Parent = part
                Debris:AddItem(bav, 0.6)
            end
        end)
    end
end)

local hitboxConn
local function updateHitbox(state)
    if hitboxConn then hitboxConn:Disconnect() hitboxConn=nil end
    if not state then
        for _,plr in ipairs(Players:GetPlayers()) do
            local hrp = getPlayerHRP(plr)
            if hrp and hrp:FindFirstChild("MoonFling_Hitbox") then pcall(function() hrp.MoonFling_Hitbox:Destroy() end) hrp.Size = Vector3.new(2,2,1) hrp.Transparency = 1 end
        end
        return
    end
    hitboxConn = RunService.Heartbeat:Connect(function()
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local hrp = getPlayerHRP(plr)
                if hrp then
                    hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                    hrp.Transparency = 0.65
                    hrp.CanCollide = false
                    if not hrp:FindFirstChild("MoonFling_Hitbox") then
                        local tag = Instance.new("BoolValue") tag.Name="MoonFling_Hitbox" tag.Parent=hrp
                    end
                end
            end
        end
    end)
end

Tabs.Fling:AddSection("Super Fling")
Tabs.Fling:AddToggle("SuperStrength", { Title = "Super Strength", Default = false, Callback = function(v) superStrengthEnabled=v end })
Tabs.Fling:AddSlider("SuperPower", { Title = "Strength Multiplier", Default = 10, Min = 1, Max = 100, Rounding = 0, Callback = function(v) superPower=v end })
Tabs.Fling:AddSlider("FlingPower", { Title = "Fling Power", Default = 100, Min = 10, Max = 800, Rounding = 0, Callback = function(v) flingPower=v end })

Tabs.Fling:AddSection("Aura")
Tabs.Fling:AddToggle("FlingAura", { Title = "Fling Aura", Default = false, Callback = function(v)
    flingAuraEnabled=v
    if v then
        if auraConn then auraConn:Disconnect() end
        auraConn = RunService.Heartbeat:Connect(function() if flingAuraEnabled then pcall(flingTargetsInRadius) end end)
    else
        if auraConn then auraConn:Disconnect() auraConn=nil end
    end
end })
Tabs.Fling:AddSlider("AuraRadius", { Title = "Aura Radius", Default = 20, Min = 5, Max = 80, Rounding = 0, Callback = function(v) flingAuraRadius=v end })
Tabs.Fling:AddSlider("AuraDelay", { Title = "Aura Delay", Default = 0.15, Min = 0.05, Max = 1, Rounding = 2, Callback = function(v) flingAuraDelay=v end })
Tabs.Fling:AddToggle("GrabAura", { Title = "Grab Aura (auto grab)", Default = false, Callback = function(v) grabAuraEnabled=v end })

Tabs.Fling:AddSection("Effects")
Tabs.Fling:AddToggle("Spin", { Title = "Spin Fling", Default = false, Callback = function(v) spinEnabled=v end })
Tabs.Fling:AddSlider("SpinSpeed", { Title = "Spin Speed", Default = 400, Min = 50, Max = 900, Rounding = 0, Callback = function(v) spinSpeed=v end })
Tabs.Fling:AddToggle("Gravity", { Title = "Up Force (Sky Fling)", Default = false, Callback = function(v) gravityEnabled=v end })
Tabs.Fling:AddSlider("GravityForce", { Title = "Up Force", Default = 6000, Min = 1000, Max = 20000, Rounding = 0, Callback = function(v) gravityForce=v end })
Tabs.Fling:AddToggle("ZeroG", { Title = "Zero-G Float", Default = false, Callback = function(v) zeroGEnabled=v end })
Tabs.Fling:AddToggle("Boomerang", { Title = "Boomerang (return)", Default = false, Callback = function(v) boomerangEnabled=v end })
Tabs.Fling:AddSlider("BoomerangTime", { Title = "Return Time", Default = 5, Min = 1, Max = 10, Rounding = 0, Callback = function(v) boomerangTime=v end })

Tabs.Fling:AddSection("Troll")
Tabs.Fling:AddButton({ Title = "FLING ALL", Callback = function() flingAll() Fluent:Notify({ Title="MoonFling", Content="Flung all!", Duration=2 }) end })
Tabs.Fling:AddButton({ Title = "Fling Selected Player", Callback = function()
    local name = Options.FlingTarget.Value
    if not name or name=="" then return end
    local plr = Players:FindFirstChild(name)
    if not plr then for _,p in ipairs(Players:GetPlayers()) do if p.Name:lower():sub(1,#name)==name:lower() then plr=p break end end end
    local hrp = plr and getPlayerHRP(plr)
    if hrp then applyFling(hrp, flingPower*6) else Fluent:Notify({ Title="Fling", Content="Player not found", Duration=3 }) end
end })
Tabs.Fling:AddInput("FlingTarget", { Title = "Target Username", Placeholder = "Name...", Callback = function() end })
Tabs.Fling:AddToggle("Hitbox", { Title = "Hitbox Expander", Default = false, Callback = function(v) hitboxEnabled=v updateHitbox(v) end })
Tabs.Fling:AddSlider("HitboxSize", { Title = "Hitbox Size", Default = 12, Min = 4, Max = 30, Rounding = 0, Callback = function(v) hitboxSize=v end })
Tabs.Fling:AddToggle("AntiFling", { Title = "Anti Fling (shield)", Default = false, Callback = function(v) antiFlingEnabled=v end })

------------------------------------------------
-- MOVEMENT (from MoonHub)
------------------------------------------------
local speedEnabled = false
local speedValue = 32
local jumpValue = 50
local flyEnabled = false
local flySpeed = 50
local noclipEnabled = false
local infJumpEnabled = false

Tabs.Movement:AddToggle("SpeedEnabled", { Title = "Enable Speed", Default = false, Callback = function(v) speedEnabled = v end })
Tabs.Movement:AddSlider("SpeedValue", { Title = "WalkSpeed", Default = 32, Min = 16, Max = 200, Rounding = 0, Callback = function(v) speedValue = v end })
Tabs.Movement:AddToggle("JumpEnabled", { Title = "Enable JumpPower", Default = false, Callback = function(v)
    local h = getHumanoid()
    if h then h.UseJumpPower = v end
end })
Tabs.Movement:AddSlider("JumpValue", { Title = "JumpPower", Default = 50, Min = 50, Max = 350, Rounding = 0, Callback = function(v)
    jumpValue = v
    local h = getHumanoid()
    if h and h.UseJumpPower then h.JumpPower = v end
    if h and not h.UseJumpPower then h.JumpHeight = v/4 end
end })

local flyConn, flyGyro, flyVel
local function startFly()
    local root = getRoot()
    if not root then return end
    flyGyro = Instance.new("BodyGyro")
    flyGyro.P = 9e4
    flyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    flyGyro.CFrame = root.CFrame
    flyGyro.Parent = root
    flyVel = Instance.new("BodyVelocity")
    flyVel.Velocity = Vector3.new(0,0,0)
    flyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    flyVel.Parent = root
    flyConn = RunService.Heartbeat:Connect(function()
        if not flyEnabled then return end
        local c = getCharacter()
        local r = getRoot()
        local h = getHumanoid()
        if not c or not r or not h then return end
        h.PlatformStand = true
        local dir = Vector3.new(0,0,0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0,1,0) end
        if dir.Magnitude > 0 then dir = dir.Unit * flySpeed else dir = Vector3.new(0,0,0) end
        flyVel.Velocity = dir
        flyGyro.CFrame = Camera.CFrame
    end)
end
local function stopFly()
    if flyConn then flyConn:Disconnect() flyConn=nil end
    if flyGyro then flyGyro:Destroy() flyGyro=nil end
    if flyVel then flyVel:Destroy() flyVel=nil end
    local h = getHumanoid()
    if h then h.PlatformStand = false end
end
Tabs.Movement:AddToggle("FlyToggle", { Title = "Fly", Default = false, Callback = function(v)
    flyEnabled = v
    if v then startFly() else stopFly() end
end })
Tabs.Movement:AddSlider("FlySpeed", { Title = "Fly Speed", Default = 50, Min = 10, Max = 300, Rounding = 0, Callback = function(v) flySpeed = v end })
Tabs.Movement:AddToggle("Noclip", { Title = "Noclip", Default = false, Callback = function(v) noclipEnabled = v end })
Tabs.Movement:AddToggle("InfJump", { Title = "Infinite Jump", Default = false, Callback = function(v) infJumpEnabled = v end })
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.7)
    local h = getHumanoid()
    if h then
        h.UseJumpPower = Options.JumpEnabled and Options.JumpEnabled.Value or false
        if h.UseJumpPower then h.JumpPower = jumpValue else h.JumpHeight = jumpValue/4 end
    end
    if flyEnabled then stopFly() task.wait(0.2) startFly() end
end)
UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled and getHumanoid() then pcall(function() getHumanoid():ChangeState(Enum.HumanoidStateType.Jumping) end) end
end)

------------------------------------------------
-- VISUALS
------------------------------------------------
local espEnabled = false
local espBoxes = true
local espNames = true
local espHealth = true
local espDistance = false
local tracerEnabled = false
local espFolder = Instance.new("Folder")
espFolder.Name = "MoonFling_ESP"
espFolder.Parent = game.CoreGui
local highlights = {}
local billboards = {}
local tracerLines = {}
local function clearESP(plr)
    if highlights[plr] then highlights[plr]:Destroy() highlights[plr]=nil end
    if billboards[plr] then billboards[plr]:Destroy() billboards[plr]=nil end
    if tracerLines[plr] then pcall(function() tracerLines[plr]:Remove() end) tracerLines[plr]=nil end
end
local function createESP(plr)
    if plr == LocalPlayer then return end
    pcall(clearESP, plr)
    local char = plr.Character
    if not char then return end
    local hl = Instance.new("Highlight")
    hl.Adornee = char
    hl.FillTransparency = 0.6
    hl.FillColor = Color3.fromRGB(124, 58, 237)
    hl.OutlineColor = Color3.fromRGB(168, 123, 255)
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = espEnabled and espBoxes
    hl.Parent = espFolder
    highlights[plr] = hl
    local bb = Instance.new("BillboardGui")
    bb.Adornee = char:WaitForChild("Head", 3) or char:FindFirstChildWhichIsA("BasePart")
    bb.Size = UDim2.fromOffset(200, 50)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = espFolder
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1,1)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextStrokeTransparency = 0.4
    label.TextColor3 = Color3.fromRGB(235,235,255)
    label.Text = plr.Name
    label.Parent = bb
    billboards[plr] = bb
    if tracerEnabled and Drawing then
        local line = Drawing.new("Line")
        line.Visible = true
        line.Thickness = 1.2
        line.Transparency = 0.85
        line.Color = Color3.fromRGB(124, 58, 237)
        tracerLines[plr] = line
    end
    char.AncestryChanged:Connect(function() if not char.Parent then clearESP(plr) end end)
end
local function updateESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local bb = billboards[plr]
            local hl = highlights[plr]
            if bb and hl then
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local head = char and char:FindFirstChild("Head")
                if char and hum and root and head and hum.Health > 0 then
                    hl.Enabled = espEnabled and espBoxes
                    bb.Enabled = espEnabled
                    local dist = LocalPlayer:DistanceFromCharacter(root.Position)
                    local txt = ""
                    if espNames then txt ..= plr.Name end
                    if espHealth and hum then txt ..= string.format("  [%d/%d]", math.floor(hum.Health), hum.MaxHealth) end
                    if espDistance then txt ..= string.format("  %dm", math.floor(dist)) end
                    bb:FindFirstChildOfClass("TextLabel").Text = txt
                    bb.Adornee = head
                    local col = hum.Health/hum.MaxHealth < 0.5 and Color3.fromRGB(239,68,68) or Color3.fromRGB(124, 58, 237)
                    hl.FillColor = col
                    hl.OutlineColor = col
                    if tracerLines[plr] then
                        local line = tracerLines[plr]
                        local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
                        line.Visible = onScreen and espEnabled and tracerEnabled
                        if onScreen then
                            line.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                            line.To = Vector2.new(pos.X, pos.Y)
                        end
                    end
                else
                    hl.Enabled = false
                    bb.Enabled = false
                    if tracerLines[plr] then tracerLines[plr].Visible = false end
                end
            elseif espEnabled and plr.Character then
                createESP(plr)
            end
        end
    end
end
for _, p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then createESP(p) end end
Players.PlayerAdded:Connect(function(p) task.wait(1) if espEnabled then createESP(p) end p.CharacterAdded:Connect(function() task.wait(1) if espEnabled then createESP(p) end end) end)
Players.PlayerRemoving:Connect(clearESP)
Tabs.Visuals:AddToggle("ESP", { Title = "Enable ESP", Default = false, Callback = function(v)
    espEnabled = v
    if not v then
        for _,plr in ipairs(Players:GetPlayers()) do
            if highlights[plr] then highlights[plr].Enabled=false end
            if billboards[plr] then billboards[plr].Enabled=false end
            if tracerLines[plr] then tracerLines[plr].Visible=false end
        end
    else
        for _,plr in ipairs(Players:GetPlayers()) do if plr~=LocalPlayer then createESP(plr) end end
    end
end })
Tabs.Visuals:AddToggle("ESPBox", { Title = "Highlight Box", Default = true, Callback = function(v) espBoxes=v end })
Tabs.Visuals:AddToggle("ESPName", { Title = "Show Name", Default = true, Callback = function(v) espNames=v end })
Tabs.Visuals:AddToggle("ESPHealth", { Title = "Show Health", Default = true, Callback = function(v) espHealth=v end })
Tabs.Visuals:AddToggle("ESPDistance", { Title = "Show Distance", Default = false, Callback = function(v) espDistance=v end })
Tabs.Visuals:AddToggle("Tracers", { Title = "Tracers", Default = false, Callback = function(v)
    tracerEnabled=v
    if not v then for _,l in pairs(tracerLines) do pcall(function() l.Visible=false end) end end
    if v and Drawing then for _,plr in ipairs(Players:GetPlayers()) do if plr~=LocalPlayer and not tracerLines[plr] then createESP(plr) end end end
end })
local fullbrightEnabled = false
local oldBrightness, oldAmbient, oldOutdoorAmbient, oldFogEnd
Tabs.Visuals:AddToggle("Fullbright", { Title = "Fullbright", Default = false, Callback = function(v)
    fullbrightEnabled=v
    if v then
        oldBrightness = Lighting.Brightness
        oldAmbient = Lighting.Ambient
        oldOutdoorAmbient = Lighting.OutdoorAmbient
        oldFogEnd = Lighting.FogEnd
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
    else
        if oldBrightness then Lighting.Brightness = oldBrightness end
        if oldAmbient then Lighting.Ambient = oldAmbient end
        if oldOutdoorAmbient then Lighting.OutdoorAmbient = oldOutdoorAmbient end
        if oldFogEnd then Lighting.FogEnd = oldFogEnd end
        Lighting.GlobalShadows = true
    end
end })
Tabs.Visuals:AddSlider("FOVSlider", { Title = "Field of View", Default = 70, Min = 70, Max = 120, Rounding = 0, Callback = function(v) Camera.FieldOfView = v end })
Tabs.Visuals:AddButton({ Title = "Remove Fog", Callback = function() Lighting.FogEnd = 100000 Lighting.FogStart = 0 end })

------------------------------------------------
-- PLAYER
------------------------------------------------
Tabs.Player:AddSection("Protection")
local antiAFK = false
Tabs.Player:AddToggle("AntiAFK", { Title = "Anti AFK", Default = false, Callback = function(v) antiAFK=v if v then Fluent:Notify({ Title = "Anti AFK", Content = "Enabled", Duration = 3 }) end end })
Tabs.Player:AddToggle("AntiFlingToggle", { Title = "Anti Grab Shield", Default = false, Callback = function(v) antiFlingEnabled=v end })
Tabs.Player:AddButton({ Title = "Anti Ragdoll", Callback = function()
    local c = getCharacter()
    if c then
        for _,v in ipairs(c:GetDescendants()) do if v:IsA("BallSocketConstraint") or v:IsA("HingeConstraint") then v:Destroy() end end
        Fluent:Notify({ Title = "Player", Content = "Ragdoll removed", Duration = 3 })
    end
end })
Tabs.Player:AddButton({ Title = "Invisible", Callback = function()
    local c = getCharacter()
    if not c then return end
    for _,part in ipairs(c:GetDescendants()) do if part:IsA("BasePart") and part.Name~="HumanoidRootPart" then part.Transparency = part.Transparency==1 and 0 or 1 end end
end })
Tabs.Player:AddButton({ Title = "Reset Character", Callback = function() local h=getHumanoid() if h then h.Health=0 end end })
Tabs.Player:AddButton({ Title = "Sit / Unsit", Callback = function() local h=getHumanoid() if h then h.Sit=not h.Sit end end })
Tabs.Player:AddButton({ Title = "Stop All Forces", Callback = function()
    for _,plr in ipairs(Players:GetPlayers()) do
        local hrp=getPlayerHRP(plr)
        if hrp then clearForces(hrp) end
    end
    local r=getRoot() if r then r.AssemblyLinearVelocity=Vector3.new(0,0,0) r.AssemblyAngularVelocity=Vector3.new(0,0,0) end
end })

------------------------------------------------
-- UTILITY
------------------------------------------------
Tabs.Utility:AddSection("Teleport")
local clickTPTool = nil
Tabs.Utility:AddToggle("ClickTP", { Title = "Click TP Tool", Default = false, Callback = function(v)
    if v then
        clickTPTool = Instance.new("Tool")
        clickTPTool.Name = "Moon TP"
        clickTPTool.RequiresHandle = false
        clickTPTool.CanBeDropped = false
        clickTPTool.Parent = LocalPlayer.Backpack
        clickTPTool.Activated:Connect(function()
            local mouse = LocalPlayer:GetMouse()
            local root = getRoot()
            if mouse.Hit and root then root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0,3,0)) end
        end)
    else
        if clickTPTool then clickTPTool:Destroy() clickTPTool=nil end
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then for _,t in ipairs(bp:GetChildren()) do if t.Name=="Moon TP" then t:Destroy() end end end
        local c = getCharacter()
        if c then for _,t in ipairs(c:GetChildren()) do if t.Name=="Moon TP" then t:Destroy() end end end
    end
end })
Tabs.Utility:AddButton({ Title = "Teleport to Spawn", Callback = function() local r=getRoot() if r then r.CFrame=CFrame.new(0,10,0) end end })
Tabs.Utility:AddInput("TPPlayer", { Title = "Teleport to Player", Placeholder = "Username", Callback = function() end })
Tabs.Utility:AddButton({ Title = "Teleport", Callback = function()
    local name = Options.TPPlayer.Value
    local plr = Players:FindFirstChild(name)
    if not plr then for _,p in ipairs(Players:GetPlayers()) do if p.Name:lower():sub(1,#name)==name:lower() then plr=p break end end end
    local target = plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    local root = getRoot()
    if target and root then root.CFrame = target.CFrame + Vector3.new(0,2,0)
    else Fluent:Notify({ Title = "Teleport", Content = "Player not found", Duration = 3 }) end
end })
Tabs.Utility:AddSection("Spawner (FTAP)")
local toyMap = {
    ["Anvil"]="AnvilGray", ["Recliner"]="ArmChairBlue", ["Basketball"]="BallBasketball", ["BombBalloon"]="BombBalloon",
    ["Missile"]="BombMissile", ["Blobman"]="CreatureBlobman", ["Robot"]="CreatureRobot", ["Couch"]="CouchBrownGray"
}
local toyNames = {}
for k,_ in pairs(toyMap) do table.insert(toyNames, k) end
table.sort(toyNames)
local selectedToy = toyNames[1]
Tabs.Utility:AddDropdown("ToySelect", { Title = "Select Toy", Values = toyNames, Default = 1, Callback = function(v) selectedToy=v end })
Tabs.Utility:AddButton({ Title = "Spawn Toy", Callback = function()
    pcall(function()
        local rf = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("SpawnToyRemoteFunction")
        if rf then
            local real = toyMap[selectedToy] or selectedToy
            rf:InvokeServer(real)
            Fluent:Notify({ Title="Spawner", Content="Spawned "..selectedToy, Duration=2 })
        else
            Fluent:Notify({ Title="Spawner", Content="Remote not found", Duration=3 })
        end
    end)
end })
Tabs.Utility:AddButton({ Title = "Spawn Blobman x10", Callback = function()
    for i=1,10 do task.spawn(function()
        local rf = ReplicatedStorage:FindFirstChild("MenuToys") and ReplicatedStorage.MenuToys:FindFirstChild("SpawnToyRemoteFunction")
        if rf then pcall(function() rf:InvokeServer("CreatureBlobman") end) task.wait(0.1) end
    end) end
end })
Tabs.Utility:AddSection("Server")
Tabs.Utility:AddButton({ Title = "Rejoin Server", Callback = function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end })
Tabs.Utility:AddButton({ Title = "Server Hop", Callback = function()
    local servers = game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")
    local data = game:GetService("HttpService"):JSONDecode(servers)
    for _,s in ipairs(data.data) do if s.id ~= game.JobId and s.playing < s.maxPlayers then TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer) return end end
    Fluent:Notify({ Title = "Server Hop", Content = "No servers found", Duration = 3 })
end })
Tabs.Utility:AddButton({ Title = "Copy JobId", Callback = function() if setclipboard then setclipboard(game.JobId) Fluent:Notify({ Title = "Copied", Content = game.JobId, Duration = 3 }) end end })
Tabs.Utility:AddButton({ Title = "FPS Boost", Callback = function()
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") then v.Material=Enum.Material.SmoothPlastic v.Reflectance=0
        elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency=1
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled=false end
    end
    Lighting.GlobalShadows=false
    Fluent:Notify({ Title = "Optimization", Content = "FPS Boost applied", Duration = 3 })
end })

------------------------------------------------
-- SETTINGS
------------------------------------------------
InterfaceManager:SetLibrary(Fluent)
SaveManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("MoonFling")
SaveManager:SetFolder("MoonFling/config")
SaveManager:BuildConfigSection(Tabs.Settings)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()

------------------------------------------------
-- LOOPS
------------------------------------------------
RunService.RenderStepped:Connect(function()
    if speedEnabled then local h=getHumanoid() if h then h.WalkSpeed=speedValue end end
    if noclipEnabled then local c=getCharacter() if c then for _,part in ipairs(c:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide=false end end end end
    if antiFlingEnabled then
        local r=getRoot()
        if r and r.AssemblyLinearVelocity.Magnitude > 80 then
            r.AssemblyLinearVelocity = Vector3.new(0,0,0)
            r.AssemblyAngularVelocity = Vector3.new(0,0,0)
            for _,v in ipairs(r:GetChildren()) do if v:IsA("BodyVelocity") or v:IsA("BodyForce") then v:Destroy() end end
        end
        local c=getCharacter()
        if c then
            for _,v in ipairs(Workspace:GetChildren()) do
                if v.Name=="GrabParts" then
                    local gp=v:FindFirstChild("GrabPart")
                    local wc=gp and gp:FindFirstChild("WeldConstraint")
                    if wc and wc.Part1 and wc.Part1:IsDescendantOf(c) then
                        wc:Destroy()
                    end
                end
            end
        end
    end
    if grabAuraEnabled and getRoot() then
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr~=LocalPlayer then
                local hrp=getPlayerHRP(plr)
                if hrp and (hrp.Position - getRoot().Position).Magnitude <= 18 then
                end
            end
        end
    end
    updateESP()
end)

LocalPlayer.Idled:Connect(function()
    if antiAFK then VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end
end)

Fluent:Notify({ Title = "MoonFling", Content = "Press LeftControl to hide", Duration = 5 })
