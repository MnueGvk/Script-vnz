-- Inicialización y Configuración Global
getgenv().SecureMode = true

-- Cargar WindUI desde GitHub
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Servicios de Roblox
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Configuración Inicial
local targetPlaceId = 139218725767607

if game.PlaceId ~= targetPlaceId then
    warn("Este script solo funciona en el lugar con ID: " .. targetPlaceId)
    -- return
end

-- Función para encontrar comida (Mejorada con más criterios)
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
    local playerPosition = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position
    if playerPosition then
        for _, food in ipairs(potentialFood) do
            local foodPosition = food:IsA("Model") and food.PrimaryPart and food.PrimaryPart.CFrame.Position or food.Position
            if foodPosition then
                local distance = (playerPosition - foodPosition).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    closestFood = food
                end
            end
        end
    end
    return closestFood
end

-- Función para mover con tween (Mejorada: tiempo variable para evadir anti-TP)
local function movePlayerWithTween(targetCFrame)
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    local tweenTime = math.random(3, 8) / 10  -- 0.3-0.8 segundos, variable
    local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    
    local targetPosition = targetCFrame.Position
    local newCFrame = CFrame.new(targetPosition) * (targetCFrame - targetPosition) * CFrame.new(0, 0, -2)
    
    local tween = TweenService:Create(humanoidRootPart, tweenInfo, {CFrame = newCFrame})
    tween:Play()
    local success = tween.Completed:Wait()  -- Espera y verifica si se completó
    if not success then
        warn("Tween interrumpido, posiblemente por anti-TP")
    end
end

-- Función para recoger comida (Corregida: hold completo en ProximityPrompt, verificación de éxito)
local function teleportAndPickUpFood()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    local food = findFoodItem()
    if food then
        local foodCFrame = food:IsA("Model") and food.PrimaryPart and food.PrimaryPart.CFrame or food.CFrame
        if foodCFrame then
            movePlayerWithTween(foodCFrame)
            
            local prompt = food:FindFirstChildOfClass("ProximityPrompt") or (food.Parent and food.Parent:FindFirstChildOfClass("ProximityPrompt"))
            if prompt then
                prompt:InputHoldBegin()
                wait(0.5)  -- Duración del hold, ajusta si es necesario
                prompt:InputHoldEnd()
                print("ProximityPrompt activado para " .. food.Name)
            end
            
            local clickDetector = food:FindFirstChildOfClass("ClickDetector") or (food.Parent and food.Parent:FindFirstChildOfClass("ClickDetector"))
            if clickDetector then
                clickDetector:MouseClick()
                print("ClickDetector activado para " .. food.Name)
            end
            
            -- Verificación de éxito
            wait(0.5)
            if not food:IsDescendantOf(Workspace) then
                print("Comida recogida exitosamente: " .. food.Name)
            else
                warn("Recogida fallida para: " .. food.Name)
            end
        else
            warn("Posición inválida para: " .. food.Name)
        end
    else
        warn("Comida no encontrada")
    end
end

-- Función para encontrar delivery target (Mejorada: filtros para excluir irrelevantes)
local function findDeliveryTarget()
    local deliveryTargets = {}
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") then
            local actionText = descendant.ActionText:lower()
            local objectName = descendant.Parent and descendant.Parent.Name:lower() or ""
            if actionText:match("deliver") or actionText:match("drop off") or actionText:match("turn in") or objectName:match("delivery") or objectName:match("npc") then
                table.insert(deliveryTargets, descendant.Parent)
            end
        end
        
        if descendant:IsA("Model") and descendant:FindFirstChildOfClass("Humanoid") and not descendant:IsDescendantOf(LocalPlayer.Character) then
            -- Filtro: Excluir NPCs con nombres de enemigo
            if not descendant.Name:lower():match("enemy") and not descendant.Name:lower():match("guard") then
                table.insert(deliveryTargets, descendant)
            end
        end
        
        if descendant:IsA("ClickDetector") and (descendant.Parent.Name:lower():match("deliver") or descendant.Parent.Name:lower():match("npc")) then
            table.insert(deliveryTargets, descendant.Parent)
        end
    end
    
    local closestTarget = nil
    local minDistance = math.huge
    local playerPosition = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position
    if playerPosition then
        for _, target in ipairs(deliveryTargets) do
            local targetPosition = target:IsA("Model") and target.PrimaryPart and target.PrimaryPart.Position or target.Position
            if targetPosition then
                local distance = (playerPosition - targetPosition).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    closestTarget = target
                end
            end
        end
    end
    return closestTarget
