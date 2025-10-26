-- ==============================
-- CONFIGURACIÓN INICIAL (PASIVA)
-- ==============================

getgenv().SecureMode = true

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local targetPlaceId = 139218725767607
if game.PlaceId ~= targetPlaceId then
    warn("Este script solo funciona en el lugar con ID: " .. targetPlaceId)
end

-- ==============================
-- FUNCIONES DE AUTO DELIVERY (SOLO CUANDO SE ACTIVA)
-- ==============================

local function findFoodItem()
    local potentialFood = {}
    for _, item in ipairs(Workspace:GetChildren()) do
        local nameLower = item.Name:lower()
        if (item:IsA("Model") or item:IsA("BasePart")) and not item:IsDescendantOf(LocalPlayer.Character) then
            if nameLower:match("box") or nameLower:match("crate") or nameLower:match("food") or nameLower:match("delivery") or nameLower:match("order") then
                table.insert(potentialFood, item)
            end
            if item:FindFirstChildOfClass("ClickDetector") or item:FindFirstChildOfClass("ProximityPrompt") then
                table.insert(potentialFood, item)
            end
        end
    end

    local closestFood = nil
    local minDistance = math.huge
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root then
        local playerPos = root.Position
        for _, food in ipairs(potentialFood) do
            local foodPos = food:IsA("Model") and food.PrimaryPart and food.PrimaryPart.Position or food.Position
            if foodPos then
                local dist = (playerPos - foodPos).Magnitude
                if dist < minDistance then
                    minDistance = dist
                    closestFood = food
                end
            end
        end
    end
    return closestFood
end

local function movePlayerWithTween(targetCFrame)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local targetPos = targetCFrame.Position
    local distance = (hrp.Position - targetPos).Magnitude

    if distance < 50 then
        humanoid:MoveTo(targetPos)
        humanoid.MoveToFinished:Wait()
    else
        local time = math.random(15, 25) / 10  -- Más lento: 1.5-2.5 segundos
        local info = TweenInfo.new(time, Enum.EasingStyle.Linear)
        local newCF = CFrame.new(targetPos) * CFrame.new(0, 0, -2)
        local tween = TweenService:Create(hrp, info, {CFrame = newCF})
        tween:Play()
        local success = tween.Completed:Wait()
        if not success then
            warn("Tween interrumpido – pausando")
            wait(10)
        end
    end
end

local function teleportAndPickUpFood()
    local food = findFoodItem()
    if not food then
        warn("Comida no encontrada")
        return
    end

    local cframe = food:IsA("Model") and food.PrimaryPart and food.PrimaryPart.CFrame or food.CFrame
    if not cframe then
        warn("Posición inválida para:", food.Name)
        return
    end

    movePlayerWithTween(cframe)
    wait(math.random(2, 4))  -- Delays más largos

    local prompt = food:FindFirstChildOfClass("ProximityPrompt") or (food.Parent and food.Parent:FindFirstChildOfClass("ProximityPrompt"))
    if prompt then
        prompt:InputHoldBegin()
        wait(0.5)
        prompt:InputHoldEnd()
        print("✅ ProximityPrompt activado:", food.Name)
    end

    local click = food:FindFirstChildOfClass("ClickDetector") or (food.Parent and food.Parent:FindFirstChildOfClass("ClickDetector"))
    if click then
        fireclickdetector(click)
        print("✅ ClickDetector activado:", food.Name)
    end

    wait(math.random(2, 5))
    if not food:IsDescendantOf(Workspace) then
        print("📦 Comida recogida:", food.Name)
    else
        warn("❌ Recogida fallida:", food.Name)
    end
end

local function findDeliveryTarget()
    local targets = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local action = obj.ActionText:lower()
            local parentName = obj.Parent and obj.Parent.Name:lower() or ""
            if action:match("deliver") or action:match("drop off") or action:match("turn in") or parentName:match("delivery") or parentName:match("npc") then
                table.insert(targets, obj.Parent)
            end
        elseif obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and not obj:IsDescendantOf(LocalPlayer.Character) then
            local name = obj.Name:lower()
            if not name:match("enemy") and not name:match("guard") then
                table.insert(targets, obj)
            end
        elseif obj:IsA("ClickDetector") and obj.Parent then
            local pName = obj.Parent.Name:lower()
            if pName:match("deliver") or pName:match("npc") then
                table.insert(targets, obj.Parent)
            end
        end
    end

    local closest = nil
    local minDist = math.huge
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root then
        local pos = root.Position
        for _, t in ipairs(targets) do
            local tPos = t:IsA("Model") and t.PrimaryPart and t.PrimaryPart.Position or t.Position
            if tPos then
                local d = (pos - tPos).Magnitude
                if d < minDist then
                    minDist = d
                    closest = t
                end
            end
        end
    end
    return closest
end

