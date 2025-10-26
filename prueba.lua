-- Script Auto Delivery para Veneyork - Versión Indetectable
-- Actualizado para ser más sigiloso: delays largos, movimiento natural, checks de seguridad.

getgenv().SecureMode = true

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

if game.PlaceId ~= 139218725767607 then
    warn("Este script es solo para Veneyork.")
    return
end

-- Función para obtener HumanoidRootPart
local function getHRP()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

local hrp = getHRP()
LocalPlayer.CharacterAdded:Connect(function()
    hrp = getHRP()
end)

-- Posición objetivo (ajusta si cambia)
local targetPos = Vector3.new(151, 44.53, 512.21)

-- Función para encontrar NPC de entrega
local function findDeliveryNPC()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == "DeliveryNPC" and (obj.PrimaryPart.Position - targetPos).Magnitude < 10 then
            return obj
        end
    end
end

-- Función para encontrar comida
local function findFood()
    local shop = Workspace:FindFirstChild("Shop")
    if not shop then return end
    for _, item in ipairs(shop:GetChildren()) do
        local name = item.Name:lower()
        if name == "pizza" or name == "burger" then
            return item
        end
    end
end

-- Movimiento sigiloso: Usa Humanoid:MoveTo para caminar natural
local function moveTo(pos)
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:MoveTo(pos)
        humanoid.MoveToFinished:Wait()
    end
    wait(math.random(1, 3))  -- Delay humano
end

-- Función para recoger comida
local function pickUpFood()
    local food = findFood()
    if not food then return end

    moveTo(food.Position + Vector3.new(0, 5, 0))  -- Posición cerca
    wait(math.random(2, 4))

    -- Simular interacción (en lugar de fireclickdetector, usa ProximityPrompt si existe)
    local prompt = food:FindFirstChildOfClass("ProximityPrompt")
    if prompt then
        prompt:InputHoldBegin()
        wait(prompt.HoldDuration or 1)
        prompt:InputHoldEnd()
    end

    wait(math.random(1, 2))
end

-- Función para entregar
local function deliverFood()
    local npc = findDeliveryNPC()
    if not npc then return end

    moveTo(npc.PrimaryPart.Position + Vector3.new(0, 5, 0))
    wait(math.random(2, 4))

    local prompt = npc:FindFirstChildOfClass("ProximityPrompt")
    if prompt then
        prompt:InputHoldBegin()
        wait(prompt.HoldDuration or 1)
        prompt:InputHoldEnd()
    end

    wait(math.random(1, 2))
end

-- Loop principal con delays largos para indetectabilidad
local running = false
local function startLoop()
    running = true
    while running do
        pickUpFood()
        wait(math.random(10, 20))  -- Pausa larga
        deliverFood()
        wait(math.random(15, 30))  -- Pausa aún más larga entre ciclos
    end
end

-- UI sigilosa: Invisible por defecto, activar solo si es necesario
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "AutoDeliveryGUI"
gui.ResetOnSpawn = false
gui.Enabled = false  -- Invisible por defecto
gui.Parent = PlayerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 200)
frame.Position = UDim2.new(0.7, 0, 0.3, 0)
frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
frame.BackgroundTransparency = 0.2
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.Text = "Auto Delivery - Veneyork"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Parent = frame

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0.8, 0, 0, 50)
toggleBtn.Position = UDim2.new(0.1, 0, 0.4, 0)
toggleBtn.Text = "Iniciar"
toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
toggleBtn.Parent = frame

toggleBtn.MouseButton1Click:Connect(function()
    if running then
        running = false
        toggleBtn.Text = "Iniciar"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    else
        startLoop()
        toggleBtn.Text = "Detener"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    end
end)

-- Activar GUI solo con un comando (ej: en chat)
LocalPlayer.Chatted:Connect(function(msg)
    if msg == "/showgui" then
        gui.Enabled = not gui.Enabled
    end
end)

print("Script cargado sigilosamente. Usa /showgui en chat para mostrar la UI.")