end

-- Función para entregar (Corregida: igual que recoger, con verificación de éxito)
local function deliverFoodToTarget()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    local deliveryTarget = findDeliveryTarget()
    if deliveryTarget then
        local targetCFrame = deliveryTarget:IsA("Model") and deliveryTarget.PrimaryPart and deliveryTarget.PrimaryPart.CFrame or deliveryTarget.CFrame
        if targetCFrame then
            movePlayerWithTween(targetCFrame)
            
            local prompt = deliveryTarget:FindFirstChildOfClass("ProximityPrompt") or (deliveryTarget.Parent and deliveryTarget.Parent:FindFirstChildOfClass("ProximityPrompt"))
            if prompt then
                prompt:InputHoldBegin()
                wait(0.5)
                prompt:InputHoldEnd()
                print("ProximityPrompt de entrega activado para " .. deliveryTarget.Name)
            end
            
            local clickDetector = deliveryTarget:FindFirstChildOfClass("ClickDetector") or (deliveryTarget.Parent and deliveryTarget.Parent:FindFirstChildOfClass("ClickDetector"))
            if clickDetector then
                clickDetector:MouseClick()
                print("ClickDetector de entrega activado para " .. deliveryTarget.Name)
            end
            
            -- Verificación de éxito (ej: si el inventario cambia o aparece una notificación; ajusta según el juego)
            wait(0.5)
            -- Aquí puedes añadir checks específicos, como si tu "puntuación" aumenta o si aparece un mensaje
            print("Intento de entrega completado para: " .. deliveryTarget.Name)
        else
            warn("Posición inválida para el objetivo de entrega: " .. deliveryTarget.Name)
        end
    else
        warn("Objetivo de entrega no encontrado")
    end
end

-- Función principal de automatización
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
        warn("Error en el ciclo de Auto Delivery: " .. tostring(err))
    end
    
    isRunning = false
end

-- Variable para controlar el estado del toggle
local toggle = false

-- Función para manejar cambios en el toggle
local function onToggleChanged(newState)
    toggle = newState
    if toggle then
        spawn(function()
            while toggle do
                automateFoodDelivery()
                wait(math.random(2, 4))  -- Delay variable para reducir detección
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- CÓDIGO DE LA INTERFAZ GRÁFICA (GUI)
--------------------------------------------------------------------------------

-- Crear la Ventana Principal
local Window = WindUI:CreateWindow({
    Title = "Lorenz0 | Hub",
    Author = "by Lorenz0",
    Folder = nil,
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Title = "Open Lorenz0 hub UI",
        Icon = "monitor",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Color = ColorSequence.new(
            Color3.fromHex("#30FF6A"),
            Color3.fromHex("#e7ff2f")
        )
    }
})

-- Agregar Etiqueta de Versión
Window:Tag({
    Title = "v1.0",
    Color = Color3.fromHex("FF1BF78D")
})

-- Crear Secciones
local ElementsSection = Window:Section({ Title = "Elementos" })
local ConfigUsageSection = Window:Section({ Title = "Configuracion" })
local OtherSection = Window:Section({ Title = "Otros" })

-- Cargar Iconos de Nebula
local NebulaIcons = loadstring(game:HttpGet("https://raw.nebulasoftworks.xyz/nebula-icon-library-loader"))()
WindUI.Creator.AddIcons("fluency", NebulaIcons.Fluency)

-- Pestaña de Delivery (Elementos)
local DeliveryTab = ElementsSection:Tab({ Title = "Delivery", Icon = "box" })

-- Toggle para Auto Delivery (CONECTADO AL CÓDIGO)
DeliveryTab:Toggle({ 
    Title = "Auto Delivery",
    Desc = "Recoge la comida automáticamente y la entrega.",
    Callback = onToggleChanged -- Conecta el toggle a la función de control
})
DeliveryTab:Space()

-- [Resto de tu código de GUI, sin cambios, para mantener la funcionalidad de los otros tabs]

-- Pestaña de Button (Elementos)
local ButtonTab = ElementsSection:Tab({
    Title = "Button",
    Icon = "mouse-pointer-click" })

local HighlightButton
HighlightButton = ButtonTab:Button({
    Title = "Highlight Button",
    Icon = "mouse",
    Callback = function()
        print("clicked highlight")
        HighlightButton:Highlight()
    end
})
ButtonTab:Space()

-- Pestaña de Input (Elementos)
local InputTab = ElementsSection:Tab({ Title = "Input", Icon = "text-cursor-input" })