local function deliverFoodToTarget()
    local target = findDeliveryTarget()
    if not target then
        warn("Objetivo de entrega no encontrado")
        return
    end

    local cframe = target:IsA("Model") and target.PrimaryPart and target.PrimaryPart.CFrame or target.CFrame
    if not cframe then
        warn("Posición inválida para entrega:", target.Name)
        return
    end

    movePlayerWithTween(cframe)
    wait(math.random(2, 4))

    local prompt = target:FindFirstChildOfClass("ProximityPrompt") or (target.Parent and target.Parent:FindFirstChildOfClass("ProximityPrompt"))
    if prompt then
        prompt:InputHoldBegin()
        wait(0.5)
        prompt:InputHoldEnd()
        print("📤 Entrega activada (Prompt):", target.Name)
    end

    local click = target:FindFirstChildOfClass("ClickDetector") or (target.Parent and target.Parent:FindFirstChildOfClass("ClickDetector"))
    if click then
        fireclickdetector(click)
        print("📤 Entrega activada (Click):", target.Name)
    end

    wait(math.random(2, 5))
    print("✅ Intento de entrega completado:", target.Name)
end

local isRunning = false
local function automateFoodDelivery()
    if isRunning then return end
    isRunning = true
    local success, err = pcall(function()
        teleportAndPickUpFood()
        wait(math.random(3, 6))
        deliverFoodToTarget()
        wait(math.random(4, 8))
    end)
    if not success then
        warn("Error en Auto Delivery:", err)
    end
    isRunning = false
end

local toggle = false
local function onToggleChanged(state)
    toggle = state
    if toggle then
        spawn(function()
            while toggle do
                automateFoodDelivery()
                wait(math.random(8, 15))  -- Loop mucho menos frecuente
            end
        end)
    end
end

-- ==============================
-- CREAR MENÚ OPTIMIZADO (SOLO UI, NADA MÁS)
-- ==============================

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Crear ScreenGui principal
local MenuGui = Instance.new("ScreenGui")
MenuGui.Name = "Lorenz0Hub"
MenuGui.ResetOnSpawn = false
MenuGui.Parent = PlayerGui

-- Frame principal del menú
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 300, 0, 400)
MainFrame.Position = UDim2.new(0.8, 0, 0.1, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
MainFrame.BackgroundTransparency = 0.1
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(0, 255, 0)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = MenuGui

-- Título
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "Title"
TitleLabel.Size = UDim2.new(1, 0, 0, 50)
TitleLabel.Position = UDim2.new(0, 0, 0, 0)
TitleLabel.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
TitleLabel.Text = "Lorenz0 | Hub v1.0"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextScaled = true
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.Parent = MainFrame

-- Sección Auto Delivery
local AutoDeliveryFrame = Instance.new("Frame")
AutoDeliveryFrame.Name = "AutoDelivery"
AutoDeliveryFrame.Size = UDim2.new(1, -20, 0, 100)
AutoDeliveryFrame.Position = UDim2.new(0, 10, 0, 60)
AutoDeliveryFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
AutoDeliveryFrame.BackgroundTransparency = 0.2
AutoDeliveryFrame.Parent = MainFrame

local AutoDeliveryLabel = Instance.new("TextLabel")
AutoDeliveryLabel.Size = UDim2.new(1, 0, 0, 30)
AutoDeliveryLabel.Position = UDim2.new(0, 0, 0, 0)
AutoDeliveryLabel.BackgroundTransparency = 1
AutoDeliveryLabel.Text = "Auto Delivery"
AutoDeliveryLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoDeliveryLabel.TextScaled = true
AutoDeliveryLabel.Font = Enum.Font.SourceSans
AutoDeliveryLabel.Parent = AutoDeliveryFrame

local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "Toggle"
ToggleButton.Size = UDim2.new(0.8, 0, 0, 50)
ToggleButton.Position = UDim2.new(0.1, 0, 0, 35)
ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
ToggleButton.Text = "OFF"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextScaled = true
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.Parent = AutoDeliveryFrame

ToggleButton.MouseButton1Click:Connect(function()
    toggle = not toggle
    if toggle then
        ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        ToggleButton.Text = "ON"
        onToggleChanged(true)
    else
        ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        ToggleButton.Text = "OFF"
        onToggleChanged(false)
    end
end)

-- Espacio Futuro (Frame vacío para añadir funciones nuevas)
local EspacioFuturo = Instance.new("Frame")
EspacioFuturo.Name = "EspacioFuturo"
EspacioFuturo.Size = UDim2.new(1, -20, 0, 200)
EspacioFuturo.Position = UDim2.new(0, 10, 0, 170)
EspacioFuturo.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
EspacioFuturo.BackgroundTransparency = 0.5
EspacioFuturo.Parent = MainFrame

local FuturoLabel = Instance.new("TextLabel")
FuturoLabel.Size = UDim2.new(1, 0, 0, 30)
FuturoLabel.Position = UDim2.new(0, 0, 0, 0)
FuturoLabel.BackgroundTransparency = 1
FuturoLabel.Text = "Espacio Futuro (Añade funciones aquí)"
FuturoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
FuturoLabel.TextScaled = true
FuturoLabel.Font = Enum.Font.SourceSans
FuturoLabel.Parent = EspacioFuturo

print("✅ Menú de Lorenz0 cargado correctamente (versión sigilosa)")
