-- Berg | BSS Auto Farm
-- Custom script build by Berg
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

math.randomseed(tick())

local LocalPlayer = Players.LocalPlayer

local FIELDS = {
    "Sunflower Field", "Dandelion Field", "Mushroom Field", "Blue Flower Field", "Clover Field",
    "Spider Field", "Strawberry Field", "Bamboo Field", "Pineapple Patch", "Pumpkin Patch",
    "Cactus Field", "Rose Field", "Pine Tree Forest", "Stump Field", "Coconut Field",
    "Mountain Top Field", "Pepper Patch",
}

local TOYS = {
    { key = "HoneyDispenser", label = "Honey Dispenser", aliases = { "honeydispenser", "honey dispenser" } },
    { key = "BlueberryDispenser", label = "Blueberry Dispenser", aliases = { "blueberrydispenser", "blueberry dispenser" } },
    { key = "StrawberryDispenser", label = "Strawberry Dispenser", aliases = { "strawberrydispenser", "strawberry dispenser" } },
    { key = "TreatDispenser", label = "Treat Dispenser", aliases = { "treatdispenser", "treat dispenser" } },
    { key = "RoyalJellyDispenser", label = "Royal Jelly Dispenser", aliases = { "royaljellydispenser", "royal jelly dispenser" } },
    { key = "GlueDispenser", label = "Glue Dispenser", aliases = { "gluedispenser", "glue dispenser" } },
    { key = "CoconutDispenser", label = "Coconut Dispenser", aliases = { "coconutdispenser", "coconut dispenser" } },
    { key = "WealthClock", label = "Wealth Clock", aliases = { "wealthclock", "wealth clock" } },
    { key = "BlueBooster", label = "Blue Field Booster", aliases = { "bluefieldbooster", "blue field booster", "blue booster" } },
    { key = "RedBooster", label = "Red Field Booster", aliases = { "redfieldbooster", "red field booster", "red booster" } },
    { key = "MountainBooster", label = "Mountain Top Booster", aliases = { "mountaintopfieldbooster", "mountain top booster", "mountain booster" } },
}

local TOY_NAMES = {}
for _, toy in ipairs(TOYS) do
    table.insert(TOY_NAMES, toy.label)
end

local DEFAULT = {
    AutoFarm = false,
    FieldName = "Sunflower Field",
    ReturnToHive = true,
    HiveBagPercent = 95,
    HiveWaitSeconds = 15,

    CollectAllTokens = true,
    TokenHoney = true,
    TokenPollen = true,
    TokenBoost = true,
    TokenAbility = true,
    TokenTicket = true,
    TokenTreat = true,
    TokenPrecise = true,
    TokenMarks = true,
    TokenPopStar = true,
    TokenLink = true,
    TokenBomb = true,
    TokenBubble = true,
    TokenFlame = true,

    PlayerSpeed = 70,
    TweenSpeed = 80,
    TweenSoftness = 70,

    AutoUseToys = false,
    ToyLoopDelay = 120,
    ToyTweenToTarget = true,
    SelectedToy = TOY_NAMES[1],

    AntiLagEnabled = false,
    AntiLagParticles = true,
    AntiLagTextures = true,
    AntiLagShadows = true,
    AntiLagLighting = true,
    AntiLagRefreshSeconds = 4,

    ConfigAutoSave = true,
    ConfigAutoSaveDelay = 20,
    ConfigAutoLoad = true,
    ConfigSaveBackup = true,
    ConfigOnlyIfChanged = true,
    ConfigProfile = "main",

    NoSafeMode = true,
}

local Settings = getgenv().BergBSSSettings or {}
for k, v in pairs(DEFAULT) do
    if Settings[k] == nil then
        Settings[k] = v
    end
end
for _, toy in ipairs(TOYS) do
    local key = "Toy_" .. toy.key
    if Settings[key] == nil then
        Settings[key] = false
    end
end
getgenv().BergBSSSettings = Settings

local UITheme = {
    SchemeColor = Color3.fromRGB(166, 73, 255),
    Background = Color3.fromRGB(8, 8, 8),
    Header = Color3.fromRGB(0, 0, 0),
    TextColor = Color3.fromRGB(235, 235, 235),
    ElementColor = Color3.fromRGB(0, 0, 0),
}

local TOKEN_PATTERNS = {
    Honey = { "honey" },
    Pollen = { "pollen" },
    Boost = { "boost", "focus", "haste", "melody" },
    Ability = { "ability", "token", "rage", "stinger" },
    Ticket = { "ticket" },
    Treat = { "treat" },
    Precise = { "precise", "precision" },
    Marks = { "mark", "target" },
    PopStar = { "popstar", "pop star", "guiding star", "starsaw", "star saw", "star" },
    Link = { "link" },
    Bomb = { "bomb" },
    Bubble = { "bubble" },
    Flame = { "flame" },
}

local EFFECT_CLASSES = {
    ParticleEmitter = true,
    Trail = true,
    Beam = true,
    Smoke = true,
    Fire = true,
    Sparkles = true,
}

local HIVE_PART_HINTS = { "spawn", "platform", "pad", "circle", "base", "convert", "hive" }
local CONFIG_FOLDER_NAME = "BergConfigs"
local CONFIG_FILE_BASENAME = tostring(LocalPlayer.UserId) .. "_" .. tostring(game.PlaceId)
local CONFIG_LEGACY_PATH = CONFIG_FOLDER_NAME .. "/" .. CONFIG_FILE_BASENAME .. ".json"
local CONFIG_META_PATH = CONFIG_FOLDER_NAME .. "/meta_" .. CONFIG_FILE_BASENAME .. ".json"
local FIELD_FALLBACK_SIZE = Vector3.new(72, 20, 72)
local SAFE_HIVE_ACTION_INTERVAL = 0.45
local AGGRESSIVE_HIVE_ACTION_INTERVAL = 0.06

local currentTween = nil
local farmLoopRunning = false
local toyLoopRunning = false
local antiLagLoopRunning = false

local fieldCache = {}
local toyCache = {}
local toyUseTracker = {}
local antiLagBackups = setmetatable({}, { __mode = "k" })
local convertRemoteCache = nil
local configWriteCache = {}
local VirtualInputManager = nil
local VirtualUser = nil
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)
pcall(function()
    VirtualUser = game:GetService("VirtualUser")
end)

local function normalizeText(value)
    local s = string.lower(tostring(value or ""))
    s = s:gsub("[%s_%-%.%[%]%(%)]+", "")
    s = s:gsub("[^%w]", "")
    return s
end

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getRootAndHumanoid()
    local character = getCharacter()
    if not character then
        return nil, nil
    end
    return character:FindFirstChild("HumanoidRootPart"), character:FindFirstChildOfClass("Humanoid")
end

local function getPart(instance)
    if not instance then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance
    end
    if instance:IsA("Model") then
        return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")
    end
    if instance:IsA("Attachment") and instance.Parent and instance.Parent:IsA("BasePart") then
        return instance.Parent
    end
    return nil
end

local function getCFrame(instance)
    local part = getPart(instance)
    if part then
        return part.CFrame
    end
    return nil
end

local function applyWalkSpeed()
    local _, humanoid = getRootAndHumanoid()
    if humanoid then
        humanoid.WalkSpeed = math.clamp(Settings.PlayerSpeed, 40, 120)
    end
end

local function stopTween()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
end

local function stopWalk()
    local root, humanoid = getRootAndHumanoid()
    if root and humanoid then
        humanoid:MoveTo(root.Position)
    end
end

local function stopMovement()
    stopTween()
    stopWalk()
end

local function walkTo(targetPos, stopDistance, timeout, cancelFn)
    local root, humanoid = getRootAndHumanoid()
    if not root or not humanoid then
        return false
    end

    stopDistance = stopDistance or 5
    timeout = timeout or 3

    local timeoutAt = os.clock() + timeout
    local lastMove = 0
    while os.clock() < timeoutAt do
        if cancelFn and cancelFn() then
            return false
        end

        if os.clock() - lastMove >= 0.7 then
            humanoid:MoveTo(targetPos)
            lastMove = os.clock()
        end

        if (root.Position - targetPos).Magnitude <= stopDistance then
            return true
        end
        task.wait(0.05)
    end

    return false
end

local function getActiveTweenSpeed()
    return math.clamp(Settings.TweenSpeed, 40, 120)
end

