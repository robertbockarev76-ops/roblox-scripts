-- LaserEyesClient_Fixed_For_Delta.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local head = character:WaitForChild("Head")

local laserEnabled = false
local laserBeam = nil
local sparkEmitter = nil
local beamLength = 0
local targetLength = 100 -- Увеличили дальность лазера
local expandSpeed = 80

-- Создаём GUI-кнопку для мобилок/планшетов
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LaserEyesGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local buttonFrame = Instance.new("Frame")
buttonFrame.Size = UDim2.new(0, 120, 0, 60)
buttonFrame.Position = UDim2.new(0.05, 0, 0.4, 0) -- Слева на экране
buttonFrame.BackgroundColor3 = Color3.new(0.5, 0, 0)
buttonFrame.BackgroundTransparency = 0.3
buttonFrame.BorderSizePixel = 2
buttonFrame.BorderColor3 = Color3.new(1, 0, 0)
buttonFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = buttonFrame

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Text = "ЛАЗЕРЫ: ВЫКЛ"
label.TextColor3 = Color3.new(1, 1, 1)
label.TextSize = 16
label.Font = Enum.Font.GothamBold
label.Parent = buttonFrame

-- Создание лазерного луча
local function createLaserBeam()
    local beam = Instance.new("Part")
    beam.Name = "EyeLaser"
    beam.Size = Vector3.new(0.3, 0.3, 0.5)
    beam.BrickColor = BrickColor.new("Bright red")
    beam.Material = Enum.Material.Neon
    beam.Anchored = true
    beam.CanCollide = false
    beam.Transparency = 0.1
    
    local att0 = Instance.new("Attachment", beam)
    att0.Name = "Att0"
    local att1 = Instance.new("Attachment", beam)
    att1.Name = "Att1"
    att1.Position = Vector3.new(0, 0, beam.Size.Z)
    
    local trail = Instance.new("Trail", beam)
    trail.Attachment0 = att0
    trail.Attachment1 = att1
    trail.Color = ColorSequence.new(Color3.new(1, 0, 0))
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.5, 0.3),
        NumberSequenceKeypoint.new(1, 0.9)
    })
    trail.Lifetime = 0.1
    
    local pointLight = Instance.new("PointLight", beam)
    pointLight.Color = Color3.new(1, 0, 0)
    pointLight.Range = 15
    pointLight.Brightness = 3
    
    beam.Parent = workspace
    return beam
end

-- Создание искр в точке попадания
local function createSparkEmitter()
    local emitter = Instance.new("Part")
    emitter.Name = "LaserSparks"
    emitter.Size = Vector3.new(0.5, 0.5, 0.5)
    emitter.Anchored = true
    emitter.CanCollide = false
    emitter.Transparency = 1 -- Полностью невидимый блок-источник
    
    local particle = Instance.new("ParticleEmitter", emitter)
    particle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particle.Color = ColorSequence.new(Color3.new(1, 0.2, 0))
    particle.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, 0.1)
    })
    particle.Lifetime = NumberRange.new(0.2, 0.5)
    particle.Rate = 150
    particle.Speed = NumberRange.new(5, 10)
    
    emitter.Parent = workspace
    return emitter
end

-- Логика переключения кнопки
buttonFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        laserEnabled = not laserEnabled
        if laserEnabled then
            label.Text = "ЛАЗЕРЫ: ВКЛ"
            buttonFrame.BackgroundColor3 = Color3.new(1, 0, 0)
            beamLength = 0.5
        else
            label.Text = "ЛАЗЕРЫ: ВЫКЛ"
            buttonFrame.BackgroundColor3 = Color3.new(0.5, 0, 0)
            if laserBeam then laserBeam:Destroy() laserBeam = nil end
            if sparkEmitter then sparkEmitter:Destroy() sparkEmitter = nil end
        end
    end
end)

-- Основной цикл работы лазера
RunService.Heartbeat:Connect(function(deltaTime)
    if not laserEnabled then return end
    
    if not head or not head.Parent then return end
    
    if not laserBeam then laserBeam = createLaserBeam() end
    if not sparkEmitter then sparkEmitter = createSparkEmitter() end
    
    local cam = workspace.CurrentCamera
    local origin = head.Position + head.CFrame.LookVector * 1.5
    local direction = cam.CFrame.LookVector
    
    -- Плавное удлинение луча без просадки FPS
    beamLength = math.min(beamLength + (expandSpeed * deltaTime), targetLength)
    
    -- Проверка препятствий (чтобы лазер не пролетал сквозь стены)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {character, laserBeam, sparkEmitter}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local raycastResult = workspace:Raycast(origin, direction * beamLength, raycastParams)
    local endPos = origin + direction * beamLength
    
    if raycastResult then
        endPos = raycastResult.Position
        local hitLength = (origin - endPos).Magnitude
        laserBeam.Size = Vector3.new(0.3, 0.3, hitLength)
        sparkEmitter.Position = endPos
        sparkEmitter.ParticleEmitter.Enabled = true
    else
        laserBeam.Size = Vector3.new(0.3, 0.3, beamLength)
        sparkEmitter.ParticleEmitter.Enabled = false
    end
    
    laserBeam.CFrame = CFrame.lookAt(origin, endPos) * CFrame.new(0, 0, -laserBeam.Size.Z / 2)
    
    local att1 = laserBeam:FindFirstChild("Att1")
    if att1 then
        att1.Position = Vector3.new(0, 0, laserBeam.Size.Z)
    end
end)

-- Сброс при смерти
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    head = character:WaitForChild("Head")
    laserEnabled = false
    label.Text = "ЛАЗЕРЫ: ВЫКЛ"
    buttonFrame.BackgroundColor3 = Color3.new(0.5, 0, 0)
    if laserBeam then laserBeam:Destroy() laserBeam = nil end
    if sparkEmitter then sparkEmitter:Destroy() sparkEmitter = nil end
end)
