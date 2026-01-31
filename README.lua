local version = "1.1.0"

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local Teams = game:GetService("Teams")
local VirtualInputManager = game:GetService("VirtualInputManager")

local guardsTeam = Teams:FindFirstChild("Guards")
local inmatesTeam = Teams:FindFirstChild("Inmates")
local criminalsTeam = Teams:FindFirstChild("Criminals")



local cfg = {
	enabled = true,
	teamcheck = false,
	wallcheck = false,
	deathcheck = false,
	ffcheck = false,
	hostilecheck = false,
	trespasscheck = false,
	vehiclecheck = false,
	criminalsnoinnmates = false,
	inmatesnocriminals = false,
	shieldbreaker = false,
	shieldfrontangle = 0.3,
	shieldrandomhead = false,
	shieldheadchance = 30,
	taserbypasshostile = false,
	taserbypasstrespass = false,
	taseralwayshit = false,
	ifplayerstill = false,
	stillthreshold = 0.5,
	hitchance = 100,
	hitchanceAutoOnly = false,
	missspread = 5,
	shotgunnaturalspread = false,
	shotgungamehandled = false,
	prioritizeclosest = false,
	targetstickiness = false,
	targetstickinessduration = 0.6,
	targetstickinessrandom = false,
	targetstickinessmin = 0.3,
	targetstickinessmax = 0.7,
	fov = 180,
	showfov = true,
	showtargetline = false,
	togglekey = Enum.KeyCode.RightShift,
	aimpart = "Head",
	randomparts = true,
	partslist = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart"},
	esp = false,
	espteamcheck = true,
	espshowteam = false,
	esptargets = {guards = true, inmates = true, criminals = true},
	espmaxdist = 500,
	espshowdist = true,
	esptoggle = Enum.KeyCode.RightControl,
	espcolor = Color3.fromRGB(0, 170, 255),
	espguards = Color3.fromRGB(0, 170, 255),
	espinmates = Color3.fromRGB(255, 150, 50),
	espcriminals = Color3.fromRGB(255, 60, 60),
	espteam = Color3.fromRGB(60, 255, 60),
	espuseteamcolors = true,
	autoshoot = true,
	autoshootdelay = 0.12,
	autoshootstartdelay = 0.2,
	autoshootfeedback = true,
	autoreload = true,
	c4esp = false,
	c4esptoggle = Enum.KeyCode.B,
	c4espcolor = Color3.fromRGB(80, 255, 80),
	c4espmaxdist = 200,
	c4espshowdist = true
}

-- DEBUG SYSTEM
local debugMode = true
local debugLogs = {}

local function debugPrint(msg)
    if debugMode then
        table.insert(debugLogs, msg)
        print("[DEBUG] " .. msg)
    end
end

local function showDebugNotification()
    if #debugLogs > 0 then
        local lastFive = ""
        for i = math.max(1, #debugLogs - 4), #debugLogs do
            lastFive = lastFive .. debugLogs[i] .. "\n"
        end
        StarterGui:SetCore("SendNotification", {
            Title = "Debug Info",
            Text = lastFive,
            Duration = 5
        })
    end
end

local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude
wallParams.IgnoreWater = true
wallParams.RespectCanCollide = false
wallParams.CollisionGroup = "ClientBullet"

local currentGun = nil
local rng = Random.new()
local lastShotTime = 0
local lastShotResult = false
local shotCooldown = 0.15
local currentTarget = nil
local targetSwitchTime = 0
local currentStickiness = 0

local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(255, 0, 0)
fovCircle.Radius = cfg.fov
fovCircle.Transparency = 0.8
fovCircle.Filled = false
fovCircle.NumSides = 64
fovCircle.Thickness = 1
fovCircle.Visible = cfg.showfov and cfg.enabled

local targetLine = Drawing.new("Line")
targetLine.Color = Color3.fromRGB(0, 255, 0)
targetLine.Thickness = 1
targetLine.Transparency = 0.5
targetLine.Visible = false

local visuals = {container = nil}
local espCache = {}

local function makeVisuals()
	local container
	if gethui then
		local screen = Instance.new("ScreenGui")
		screen.Name = "SilentAimESP"
		screen.ResetOnSpawn = false
		screen.Parent = gethui()
		container = screen
	elseif syn and syn.protect_gui then
		local screen = Instance.new("ScreenGui")
		screen.Name = "SilentAimESP"
		screen.ResetOnSpawn = false
		syn.protect_gui(screen)
		screen.Parent = CoreGui
		container = screen
	else
		local screen = Instance.new("ScreenGui")
		screen.Name = "SilentAimESP"
		screen.ResetOnSpawn = false
		screen.Parent = CoreGui
		container = screen
	end
	visuals.container = container
end

local function makeEsp(player)
	if espCache[player] then return espCache[player] end

	local esp = Instance.new("BillboardGui")
	esp.Name = "ESP_" .. player.Name
	esp.AlwaysOnTop = true
	esp.Size = UDim2.new(0, 20, 0, 20)
	esp.StudsOffset = Vector3.new(0, 3, 0)
	esp.LightInfluence = 0

	local diamond = Instance.new("Frame")
	diamond.Name = "Diamond"
	diamond.BackgroundColor3 = cfg.espcolor
	diamond.BorderSizePixel = 0
	diamond.Size = UDim2.new(0, 10, 0, 10)
	diamond.Position = UDim2.new(0.5, -5, 0.5, -5)
	diamond.Rotation = 45
	diamond.Parent = esp

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.3
	stroke.Parent = diamond

	local distLabel = Instance.new("TextLabel")
	distLabel.Name = "DistanceLabel"
	distLabel.BackgroundTransparency = 1
	distLabel.Size = UDim2.new(0, 60, 0, 16)
	distLabel.Position = UDim2.new(0.5, -30, 1, 2)
	distLabel.Font = Enum.Font.GothamBold
	distLabel.TextSize = 11
	distLabel.TextColor3 = Color3.new(1, 1, 1)
	distLabel.TextStrokeTransparency = 0.5
	distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	distLabel.Text = ""
	distLabel.Parent = esp

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(0, 100, 0, 14)
	nameLabel.Position = UDim2.new(0.5, -50, 0, -16)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 10
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.Text = player.Name
	nameLabel.Parent = esp

	espCache[player] = esp
	return esp
end

local function removeEsp(player)
	local e = espCache[player]
	if e then e:Destroy() espCache[player] = nil end
end

local function shouldShowEsp(player)
	if not player or player == LocalPlayer or not player.Character then return false end

	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local myChar = LocalPlayer.Character
	if not myChar then return false end
	local myHrp = myChar:FindFirstChild("HumanoidRootPart")
	if not myHrp then return false end

	local distance = (hrp.Position - myHrp.Position).Magnitude
	if distance > cfg.espmaxdist then return false end

	local myTeam = LocalPlayer.Team
	local theirTeam = player.Team

	if theirTeam == myTeam then
		if not cfg.espshowteam then return false end
		return true
	end

	if cfg.espteamcheck then
		local imCrimOrInmate = (myTeam == criminalsTeam or myTeam == inmatesTeam)
		local theyCrimOrInmate = (theirTeam == criminalsTeam or theirTeam == inmatesTeam)
		if imCrimOrInmate and theyCrimOrInmate then return false end
	end

	if theirTeam == guardsTeam then return cfg.esptargets.guards
	elseif theirTeam == inmatesTeam then return cfg.esptargets.inmates
	elseif theirTeam == criminalsTeam then return cfg.esptargets.criminals end

	return false
end

local function updateEsp()
	if not cfg.esp or not visuals.container then
		for _, e in pairs(espCache) do e.Parent = nil end
		return
	end

	local myChar = LocalPlayer.Character
	local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

	for _, player in ipairs(Players:GetPlayers()) do
		local show = shouldShowEsp(player)

		if show then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local head = char and char:FindFirstChild("Head")

			if hrp and head then
				local esp = makeEsp(player)
				esp.Adornee = head
				esp.Parent = visuals.container

				local d = esp:FindFirstChild("Diamond")
				if d and cfg.espuseteamcolors then
					local t = player.Team
					if t == LocalPlayer.Team then d.BackgroundColor3 = cfg.espteam
					elseif t == guardsTeam then d.BackgroundColor3 = cfg.espguards
					elseif t == inmatesTeam then d.BackgroundColor3 = cfg.espinmates
					elseif t == criminalsTeam then d.BackgroundColor3 = cfg.espcriminals
					else d.BackgroundColor3 = cfg.espcolor end
				end

				if cfg.espshowdist and myHrp then
					local label = esp:FindFirstChild("DistanceLabel")
					if label then
						label.Text = math.floor((hrp.Position - myHrp.Position).Magnitude) .. "m"
						label.Visible = true
					end
				end
			end
		else
			local e = espCache[player]
			if e then e.Parent = nil end
		end
	end
end

local c4espCache = {}

local function makeC4Esp(c4Part)
	if c4espCache[c4Part] then return c4espCache[c4Part] end

	local esp = Instance.new("BillboardGui")
	esp.Name = "C4ESP_" .. tostring(c4Part)
	esp.AlwaysOnTop = true
	esp.Size = UDim2.new(0, 24, 0, 24)
	esp.StudsOffset = Vector3.new(0, 1, 0)
	esp.LightInfluence = 0

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.BackgroundColor3 = cfg.c4espcolor
	icon.BorderSizePixel = 0
	icon.Size = UDim2.new(0, 14, 0, 14)
	icon.Position = UDim2.new(0.5, -7, 0.5, -7)
	icon.Rotation = 45
	icon.Parent = esp

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = icon

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, 60, 0, 14)
	label.Position = UDim2.new(0.5, -30, 1, 2)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Text = "C4"
	label.Parent = esp

	local distLabel = Instance.new("TextLabel")
	distLabel.Name = "DistLabel"
	distLabel.BackgroundTransparency = 1
	distLabel.Size = UDim2.new(0, 60, 0, 12)
	distLabel.Position = UDim2.new(0.5, -30, 1, 16)
	distLabel.Font = Enum.Font.GothamBold
	distLabel.TextSize = 10
	distLabel.TextColor3 = cfg.c4espcolor
	distLabel.TextStrokeTransparency = 0.5
	distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	distLabel.Text = ""
	distLabel.Parent = esp

	c4espCache[c4Part] = esp
	return esp
