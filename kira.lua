local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Создаем RemoteEvent, если его нет
local remoteEvent = ReplicatedStorage:FindFirstChild("IceSpawnRemote") or Instance.new("RemoteEvent", ReplicatedStorage)
remoteEvent.Name = "IceSpawnRemote"

local iceTemplate = Instance.new("Part")
iceTemplate.Name = "IceTemplate"
iceTemplate.Size = Vector3.new(2, 0.4, 2)
iceTemplate.Material = Enum.Material.Ice
iceTemplate.Anchored = true
iceTemplate.CanCollide = false
iceTemplate.Transparency = 0.1
iceTemplate.BrickColor = BrickColor.new("Cyan")

remoteEvent.OnServerEvent:Connect(function(player, pos)
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local ice = iceTemplate:Clone()
    ice.Position = pos - Vector3.new(0, 2.5, 0)
    ice.CFrame = ice.CFrame * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
    ice.Parent = workspace
    
    task.delay(5, function()
        local tween = TweenService:Create(ice, TweenInfo.new(1), {Transparency = 1})
        tween:Play()
        tween.Completed:Connect(function() ice:Destroy() end)
    end)
end)
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remoteEvent = ReplicatedStorage:WaitForChild("IceSpawnRemote")

local player = game.Players.LocalPlayer
local lastSpawn = 0
local cooldown = 0.2 

RunService.Heartbeat:Connect(function()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local root = char.HumanoidRootPart
        -- Проверка, что игрок двигается
        if root.AssemblyLinearVelocity.Magnitude > 5 then
            if tick() - lastSpawn > cooldown then
                remoteEvent:FireServer(root.Position)
                lastSpawn = tick()
            end
        end
    end
end)