local function tweenTo(targetCFrame, speed)
    local root = select(1, getRootAndHumanoid())
    if not root then
        return
    end

    local targetPos = targetCFrame.Position
    local dist = (root.Position - targetPos).Magnitude
    local tweenSpeed = math.clamp(speed, 40, 120)
    local softness = math.clamp(tonumber(Settings.TweenSoftness) or 70, 0, 100)
    local duration = (dist / tweenSpeed) * (1 + softness / 180)
    duration = math.clamp(duration, 0.08, 10)
    local rotationOnly = root.CFrame - root.Position
    local tweenGoal = CFrame.new(targetPos) * rotationOnly

    if duration <= 0.06 then
        root.CFrame = tweenGoal
        return
    end

    stopTween()
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    local tween = TweenService:Create(root, tweenInfo, { CFrame = tweenGoal })
    currentTween = tween
    tween:Play()
    tween.Completed:Wait()
    if currentTween == tween then
        currentTween = nil
    end
end

local function findFieldInstance(fieldName)
    local cached = fieldCache[fieldName]
    if cached and cached.Parent then
        return cached
    end

    for _, containerName in ipairs({ "FlowerZones", "Flowers", "Fields" }) do
        local container = workspace:FindFirstChild(containerName)
        if container then
            for _, item in ipairs(container:GetDescendants()) do
                if item.Name == fieldName then
                    fieldCache[fieldName] = item
                    return item
                end
            end
        end
    end

    local fallback = workspace:FindFirstChild(fieldName, true)
    if fallback then
        fieldCache[fieldName] = fallback
        return fallback
    end

    return nil
end

local function getFieldData(fieldName)
    local instance = findFieldInstance(fieldName)
    if not instance then
        return nil, nil
    end

    local part = getPart(instance)
    if part then
        return part.CFrame, part.Size
    end

    local cf = getCFrame(instance)
    if cf then
        return cf, FIELD_FALLBACK_SIZE
    end

    return nil, nil
end

local function getFieldCFrame(fieldName)
    local cf = getFieldData(fieldName)
    return cf
end

local function isPositionInsideField(position, fieldName, margin)
    local fieldCFrame, fieldSize = getFieldData(fieldName)
    if not fieldCFrame or not fieldSize then
        return false
    end

    margin = margin or 4
    local localPos = fieldCFrame:PointToObjectSpace(position)
    local halfX = (fieldSize.X * 0.5) + margin
    local halfZ = (fieldSize.Z * 0.5) + margin
    return math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ
end

local function getRandomPointInField(fieldName)
    local fieldCFrame, fieldSize = getFieldData(fieldName)
    if not fieldCFrame or not fieldSize then
        return nil
    end

    local xRadius = math.max(4, math.floor((fieldSize.X * 0.5) - 4))
    local zRadius = math.max(4, math.floor((fieldSize.Z * 0.5) - 4))
    local x = math.random(-xRadius, xRadius)
    local z = math.random(-zRadius, zRadius)
    local point = (fieldCFrame * CFrame.new(x, 0, z)).Position

    local root = select(1, getRootAndHumanoid())
    if root then
        point = Vector3.new(point.X, root.Position.Y, point.Z)
    end
    return point
end

local function getCollectiblesFolder()
    return workspace:FindFirstChild("Collectibles")
        or workspace:FindFirstChild("Particles")
        or workspace:FindFirstChild("Tokens")
end

local function tokenMatches(tokenName, patterns)
    local normalizedName = normalizeText(tokenName)
    for _, pattern in ipairs(patterns) do
        local normalizedPattern = normalizeText(pattern)
        if normalizedPattern ~= "" and string.find(normalizedName, normalizedPattern, 1, true) then
            return true
        end
    end
    return false
end

local function isTokenAllowed(tokenName)
    if Settings.CollectAllTokens then
        return true
    end

    if Settings.TokenHoney and tokenMatches(tokenName, TOKEN_PATTERNS.Honey) then return true end
    if Settings.TokenPollen and tokenMatches(tokenName, TOKEN_PATTERNS.Pollen) then return true end
    if Settings.TokenBoost and tokenMatches(tokenName, TOKEN_PATTERNS.Boost) then return true end
    if Settings.TokenAbility and tokenMatches(tokenName, TOKEN_PATTERNS.Ability) then return true end
    if Settings.TokenTicket and tokenMatches(tokenName, TOKEN_PATTERNS.Ticket) then return true end
    if Settings.TokenTreat and tokenMatches(tokenName, TOKEN_PATTERNS.Treat) then return true end
    if Settings.TokenPrecise and tokenMatches(tokenName, TOKEN_PATTERNS.Precise) then return true end
    if Settings.TokenMarks and tokenMatches(tokenName, TOKEN_PATTERNS.Marks) then return true end
    if Settings.TokenPopStar and tokenMatches(tokenName, TOKEN_PATTERNS.PopStar) then return true end
    if Settings.TokenLink and tokenMatches(tokenName, TOKEN_PATTERNS.Link) then return true end
    if Settings.TokenBomb and tokenMatches(tokenName, TOKEN_PATTERNS.Bomb) then return true end
    if Settings.TokenBubble and tokenMatches(tokenName, TOKEN_PATTERNS.Bubble) then return true end
    if Settings.TokenFlame and tokenMatches(tokenName, TOKEN_PATTERNS.Flame) then return true end

    return false
end

local function getTokenPos(token)
    if token:IsA("BasePart") then
        return token.Position
    end
    if token:IsA("Model") then
        local part = token.PrimaryPart or token:FindFirstChildWhichIsA("BasePart")
        if part then
            return part.Position
        end
    end
    if token:IsA("Attachment") and token.Parent and token.Parent:IsA("BasePart") then
        return token.Parent.Position
    end
    return nil
end

local function getNearestTokenInField(fieldName)
    local root = select(1, getRootAndHumanoid())
    if not root then
        return nil
    end

    local collectibles = getCollectiblesFolder()
    if not collectibles then
        return nil
    end

    local bestPos, bestDist = nil, math.huge
    for _, item in ipairs(collectibles:GetDescendants()) do
        local valid = item:IsA("BasePart") or item:IsA("Model") or item:IsA("Attachment")
        if valid and isTokenAllowed(item.Name) then
            local pos = getTokenPos(item)
            if pos and isPositionInsideField(pos, fieldName, 5) then
                local dist = (root.Position - pos).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestPos = pos
                end
            end
        end
    end

    return bestPos
end

local function getBagPercent()
    local stats = LocalPlayer:FindFirstChild("CoreStats")
    if not stats then
        return 0
    end

    local pollen = stats:FindFirstChild("Pollen")
    local capacity = stats:FindFirstChild("Capacity")
    if pollen and capacity and capacity.Value > 0 then
        return (pollen.Value / capacity.Value) * 100
    end

    return 0
end

local function getHiveCenterFromInstance(instance)
    if not instance then
        return nil
    end

    if instance:IsA("Model") then
        local bestPart, bestScore = nil, -math.huge
        for _, desc in ipairs(instance:GetDescendants()) do
            if desc:IsA("BasePart") then
                local score = (desc.Size.X * desc.Size.Z) * 0.02
                if desc.Size.Y <= 8 then
                    score = score + 5
                else
                    score = score - 4
                end

                local normalizedName = normalizeText(desc.Name)
                for _, hint in ipairs(HIVE_PART_HINTS) do
                    if string.find(normalizedName, hint, 1, true) then
                        score = score + 10
                    end
                end

                if desc.Transparency > 0.85 then
                    score = score - 1
                end

                if score > bestScore then
                    bestScore = score
                    bestPart = desc
                end
            end
        end

        if bestPart then
            return CFrame.new(bestPart.Position + Vector3.new(0, 3, 0))
        end
    end

    local part = getPart(instance)
    if part then
        return CFrame.new(part.Position + Vector3.new(0, 3, 0))
    end

    return nil
end

local function getHiveConvertTargets(hiveCFrame)
    local p = hiveCFrame.Position
    return {
        p,
        p + Vector3.new(2.6, 0, 0),
        p + Vector3.new(-2.6, 0, 0),
        p + Vector3.new(0, 0, 2.6),
        p + Vector3.new(0, 0, -2.6),
        p + Vector3.new(2, 0, 2),
        p + Vector3.new(-2, 0, -2),
    }
end