end

local trackedC4s = {}

local function isC4Part(part)
	if not part or not part:IsA("BasePart") then return false end
	local name = part.Name:lower()
	local parentName = part.Parent and part.Parent.Name:lower() or ""
	return name == "explosive" or name == "c4" or name == "clientc4" or 
		parentName:find("c4") or name:find("c4")
end

local function onDescendantAdded(desc)
	if isC4Part(desc) then
		trackedC4s[desc] = true
	end
end

local function onDescendantRemoving(desc)
	trackedC4s[desc] = nil
	if c4espCache[desc] then
		c4espCache[desc]:Destroy()
		c4espCache[desc] = nil
	end
end

for _, desc in ipairs(workspace:GetDescendants()) do
	if isC4Part(desc) then trackedC4s[desc] = true end
end
workspace.DescendantAdded:Connect(onDescendantAdded)
workspace.DescendantRemoving:Connect(onDescendantRemoving)

local function updateC4Esp()
	if not cfg.c4esp or not visuals.container then
		for _, e in pairs(c4espCache) do e.Parent = nil end
		return
	end

	local myChar = LocalPlayer.Character
	local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

	for part in pairs(trackedC4s) do
		if part and part:IsDescendantOf(workspace) then
			local dist = 0
			if myHrp then
				dist = (part.Position - myHrp.Position).Magnitude
			end

			if dist <= cfg.c4espmaxdist then
				local esp = makeC4Esp(part)
				esp.Adornee = part
				esp.Parent = visuals.container

				if cfg.c4espshowdist and myHrp then
					local distLabel = esp:FindFirstChild("DistLabel")
					if distLabel then
						distLabel.Text = math.floor(dist) .. "m"
					end
				end
			else
				local e = c4espCache[part]
				if e then e.Parent = nil end
			end
		else
			trackedC4s[part] = nil
			if c4espCache[part] then
				c4espCache[part]:Destroy()
				c4espCache[part] = nil
			end
		end
	end
end

local ShootEvent = ReplicatedStorage:WaitForChild("GunRemotes"):WaitForChild("ShootEvent")
local Debris = game:GetService("Debris")
local lastAutoShoot = 0
local targetAcquiredTime = 0
local lastAutoTarget = nil
local cachedBulletsLabel = nil

local function createBulletTrail(startPos, endPos, isTaser)
	local distance = (endPos - startPos).Magnitude
	local trail = Instance.new("Part")
	trail.Name = "BulletTrail"
	trail.Anchored = true
	trail.CanCollide = false
	trail.CanQuery = false
	trail.CanTouch = false
	trail.Material = Enum.Material.Neon
	trail.Size = Vector3.new(0.1, 0.1, distance)
	trail.CFrame = CFrame.new(startPos, endPos) * CFrame.new(0, 0, -distance / 2)
	trail.Transparency = 0.5

	if isTaser then
		trail.BrickColor = BrickColor.new("Cyan")
		trail.Size = Vector3.new(0.2, 0.2, distance)
		local light = Instance.new("SurfaceLight")
		light.Color = Color3.fromRGB(0, 234, 255)
		light.Range = 7
		light.Brightness = 5
		light.Face = Enum.NormalId.Bottom
		light.Parent = trail
	else
		trail.BrickColor = BrickColor.Yellow()
	end

	trail.Parent = workspace
	Debris:AddItem(trail, isTaser and 0.8 or 0.1)
end

