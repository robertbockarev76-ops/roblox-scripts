--[СЕРВЕРНАЯ ЧАСТЬ] – В ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local remoteEvent = Instance.new("RemoteEvent", ReplicatedStorage)
remoteEvent.Name = "IceSpawnRemote"

local iceTemplate = ReplicatedStorage:FindFirstChild("IceTemplate")
if not iceTemplate then
    iceTemplate = Instance.new("Part")
    iceTemplate.Name = "IceTemplate"
    iceTemplate.Size = Vector3.new(2, 0.4, 2)
    iceTemplate.Anchored = true
    iceTemplate.Material = Enum.Material.Ice
    iceTemplate.BrickColor = BrickColor.new("Cyan")
    iceTemplate.Parent = ReplicatedStorage
end

local playerTrails = {}
local ICE_LIFETIME = 8 -- Время жизни в секундах

-- Добавляем Trail к льду
local function addTrailToIce(icePart)
    local att1 = Instance.new("Attachment", icePart)
    att1.Position = Vector3.new(-0.8, 0, 0)
    local att2 = Instance.new("Attachment", icePart)
    att2.Position = Vector3.new(0.8, 0, 0)
    
    local trail = Instance.new("Trail", icePart)
    trail.Attachment0 = att1
    trail.Attachment1 = att2
    trail.Color = ColorSequence.new(Color3.new(0.6, 0.9, 1))
    trail.Lifetime = 1.5
end

remoteEvent.OnServerEvent:Connect(function(player, position)
    if not player.Character then return end
    
    local ice = iceTemplate:Clone()
    ice.Position = position
    ice.CFrame = CFrame.new(position) * CFrame.Angles(0, math.random() * 2 * math.pi, 0)
    ice.Parent = workspace
    addTrailToIce(ice)
    
    if not playerTrails[player.UserId] then playerTrails[player.UserId] = {} end
    table.insert(playerTrails[player.UserId], {part = ice, spawnTime = tick()})
    
    -- Плавное удаление через время
    task.delay(ICE_LIFETIME, function()
        if ice and ice.Parent then
            TweenService:Create(ice, TweenInfo.new(1), {Transparency = 1}):Play()
            Debris:AddItem(ice, 1.1)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    playerTrails[player.UserId] = nil
end)
