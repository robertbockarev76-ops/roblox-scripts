-- ClientNoclipFly_Touch_Fixed.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local function createButton(text, position, color, callback, releaseCallback)
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
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            callback()
        end
    end)
    
    if releaseCallback then
        frame.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                releaseCallback()
            end
        end)
    end
    return frame
end

-- Кнопки управления
local flyBtn
local noclipBtn

flyBtn = createButton("ПОЛЁТ", UDim2.new(0.05, 0, 0.7, 0), Color3.new(0, 0.8, 0), function()
    flyEnabled = not flyEnabled
    if flyEnabled then
        noclipEnabled = false
        noclipBtn.BackgroundColor3 = Color3.new(0, 0.4, 0.8)
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
        flyBtn.BackgroundColor3 = Color3.new(0, 1, 0)
        flyBtn.BackgroundTransparency = 0.1
    else
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        local bv = rootPart:FindFirstChild("FlyBV")
        if bv then bv:Destroy() end
        flyBtn.BackgroundColor3 = Color3.new(0, 0.8, 0)
        flyBtn.BackgroundTransparency = 0.3
    end
end)

noclipBtn = createButton("НОКЛИП", UDim2.new(0.05, 0, 0.82, 0), Color3.new(0, 0.4, 0.8), function()
    noclipEnabled = not noclipEnabled
    if noclipEnabled then
        flyEnabled = false
        flyBtn.BackgroundColor3 = Color3.new(0, 0.8, 0)
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
        noclipBtn.BackgroundColor3 = Color3.new(0, 0.6, 1)
        noclipBtn.BackgroundTransparency = 0.1
    else
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        local bv = rootPart:FindFirstChild("FlyBV")
        if bv then bv:Destroy() end
        noclipBtn.BackgroundColor3 = Color3.new(0, 0.4, 0.8)
        noclipBtn.BackgroundTransparency = 0.3
    end
end)

-- Виртуальный джойстик для управления движением
local joystickFrame = Instance.new("Frame")
joystickFrame.Size = UDim2.new(0, 140, 0, 140)
joystickFrame.Position = UDim2.new(0.75, 0, 0.65, 0)
joystickFrame.BackgroundColor3 = Color3.new(0, 0, 0)
joystickFrame.BackgroundTransparency = 0.6
joystickFrame.BorderSizePixel = 2
joystickFrame.BorderColor3 = Color3.new(1, 1, 1)
joystickFrame.Parent = screenGui

local joyCorner = Instance.new("UICorner")
joyCorner.CornerRadius = UDim.new(1, 0)
joyCorner.Parent = joystickFrame

local joystickCircle = Instance.new("Frame")
joystickCircle.Size = UDim2.new(0, 50, 0, 50)
joystickCircle.Position = UDim2.new(0.5, -25, 0.5, -25)
joystickCircle.BackgroundColor3 = Color3.new(1, 1, 1)
joystickCircle.BackgroundTransparency = 0.3
joystickCircle.Parent = joystickFrame

local circleCorner = Instance.new("UICorner")
circleCorner.CornerRadius = UDim.new(1, 0)
circleCorner.Parent = joystickCircle

local joystickActive = false
local joystickTouchInput = nil

joystickFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        joystickActive = true
        joystickTouchInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if joystickActive and (input == joystickTouchInput or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local center = joystickFrame.AbsolutePosition + (joystickFrame.AbsoluteSize / 2)
        local inputPos = Vector2.new(input.Position.X, input.Position.Y)
        local delta = inputPos - center
        local maxDist = joystickFrame.AbsoluteSize.X / 2
        
        if delta.Magnitude > maxDist then
            delta = delta.Unit * maxDist
        end
        
        joystickCircle.Position = UDim2.new(0.5, -25 + delta.X, 0.5, -25 + delta.Y)
        
        local normX = delta.X / maxDist
        local normY = delta.Y / maxDist
        
        local camLook = Camera.CFrame.LookVector
        local camRight = Camera.CFrame.RightVector
        local flatLook = Vector3.new(camLook.X, 0, camLook.Z).Unit
        local flatRight = Vector3.new(camRight.X, 0, camRight.Z).Unit
        
        moveVector = flatLook * -normY + flatRight * normX
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if joystickActive and (input == joystickTouchInput or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
        joystickActive = false
        joystickTouchInput = nil
        joystickCircle.Position = UDim2.new(0.5, -25, 0.5, -25)
        moveVector = Vector3.new(0, 0, 0)
    end
end)

-- Кнопки вертикального перемещения (вверх/вниз с удержанием)
createButton("ВВЕРХ ↑", UDim2.new(0.62, 0, 0.68, 0), Color3.new(0.2, 0.8, 0.2), function()
    verticalInput = 1
end, function()
    verticalInput = 0
end)

createButton("ВНИЗ ↓", UDim2.new(0.62, 0, 0.8, 0), Color3.new(0.8, 0.2, 0.2), function()
    verticalInput = -1
end, function()
    verticalInput = 0
end)

-- Основная функция обновления позиции
local function updatePosition(deltaTime)
    if not flyEnabled and not noclipEnabled then 
        local bv = rootPart:FindFirstChild("FlyBV")
        if bv then bv:Destroy() end
        return 
    end
    
    local currentSpeed = flyEnabled and flySpeed or noclipSpeed
    local velocity = moveVector * currentSpeed + Vector3.new(0, verticalInput * currentSpeed, 0)
    
    if flyEnabled then
        local bv = rootPart:FindFirstChild("FlyBV") or Instance.new("BodyVelocity")
        bv.Name = "FlyBV"
        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        bv.Velocity = velocity
        bv.P = 5000
        bv.Parent = rootPart
    elseif noclipEnabled then
        local bv = rootPart:FindFirstChild("FlyBV")
        if bv then bv:Destroy() end
        
        local newPos = rootPart.Position + velocity * deltaTime
        rootPart.CFrame = CFrame.new(newPos) * Camera.CFrame.Rotation
    end
end

RunService.Heartbeat:Connect(function(deltaTime)
    updatePosition(deltaTime)
end)

-- Отключение коллизий при noclip
RunService.Stepped:Connect(function()
    if noclipEnabled and character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    flyEnabled = false
    noclipEnabled = false
end)