-- FUNÇÃO AUTO SHOOT CORRIGIDA
local function autoShoot()
    debugPrint("=== AUTO SHOOT STARTED ===")
    
    if not cfg.autoshoot then 
        debugPrint("Auto shoot disabled in config")
        return 
    end
    if not cfg.enabled then 
        debugPrint("Silent aim disabled")
        return 
    end
    if not currentGun then 
        debugPrint("No current gun")
        return 
    end

    local now = os.clock()
    local fireRate = currentGun:GetAttribute("FireRate") or cfg.autoshootdelay
    debugPrint("Fire rate: " .. tostring(fireRate))
    
    if now - lastAutoShoot < fireRate then 
        debugPrint("On cooldown: " .. tostring(now - lastAutoShoot) .. " < " .. tostring(fireRate))
        return 
    end

    local myChar = LocalPlayer.Character
    if not myChar then 
        debugPrint("No character")
        return 
    end
    
    local myHead = myChar:FindFirstChild("Head")
    if not myHead then 
        debugPrint("No head part")
        return 
    end

    debugPrint("Looking for target...")
    local target, targetPos = getClosest(cfg.fov)
    
    if not target then 
        debugPrint("No target found")
        lastAutoTarget = nil
        return 
    end
    
    if not target.Character then
        debugPrint("Target has no character")
        return
    end
    
    if not fullCheck(target) then 
        debugPrint("Target failed full check")
        return 
    end

    debugPrint("Target found: " .. target.Name)
    
    if target ~= lastAutoTarget then
        targetAcquiredTime = now
        lastAutoTarget = target
        debugPrint("New target acquired")
    end

    if now - targetAcquiredTime < cfg.autoshootstartdelay then 
        debugPrint("Waiting start delay: " .. tostring(now - targetAcquiredTime))
        return 
    end

    local targetPart = getTargetPart(target.Character)
    if not targetPart then 
        debugPrint("No target part found")
        return 
    end
    debugPrint("Target part: " .. targetPart.Name)

    local ammo = currentGun:GetAttribute("Local_CurrentAmmo") or currentGun:GetAttribute("CurrentAmmo") or 0
    debugPrint("Ammo: " .. tostring(ammo))
    
    if ammo <= 0 then 
        debugPrint("Out of ammo")
        if cfg.autoreload then
            local reloadEvent = currentGun:FindFirstChild("Reload")
            if reloadEvent then
                reloadEvent:FireServer()
                debugPrint("Auto reload triggered")
            end
        end
        return 
    end

    lastAutoShoot = now
    debugPrint("Last auto shoot time updated")

    local isTaser = currentGun:GetAttribute("Projectile") == "Taser"
    local isShotgun = currentGun:GetAttribute("IsShotgun")
    local shouldHit = false

    if cfg.taseralwayshit and isTaser then
        shouldHit = true
        debugPrint("Taser always hit enabled")
    elseif cfg.ifplayerstill and isStanding(target) then
        shouldHit = true
        debugPrint("Target is standing still")
    elseif cfg.hitchanceAutoOnly and isShotgun then
        shouldHit = true
        debugPrint("Shotgun always hit")
    else
        shouldHit = rollHit()
        debugPrint("Hit chance roll: " .. tostring(shouldHit))
    end

    if not shouldHit and cfg.missspread <= 0 then
        debugPrint("Miss with no spread - canceling")
        return
    end

    local projectileCount = currentGun:GetAttribute("ProjectileCount") or 1
    debugPrint("Projectile count: " .. tostring(projectileCount))
    
    local shots = {}

    for i = 1, projectileCount do
        local finalPos
        if shouldHit then
            if targetPos then
                finalPos = targetPos
            else
                finalPos = targetPart.Position
            end
        else
            if cfg.missspread > 0 then
                finalPos = getMissPos(targetPart.Position)
            else
                return
            end
        end
        shots[i] = {myHead.Position, finalPos, shouldHit and targetPart or nil}
        createBulletTrail(myHead.Position, finalPos, isTaser)
    end

    debugPrint("Attempting to fire " .. #shots .. " shots")
    
    -- Tentativa 1: ShootEvent principal
    local shotFired = false
    if ShootEvent then
        local success, errorMsg = pcall(function()
            ShootEvent:FireServer(shots)
        end)
        
        if success then
            shotFired = true
            debugPrint("ShootEvent fired successfully")
        else
            debugPrint("ShootEvent error: " .. tostring(errorMsg))
        end
    else
        debugPrint("ShootEvent not found")
    end
    
    -- Tentativa 2: Evento direto na arma
    if not shotFired and currentGun then
        debugPrint("Looking for gun events...")
        for _, child in pairs(currentGun:GetChildren()) do
            if child:IsA("RemoteEvent") then
                debugPrint("Found RemoteEvent: " .. child.Name)
                if child.Name:find("Shoot") or child.Name:find("Fire") or child.Name == "ShootEvent" then
                    local success, err = pcall(function()
                        child:FireServer(shots)
                    end)
                    if success then
                        shotFired = true
                        debugPrint("Fired via " .. child.Name)
                        break
                    else
                        debugPrint("Error firing via " .. child.Name .. ": " .. tostring(err))
                    end
                end
            end
        end
    end
    
    -- Tentativa 3: Método alternativo
    if not shotFired then
        debugPrint("Trying alternative method...")
        -- Tenta encontrar qualquer RemoteFunction também
        for _, child in pairs(currentGun:GetChildren()) do
            if child:IsA("RemoteFunction") then
                debugPrint("Found RemoteFunction: " .. child.Name)
                if child.Name:find("Shoot") or child.Name:find("Fire") then
                    pcall(function()
                        child:InvokeServer(shots)
                        shotFired = true
                        debugPrint("Invoked via " .. child.Name)
                    end)
                end
            end
        end
    end

    if shotFired then
        debugPrint("SHOT FIRED SUCCESSFULLY!")
        
        -- Atualiza munição
        local newAmmo = ammo - 1
        currentGun:SetAttribute("Local_CurrentAmmo", newAmmo)
        debugPrint("New ammo: " .. tostring(newAmmo))
        
        -- Feedback
        if cfg.autoshootfeedback then
            spawn(function()
                if currentGun and currentGun:FindFirstChild("Handle") then
                    local handle = currentGun.Handle
                    local original = handle.Transparency
                    handle.Transparency = 0.5
                    wait(0.05)
                    handle.Transparency = original
                end
            end)
        end
    else
        debugPrint("FAILED TO FIRE SHOT")
        showDebugNotification()
    end

    debugPrint("=== AUTO SHOOT ENDED ===")
end

    -- Verifica munição
    local ammo = currentGun:GetAttribute("Local_CurrentAmmo") or currentGun:GetAttribute("CurrentAmmo") or 0
    if ammo <= 0 then 
        -- Recarga automática
        if cfg.autoreload then
            local reloadEvent = currentGun:FindFirstChild("Reload")
            if reloadEvent then
                reloadEvent:FireServer()
            end
        end
        return 
    end

    lastAutoShoot = now

    local isTaser = currentGun:GetAttribute("Projectile") == "Taser"
    local isShotgun = currentGun:GetAttribute("IsShotgun")
    local shouldHit = false

    if cfg.taseralwayshit and isTaser then
        shouldHit = true
    elseif cfg.ifplayerstill and isStanding(target) then
        shouldHit = true
    elseif cfg.hitchanceAutoOnly and isShotgun then
        shouldHit = true
    else
        shouldHit = rollHit()
    end

    -- CORREÇÃO: Se não deve acertar e não tem spread configurado, não atira
    if not shouldHit and cfg.missspread <= 0 then
        return
    end

    local projectileCount = currentGun:GetAttribute("ProjectileCount") or 1
    local shots = {}

    -- CORREÇÃO: Usa a posição do silent aim quando disponível
    for i = 1, projectileCount do
        local finalPos
        if shouldHit then
            if targetPos then
                finalPos = targetPos
            else
                finalPos = targetPart.Position
            end
        else
            if cfg.missspread > 0 then
                finalPos = getMissPos(targetPart.Position)
            else
                return
            end
        end
        shots[i] = {myHead.Position, finalPos, shouldHit and targetPart or nil}
        createBulletTrail(startPos, finalPos, isTaser)
    end

    -- CORREÇÃO: Múltiplas tentativas de disparo
    local shotFired = false
    
    -- Tentativa 1: ShootEvent principal
    if ShootEvent then
        local success, errorMsg = pcall(function()
            ShootEvent:FireServer(shots)
        end)
        
        if success then
            shotFired = true
        else
            warn("Erro no ShootEvent: " .. tostring(errorMsg))
        end
    end
    
    -- Tentativa 2: Evento direto na arma
    if not shotFired and currentGun then
        for _, child in pairs(currentGun:GetChildren()) do
            if child:IsA("RemoteEvent") and (child.Name:find("Shoot") or child.Name:find("Fire")) then
                pcall(function()
                    child:FireServer(shots)
                    shotFired = true
                end)
                if shotFired then break end
            end
        end
    end
    
    -- Tentativa 3: Simular clique (para mobile)
    if not shotFired then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            shotFired = true
        end)
    end

    if not shotFired then
        warn("Não foi possível disparar")
        return
    end

    -- Atualiza munição local
    local newAmmo = ammo - 1
    currentGun:SetAttribute("Local_CurrentAmmo", newAmmo)

    -- Atualiza interface
    if not cachedBulletsLabel then
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            local home = playerGui:FindFirstChild("Home")
            if home then
                local hud = home:FindFirstChild("hud")
                if hud then
                    local br = hud:FindFirstChild("BottomRightFrame")
                    if br then
                        local gf = br:FindFirstChild("GunFrame")
                        if gf then
                            cachedBulletsLabel = gf:FindFirstChild("BulletsLabel")
                        end
                    end
                end
            end
        end
    end

    if cachedBulletsLabel then
        cachedBulletsLabel.Text = newAmmo .. "/" .. (currentGun:GetAttribute("MaxAmmo") or 30)
    end

    -- Toca som
    local handle = currentGun:FindFirstChild("Handle")
    if handle then
        local shootSound = handle:FindFirstChild("ShootSound")
        if shootSound then
            local sound = shootSound:Clone()
            sound.Parent = handle
            sound:Play()
            Debris:AddItem(sound, 2)
        end
    end

    -- Feedback visual
    if cfg.autoshootfeedback then
        spawn(function()
            if currentGun and currentGun:FindFirstChild("Handle") then
                local handle = currentGun.Handle
                local original = handle.Transparency
                handle.Transparency = 0.5
                wait(0.05)
                handle.Transparency = original
            end
        end)
    end