InputTab:Input({ Title = "Input", Icon = "mouse" })
InputTab:Space()
InputTab:Input({ Title = "Input Textarea", Type = "Textarea", Icon = "mouse" })
InputTab:Space()
InputTab:Input({ Title = "Input Textarea", Type = "Textarea" })
InputTab:Space()
InputTab:Input({ Title = "Input", Desc = "Input example" })
InputTab:Space()
InputTab:Input({ Title = "Input Textarea", Desc = "Input example", Type = "Textarea" })
InputTab:Space()
InputTab:Input({ Title = "Input", Locked = true })
InputTab:Input({ Title = "Input", Desc = "Input example", Locked = true })

-- Pestaña de Config Elements (Configuración)
local ConfigElementsTab = ConfigUsageSection:Tab({
    Title = "Config Elements",
    Icon = "square-dashed-mouse-pointer"
})

ConfigElementsTab:Colorpicker({
    Flag = "ColorpickerTest",
    Title = "Colorpicker",
    Desc = "Colorpicker Description",
    Default = Color3.fromRGB(0, 255, 0),
    Transparency = 0,
    Locked = false,
    Callback = function(color) print("Background color: " .. tostring(color)) end
})
ConfigElementsTab:Space()

ConfigElementsTab:Dropdown({
    Flag = "DropdownTest",
    Title = "Advanced Dropdown",
    Values = {
        { Title = "Category A", Icon = "bird" },
        { Title = "Category B", Icon = "house" },
        { Title = "Category C", Icon = "droplet" },
    },
    Value = "Category A",
    Callback = function(option) print("Category selected: " .. option.Title .. " with icon " .. option.Icon) end
})
ConfigElementsTab:Space()

ConfigElementsTab:Keybind({
    Flag = "KeybindTest",
    Title = "Keybind",
    Desc = "Keybind to open ui",
    Value = "G",
    Callback = function(v) Window:SetToggleKey(Enum.KeyCode[v]) end
})
ConfigElementsTab:Space()

-- Pestaña de Config Usage (Configuración)
local ConfigTab = ConfigUsageSection:Tab({  
    Title = "Config Usage",
    Icon = "folder"
})

local ConfigManager = Window.ConfigManager
local ConfigName = "default"

local ConfigNameInput = ConfigTab:Input({
    Title = "Config Name",
    Icon = "file-cog",
    Callback = function(value) ConfigName = value end
})

local AllConfigs = ConfigManager:AllConfigs()
local DefaultValue = table.find(AllConfigs, ConfigName) and ConfigName or nil

ConfigTab:Dropdown({
    Title = "All Configs",
    Desc = "Select existing configs",
    Values = AllConfigs,
    Value = DefaultValue,
    Callback = function(value)
        ConfigName = value
        ConfigNameInput:Set(value)
    end
})
ConfigTab:Space()
ConfigTab:Button({
    Title = "Save Config",
    Icon = "",
    Justify = "Center",
    Callback = function()
        Window.CurrentConfig = ConfigManager:CreateConfig(ConfigName)
        if Window.CurrentConfig:Save() then
            WindUI:Notify({
                Title = "Config Saved",
                Desc = "Config '" .. ConfigName .. "' saved",
                Icon = "check",
            })
        end
    end
})
ConfigTab:Space()
ConfigTab:Button({
    Title = "Load Config",
    Icon = "",
    Justify = "Center",
    Callback = function()
        Window.CurrentConfig = ConfigManager:CreateConfig(ConfigName)
        if Window.CurrentConfig:Load() then
            WindUI:Notify({
                Title = "Config Loaded",
                Desc = "Config '" .. ConfigName .. "' loaded",
                Icon = "refresh-cw",
            })
        end
    end
})

-- Pestaña de Discord (Otros)
local InviteCode = "ftgs-development-hub-1300692552005189632"
local DiscordAPI = "https://discord.com/api/v10/invites/" .. InviteCode .. "?with_counts=true&with_expiration=true"

local Response = game:GetService("HttpService"):JSONDecode(WindUI.Creator.Request({
    Url = DiscordAPI,
    Method = "GET",
    Headers = {
        ["User-Agent"] = "WindUI/Example",
        ["Accept"] = "application/json"
    }
}).Body)

local DiscordTab = OtherSection:Tab({ Title = "Discord" })

if Response and Response.guild then
    DiscordTab:Section({ Title = "Join our Discord server!", TextSize = 20,})
end