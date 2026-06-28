-- LaserEyes_Visible_Mobile.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local head = character:WaitForChild("Head")

local enabled = false
local beam = nil
local sparks = nil
local currentLength = 0.5
local maxLength = 60
local speed = 75

-- Создаём кнопку переключения для планшета
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LaserMobileGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 130, 0, 50)
button.Position = UDim2.new(0.05, 0, 0.3, 0)
button.BackgroundColor3 = Color3.new(0.6, 0, 0)
button.Text = "ЛАЗЕРЫ: ВЫКЛ"
button.TextColor3 = Color3.new(1, 1, 1)
button.TextSize = 16
button.Font = Enum.Font.GothamBold
button.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = button

-- Функция создания луча
local function createBeam()
    -- Для максимальной видимости используем SelectionBox или гламурные эффекты внутри персонажа
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.25, 0.25, 0.5)
    part.BrickColor = BrickColor.new("Bright red")
    part.Material = Enum.Material.Neon
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 0.05
    part.Name = "EyeLaser"
    
    local att0 = Instance.new("Attachment", part)
    local att1 = Instance.new("Attachment", part)
    att1.Position = Vector3.new(0, 0, part.Size.Z)
    
    local trail = Instance.new("Trail", part)
    trail.Attachment0 = att0
    trail.Attachment1 = att1
    trail.Color = ColorSequence.new(Color3.new(1, 0, 0))
    trail.Lifetime = 0.08
    
    part.Parent = character -- Кладим в персонажа для репликации
    return part
end

local function createSparks()
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.4, 0.4, 0.4)
    part.BrickColor = BrickColor.new("Bright red")
    part.Material = Enum.Material.Neon
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 0.4
    
    local p = Instance.new("ParticleEmitter", part)
    p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    p.Color = ColorSequence.new(Color3.new(1, 0.1, 0))
    p.Rate = 150
    
    part.Parent = character
    return part
end

-- Обработка нажатия на планшете
button.MouseButton1Click:Connect(function()
    enabled = not enabled
    if enabled then
        button.Text = "ЛАЗЕРЫ: ВКЛ"
        button.BackgroundColor3 = Color3.new(1, 0, 0)
        currentLength = 0.5
    else
        button.Text = "ЛАЗЕРЫ: ВЫКЛ"
        button.BackgroundColor3 = Color3.new(0.6, 0, 0)
        if beam then beam:Destroy() beam = nil end
        if sparks then sparks:Destroy() sparks = nil end
    end
end)

-- Безопасный цикл без Wait() внутри функции
RunService.Heartbeat:Connect(function(deltaTime)
    if not enabled then
        if beam then beam:Destroy() beam = nil end
        if sparks then sparks:Destroy() sparks = nil end
        return
    end
    
    if not head or not head.Parent then return end
    
    if not beam then beam = createBeam() end
    if not sparks then sparks = createSparks() end
    
    local camera = Workspace.CurrentCamera
    local origin = head.Position + head.CFrame.LookVector * 1.8
    local direction = camera.CFrame.LookVector
    
    -- Плавное увеличение длины на основе deltaTime
    currentLength = math.min(currentLength + speed * deltaTime, maxLength)
    
    local endPos = origin + direction * currentLength
    
    beam.Size = Vector3.new(0.25, 0.25, currentLength)
    beam.CFrame = CFrame.lookAt(origin, endPos) * CFrame.new(0, 0, -currentLength/2)
    
    local att1 = beam:FindFirstChild("Attachment")
    if att1 then
        att1.Position = Vector3.new(0, 0, currentLength/2)
    end
    
    if sparks then
        sparks.CFrame = CFrame.lookAt(endPos, endPos + direction)
    end
end)

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    head = character:WaitForChild("Head")
    enabled = false
    button.Text = "ЛАЗЕРЫ: ВЫКЛ"
    button.BackgroundColor3 = Color3.new(0.6, 0, 0)
end)