end

makeVisuals()

local partMap = {
	["Torso"] = {"Torso", "UpperTorso", "LowerTorso"},
	["LeftArm"] = {"Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand"},
	["RightArm"] = {"Right Arm", "RightUpperArm", "RightLowerArm", "RightHand"},
	["LeftLeg"] = {"Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"},
	["RightLeg"] = {"Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot"}
}

local function getPart(char, name)
	if not char then return nil end
	local p = char:FindFirstChild(name)
	if p then return p end

	local maps = partMap[name]
	if maps then
		for _, n in ipairs(maps) do
			local part = char:FindFirstChild(n)
			if part then return part end
		end
	end
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
end

local function getTargetPart(char)
	if not char then return nil end

	if cfg.shieldbreaker then
		local shield = char:FindFirstChild("RiotShieldPart")
		if shield and shield:IsA("BasePart") then
			local hp = shield:GetAttribute("Health")
			if hp and hp > 0 then
				local myChar = LocalPlayer.Character
				local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
				local theirHrp = char:FindFirstChild("HumanoidRootPart")

				if myHrp and theirHrp then
					local toMe = (myHrp.Position - theirHrp.Position).Unit
					local theirLook = theirHrp.CFrame.LookVector
					local dot = toMe:Dot(theirLook)

					if dot > cfg.shieldfrontangle then
						if cfg.shieldrandomhead and rng:NextInteger(1, 100) <= cfg.shieldheadchance then
							return getPart(char, "Head")
						end
						return shield
					end
				end
			end
		end
	end

	local partName
	if cfg.randomparts then
		local list = cfg.partslist
		partName = (list and #list > 0) and list[rng:NextInteger(1, #list)] or "Head"
	else
		partName = cfg.aimpart
	end
	return getPart(char, partName)
end

local function isDead(player)
	if not player or not player.Character then return true end
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	return not humanoid or humanoid.Health <= 0
end

-- FUNÇÃO ADICIONADA: Verifica se player está parado
local function isStanding(player)
    if not player or not player.Character then return false end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local vel = hrp.AssemblyLinearVelocity
    return Vector2.new(vel.X, vel.Z).Magnitude <= cfg.stillthreshold
end

local function hasForceField(player)
	if not player or not player.Character then return false end
	return player.Character:FindFirstChildOfClass("ForceField") ~= nil
end

local function isInVehicle(player)
	if not player or not player.Character then return false end
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	return humanoid.SeatPart ~= nil
end

local function wallBetween(startPos, endPos, targetChar)
	local myChar = LocalPlayer.Character
	if not myChar then return true end

	local filter = {myChar}
	if targetChar then table.insert(filter, targetChar) end
	wallParams.FilterDescendantsInstances = filter

	local direction = endPos - startPos
	local distance = direction.Magnitude
	local unit = direction.Unit

	local currentStart = startPos
	local remaining = distance

	for _ = 1, 10 do
		local result = workspace:Raycast(currentStart, unit * remaining, wallParams)
		if not result then return false end

		local hit = result.Instance
		if hit.Transparency < 0.8 and hit.CanCollide then return true end

		local hitDist = (result.Position - currentStart).Magnitude
		remaining = remaining - hitDist - 0.01
		if remaining <= 0 then return false end

		currentStart = result.Position + unit * 0.01
	end
	return false
end

local function quickCheck(player)
	if not player or player == LocalPlayer or not player.Character then return false end
	if not getTargetPart(player.Character) then return false end
	if cfg.deathcheck and isDead(player) then return false end
	if cfg.ffcheck and hasForceField(player) then return false end
	if cfg.vehiclecheck and isInVehicle(player) then return false end
	if cfg.teamcheck and player.Team == LocalPlayer.Team then return false end
	if cfg.criminalsnoinnmates then
		if LocalPlayer.Team == criminalsTeam and player.Team == inmatesTeam then return false end
	end
	if cfg.inmatesnocriminals then
		if LocalPlayer.Team == inmatesTeam and player.Team == criminalsTeam then return false end
	end

	if cfg.hostilecheck or cfg.trespasscheck then
		local isTaser = currentGun and currentGun:GetAttribute("Projectile") == "Taser"
		local bypassHostile = cfg.taserbypasshostile and isTaser
		local bypassTrespass = cfg.taserbypasstrespass and isTaser
		local targetChar = player.Character

		if LocalPlayer.Team == guardsTeam and player.Team == inmatesTeam then
			local hostile = targetChar:GetAttribute("Hostile")
			local trespass = targetChar:GetAttribute("Trespassing")

			if cfg.hostilecheck and cfg.trespasscheck then
				if not bypassHostile and not bypassTrespass then
					if not hostile and not trespass then return false end
				end
			elseif cfg.hostilecheck and not bypassHostile then
				if not hostile then return false end
			elseif cfg.trespasscheck and not bypassTrespass then
				if not trespass then return false end
			end
		end
	end
	return true
end

local function fullCheck(player)
	if not quickCheck(player) then return false end

	if cfg.wallcheck then
		local myChar = LocalPlayer.Character
		local myHead = myChar and myChar:FindFirstChild("Head")
		local targetPart = getTargetPart(player.Character)
		if myHead and targetPart then
			if wallBetween(myHead.Position, targetPart.Position, player.Character) then
				return false
			end
		end
	end
	return true
end
-- FUNÇÃO ADICIONADA: Chance de acerto melhorada
local function rollHit()
    local now = os.clock()
    if now - lastShotTime > shotCooldown then
        lastShotTime = now
        local chance = cfg.hitchance
        if chance >= 100 then
            lastShotResult = true
        elseif chance <= 0 then
            lastShotResult = false
        else
            lastShotResult = math.random(1, 100) <= chance
        end
    end
    return lastShotResult
end

-- FUNÇÃO ADICIONADA: Posição de erro melhorada
local function getMissPos(targetPos)
    local spread = cfg.missspread or 5
    local angle = math.random() * math.pi * 2
    local d = math.random() * spread
    local yOffset = (math.random() - 0.5) * spread * 0.5
    return targetPos + Vector3.new(math.cos(angle) * d, yOffset, math.sin(angle) * d)
end

local function getClosest(fovRadius)
	fovRadius = fovRadius or cfg.fov
	local camera = workspace.CurrentCamera
	if not camera then return nil, nil end

	local lastInput = UserInputService:GetLastInputType()
	local locked = (lastInput == Enum.UserInputType.Touch) or (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter)

	local aimPos
	if locked then
		local viewportSize = camera.ViewportSize
		aimPos = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
	else
		aimPos = UserInputService:GetMouseLocation()
	end

	local now = os.clock()

	if cfg.targetstickiness and currentTarget and (now - targetSwitchTime) < currentStickiness then
		if fullCheck(currentTarget) then
			local part = getTargetPart(currentTarget.Character)
			if part then
				local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
				if onScreen and screenPos.Z > 0 then
					local dist = (Vector2.new(screenPos.X, screenPos.Y) - aimPos).Magnitude
					if dist < fovRadius then
						return currentTarget, part.Position
					end
				end
			end
		end
	end

	local candidates = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if quickCheck(player) then
			local part = getTargetPart(player.Character)
			if part then
				local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
				if onScreen and screenPos.Z > 0 then
					local dist = (Vector2.new(screenPos.X, screenPos.Y) - aimPos).Magnitude
					if dist < fovRadius then
						candidates[#candidates + 1] = {player = player, dist = dist, part = part}
					end
				end
			end
		end
	end

	if cfg.prioritizeclosest then
		table.sort(candidates, function(a, b) return a.dist < b.dist end)
	else
		for i = #candidates, 2, -1 do
			local j = rng:NextInteger(1, i)
			candidates[i], candidates[j] = candidates[j], candidates[i]
		end
	end

	for _, candidate in ipairs(candidates) do
		if fullCheck(candidate.player) then
			if candidate.player ~= currentTarget then
				currentTarget = candidate.player
				targetSwitchTime = now
				if cfg.targetstickinessrandom then
					currentStickiness = rng:NextNumber(cfg.targetstickinessmin, cfg.targetstickinessmax)
				else
					currentStickiness = cfg.targetstickinessduration
				end
			end
			return candidate.player, candidate.part.Position
		end
	end

	currentTarget = nil
	return nil, nil
end

local function getGun()
	local char = LocalPlayer.Character
	if not char then return nil end
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") and tool:GetAttribute("ToolType") == "Gun" then
			return tool
		end
	end
	return nil
end

local function notify(title, text, duration)
	StarterGui:SetCore("SendNotification", {
		Title = title,
		Text = text,
		Duration = duration or 3
	})
end

local lastGun = nil

RunService.Heartbeat:Connect(function()
	currentGun = getGun()
	if currentGun ~= lastGun then
		lastAutoShoot = 0
		lastGun = currentGun
	end
	
	-- CORREÇÃO: Executa auto shoot apenas se tiver arma
	if cfg.autoshoot and cfg.enabled and currentGun then
		autoShoot()
	end
end)

RunService.PreRender:Connect(function()
	local aimPos = UserInputService:GetMouseLocation()
	local camera = workspace.CurrentCamera

	if camera then
		local lastInput = UserInputService:GetLastInputType()
		local locked = (lastInput == Enum.UserInputType.Touch) or (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter)
		if locked then
			local viewportSize = camera.ViewportSize
			aimPos = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
		end
	end

	fovCircle.Position = aimPos
	fovCircle.Radius = cfg.fov
	fovCircle.Visible = cfg.showfov and cfg.enabled

	if cfg.showtargetline and cfg.enabled then
		local target, targetPos = getClosest()
		if target and targetPos and camera then
			local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
			if onScreen then
				targetLine.From = aimPos
				targetLine.To = Vector2.new(screenPos.X, screenPos.Y)
				targetLine.Visible = true
			else
				targetLine.Visible = false
			end
		else
			targetLine.Visible = false
		end
	else
		targetLine.Visible = false
	end

	updateEsp()
	updateC4Esp()
end)

Players.PlayerRemoving:Connect(removeEsp)

local function clearEsp()
	for player, e in pairs(espCache) do
		if e then e:Destroy() end
		espCache[player] = nil
	end
end

LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
	clearEsp()
end)

local function noUpvals(fn)
	return function(...) return fn(...) end
end

local origCastRay
local hooked = false

local function setupHook()
	local castRayFunc = filtergc("function", {Name = "castRay"}, true)
	if not castRayFunc then return false end

	origCastRay = hookfunction(castRayFunc, noUpvals(function(startPos, targetPos, ...)
		if not cfg.enabled then return origCastRay(startPos, targetPos, ...) end

		local closest, closestPos = getClosest(cfg.fov)

		if closest and closest.Character then
			local isTaser = currentGun and currentGun:GetAttribute("Projectile") == "Taser"
			local isShotgun = currentGun and currentGun:GetAttribute("IsShotgun")
			local shouldHit = false


      if cfg.shotgungamehandled and isShotgun then
				local targetPart = getTargetPart(closest.Character)
				if targetPart then
					return origCastRay(startPos, targetPart.Position, ...)
				end
				return origCastRay(startPos, targetPos, ...)
			end

			if cfg.taseralwayshit and isTaser then
				shouldHit = true
			elseif cfg.ifplayerstill and isStanding(closest) then
				shouldHit = true
			else
				shouldHit = rollHit()
			end

			if shouldHit then
				local targetPart = getTargetPart(closest.Character)
				if targetPart then
					if cfg.shotgunnaturalspread and isShotgun then
						return origCastRay(startPos, targetPart.Position, ...)
					end
					return targetPart, targetPart.Position
				end
			else
				if cfg.missspread > 0 then
					local targetPart = getTargetPart(closest.Character)
					if targetPart then
						local missPos = getMissPos(targetPart.Position)
						return origCastRay(startPos, missPos, ...)
					end
				end
				return origCastRay(startPos, targetPos, ...)
			end
		end

		return origCastRay(startPos, targetPos, ...)
	end))

	return true
end

if not setupHook() then
	task.spawn(function()
		while not hooked do
			task.wait(0.5)
			if setupHook() then
				hooked = true
			end
		end
	end)
else
	hooked = true
end

local MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()
local Folder = "Silent Aim"

local Window = MacLib:Window({
	Title = "Prison Life Silent Aim",
	Subtitle = "v1.1.0 - Auto Shoot Fix",
	Size = UDim2.fromOffset(800, 600),
	DragStyle = 1,
	DisabledWindowControls = {},
	ShowUserInfo = true,
	Keybind = Enum.KeyCode.RightAlt,
	AcrylicBlur = true,
})

MacLib:SetFolder(Folder)

local globalSettings = {
	UIBlurToggle = Window:GlobalSetting({
		Name = "UI Blur",
		Default = Window:GetAcrylicBlurState(),
		Callback = function(bool)
			Window:SetAcrylicBlurState(bool)
			Window:Notify({
				Title = Window.Settings.Title,
				Description = (bool and "Enabled" or "Disabled") .. " UI Blur",
				Lifetime = 5
			})
		end,
	}),

	NotificationToggler = Window:GlobalSetting({
		Name = "Notifications",
		Default = Window:GetNotificationsState(),
		Callback = function(bool)
			Window:SetNotificationsState(bool)
			Window:Notify({
				Title = Window.Settings.Title,
				Description = (bool and "Enabled" or "Disabled") .. " Notifications",
				Lifetime = 5
			})
		end,
	}),

	ShowUserInfo = Window:GlobalSetting({
		Name = "Show User Info",
		Default = Window:GetUserInfoState(),
		Callback = function(bool)
			Window:SetUserInfoState(bool)
			Window:Notify({
				Title = Window.Settings.Title,
				Description = (bool and "Showing" or "Redacted") .. " User Info",
				Lifetime = 5
			})
		end,
	})
}

local MainGroup = Window:TabGroup()

local AimbotTab = MainGroup:Tab({Name = "Aimbot", Image = "rbxassetid://4034483344"})
local ESPTab = MainGroup:Tab({Name = "ESP", Image = "rbxassetid://4034483345"})
local AutoshootTab = MainGroup:Tab({Name = "Autoshoot", Image = "rbxassetid://4034483346"})
local SettingsTab = MainGroup:Tab({Name = "Settings", Image = "rbxassetid://4034483347"})

local sections = {
	aimbotLeft = AimbotTab:Section({ Side = "Left" }),
	aimbotRight = AimbotTab:Section({ Side = "Right" }),
	espLeft = ESPTab:Section({ Side = "Left" }),
	espRight = ESPTab:Section({ Side = "Right" }),
	autoshootLeft = AutoshootTab:Section({ Side = "Left" }),
	autoshootRight = AutoshootTab:Section({ Side = "Right" }),
	settingsLeft = SettingsTab:Section({ Side = "Left" }),
	settingsRight = SettingsTab:Section({ Side = "Right" })
}

AimbotTab:Select()

Window:Notify({
Title = "Version",
	Description = string.format("Version %s loaded! Auto Shoot Fixed!", version),
	Lifetime = 5
})

local configFolder = "SilentAimConfigs"

local function serializeColor3(color)
	return {R = color.R, G = color.G, B = color.B}
end

local function deserializeColor3(tbl)
	if tbl and tbl.R and tbl.G and tbl.B then
		return Color3.new(tbl.R, tbl.G, tbl.B)
	end
	return Color3.new(1, 1, 1)
end

local function serializeConfig()
	local data = {}
	for key, value in pairs(cfg) do
		if typeof(value) == "Color3" then
			data[key] = {type = "Color3", value = serializeColor3(value)}
		elseif typeof(value) == "EnumItem" then
			data[key] = {type = "EnumItem", value = tostring(value)}
		elseif typeof(value) == "table" then
			data[key] = {type = "table", value = value}
		else
			data[key] = {type = typeof(value), value = value}
		end
	end
	return game:GetService("HttpService"):JSONEncode(data)
end

local function deserializeConfig(jsonString)
	local success, data = pcall(function()
		return game:GetService("HttpService"):JSONDecode(jsonString)
	end)
	if not success then return nil end
	
	local result = {}
	for key, entry in pairs(data) do
		if entry.type == "Color3" then
			result[key] = deserializeColor3(entry.value)
		elseif entry.type == "EnumItem" then
			local enumPath = entry.value:match("Enum%.(.+)")
			if enumPath then
				local parts = enumPath:split(".")
				if #parts == 2 then
					local enumType = Enum[parts[1]]
					if enumType then
						result[key] = enumType[parts[2]]
					end
				end
			end
		elseif entry.type == "table" then
			result[key] = entry.value
		else
			result[key] = entry.value
		end
	end
	return result
end

local function saveConfig(name)
	if not isfolder then return false end
	if not isfolder(configFolder) then
		makefolder(configFolder)
	end
	local path = configFolder .. "/" .. name .. ".json"
	local data = serializeConfig()
	writefile(path, data)
	return true
end

local function loadConfig(name)
	if not isfolder or not isfile then return false end
	local path = configFolder .. "/" .. name .. ".json"
	if not isfile(path) then return false end
	
	local data = readfile(path)
	local loaded = deserializeConfig(data)
	if not loaded then return false end
	
	for key, value in pairs(loaded) do
		if cfg[key] ~= nil then
			cfg[key] = value
		end
	end
	return true
end

local function getConfigList()
	if not isfolder or not listfiles then return {} end
	if not isfolder(configFolder) then return {} end
	
	local files = listfiles(configFolder)
	local configs = {}
	for _, path in ipairs(files) do
		local name = path:match("([^/\\]+)%.json$")
		if name then
			table.insert(configs, name)
		end
	end
	return configs
end

local function deleteConfig(name)
	if not isfolder or not isfile or not delfile then return false end
	local path = configFolder .. "/" .. name .. ".json"
	if isfile(path) then
		delfile(path)
		return true
	end
	return false
end

local uiElements = {}

local function refreshUI()
	for key, element in pairs(uiElements) do
		if element and element.UpdateState and cfg[key] ~= nil then
			element:UpdateState(cfg[key])
		elseif element and element.UpdateValue and cfg[key] ~= nil then
			element:UpdateValue(cfg[key])
		end
	end
	updateEsp()
	updateC4Esp()
end

uiElements.enabled = sections.aimbotLeft:Toggle({
	Name = "Silent Aim",
	Default = cfg.enabled,
	Callback = function(state)
		cfg.enabled = state
		fovCircle.Visible = cfg.showfov and cfg.enabled
	end,
}, "SilentAimToggle")

uiElements.teamcheck = sections.aimbotLeft:Toggle({
	Name = "Team Check",
	Default = cfg.teamcheck,
	Callback = function(state)
		cfg.teamcheck = state
	end,
}, "TeamCheckToggle")

uiElements.wallcheck = sections.aimbotLeft:Toggle({
	Name = "Wall Check",
	Default = cfg.wallcheck,
	Callback = function(state)
		cfg.wallcheck = state
	end,
}, "WallCheckToggle")

uiElements.deathcheck = sections.aimbotLeft:Toggle({
	Name = "Death Check",
	Default = cfg.deathcheck,
	Callback = function(state)
		cfg.deathcheck = state
	end,
}, "DeathCheckToggle")

uiElements.vehiclecheck = sections.aimbotLeft:Toggle({
	Name = "Vehicle Check",
	Default = cfg.vehiclecheck,
	Callback = function(state)
		cfg.vehiclecheck = state
	end,
}, "VehicleCheckToggle")

uiElements.hostilecheck = sections.aimbotLeft:Toggle({
	Name = "Hostile Check",
	Default = cfg.hostilecheck,
	Callback = function(state)
		cfg.hostilecheck = state
	end,
}, "HostileCheckToggle")

uiElements.trespasscheck = sections.aimbotLeft:Toggle({
	Name = "Trespass Check",
	Default = cfg.trespasscheck,
	Callback = function(state)
		cfg.trespasscheck = state
	end,
}, "TrespassCheckToggle")

uiElements.criminalsnoinnmates = sections.aimbotLeft:Toggle({
	Name = "Criminals Skip Inmates",
	Default = cfg.criminalsnoinnmates,
	Callback = function(state)
		cfg.criminalsnoinnmates = state
	end,
}, "CriminalsSkipInmatesToggle")

uiElements.inmatesnocriminals = sections.aimbotLeft:Toggle({
	Name = "Inmates Skip Criminals",
	Default = cfg.inmatesnocriminals,
	Callback = function(state)
		cfg.inmatesnocriminals = state
	end,
}, "InmatesSkipCriminalsToggle")

uiElements.ffcheck = sections.aimbotLeft:Toggle({
	Name = "ForceField Check",
	Default = cfg.ffcheck,
	Callback = function(state)
		cfg.ffcheck = state
	end,
}, "FFCheckToggle")

uiElements.shieldbreaker = sections.aimbotRight:Toggle({
	Name = "Shield Breaker",
	Default = cfg.shieldbreaker,
	Callback = function(state)
		cfg.shieldbreaker = state
	end,
}, "ShieldBreakerToggle")

uiElements.shieldfrontangle = sections.aimbotRight:Slider({
	Name = "Shield Front Angle",
	Default = cfg.shieldfrontangle,
	Minimum = -1,
	Maximum = 1,
	Precision = 2,
	Callback = function(value)
		cfg.shieldfrontangle = value
	end,
}, "ShieldFrontAngleSlider")

uiElements.shieldrandomhead = sections.aimbotRight:Toggle({
	Name = "Shield Random Head",
	Default = cfg.shieldrandomhead,
	Callback = function(state)
		cfg.shieldrandomhead = state
	end,
}, "ShieldRandomHeadToggle")

uiElements.shieldheadchance = sections.aimbotRight:Slider({
Name = "Shield Head Chance",
	Default = cfg.shieldheadchance,
	Minimum = 0,
	Maximum = 100,
	Callback = function(value)
		cfg.shieldheadchance = value
	end,
}, "ShieldHeadChanceSlider")

uiElements.taserbypasshostile = sections.aimbotRight:Toggle({
	Name = "Taser Bypass Hostile",
	Default = cfg.taserbypasshostile,
	Callback = function(state)
		cfg.taserbypasshostile = state
	end,
}, "TaserBypassHostileToggle")

uiElements.taserbypasstrespass = sections.aimbotRight:Toggle({
	Name = "Taser Bypass Trespass",
	Default = cfg.taserbypasstrespass,
	Callback = function(state)
		cfg.taserbypasstrespass = state
	end,
}, "TaserBypassTrespassToggle")

uiElements.taseralwayshit = sections.aimbotRight:Toggle({
	Name = "Taser Always Hit",
	Default = cfg.taseralwayshit,
	Callback = function(state)
		cfg.taseralwayshit = state
	end,
}, "TaserAlwaysHitToggle")

uiElements.ifplayerstill = sections.aimbotRight:Toggle({
	Name = "Hit If Player Still",
	Default = cfg.ifplayerstill,
	Callback = function(state)
		cfg.ifplayerstill = state
	end,
}, "HitIfPlayerStillToggle")

uiElements.stillthreshold = sections.aimbotRight:Slider({
	Name = "Still Threshold",
	Default = cfg.stillthreshold,
	Minimum = 0,
	Maximum = 5,
	Precision = 2,
	Callback = function(value)
		cfg.stillthreshold = value
	end,
}, "StillThresholdSlider")

uiElements.hitchance = sections.aimbotRight:Slider({
	Name = "Hit Chance",
	Default = cfg.hitchance,
	Minimum = 0,
	Maximum = 100,
	Callback = function(value)
		cfg.hitchance = value
	end,
}, "HitChanceSlider")

uiElements.hitchanceAutoOnly = sections.aimbotRight:Toggle({
	Name = "Hit Chance Auto Only",
	Default = cfg.hitchanceAutoOnly,
	Callback = function(state)
		cfg.hitchanceAutoOnly = state
	end,
}, "HitChanceAutoOnlyToggle")

uiElements.missspread = sections.aimbotRight:Slider({
	Name = "Miss Spread",
	Default = cfg.missspread,
	Minimum = 0,
	Maximum = 20,
	Precision = 1,
	Callback = function(value)
		cfg.missspread = value
	end,
}, "MissSpreadSlider")

uiElements.shotgunnaturalspread = sections.aimbotRight:Toggle({
	Name = "Shotgun Natural Spread",
	Default = cfg.shotgunnaturalspread,
	Callback = function(state)
		cfg.shotgunnaturalspread = state
	end,
}, "ShotgunNaturalSpreadToggle")

uiElements.shotgungamehandled = sections.aimbotRight:Toggle({
	Name = "Shotgun Game Handled",
	Default = cfg.shotgungamehandled,
	Callback = function(state)
		cfg.shotgungamehandled = state
	end,
}, "ShotgunGameHandledToggle")

uiElements.prioritizeclosest = sections.aimbotRight:Toggle({
	Name = "Prioritize Closest",
	Default = cfg.prioritizeclosest,
	Callback = function(state)
		cfg.prioritizeclosest = state
	end,
}, "PrioritizeClosestToggle")

uiElements.targetstickiness = sections.aimbotRight:Toggle({
	Name = "Target Stickiness",
	Default = cfg.targetstickiness,
	Callback = function(state)
		cfg.targetstickiness = state
	end,
}, "TargetStickinessToggle")

uiElements.targetstickinessduration = sections.aimbotRight:Slider({
	Name = "Stickiness Duration",
	Default = cfg.targetstickinessduration,
	Minimum = 0.1,
	Maximum = 2,
	Precision = 2,
	Callback = function(value)
		cfg.targetstickinessduration = value
	end,
}, "StickinessDurationSlider")

uiElements.targetstickinessrandom = sections.aimbotRight:Toggle({
	Name = "Target Stickiness Random",
	Default = cfg.targetstickinessrandom,
	Callback = function(state)
		cfg.targetstickinessrandom = state
	end,
}, "TargetStickinessRandomToggle")

uiElements.targetstickinessmin = sections.aimbotRight:Slider({
	Name = "Target Stickiness Min",
	Default = cfg.targetstickinessmin,
	Minimum = 0.1,
	Maximum = 1,
	Precision = 2,
	Callback = function(value)
		cfg.targetstickinessmin = value
	end,
}, "TargetStickinessMinSlider")

uiElements.targetstickinessmax = sections.aimbotRight:Slider({
	Name = "Target Stickiness Max",
	Default = cfg.targetstickinessmax,
	Minimum = 0.1,
	Maximum = 1,
	Precision = 2,
	Callback = function(value)
		cfg.targetstickinessmax = value
	end,
}, "TargetStickinessMaxSlider")

uiElements.fov = sections.aimbotRight:Slider({
	Name = "FOV",
	Default = cfg.fov,
	Minimum = 10,
	Maximum = 500,
	Callback = function(value)
		cfg.fov = value
		fovCircle.Radius = cfg.fov
	end,
}, "FovSlider")

uiElements.showfov = sections.aimbotRight:Toggle({
	Name = "Show FOV",
	Default = cfg.showfov,
	Callback = function(state)
		cfg.showfov = state
		fovCircle.Visible = cfg.showfov and cfg.enabled
	end,
}, "ShowFovToggle")

uiElements.showtargetline = sections.aimbotRight:Toggle({
	Name = "Show Target Line",
	Default = cfg.showtargetline,
	Callback = function(state)
		cfg.showtargetline = state
	end,
}, "ShowTargetLineToggle")

sections.aimbotRight:Dropdown({
	Name = "Aim Part",
	Default = cfg.aimpart,
	Options = cfg.partslist,
	Callback = function(value)
		cfg.aimpart = value
	end,
}, "AimPartDropdown")

uiElements.randomparts = sections.aimbotRight:Toggle({
	Name = "Random Parts",
	Default = cfg.randomparts,
	Callback = function(state)
		cfg.randomparts = state
	end,
}, "RandomPartsToggle")

uiElements.esp = sections.espLeft:Toggle({
	Name = "ESP",
	Default = cfg.esp,
	Callback = function(state)
		cfg.esp = state
		updateEsp()
	end,
}, "EspToggle")

uiElements.espteamcheck = sections.espLeft:Toggle({
	Name = "ESP Team Check",
	Default = cfg.espteamcheck,
	Callback = function(state)
		cfg.espteamcheck = state
		updateEsp()
	end,
}, "EspTeamCheckToggle")

uiElements.espshowteam = sections.espLeft:Toggle({
	Name = "Show Team",
	Default = cfg.espshowteam,
	Callback = function(state)
		cfg.espshowteam = state
		updateEsp()
	end,
}, "ShowTeamToggle")

uiElements.espmaxdist = sections.espLeft:Slider({
	Name = "ESP Max Distance",
	Default = cfg.espmaxdist,
	Minimum = 50,
	Maximum = 1000,
	Callback = function(value)
		cfg.espmaxdist = value
		updateEsp()
	end,
}, "EspMaxDistanceSlider")

uiElements.espshowdist = sections.espLeft:Toggle({
	Name = "Show Distance",
	Default = cfg.espshowdist,
	Callback = function(state)
		cfg.espshowdist = state
		updateEsp()
	end,
}, "ShowDistanceToggle")

uiElements.espuseteamcolors = sections.espLeft:Toggle({
	Name = "Use Team Colors",
	Default = cfg.espuseteamcolors,
	Callback = function(state)
		cfg.espuseteamcolors = state
		updateEsp()
	end,
}, "UseTeamColorsToggle")

sections.espLeft:Colorpicker({
	Name = "ESP Color",
	Default = cfg.espcolor,
	Callback = function(color)
		cfg.espcolor = color
		updateEsp()
	end,
}, "EspColorPicker")

sections.espLeft:Colorpicker({
	Name = "Guards Color",
	Default = cfg.espguards,
	Callback = function(color)
		cfg.espguards = color
		updateEsp()
	end,
}, "GuardsColorPicker")

sections.espLeft:Colorpicker({
Name = "Inmates Color",
	Default = cfg.espinmates,
	Callback = function(color)
		cfg.espinmates = color
		updateEsp()
	end,
}, "InmatesColorPicker")

sections.espLeft:Colorpicker({
	Name = "Criminals Color",
	Default = cfg.espcriminals,
	Callback = function(color)
		cfg.espcriminals = color
		updateEsp()
	end,
}, "CriminalsColorPicker")

sections.espLeft:Colorpicker({
	Name = "Team Color",
	Default = cfg.espteam,
	Callback = function(color)
		cfg.espteam = color
		updateEsp()
	end,
}, "TeamColorPicker")

uiElements.c4esp = sections.espRight:Toggle({
	Name = "C4 ESP",
	Default = cfg.c4esp,
	Callback = function(state)
		cfg.c4esp = state
		updateC4Esp()
	end,
}, "C4EspToggle")

uiElements.c4espmaxdist = sections.espRight:Slider({
	Name = "C4 ESP Max Distance",
	Default = cfg.c4espmaxdist,
	Minimum = 50,
	Maximum = 500,
	Callback = function(value)
		cfg.c4espmaxdist = value
		updateC4Esp()
	end,
}, "C4EspMaxDistanceSlider")

uiElements.c4espshowdist = sections.espRight:Toggle({
	Name = "C4 Show Distance",
	Default = cfg.c4espshowdist,
	Callback = function(state)
		cfg.c4espshowdist = state
		updateC4Esp()
	end,
}, "C4ShowDistanceToggle")

sections.espRight:Colorpicker({
	Name = "C4 ESP Color",
	Default = cfg.c4espcolor,
	Callback = function(color)
		cfg.c4espcolor = color
		updateC4Esp()
	end,
}, "C4EspColorPicker")

-- NOVAS CONFIGURAÇÕES DE AUTO SHOOT
uiElements.autoshoot = sections.autoshootLeft:Toggle({
	Name = "Autoshoot",
	Default = cfg.autoshoot,
	Callback = function(state)
		cfg.autoshoot = state
	end,
}, "AutoshootToggle")

uiElements.autoshootdelay = sections.autoshootLeft:Slider({
	Name = "Autoshoot Delay",
	Default = cfg.autoshootdelay,
	Minimum = 0.05,
	Maximum = 0.5,
	Precision = 2,
	Callback = function(value)
		cfg.autoshootdelay = value
	end,
}, "AutoshootDelaySlider")

uiElements.autoshootstartdelay = sections.autoshootLeft:Slider({
	Name = "Autoshoot Start Delay",
	Default = cfg.autoshootstartdelay,
	Minimum = 0,
	Maximum = 1,
	Precision = 2,
	Callback = function(value)
		cfg.autoshootstartdelay = value
	end,
}, "AutoshootStartDelaySlider")

uiElements.autoshootfeedback = sections.autoshootLeft:Toggle({
	Name = "Autoshoot Feedback",
	Default = cfg.autoshootfeedback,
	Callback = function(state)
		cfg.autoshootfeedback = state
	end,
}, "AutoshootFeedbackToggle")

uiElements.autoreload = sections.autoshootLeft:Toggle({
	Name = "Auto Reload",
	Default = cfg.autoreload,
	Callback = function(state)
		cfg.autoreload = state
	end,
}, "AutoReloadToggle")

sections.autoshootRight:Label({Text = "Auto Shoot Debug:"})

sections.autoshootRight:Button({
	Name = "Test Auto Shoot",
	Callback = function()
		local oldValue = cfg.autoshoot
		cfg.autoshoot = true
		autoShoot()
		cfg.autoshoot = oldValue
		Window:Notify({
			Title = "Test",
			Description = "Auto shoot testado!",
			Lifetime = 3
		})
	end,
})

sections.autoshootRight:Button({
	Name = "Check Current Gun",
	Callback = function()
		local gun = getGun()
		if gun then
			Window:Notify({
				Title = "Current Gun",
				Description = "Nome: " .. gun.Name .. "\nMunição: " .. (gun:GetAttribute("CurrentAmmo") or "N/A"),
				Lifetime = 5
			})
		else
			Window:Notify({
				Title = "Current Gun",
				Description = "Nenhuma arma equipada!",
				Lifetime = 3
			})
		end
	end,
})

local configNameInput = ""

sections.settingsLeft:Input({
	Name = "Config Name",
	Placeholder = "Enter config name...",
	Callback = function(text)
		configNameInput = text
	end,
}, "ConfigNameInput")

sections.settingsLeft:Button({
	Name = "Save Config",
	Callback = function()
		if configNameInput == "" then
			Window:Notify({
				Title = "Config",
				Description = "Please enter a config name!",
				Lifetime = 3
			})
			return
		end
		if saveConfig(configNameInput) then
			Window:Notify({
				Title = "Config",
				Description = "Saved config: " .. configNameInput,
				Lifetime = 3
			})
		else
			Window:Notify({
				Title = "Config",
				Description = "Failed to save config!",
				Lifetime = 3
			})
		end
	end,
})

sections.settingsLeft:Button({
	Name = "Load Config",
	Callback = function()
		if configNameInput == "" then
			Window:Notify({
				Title = "Config",
				Description = "Please enter a config name!",
				Lifetime = 3
			})
			return
		end
		if loadConfig(configNameInput) then
			refreshUI()
			Window:Notify({
				Title = "Config",
				Description = "Loaded config: " .. configNameInput,
				Lifetime = 3
			})
		else
			Window:Notify({
				Title = "Config",
				Description = "Config not found: " .. configNameInput,
				Lifetime = 3
			})
		end
	end,
})

sections.settingsLeft:Button({
	Name = "Delete Config",
	Callback = function()
		if configNameInput == "" then
			Window:Notify({
				Title = "Config",
				Description = "Please enter a config name!",
				Lifetime = 3
			})
			return
		end
		if deleteConfig(configNameInput) then
			Window:Notify({
				Title = "Config",
				Description = "Deleted config: " .. configNameInput,
				Lifetime = 3
			})
		else
			Window:Notify({
				Title = "Config",
				Description = "Config not found: " .. configNameInput,
				Lifetime = 3
			})
		end
	end,
})

sections.settingsLeft:Button({
	Name = "List Configs",
	Callback = function()
		local configs = getConfigList()
		if #configs == 0 then
			Window:Notify({
				Title = "Configs",
				Description = "No configs found!",
				Lifetime = 5
			})
		else
			Window:Notify({
				Title = "Configs",
				Description = table.concat(configs, ", "),
				Lifetime = 10
			})
		end
	end,
})

sections.settingsRight:Button({
	Name = "Reset to Defaults",
	Callback = function()
		cfg.enabled = true
		cfg.teamcheck = false
		cfg.wallcheck = false
		cfg.deathcheck = false
		cfg.ffcheck = false
		cfg.hostilecheck = false
		cfg.trespasscheck = false
		cfg.vehiclecheck = false
		cfg.criminalsnoinnmates = false
		cfg.inmatesnocriminals = false
		cfg.shieldbreaker = false
		cfg.shieldrandomhead = false
		cfg.taserbypasshostile = false
		cfg.taserbypasstrespass = false
		cfg.taseralwayshit = false
		cfg.ifplayerstill = false
		cfg.hitchance = 100
		cfg.shotgunnaturalspread = false
		cfg.prioritizeclosest = false
		cfg.esp = false
		cfg.c4esp = false
		cfg.autoshoot = true
		cfg.autoshootdelay = 0.12
		cfg.autoshootstartdelay = 0.2
		cfg.autoshootfeedback = true
		cfg.autoreload = true
		refreshUI()
		Window:Notify({
			Title = "Config",
			Description = "Reset to defaults!",
			Lifetime = 3
		})
	end,
})

-- Atalhos de teclado
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == cfg.togglekey then
		cfg.enabled = not cfg.enabled
		fovCircle.Visible = cfg.showfov and cfg.enabled
		Window:Notify({
			Title = "Silent Aim",
			Description = cfg.enabled and "ENABLED" or "DISABLED",
			Lifetime = 2
		})
	end
	
	if input.KeyCode == cfg.esptoggle then
		cfg.esp = not cfg.esp
		updateEsp()
		Window:Notify({
			Title = "ESP",
			Description = cfg.esp and "ENABLED" or "DISABLED",
			Lifetime = 2
		})
	end
	
	if input.KeyCode == cfg.c4esptoggle then
		cfg.c4esp = not cfg.c4esp
		updateC4Esp()
		Window:Notify({
			Title = "C4 ESP",
			Description = cfg.c4esp and "ENABLED" or "DISABLED",
			Lifetime = 2
		})
	end
end)

-- Notificação inicial
Window:Notify({
	Title = "Auto Shoot Fix",
	Description = "Versão 1.1.0 carregada!\nAuto Shoot agora funciona com Silent Aim.",
	Lifetime = 6
})

print("=== Silent Aim v" .. version .. " loaded ===")
print("Auto Shoot Status: " .. (cfg.autoshoot and "ENABLED" or "DISABLED"))
print("Targeting Mode: " .. (cfg.prioritizeclosest and "Closest to Cursor" or "Random in FOV"))
print("FOV Size: " .. cfg.fov)