local function getSpawnPadCFrame()
    local spawnPosRef = LocalPlayer:FindFirstChild("SpawnPos")
    if spawnPosRef and spawnPosRef:IsA("ObjectValue") and spawnPosRef.Value then
        local part = getPart(spawnPosRef.Value)
        if part then
            return CFrame.new(part.Position + Vector3.new(0, 2.4, 0))
        end
        local cf = getCFrame(spawnPosRef.Value)
        if cf then
            return CFrame.new(cf.Position + Vector3.new(0, 2.4, 0))
        end
    end
    return nil
end

local function getHiveCFrame()
    local spawnPosRef = LocalPlayer:FindFirstChild("SpawnPos")
    if spawnPosRef and spawnPosRef:IsA("ObjectValue") and spawnPosRef.Value then
        local spawnCenter = getHiveCenterFromInstance(spawnPosRef.Value)
        if spawnCenter then
            return spawnCenter
        end
    end

    for _, refName in ipairs({ "Hive", "HiveModel", "HivePart", "Honeycomb", "HiveBase" }) do
        local ref = LocalPlayer:FindFirstChild(refName)
        if ref and ref:IsA("ObjectValue") and ref.Value then
            local hiveCenter = getHiveCenterFromInstance(ref.Value)
            if hiveCenter then
                return hiveCenter
            end
        end
    end

    local hives = workspace:FindFirstChild("Honeycombs") or workspace:FindFirstChild("Hives")
    if not hives then
        return nil
    end

    local playerName = string.lower(LocalPlayer.Name)

    for _, obj in ipairs(hives:GetDescendants()) do
        if obj:IsA("StringValue") then
            local name = string.lower(obj.Name)
            if (name == "owner" or name == "playername" or name == "ownername") and string.lower(obj.Value) == playerName then
                local ancestor = obj.Parent
                while ancestor and ancestor ~= hives do
                    local hiveCenter = getHiveCenterFromInstance(ancestor)
                    if hiveCenter then
                        return hiveCenter
                    end
                    ancestor = ancestor.Parent
                end
            end
        end
    end

    for _, obj in ipairs(hives:GetDescendants()) do
        local itemName = string.lower(obj.Name)
        if string.find(itemName, playerName, 1, true) then
            local hiveCenter = getHiveCenterFromInstance(obj)
            if hiveCenter then
                return hiveCenter
            end
        end
    end

    local referencePos = nil
    if spawnPosRef and spawnPosRef:IsA("ObjectValue") and spawnPosRef.Value and spawnPosRef.Value:IsA("BasePart") then
        referencePos = spawnPosRef.Value.Position
    else
        local root = select(1, getRootAndHumanoid())
        referencePos = root and root.Position or Vector3.new(0, 0, 0)
    end

    local nearestCFrame, nearestDist = nil, math.huge
    for _, child in ipairs(hives:GetChildren()) do
        local hiveCenter = getHiveCenterFromInstance(child)
        if hiveCenter then
            local dist = (hiveCenter.Position - referencePos).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearestCFrame = hiveCenter
            end
        end
    end

    return nearestCFrame
end

local function isConvertRemoteName(remoteName)
    local name = normalizeText(remoteName)
    return string.find(name, "convert", 1, true)
        or string.find(name, "makehoney", 1, true)
        or string.find(name, "hive", 1, true)
        or string.find(name, "honey", 1, true)
end

local function fireRemoteNoArgs(remote)
    if remote:IsA("RemoteEvent") then
        local attempts = {
            {},
            { "Convert" },
            { "MakeHoney" },
            { "ConvertHoney" },
            { "StartConverting" },
            { "StartHoneyMaking" },
            { LocalPlayer },
            { LocalPlayer, "Convert" },
            { LocalPlayer, "MakeHoney" },
            { "Hive", "Convert" },
            { "Hive", "MakeHoney" },
            { "Honey", "Convert" },
        }
        for _, args in ipairs(attempts) do
            local ok = pcall(function()
                remote:FireServer(table.unpack(args))
            end)
            if ok then
                return true
            end
        end
        return false
    elseif remote:IsA("RemoteFunction") then
        local attempts = {
            {},
            { "Convert" },
            { "MakeHoney" },
            { "ConvertHoney" },
            { LocalPlayer },
            { LocalPlayer, "Convert" },
            { LocalPlayer, "MakeHoney" },
        }
        for _, args in ipairs(attempts) do
            local ok = pcall(function()
                remote:InvokeServer(table.unpack(args))
            end)
            if ok then
                return true
            end
        end
        return false
    elseif remote:IsA("BindableEvent") then
        return pcall(function()
            remote:Fire()
        end)
    elseif remote:IsA("BindableFunction") then
        return pcall(function()
            remote:Invoke()
        end)
    end
    return false
end

local function getConvertRemotes()
    if convertRemoteCache then
        local valid = {}
        for _, remote in ipairs(convertRemoteCache) do
            if remote and remote.Parent then
                table.insert(valid, remote)
            end
        end
        if #valid > 0 then
            convertRemoteCache = valid
            return valid
        end
    end

    local found = {}
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        local isRemote = obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("BindableEvent") or obj:IsA("BindableFunction")
        if isRemote and isConvertRemoteName(obj.Name) then
            table.insert(found, obj)
        end
    end
    convertRemoteCache = found
    return found
end

local function tryTapMakeHoneyUI()
    local activated = false
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return false
    end

    local sawMakeHoneyText = false
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local text = normalizeText(obj.Text)
            if string.find(text, "makehoney", 1, true) then
                sawMakeHoneyText = true
            end
        end
    end

    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("TextButton") then
            local text = normalizeText(obj.Text)
            if string.find(text, "makehoney", 1, true) or string.find(text, "tap", 1, true) then
                if type(firesignal) == "function" then
                    pcall(function()
                        firesignal(obj.MouseButton1Click)
                    end)
                    pcall(function()
                        firesignal(obj.Activated)
                    end)
                    activated = true
                end
            end
        end
    end

    if sawMakeHoneyText and VirtualInputManager and workspace.CurrentCamera then
        local viewport = workspace.CurrentCamera.ViewportSize
        local x = math.floor(viewport.X * 0.5)
        local y = math.floor(viewport.Y * 0.5)

        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
            activated = true
        end)
    end

    return activated
end

local function tryKeyboardOrTapInput()
    local activated = false

    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            activated = true
        end)
    end

    if VirtualUser and workspace.CurrentCamera then
        local viewport = workspace.CurrentCamera.ViewportSize
        local v = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button1Down(v)
            task.wait(0.03)
            VirtualUser:Button1Up(v)
            activated = true
        end)
    end

    return activated
end

local function tryAggressiveInputSpam()
    if not Settings.NoSafeMode then
        return false
    end

    local activated = false

    if type(keypress) == "function" and type(keyrelease) == "function" then
        pcall(function()
            keypress(0x45)
            keyrelease(0x45)
            activated = true
        end)
    end

    if type(mouse1click) == "function" then
        pcall(function()
            mouse1click()
            activated = true
        end)
    elseif type(mouse1press) == "function" and type(mouse1release) == "function" then
        pcall(function()
            mouse1press()
            task.wait(0.01)
            mouse1release()
            activated = true
        end)
    end

    if VirtualInputManager and workspace.CurrentCamera then
        local viewport = workspace.CurrentCamera.ViewportSize
        local cx = math.floor(viewport.X * 0.5)
        local cy = math.floor(viewport.Y * 0.5)
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            activated = true
        end)
    end

    return activated
end

local function tryTouchHiveParts(center)
    if type(firetouchinterest) ~= "function" then
        return false
    end

    local root = select(1, getRootAndHumanoid())
    if not root then
        return false
    end

    local activated = false
    for _, part in ipairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") and (part.Position - center).Magnitude <= 13 then
            local n = normalizeText(part.Name)
            if string.find(n, "hive", 1, true)
                or string.find(n, "convert", 1, true)
                or string.find(n, "spawn", 1, true)
                or string.find(n, "pad", 1, true)
                or string.find(n, "platform", 1, true)
            then
                pcall(function()
                    firetouchinterest(root, part, 0)
                    firetouchinterest(root, part, 1)
                    activated = true
                end)
            end
        end
    end

    return activated
end

