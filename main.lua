-- ==============================
-- CARGA SEGURA DE WINDUI
-- ==============================

local success, winduiErr = pcall(function()
    getgenv().SecureMode = true
    _G.WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/main.lua"))()
end)

if not success then
    warn("🚨 Falló la carga de WindUI:", winduiErr)
    return
end

local WindUI = _G.WindUI

-- ==============================
-- SERVICIOS Y CONFIGURACIÓN
-- ==============================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local targetPlaceId = 139218725767607
if game.PlaceId ~= targetPlaceId then
    warn("Este script solo funciona en el lugar con ID: " .. targetPlaceId)
    -- Puedes descomentar el return si quieres bloquear la GUI fuera del lugar
end

-- ==============================
-- FUNCIONES DE AUTO DELIVERY
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
    local time = math.random(3, 8) / 10
    local info = TweenInfo.new(time, Enum.EasingStyle.Linear)
    local pos = targetCFrame.Position
    -- Corregido: Simplifica el offset para evitar errores
    local newCF = CFrame.new(pos) * CFrame.new(0, 0, -2)
    local tween = TweenService:Create(hrp, info, {CFrame = newCF})
    tween:Play()
    tween.Completed:Wait()
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

    local prompt = food:FindFirstChildOfClass("ProximityPrompt") or (food.Parent and food.Parent:FindFirstChildOfClass("ProximityPrompt"))
    if prompt then
        prompt:InputHoldBegin()
        wait(0.5)
        prompt:InputHoldEnd()
        print("✅ ProximityPrompt activado:", food.Name)
    end

    local click = food:FindFirstChildOfClass("ClickDetector") or (food.Parent and food.Parent:FindFirstChildOfClass("ClickDetector"))
    if click then
        -- Corregido: Usa fireclickdetector (compatible con más executors)
        fireclickdetector(click)
        print("✅ ClickDetector activado:", food.Name)
    end

    wait(0.5)
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

    local prompt = target:FindFirstChildOfClass("ProximityPrompt") or (target.Parent and target.Parent:FindFirstChildOfClass("ProximityPrompt"))
    if prompt then
        prompt:InputHoldBegin()
        wait(0.5)
        prompt:InputHoldEnd()
        print("📤 Entrega activada (Prompt):", target.Name)
    end

    local click = target:FindFirstChildOfClass("ClickDetector") or (target.Parent and target.Parent:FindFirstChildOfClass("ClickDetector"))
    if click then
        -- Corregido: Usa fireclickdetector
        fireclickdetector(click)
        print("📤 Entrega activada (Click):", target.Name)
    end

    wait(0.5)
    print("✅ Intento de entrega completado:", target.Name)
end

local isRunning = false
local function automateFoodDelivery()
    if isRunning then return end
    isRunning = true
    local success, err = pcall(function()
        teleportAndPickUpFood()
        wait(0.5)
        deliverFoodToTarget()
        wait(1)
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
                wait(math.random(2, 4))
            end
        end)
    end
end

-- ==============================
-- CREAR GUI (SIEMPRE SE CREA)
-- ==============================

local Window = WindUI:CreateWindow({
    Title = "Lorenz0 | Hub",
    Author = "by Lorenz0",
    OpenButton = {
        Title = "Open Lorenz0 Hub",
        Icon = "monitor",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Color = ColorSequence.new(Color3.fromHex("#30FF6A"), Color3.fromHex("#e7ff2f"))
    }
})

Window:Tag({ Title = "v1.0", Color = Color3.fromRGB(26, 255, 141) })

local ElementsSection = Window:Section({ Title = "Elementos" })
local ConfigSection = Window:Section({ Title = "Configuración" })
local OtherSection = Window:Section({ Title = "Otros" })

-- Cargar íconos (opcional, no crítico)
local successIcons, NebulaIcons = pcall(function()
    return loadstring(game:HttpGet("https://raw.nebulasoftworks.xyz/nebula-icon-library-loader"))()
end)

if successIcons and NebulaIcons and NebulaIcons.Fluency then
    WindUI.Creator.AddIcons("fluency", NebulaIcons.Fluency)
end

-- Pestaña Delivery
local DeliveryTab = ElementsSection:Tab({ Title = "Delivery", Icon = "box" })
DeliveryTab:Toggle({
    Title = "Auto Delivery",
    Desc = "Recoge y entrega comida automáticamente.",
    Callback = onToggleChanged
})
DeliveryTab:Space()

-- Botón de prueba
local ButtonTab = ElementsSection:Tab({ Title = "Pruebas", Icon = "test-tube" })
ButtonTab:Button({
    Title = "Test Button",
    Callback = function() print("Botón de prueba funcionando") end
})

-- Sección de Discord (sin romper si falla)
local DiscordTab = OtherSection:Tab({ Title = "Discord" })
DiscordTab:Button({
    Title = "Unirse al Discord",
    Callback = function()
        setclipboard("https://discord.gg/ftgs-development-hub-1300692552005189632")
        WindUI:Notify({
            Title = "Enlace copiado",
            Desc = "¡Únete a nuestro servidor!",
            Icon = "users"
        })
    end
})

print("✅ GUI de Lorenz0 cargada correctamente")
