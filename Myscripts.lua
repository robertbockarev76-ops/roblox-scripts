-- ClientNoclipFly_Touch.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Настройки
local flyEnabled = false
local noclipEnabled = false
local flySpeed = 50
local noclipSpeed = 30
local moveVector = Vector3.new(0, 0, 0)
local verticalInput = 0

-- Создаём GUI-кнопки поверх экрана
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyNoclipGUI"
screenGui.Parent = player:WaitForChild("PlayerGui")

local function createButton(text, position, color, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 100, 0, 60)
    frame.Position = position
    frame.BackgroundColor3 = color
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.new(1, 1, 1)
    frame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextSize = 18
    label.Font = Enum.Font.GothamBold
    label.Parent = frame
    
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            callback()
        end
    end)
    return frame
end

-- Кнопки управления
local flyBtn = createButton("ПОЛЁТ", UDim2.new(0.05, 0, 0.8, 0), Color3.new(0, 0.8, 0), function()
    flyEnabled = not flyEnabled
    if flyEnabled then
        noclipEnabled = false
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
        flyBtn.BackgroundColor3 = Color3.new(0, 1, 0)
        flyBtn.BackgroundTransparency = 0.1
    else
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        rootPart:FindFirstChild("FlyBV") and rootPart:FindFirstChild("FlyBV"):Destroy()
        flyBtn.BackgroundColor3 = Color3.new(0, 0.8, 0)
        flyBtn.BackgroundTransparency = 0.3
    end
end)

local noclipBtn = createButton("НОКЛИП", UDim2.new(0.05, 0, 0.9, 0), Color3.new(0, 0.4, 0.8), function()
    noclipEnabled = not noclipEnabled
    if noclipEnabled then
        flyEnabled = false
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
        noclipBtn.BackgroundColor3 = Color3.new(0, 0.6, 1)
        noclipBtn.BackgroundTransparency = 0.1
    else
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        noclipBtn.BackgroundColor3 = Color3.new(0, 0.4, 0.8)
        noclipBtn.BackgroundTransparency = 0.3
    end
end)

-- Виртуальный джойстик для управления движением (касанием)
local joystickFrame = Instance.new("Frame")
joystickFrame.Size = UDim2.new(0, 150, 0, 150)
joystickFrame.Position = UDim2.new(0.8, 0, 0.7, 0)
joystickFrame.BackgroundColor3 = Color3.new(1, 1, 1)
joystickFrame.BackgroundTransparency = 0.7
joystickFrame.BorderSizePixel = 2
joystickFrame.BorderColor3 = Color3.new(0.5, 0.5, 0.5)
joystickFrame.Parent = screenGui

local joystickCircle = Instance.new("Frame")
joystickCircle.Size = UDim2.new(0, 50, 0, 50)
joystickCircle.Position = UDim2.new(0.5, -25, 0.5, -25)
joystickCircle.BackgroundColor3 = Color3.new(1, 1, 1)
joystickCircle.BackgroundTransparency = 0.4
joystickCircle.BorderSizePixel = 0
joystickCircle.Parent = joystickFrame
local circleCorner = Instance.new("UICorner")
circleCorner.CornerRadius = UDim.new(1, 0)
circleCorner.Parent = joystickCircle

local joystickActive = false
local joystickStartPos = Vector2.new(0, 0)

joystickFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        joystickActive = true
        joystickStartPos = input.Position
    end
end)

joystickFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        joystickActive = false
        joystickCircle.Position = UDim2.new(0.5, -25, 0.5, -25)
        moveVector = Vector3.new(0, 0, 0)
        verticalInput = 0
    end
end)

-- Отслеживание перемещения пальца
game:GetService("RunService").RenderStepped:Connect(function()
    if not joystickActive then return end
    local touchPos = UserInputService:GetTouchPositions()
    if #touchPos == 0 then 
        joystickActive = false
        moveVector = Vector3.new(0, 0, 0)
        return 
    end
    
    local touch = touchPos[1]
    local delta = touch - joystickStartPos
    local maxDist = 60
    local clampedDelta = Vector2.new(
        math.clamp(delta.X, -maxDist, maxDist),
        math.clamp(delta.Y, -maxDist, maxDist)
    )
    
    joystickCircle.Position = UDim2.new(0.5, -25 + clampedDelta.X, 0.5, -25 + clampedDelta.Y)
    
    -- Преобразуем в направление движения
    local normX = clampedDelta.X / maxDist
    local normY = clampedDelta.Y / maxDist
    
    local camLook = Camera.CFrame.LookVector
    local camRight = Camera.CFrame.RightVector
    local flatLook = Vector3.new(camLook.X, 0, camLook.Z).Unit
    local flatRight = Vector3.new(camRight.X, 0, camRight.Z).Unit
    
    moveVector = flatLook * -normY + flatRight * normX
    verticalInput = 0
end)

-- Кнопки вертикального перемещения (вверх/вниз)
local upBtn = createButton("↑", UDim2.new(0.75, 0, 0.6, 0), Color3.new(0.2, 0.8, 0.2), function()
    verticalInput = 1
end)
local downBtn = createButton("↓", UDim2.new(0.75, 0, 0.68, 0), Color3.new(0.8, 0.2, 0.2), function()
    verticalInput = -1
end)

-- Основная функция обновления позиции
local function updatePosition(deltaTime)
    if not flyEnabled and not noclipEnabled then return end
    
    local currentSpeed = flyEnabled and flySpeed or noclipSpeed
    local velocity = moveVector * currentSpeed + Vector3.new(0, verticalInput * currentSpeed, 0)
    
    -- Применяем BodyVelocity
    local bv = rootPart:FindFirstChild("FlyBV") or Instance.new("BodyVelocity")
    bv.Name = "FlyBV"
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Velocity = velocity * (flyEnabled and 1 or 0.7)
    bv.P = 5000
    bv.Parent = rootPart
    
    if noclipEnabled then
        local newPos = rootPart.Position + velocity * deltaTime
        rootPart.CFrame = CFrame.new(newPos) * rootPart.CFrame.Rotation
    end
end

-- Цикл обновления
RunService.Heartbeat:Connect(function(deltaTime)
    if flyEnabled or noclipEnabled then
        updatePosition(deltaTime)
    end
end)

-- Отключение коллизий при noclip
local function setCollision(state)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = state
            part.CanTouch = state
        end
    end
end

-- Включаем отключение коллизий если noclip активен
game:GetService("RunService").Stepped:Connect(function()
    if noclipEnabled then
        setCollision(false)
    end
end)

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    flyEnabled = false
    noclipEnabled = false
    humanoid.PlatformStand = false
end)