local function tryActivateHiveConversion(hiveCFrame)
    local activated = false
    local center = hiveCFrame.Position
    local searchRoot = workspace

    if tryTapMakeHoneyUI() then
        activated = true
    end

    if tryKeyboardOrTapInput() then
        activated = true
    end

    if tryAggressiveInputSpam() then
        activated = true
    end

    if type(fireproximityprompt) == "function" then
        for _, obj in ipairs(searchRoot:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Parent then
                local part = getPart(obj.Parent)
                if part and (part.Position - center).Magnitude <= 14 then
                    local ok = pcall(function()
                        fireproximityprompt(obj)
                    end)
                    activated = activated or ok
                end
            end
        end
    end

    if type(fireclickdetector) == "function" then
        for _, obj in ipairs(searchRoot:GetDescendants()) do
            if obj:IsA("ClickDetector") and obj.Parent then
                local part = getPart(obj.Parent)
                if part and (part.Position - center).Magnitude <= 14 then
                    local ok = pcall(function()
                        fireclickdetector(obj)
                    end)
                    activated = activated or ok
                end
            end
        end
    end

    for _, remote in ipairs(getConvertRemotes()) do
        local ok = fireRemoteNoArgs(remote)
        activated = activated or ok
    end

    if Settings.NoSafeMode and tryTouchHiveParts(center) then
        activated = true
    end

    return activated
end

local function runAutoFarm()
    if farmLoopRunning then
        return
    end
    farmLoopRunning = true

    local lastRootPos = nil
    local lastMoveAt = os.clock()

    while Settings.AutoFarm do
        applyWalkSpeed()
        local inHivePhase = false

        if Settings.ReturnToHive and getBagPercent() >= Settings.HiveBagPercent then
            inHivePhase = true
            local hiveCFrame = getSpawnPadCFrame() or getHiveCFrame()
            if hiveCFrame then
                tweenTo(hiveCFrame, getActiveTweenSpeed())
                local rootAtHive = select(1, getRootAndHumanoid())
                if rootAtHive then
                    local exactCenter = Vector3.new(hiveCFrame.Position.X, rootAtHive.Position.Y, hiveCFrame.Position.Z)
                    walkTo(exactCenter, 1.9, 1.8, function()
                        return not Settings.AutoFarm
                    end)
                end

                local convertTargets = getHiveConvertTargets(hiveCFrame)
                local convertIndex = 1
                local previousBagPercent = getBagPercent()
                local nextNudgeAt = os.clock() + (Settings.NoSafeMode and 2 or 6)
                local nextActionAt = os.clock()
                local timeoutAt = os.clock() + Settings.HiveWaitSeconds
                local lastDecreaseAt = os.clock()
                local actionInterval = Settings.NoSafeMode and AGGRESSIVE_HIVE_ACTION_INTERVAL or SAFE_HIVE_ACTION_INTERVAL

                while Settings.AutoFarm and os.clock() < timeoutAt do
                    local currentBagPercent = getBagPercent()
                    if currentBagPercent <= 10 then
                        break
                    end

                    if currentBagPercent + 0.2 < previousBagPercent then
                        previousBagPercent = currentBagPercent
                        lastDecreaseAt = os.clock()
                        nextNudgeAt = os.clock() + (Settings.NoSafeMode and 2.5 or 6)
                    end

                    if os.clock() >= nextActionAt then
                        tryActivateHiveConversion(hiveCFrame)
                        if Settings.NoSafeMode then
                            tryActivateHiveConversion(hiveCFrame)
                        end
                        nextActionAt = os.clock() + actionInterval
                    end

                    local root = select(1, getRootAndHumanoid())
                    if root and (root.Position - hiveCFrame.Position).Magnitude > (Settings.NoSafeMode and 3.6 or 5.5) then
                        tweenTo(hiveCFrame, getActiveTweenSpeed())
                    end

                    if os.clock() >= nextNudgeAt and (os.clock() - lastDecreaseAt) >= (Settings.NoSafeMode and 2 or 5) then
                        convertIndex = (convertIndex % #convertTargets) + 1
                        if root then
                            local target = convertTargets[convertIndex]
                            local walkTarget = Vector3.new(target.X, root.Position.Y, target.Z)
                            walkTo(walkTarget, Settings.NoSafeMode and 1.2 or 2.5, Settings.NoSafeMode and 0.9 or 1.4, function()
                                return not Settings.AutoFarm
                            end)
                        end
                        nextNudgeAt = os.clock() + (Settings.NoSafeMode and 1.2 or 4)
                    end

                    task.wait(Settings.NoSafeMode and 0.05 or 0.2)
                end

                if Settings.AutoFarm and getBagPercent() >= (Settings.HiveBagPercent - 1) then
                    local fieldReset = getFieldCFrame(Settings.FieldName)
                    if fieldReset then
                        local root = select(1, getRootAndHumanoid())
                        local y = root and root.Position.Y or fieldReset.Position.Y
                        tweenTo(CFrame.new(fieldReset.Position.X, y, fieldReset.Position.Z), getActiveTweenSpeed())
                    end
                end
            else
                task.wait(0.2)
            end
        else
            stopTween()

            local tokenPos = getNearestTokenInField(Settings.FieldName)
            if tokenPos then
                local root = select(1, getRootAndHumanoid())
                local walkTarget = tokenPos
                if root then
                    walkTarget = Vector3.new(tokenPos.X, root.Position.Y, tokenPos.Z)
                end
                walkTo(walkTarget, 4, 2.6, function()
                    return not Settings.AutoFarm
                end)
            else
                local walkPos = getRandomPointInField(Settings.FieldName)
                if walkPos then
                    walkTo(walkPos, 5, 3, function()
                        return not Settings.AutoFarm
                    end)
                else
                    task.wait(0.2)
                end
            end
        end

        if not inHivePhase then
            local root = select(1, getRootAndHumanoid())
            if root then
                if not lastRootPos then
                    lastRootPos = root.Position
                    lastMoveAt = os.clock()
                else
                    local moved = (root.Position - lastRootPos).Magnitude
                    if moved >= 1.5 then
                        lastRootPos = root.Position
                        lastMoveAt = os.clock()
                    elseif os.clock() - lastMoveAt >= 6 then
                        local fieldReset = getFieldCFrame(Settings.FieldName)
                        if fieldReset then
                            local y = root.Position.Y
                            tweenTo(CFrame.new(fieldReset.Position.X, y, fieldReset.Position.Z), getActiveTweenSpeed())
                        end
                        lastRootPos = root.Position
                        lastMoveAt = os.clock()
                    end
                end
            end
        end

        task.wait(0.05)
    end

    stopMovement()
    farmLoopRunning = false
end

local function getToyByLabel(label)
    for _, toy in ipairs(TOYS) do
        if toy.label == label then
            return toy
        end
    end
    return TOYS[1]
end

local function toySettingKey(toy)
    return "Toy_" .. toy.key
end

local function nameMatchesAliases(rawName, aliases)
    local normalizedName = normalizeText(rawName)
    for _, alias in ipairs(aliases) do
        local normalizedAlias = normalizeText(alias)
        if normalizedAlias ~= "" and string.find(normalizedName, normalizedAlias, 1, true) then
            return true
        end
    end
    return false
end

local function isRemoteLike(instance)
    return instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") or instance:IsA("BindableEvent") or instance:IsA("BindableFunction")
end

local function triggerRemote(instance)
    if instance:IsA("RemoteEvent") then
        local ok = pcall(function() instance:FireServer() end)
        if ok then return true, "RemoteEvent" end
    elseif instance:IsA("RemoteFunction") then
        local ok = pcall(function() instance:InvokeServer() end)
        if ok then return true, "RemoteFunction" end
    elseif instance:IsA("BindableEvent") then
        local ok = pcall(function() instance:Fire() end)
        if ok then return true, "BindableEvent" end
    elseif instance:IsA("BindableFunction") then
        local ok = pcall(function() instance:Invoke() end)
        if ok then return true, "BindableFunction" end
    end
    return false, "none"
end

local function triggerPrompt(instance)
    if type(fireproximityprompt) ~= "function" then
        return false
    end

    local prompt = instance:IsA("ProximityPrompt") and instance or instance:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt then
        return false
    end

    local ok = pcall(function()
        fireproximityprompt(prompt)
    end)
    return ok
end

local function triggerClick(instance)
    if type(fireclickdetector) ~= "function" then
        return false
    end

    local click = instance:IsA("ClickDetector") and instance or instance:FindFirstChildWhichIsA("ClickDetector", true)
    if not click then
        return false
    end

    local ok = pcall(function()
        fireclickdetector(click)
    end)
    return ok
end

local function triggerTouch(instance)
    if type(firetouchinterest) ~= "function" then
        return false
    end

    local root = select(1, getRootAndHumanoid())
    local part = getPart(instance)
    if not root or not part then
        return false
    end

    local ok = pcall(function()
        firetouchinterest(root, part, 0)
        task.wait(0.05)
        firetouchinterest(root, part, 1)
    end)
    return ok
end

local function triggerFromInstance(instance)
    if not instance then
        return false, "none"
    end

    if isRemoteLike(instance) then
        local ok, method = triggerRemote(instance)
        if ok then
            return true, method
        end
    end

    for _, d in ipairs(instance:GetDescendants()) do
        if isRemoteLike(d) then
            local ok, method = triggerRemote(d)
            if ok then
                return true, method
            end
        end
    end

    if triggerPrompt(instance) then
        return true, "ProximityPrompt"
    end

    if triggerClick(instance) then
        return true, "ClickDetector"
    end

    if triggerTouch(instance) then
        return true, "Touch"
    end

    return false, "none"
end

local function toyRoots()
    local roots = {}
    local wEvents = workspace:FindFirstChild("Events")
    local rEvents = ReplicatedStorage:FindFirstChild("Events")
    if wEvents then table.insert(roots, wEvents) end
    if rEvents then table.insert(roots, rEvents) end
    table.insert(roots, workspace)
    table.insert(roots, ReplicatedStorage)
    return roots
end

local function findToyRemote(toy)
    local cached = toyCache[toy.key]
    if cached and cached.remote and cached.remote.Parent then
        return cached.remote
    end

    for _, root in ipairs(toyRoots()) do
        for _, d in ipairs(root:GetDescendants()) do
            if isRemoteLike(d) and nameMatchesAliases(d.Name, toy.aliases) then
                toyCache[toy.key] = toyCache[toy.key] or {}
                toyCache[toy.key].remote = d
                return d
            end
        end
    end

    return nil
end

local function findToyObject(toy)
    local cached = toyCache[toy.key]
    if cached and cached.obj and cached.obj.Parent then
        return cached.obj
    end

    for _, d in ipairs(workspace:GetDescendants()) do
        local valid = d:IsA("Model") or d:IsA("BasePart")
        if valid and nameMatchesAliases(d.Name, toy.aliases) then
            toyCache[toy.key] = toyCache[toy.key] or {}
            toyCache[toy.key].obj = d
            return d
        end
    end

    for _, d in ipairs(workspace:GetDescendants()) do
        if (d:IsA("ProximityPrompt") or d:IsA("ClickDetector")) and d.Parent then
            if nameMatchesAliases(d.Parent.Name, toy.aliases) then
                toyCache[toy.key] = toyCache[toy.key] or {}
                toyCache[toy.key].obj = d.Parent
                return d.Parent
            end
        end
    end

    return nil
end

local function useToy(toy)
    local remote = findToyRemote(toy)
    if remote then
        local ok, method = triggerRemote(remote)
        if ok then
            return true, "remote:" .. method
        end
    end

    local obj = findToyObject(toy)
    if obj then
        if Settings.ToyTweenToTarget then
            local cf = getCFrame(obj)
            if cf then
                tweenTo(cf * CFrame.new(0, 3, 0), getActiveTweenSpeed())
            end
        end

        local ok, method = triggerFromInstance(obj)
        if ok then
            return true, method
        end
    end

    return false, "not found/blocked"
end

local function runToyLoop(updateStatus)
    if toyLoopRunning then
        return
    end
    toyLoopRunning = true

    while Settings.AutoUseToys do
        local now = os.clock()
        local usedAny = false

        for _, toy in ipairs(TOYS) do
            if not Settings.AutoUseToys then
                break
            end

            local enabledKey = toySettingKey(toy)
            if Settings[enabledKey] then
                local lastUse = toyUseTracker[toy.key] or 0
                if (now - lastUse) >= math.max(20, Settings.ToyLoopDelay) then
                    local ok, method = useToy(toy)
                    toyUseTracker[toy.key] = os.clock()
                    usedAny = true
                    if updateStatus then
                        if ok then
                            updateStatus("Toy: " .. toy.label .. " via " .. method)
                        else
                            updateStatus("Toy failed: " .. toy.label .. " (" .. method .. ")")
                        end
                    end
                    task.wait(0.5)
                end
            end
        end

        if not usedAny and updateStatus then
            updateStatus("Toy loop idle")
        end

        task.wait(1)
    end

    toyLoopRunning = false
end

local function backupAndSet(instance, prop, newValue)
    local okGet, oldValue = pcall(function()
        return instance[prop]
    end)
    if not okGet then
        return false
    end

    antiLagBackups[instance] = antiLagBackups[instance] or {}
    if antiLagBackups[instance][prop] == nil then
        antiLagBackups[instance][prop] = oldValue
    end

    local okSet = pcall(function()
        instance[prop] = newValue
    end)
    return okSet
end

local function applyAntiLagPass()
    if Settings.AntiLagLighting then
        backupAndSet(Lighting, "GlobalShadows", false)
        backupAndSet(Lighting, "FogEnd", 100000)
        backupAndSet(Lighting, "Brightness", 1)

        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            backupAndSet(terrain, "WaterWaveSize", 0)
            backupAndSet(terrain, "WaterWaveSpeed", 0)
            backupAndSet(terrain, "WaterReflectance", 0)
            backupAndSet(terrain, "WaterTransparency", 1)
        end
    end

    for _, d in ipairs(workspace:GetDescendants()) do
        if Settings.AntiLagParticles and EFFECT_CLASSES[d.ClassName] then
            backupAndSet(d, "Enabled", false)
        end

        if Settings.AntiLagTextures and (d:IsA("Decal") or d:IsA("Texture")) then
            backupAndSet(d, "Transparency", 1)
        end

        if Settings.AntiLagShadows and d:IsA("BasePart") then
            backupAndSet(d, "CastShadow", false)
        end
    end
end

local function restoreAntiLag()
    for instance, props in pairs(antiLagBackups) do
        if instance and instance.Parent then
            for prop, oldValue in pairs(props) do
                pcall(function()
                    instance[prop] = oldValue
                end)
            end
        end
    end
    antiLagBackups = setmetatable({}, { __mode = "k" })
end

local function runAntiLagLoop(updateStatus)
    if antiLagLoopRunning then
        return
    end
    antiLagLoopRunning = true

    while Settings.AntiLagEnabled do
        applyAntiLagPass()
        if updateStatus then
            updateStatus("AntiLag active")
        end
        task.wait(math.clamp(Settings.AntiLagRefreshSeconds, 1, 15))
    end

    antiLagLoopRunning = false
end

local function scanTokenNames()
    local collectibles = getCollectiblesFolder()
    local map = {}

    if collectibles then
        for _, d in ipairs(collectibles:GetDescendants()) do
            local valid = d:IsA("BasePart") or d:IsA("Model") or d:IsA("Attachment")
            if valid then
                map[d.Name] = true
            end
        end
    end

    local names = {}
    for name in pairs(map) do
        table.insert(names, name)
    end
    table.sort(names)

    print("[Berg] Token scan found " .. tostring(#names) .. " names")
    for _, name in ipairs(names) do
        print(" - " .. name)
    end

    if type(setclipboard) == "function" then
        pcall(function()
            setclipboard(table.concat(names, "\n"))
        end)
    end

    return names
end

local function hasConfigFileApi()
    return type(isfolder) == "function"
        and type(makefolder) == "function"
        and type(isfile) == "function"
        and type(readfile) == "function"
        and type(writefile) == "function"
end

local function normalizeProfileName(profileName)
    local raw = tostring(profileName or "main")
    raw = string.lower(raw)
    raw = raw:gsub("%s+", "_")
    raw = raw:gsub("[^%w_%-]", "")
    raw = raw:gsub("_+", "_")
    if raw == "" then
        raw = "main"
    end
    return string.sub(raw, 1, 32)
end

local function getConfigFilePath(profileName)
    local normalized = normalizeProfileName(profileName)
    local path = CONFIG_FOLDER_NAME .. "/" .. CONFIG_FILE_BASENAME .. "_" .. normalized .. ".json"
    return path, normalized
end

local function ensureConfigFolder()
    if not hasConfigFileApi() then
        return false, "Executor has no file API"
    end

    local okFolder = pcall(function()
        if not isfolder(CONFIG_FOLDER_NAME) then
            makefolder(CONFIG_FOLDER_NAME)
        end
    end)
    if not okFolder then
        return false, "Cannot access config folder"
    end
    return true
end

local function saveConfigMetaProfile(profileName)
    local okFolder, msg = ensureConfigFolder()
    if not okFolder then
        return false, msg
    end

    local payload = {
        version = 1,
        profile = normalizeProfileName(profileName),
    }

    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not okEncode then
        return false, "Meta encode failed"
    end

    local okWrite = pcall(function()
        writefile(CONFIG_META_PATH, encoded)
    end)
    if not okWrite then
        return false, "Meta write failed"
    end

    return true
end

local function loadConfigMetaProfile()
    local okFolder = ensureConfigFolder()
    if not okFolder then
        return false
    end

    if not isfile(CONFIG_META_PATH) then
        return false
    end

    local okRead, raw = pcall(function()
        return readfile(CONFIG_META_PATH)
    end)
    if not okRead then
        return false
    end

    local okDecode, payload = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not okDecode or type(payload) ~= "table" then
        return false
    end

    if payload.profile ~= nil then
        Settings.ConfigProfile = normalizeProfileName(payload.profile)
        return true
    end

    return false
end

local function colorToArray(color)
    return {
        math.floor(color.R * 255 + 0.5),
        math.floor(color.G * 255 + 0.5),
        math.floor(color.B * 255 + 0.5),
    }
end

local function arrayToColor(value)
    if type(value) ~= "table" then
        return nil
    end
    local r = tonumber(value[1])
    local g = tonumber(value[2])
    local b = tonumber(value[3])
    if not r or not g or not b then
        return nil
    end
    return Color3.fromRGB(
        math.clamp(math.floor(r + 0.5), 0, 255),
        math.clamp(math.floor(g + 0.5), 0, 255),
        math.clamp(math.floor(b + 0.5), 0, 255)
    )
end

local function captureConfigData()
    local payload = {
        version = 2,
        userId = LocalPlayer.UserId,
        placeId = game.PlaceId,
        profile = normalizeProfileName(Settings.ConfigProfile),
        script = "Berg",
        savedAtUnix = os.time(),
        savedAtISO = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        settings = {},
        toys = {},
        theme = {},
    }

    for key in pairs(DEFAULT) do
        payload.settings[key] = Settings[key]
    end

    for _, toy in ipairs(TOYS) do
        local key = toySettingKey(toy)
        payload.toys[key] = Settings[key] and true or false
    end

    for themeKey, color in pairs(UITheme) do
        payload.theme[themeKey] = colorToArray(color)
    end

    return payload
end

local function normalizeConfigValues()
    Settings.TweenSoftness = math.clamp(tonumber(Settings.TweenSoftness) or 70, 0, 100)
    Settings.ConfigAutoSaveDelay = math.clamp(tonumber(Settings.ConfigAutoSaveDelay) or 20, 5, 120)
    Settings.ConfigProfile = normalizeProfileName(Settings.ConfigProfile)
    if not table.find(TOY_NAMES, Settings.SelectedToy) then
        Settings.SelectedToy = TOY_NAMES[1]
    end
end

local function applyConfigData(payload)
    if type(payload) ~= "table" then
        return false, "Invalid config payload"
    end

    if type(payload.settings) == "table" then
        for key in pairs(DEFAULT) do
            if payload.settings[key] ~= nil then
                Settings[key] = payload.settings[key]
            end
        end
    end

    if type(payload.toys) == "table" then
        for _, toy in ipairs(TOYS) do
            local key = toySettingKey(toy)
            if payload.toys[key] ~= nil then
                Settings[key] = payload.toys[key]
            end
        end
    end

    if type(payload.theme) == "table" then
        for themeKey in pairs(UITheme) do
            local converted = arrayToColor(payload.theme[themeKey])
            if converted then
                UITheme[themeKey] = converted
            end
        end
    end

    normalizeConfigValues()
    return true, "Config applied"
end

local function saveConfigToFile(profileName, forceWrite)
    local okFolder, msg = ensureConfigFolder()
    if not okFolder then
        return false, msg
    end

    local path, normalizedProfile = getConfigFilePath(profileName or Settings.ConfigProfile)
    Settings.ConfigProfile = normalizedProfile

    local payload = captureConfigData()
    payload.profile = normalizedProfile

    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not okEncode then
        return false, "JSON encode failed"
    end

    if Settings.ConfigOnlyIfChanged and not forceWrite and configWriteCache[path] == encoded then
        return true, "No changes"
    end

    if Settings.ConfigSaveBackup and isfile(path) then
        pcall(function()
            local oldRaw = readfile(path)
            writefile(path .. ".bak", oldRaw)
        end)
    end

    local okWrite = pcall(function()
        writefile(path, encoded)
    end)
    if not okWrite then
        return false, "Write failed"
    end

    configWriteCache[path] = encoded
    pcall(function()
        saveConfigMetaProfile(normalizedProfile)
    end)

    return true, "Saved (" .. normalizedProfile .. ")"
end

local function loadConfigFromFile(profileName)
    local okFolder, msg = ensureConfigFolder()
    if not okFolder then
        return false, msg
    end

    local path, normalizedProfile = getConfigFilePath(profileName or Settings.ConfigProfile)
    local fallbackLegacy = false
    if not isfile(path) then
        if normalizedProfile == "main" and isfile(CONFIG_LEGACY_PATH) then
            path = CONFIG_LEGACY_PATH
            fallbackLegacy = true
        else
            return false, "No config for profile: " .. normalizedProfile
        end
    end

    local okRead, raw = pcall(function()
        return readfile(path)
    end)
    if not okRead then
        return false, "Read failed"
    end

    local okDecode, payload = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not okDecode then
        if isfile(path .. ".bak") then
            local okBakRead, bakRaw = pcall(function()
                return readfile(path .. ".bak")
            end)
            if okBakRead then
                okDecode, payload = pcall(function()
                    return HttpService:JSONDecode(bakRaw)
                end)
                if okDecode then
                    raw = bakRaw
                end
            end
        end
    end
    if not okDecode then
        return false, "JSON decode failed"
    end

    local okApply, applyMsg = applyConfigData(payload)
    if not okApply then
        return false, applyMsg
    end

    Settings.ConfigProfile = normalizedProfile
    configWriteCache[path] = raw
    pcall(function()
        saveConfigMetaProfile(normalizedProfile)
    end)
    if fallbackLegacy then
        pcall(function()
            saveConfigToFile(normalizedProfile, true)
        end)
    end

    return true, "Loaded (" .. normalizedProfile .. ")"
end

local function loadBackupConfigFromFile(profileName)
    local okFolder, msg = ensureConfigFolder()
    if not okFolder then
        return false, msg
    end

    local path, normalizedProfile = getConfigFilePath(profileName or Settings.ConfigProfile)
    local backupPath = path .. ".bak"
    if not isfile(backupPath) then
        return false, "No backup for profile: " .. normalizedProfile
    end

    local okRead, raw = pcall(function()
        return readfile(backupPath)
    end)
    if not okRead then
        return false, "Backup read failed"
    end

    local okDecode, payload = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not okDecode then
        return false, "Backup JSON decode failed"
    end

    local okApply, applyMsg = applyConfigData(payload)
    if not okApply then
        return false, applyMsg
    end

    Settings.ConfigProfile = normalizedProfile
    configWriteCache[path] = raw
    pcall(function()
        saveConfigMetaProfile(normalizedProfile)
    end)
    return true, "Backup loaded (" .. normalizedProfile .. ")"
end

local function exportConfigToClipboard()
    if type(setclipboard) ~= "function" then
        return false, "Clipboard export not supported"
    end

    local payload = captureConfigData()
    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not okEncode then
        return false, "JSON encode failed"
    end

    local okSet = pcall(function()
        setclipboard(encoded)
    end)
    if not okSet then
        return false, "Clipboard write failed"
    end

    return true, "Exported to clipboard"
end

local function importConfigFromClipboard()
    if type(getclipboard) ~= "function" then
        return false, "Clipboard import not supported"
    end

    local okGet, raw = pcall(function()
        return getclipboard()
    end)
    if not okGet or type(raw) ~= "string" or raw == "" then
        return false, "Clipboard empty"
    end

    local okDecode, payload = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not okDecode then
        return false, "Clipboard JSON invalid"
    end

    local okApply, msg = applyConfigData(payload)
    if not okApply then
        return false, msg
    end

    normalizeConfigValues()
    return true, "Imported from clipboard"
end

normalizeConfigValues()
if hasConfigFileApi() then
    loadConfigMetaProfile()
end

local initialConfigLoaded = false
local initialConfigMessage = "No config loaded"
if hasConfigFileApi() then
    if Settings.ConfigAutoLoad then
        initialConfigLoaded, initialConfigMessage = loadConfigFromFile(Settings.ConfigProfile)
        if not initialConfigLoaded then
            initialConfigMessage = initialConfigMessage or "No config loaded"
        end
    else
        initialConfigMessage = "Auto load disabled"
    end
else
    Settings.ConfigAutoSave = false
    initialConfigMessage = "Executor has no file API"
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    applyWalkSpeed()
end)

local Window = Library.CreateLib("Berg | BSS Auto Farm", UITheme)

local MainTab = Window:NewTab("Main")
local MainControl = MainTab:NewSection("Quick Control")
local MainTravel = MainTab:NewSection("Navigation")
local MainUI = MainTab:NewSection("UI")

MainControl:NewLabel("Style: Purple + Black")

MainControl:NewToggle("Auto Farm", "Start/stop autofarm", function(state)
    Settings.AutoFarm = state
    if state then
        task.spawn(runAutoFarm)
    else
        stopMovement()
    end
end)

MainControl:NewButton("Stop Now", "Stop autofarm and movement", function()
    Settings.AutoFarm = false
    stopMovement()
end)

MainTravel:NewButton("Go To Hive", "Move to hive once", function()
    local hive = getHiveCFrame()
    if hive then
        tweenTo(hive, getActiveTweenSpeed())
    end
end)

MainTravel:NewButton("Force Convert", "Try all hive convert triggers now", function()
    local hive = getSpawnPadCFrame() or getHiveCFrame()
    if hive then
        tweenTo(hive, getActiveTweenSpeed())
        tryActivateHiveConversion(hive)
    end
end)

MainTravel:NewButton("Go To Field", "Walk to selected field once", function()
    local field = getFieldCFrame(Settings.FieldName)
    if field then
        local root = select(1, getRootAndHumanoid())
        local target = field.Position
        if root then
            target = Vector3.new(field.Position.X, root.Position.Y, field.Position.Z)
        end
        applyWalkSpeed()
        walkTo(target, 6, 8)
    end
end)

MainUI:NewKeybind("Toggle UI", "Show/hide the UI", Enum.KeyCode.RightControl, function()
    Library:ToggleUI()
end)

local FarmTab = Window:NewTab("Farm")
local FarmSection = FarmTab:NewSection("Field + Hive")

FarmSection:NewLabel("Farming is locked to selected field only")

FarmSection:NewDropdown("Field", "Select farming field", FIELDS, function(value)
    Settings.FieldName = value
end)

FarmSection:NewToggle("Return To Hive", "Return to hive when bag is full", function(state)
    Settings.ReturnToHive = state
end)

FarmSection:NewSlider("Bag Percent", "Hive threshold", 100, 70, function(value)
    Settings.HiveBagPercent = value
end)

FarmSection:NewSlider("Hive Wait Seconds", "Time waiting at hive", 90, 5, function(value)
    Settings.HiveWaitSeconds = value
end)

local TokenTab = Window:NewTab("Tokens")
local TokenMain = TokenTab:NewSection("Token Filter")
local TokenAdvanced = TokenTab:NewSection("Precise / Pop-Star")

TokenMain:NewToggle("Collect All Tokens", "Ignore filters below", function(state)
    Settings.CollectAllTokens = state
end)

TokenMain:NewToggle("Honey", "Honey token filter", function(state)
    Settings.TokenHoney = state
end)

TokenMain:NewToggle("Pollen", "Pollen token filter", function(state)
    Settings.TokenPollen = state
end)

TokenMain:NewToggle("Boost", "Boost/focus/haste/melody", function(state)
    Settings.TokenBoost = state
end)

TokenMain:NewToggle("Ability", "General ability tokens", function(state)
    Settings.TokenAbility = state
end)

TokenMain:NewToggle("Ticket", "Ticket tokens", function(state)
    Settings.TokenTicket = state
end)

TokenMain:NewToggle("Treat", "Treat tokens", function(state)
    Settings.TokenTreat = state
end)

TokenAdvanced:NewToggle("Precise", "Precise / precision tokens", function(state)
    Settings.TokenPrecise = state
end)

TokenAdvanced:NewToggle("Marks", "Mark / target tokens", function(state)
    Settings.TokenMarks = state
end)

TokenAdvanced:NewToggle("Pop Star", "Pop star / star style tokens", function(state)
    Settings.TokenPopStar = state
end)

TokenAdvanced:NewToggle("Link", "Link tokens", function(state)
    Settings.TokenLink = state
end)

TokenAdvanced:NewToggle("Bomb", "Bomb tokens", function(state)
    Settings.TokenBomb = state
end)

TokenAdvanced:NewToggle("Bubble", "Bubble tokens", function(state)
    Settings.TokenBubble = state
end)

TokenAdvanced:NewToggle("Flame", "Flame tokens", function(state)
    Settings.TokenFlame = state
end)

local ToysTab = Window:NewTab("Toys")
local ToyControl = ToysTab:NewSection("Remote + Trigger")
local ToyList = ToysTab:NewSection("Auto Toy List")

local toyStatusLabel = ToyControl:NewLabel("Toy: idle")
local function setToyStatus(text)
    if toyStatusLabel and toyStatusLabel.UpdateLabel then
        toyStatusLabel:UpdateLabel(text)
    end
end

ToyControl:NewToggle("Auto Use Toys", "Auto use enabled toys", function(state)
    Settings.AutoUseToys = state
    if state then
        task.spawn(function()
            runToyLoop(setToyStatus)
        end)
    else
        setToyStatus("Toy loop stopped")
    end
end)

ToyControl:NewSlider("Toy Loop Delay", "Seconds between toy attempts", 600, 20, function(value)
    Settings.ToyLoopDelay = value
end)

ToyControl:NewToggle("Tween To Toy", "Move to toy if remote fails", function(state)
    Settings.ToyTweenToTarget = state
end)

ToyControl:NewDropdown("Selected Toy", "Choose toy to use now", TOY_NAMES, function(value)
    Settings.SelectedToy = value
end)

ToyControl:NewButton("Use Selected Toy", "Try remote then prompt/click/touch", function()
    local toy = getToyByLabel(Settings.SelectedToy)
    if toy then
        local ok, method = useToy(toy)
        if ok then
            setToyStatus("Toy: " .. toy.label .. " via " .. method)
        else
            setToyStatus("Toy failed: " .. toy.label .. " (" .. method .. ")")
        end
    end
end)

ToyControl:NewButton("Use Enabled Toys Once", "Run one pass over enabled toys", function()
    for _, toy in ipairs(TOYS) do
        if Settings[toySettingKey(toy)] then
            local ok, method = useToy(toy)
            if ok then
                setToyStatus("Toy: " .. toy.label .. " via " .. method)
            else
                setToyStatus("Toy failed: " .. toy.label .. " (" .. method .. ")")
            end
            task.wait(0.2)
        end
    end
end)

for _, toy in ipairs(TOYS) do
    local key = toySettingKey(toy)
    ToyList:NewToggle(toy.label, "Enable this toy in loop", function(state)
        Settings[key] = state
    end)
end

local ConfigTab = Window:NewTab("Config")
local SpeedSection = ConfigTab:NewSection("Speed")
local StorageSection = ConfigTab:NewSection("JSON Profile")

SpeedSection:NewSlider("WalkSpeed", "Player walk speed (40-120)", 120, 40, function(value)
    Settings.PlayerSpeed = value
    applyWalkSpeed()
end)

SpeedSection:NewSlider("TweenSpeed", "Tween speed (40-120)", 120, 40, function(value)
    Settings.TweenSpeed = value
end)

SpeedSection:NewSlider("TweenSoftness", "Softer tween feel (0-100)", 100, 0, function(value)
    Settings.TweenSoftness = value
end)

SpeedSection:NewToggle("No Safe Mode", "Aggressive convert/tap spam", function(state)
    Settings.NoSafeMode = state
end)

local configStatusLabel = StorageSection:NewLabel("Config: " .. tostring(initialConfigMessage))
local function setConfigStatus(text)
    if configStatusLabel and configStatusLabel.UpdateLabel then
        configStatusLabel:UpdateLabel("Config: " .. text)
    end
end

local activeProfileLabel = StorageSection:NewLabel("Profile: " .. tostring(Settings.ConfigProfile))
local configPathLabel = StorageSection:NewLabel("File: " .. tostring(select(1, getConfigFilePath(Settings.ConfigProfile))))
local function refreshConfigProfileLabels()
    local path, normalizedProfile = getConfigFilePath(Settings.ConfigProfile)
    Settings.ConfigProfile = normalizedProfile

    if activeProfileLabel and activeProfileLabel.UpdateLabel then
        activeProfileLabel:UpdateLabel("Profile: " .. normalizedProfile)
    end
    if configPathLabel and configPathLabel.UpdateLabel then
        configPathLabel:UpdateLabel("File: " .. path)
    end
end

StorageSection:NewTextBox("Profile Name", "Use letters/numbers/_/-", function(value)
    Settings.ConfigProfile = normalizeProfileName(value)
    refreshConfigProfileLabels()
    setConfigStatus("profile set")
end)

StorageSection:NewToggle("Auto Save", "Save config automatically", function(state)
    Settings.ConfigAutoSave = state
end)

StorageSection:NewToggle("Auto Load", "Load selected profile on inject", function(state)
    Settings.ConfigAutoLoad = state
end)

StorageSection:NewToggle("Backup On Save", "Write .bak before save", function(state)
    Settings.ConfigSaveBackup = state
end)

StorageSection:NewToggle("Save Only Changes", "Skip file write if unchanged", function(state)
    Settings.ConfigOnlyIfChanged = state
end)

StorageSection:NewSlider("Auto Save Delay", "Seconds between auto saves", 120, 5, function(value)
    Settings.ConfigAutoSaveDelay = value
end)

StorageSection:NewButton("Save Config", "Save your profile to JSON", function()
    local ok, msg = saveConfigToFile(Settings.ConfigProfile, true)
    if ok then
        refreshConfigProfileLabels()
        setConfigStatus(msg)
    else
        setConfigStatus(msg)
    end
end)

StorageSection:NewButton("Load Config", "Load your profile from JSON", function()
    local ok, msg = loadConfigFromFile(Settings.ConfigProfile)
    if ok then
        applyWalkSpeed()
        if Library.ChangeColor then
            for themeKey, color in pairs(UITheme) do
                Library:ChangeColor(themeKey, color)
            end
        end
        refreshConfigProfileLabels()
        setConfigStatus(msg)
    else
        setConfigStatus(msg)
    end
end)

StorageSection:NewButton("Load Backup", "Load .bak for current profile", function()
    local ok, msg = loadBackupConfigFromFile(Settings.ConfigProfile)
    if ok then
        refreshConfigProfileLabels()
        applyWalkSpeed()
        if Library.ChangeColor then
            for themeKey, color in pairs(UITheme) do
                Library:ChangeColor(themeKey, color)
            end
        end
        setConfigStatus(msg)
    else
        setConfigStatus(msg)
    end
end)

StorageSection:NewButton("Export JSON", "Copy active profile JSON to clipboard", function()
    local ok, msg = exportConfigToClipboard()
    if ok then
        setConfigStatus(msg)
    else
        setConfigStatus(msg)
    end
end)

StorageSection:NewButton("Import JSON", "Load JSON from clipboard", function()
    local ok, msg = importConfigFromClipboard()
    if ok then
        refreshConfigProfileLabels()
        applyWalkSpeed()
        if Library.ChangeColor then
            for themeKey, color in pairs(UITheme) do
                Library:ChangeColor(themeKey, color)
            end
        end
        setConfigStatus(msg)
    else
        setConfigStatus(msg)
    end
end)

local ThemeTab = Window:NewTab("Theme")
local ThemeSection = ThemeTab:NewSection("Customize Colors")

ThemeSection:NewLabel("Tabs and background are black in default preset")

ThemeSection:NewColorPicker("SchemeColor", "Purple accent", UITheme.SchemeColor, function(color)
    UITheme.SchemeColor = color
    if Library.ChangeColor then
        Library:ChangeColor("SchemeColor", color)
    end
end)

ThemeSection:NewColorPicker("Background", "Background color", UITheme.Background, function(color)
    UITheme.Background = color
    if Library.ChangeColor then
        Library:ChangeColor("Background", color)
    end
end)

ThemeSection:NewColorPicker("Header", "Tab/header color", UITheme.Header, function(color)
    UITheme.Header = color
    if Library.ChangeColor then
        Library:ChangeColor("Header", color)
    end
end)

ThemeSection:NewColorPicker("ElementColor", "Section/button color", UITheme.ElementColor, function(color)
    UITheme.ElementColor = color
    if Library.ChangeColor then
        Library:ChangeColor("ElementColor", color)
    end
end)

ThemeSection:NewColorPicker("TextColor", "Text color", UITheme.TextColor, function(color)
    UITheme.TextColor = color
    if Library.ChangeColor then
        Library:ChangeColor("TextColor", color)
    end
end)

ThemeSection:NewButton("Preset: Purple Black", "Apply purple + black style", function()
    local preset = {
        SchemeColor = Color3.fromRGB(166, 73, 255),
        Background = Color3.fromRGB(8, 8, 8),
        Header = Color3.fromRGB(0, 0, 0),
        TextColor = Color3.fromRGB(235, 235, 235),
        ElementColor = Color3.fromRGB(0, 0, 0),
    }
    for key, color in pairs(preset) do
        UITheme[key] = color
        if Library.ChangeColor then
            Library:ChangeColor(key, color)
        end
    end
end)

local DebugTab = Window:NewTab("Debug")
local DebugPerf = DebugTab:NewSection("Anti-Lag")
local DebugTools = DebugTab:NewSection("Tools")

local debugStatusLabel = DebugPerf:NewLabel("Debug: idle")
local function setDebugStatus(text)
    if debugStatusLabel and debugStatusLabel.UpdateLabel then
        debugStatusLabel:UpdateLabel(text)
    end
end

DebugPerf:NewToggle("Anti Lag", "Enable/disable anti lag", function(state)
    Settings.AntiLagEnabled = state
    if state then
        task.spawn(function()
            runAntiLagLoop(setDebugStatus)
        end)
    else
        restoreAntiLag()
        setDebugStatus("AntiLag restored")
    end
end)

DebugPerf:NewToggle("Disable Particles", "Turn off particles/trails/beams", function(state)
    Settings.AntiLagParticles = state
end)

DebugPerf:NewToggle("Hide Textures", "Hide decals and textures", function(state)
    Settings.AntiLagTextures = state
end)

DebugPerf:NewToggle("Disable Shadows", "Disable part cast shadows", function(state)
    Settings.AntiLagShadows = state
end)

DebugPerf:NewToggle("Low Lighting", "Lower lighting effects", function(state)
    Settings.AntiLagLighting = state
end)

DebugPerf:NewSlider("Refresh Seconds", "Anti-lag refresh interval", 15, 1, function(value)
    Settings.AntiLagRefreshSeconds = value
end)

DebugTools:NewButton("Apply Anti Lag Now", "Run anti-lag pass instantly", function()
    applyAntiLagPass()
    setDebugStatus("AntiLag pass applied")
end)

DebugTools:NewButton("Restore Visuals", "Restore visual changes", function()
    Settings.AntiLagEnabled = false
    restoreAntiLag()
    setDebugStatus("Visuals restored")
end)

local tokenScanLabel = DebugTools:NewLabel("Token scan: not run")

DebugTools:NewButton("Scan Token Names", "List token names to console", function()
    local names = scanTokenNames()
    local text = "Token scan: " .. tostring(#names) .. " names"
    if tokenScanLabel and tokenScanLabel.UpdateLabel then
        tokenScanLabel:UpdateLabel(text)
    end
    setDebugStatus(text)
end)

task.spawn(function()
    applyWalkSpeed()
    if Settings.AutoFarm then
        runAutoFarm()
    end
    if Settings.AutoUseToys then
        runToyLoop(setToyStatus)
    end
    if Settings.AntiLagEnabled then
        runAntiLagLoop(setDebugStatus)
    end
end)

task.spawn(function()
    while true do
        local waitSeconds = math.clamp(tonumber(Settings.ConfigAutoSaveDelay) or 20, 5, 120)
        task.wait(waitSeconds)
        if Settings.ConfigAutoSave then
            local ok, msg = saveConfigToFile(Settings.ConfigProfile, false)
            if ok then
                if msg ~= "No changes" then
                    setConfigStatus("autosaved " .. tostring(Settings.ConfigProfile))
                end
            else
                setConfigStatus(msg)
            end
        end
    end
end)
