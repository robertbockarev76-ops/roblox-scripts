local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local ICE_TAG = "IceFootprint"
local remoteEvent = ReplicatedStorage:FindFirstChild("IceFootstepRemote") or Instance.new("RemoteEvent", ReplicatedStorage)
remoteEvent.Name = "IceFootstepRemote"

local activeFootsteps = {}

local function createIcePart(position)
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.8, 0.1, 0.8)
    part.Material = Enum.Material.Ice
    part.Color = Color3.fromHex("#8CD4F0")
    part.Anchored = true
    part.CanCollide = false
    part.CFrame = CFrame.new(position)
    part.Parent = workspace
    return part
end

remoteEvent.OnServerEvent:Connect(function(player, position)
    if not player.Character or (player.Character.HumanoidRootPart.Position - position).Magnitude > 20 then return end
    
    local ice = createIcePart(position)
    CollectionService:AddTag(ice, ICE_TAG)
    
    task.delay(8, function()
        if ice then
            TweenService:Create(ice, TweenInfo.new(1.5), {Transparency = 1}):Play()
            task.wait(1.5)
            ice:Destroy()
        end
    end)
end)
