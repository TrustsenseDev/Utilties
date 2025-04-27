-- https://discord.gg/AUmmjk4HAe

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestUtil = require(ReplicatedStorage.Shared.Utils.Stats.QuestUtil)
local CompetitiveShared = require(ReplicatedStorage.Shared.Data.CompetitiveShared)
local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)

local event = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Framework"):WaitForChild("Network"):WaitForChild("Remote"):WaitForChild("Event")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local player = Players.LocalPlayer

local CompetitiveQuests = {}

function CompetitiveQuests:GetCurrentQuests()
    local playerData = LocalData:Get()
    if not playerData then return {} end
    
    local competitive = playerData.Competitive
    if not competitive then return {} end
    
    local seasonId = CompetitiveShared:GetSeason()
    if not seasonId then return {} end
    
    local quests = {}
    for i = 1, 4 do
        local questId = CompetitiveShared.QuestKey .. "-" .. i
        local quest = QuestUtil:FindById(playerData, questId)
        
        if quest then
            local progress = quest.Progress[1]
            local requirement = QuestUtil:GetRequirement(quest.Tasks[1])
            
            local description = QuestUtil:FormatTask(quest.Tasks[1])
            
            table.insert(quests, {
                index = i,
                id = questId,
                description = description,
                progress = progress,
                requirement = requirement,
                permanent = i <= 2,
                reward = quest.Rewards[1],
                task = quest.Tasks[1]
            })
        end
    end
    
    return quests
end

local function LerpToPosition(targetPosition, duration)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = humanoid and humanoid.RootPart

    if not humanoid or not rootPart then
        return false
    end

    local distance = (rootPart.Position - targetPosition).Magnitude
    if distance < 5 then
        return true
    end

    local tweenInfo = TweenInfo.new(
        duration or 1.0,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.Out
    )

    local targetCFrame = CFrame.new(targetPosition)
    
    local currentOrientation = rootPart.CFrame - rootPart.Position
    targetCFrame = targetCFrame * currentOrientation

    local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = targetCFrame})

    local success = pcall(function()
        tween:Play()
        tween.Completed:Wait()
    end)

    if not success then
        return false
    end
    
    task.wait(0.1)
    return true
end

local AutoCompetitive = {}

function AutoCompetitive:Start()
    if self.Running then return end
    self.Running = true
    
    task.spawn(function()
        while self.Running do
            self:ProcessQuests()
            task.wait(1)
        end
    end)
end

function AutoCompetitive:Stop()
    self.Running = false
end

function AutoCompetitive:ProcessQuests()
    local quests = CompetitiveQuests:GetCurrentQuests()
    if #quests == 0 then return end

    local rerollOccurred = false
    for _, quest in ipairs(quests) do
        if quest.index == 3 or quest.index == 4 then
            local shouldReroll = false
            if quest.task.Type ~= "Hatch" or not quest.task.Egg then
                shouldReroll = true
                event:FireServer("CompetitiveReroll", quest.index)
                rerollOccurred = true
            elseif quest.task.Type == "Hatch" and quest.task.Egg and quest.requirement > 450 then
                shouldReroll = true
                event:FireServer("CompetitiveReroll", quest.index)
                rerollOccurred = true
            end
        end
    end

    if rerollOccurred then
        return 
    end

    local specificHatchQuests = {}
    for _, quest in ipairs(quests) do
        if quest.task.Type == "Hatch" and quest.task.Egg and quest.progress < quest.requirement then
            table.insert(specificHatchQuests, quest)
        end
    end

    if #specificHatchQuests > 0 then
        table.sort(specificHatchQuests, function(a, b)
            return a.requirement < b.requirement
        end)
        
        self:HandleHatchQuest(specificHatchQuests[1])
        return
    end

    for _, quest in ipairs(quests) do
        if quest.task.Type == "Hatch" and not quest.task.Egg and not quest.task.Shiny and quest.progress < quest.requirement then
            self:HandleGenericHatchQuest(quest)
            return
        end
    end

    for _, quest in ipairs(quests) do
        if quest.task.Type == "Hatch" and quest.task.Shiny and quest.progress < quest.requirement then
            self:HandleGenericHatchQuest(quest)
            return
        end
    end
end

function AutoCompetitive:HandleHatchQuest(quest)
    local eggModel = self:FindEggModel(quest.task.Egg)
    if not eggModel or not eggModel.Root then
        return
    end

    local targetOffset = (player.Character.HumanoidRootPart.Position - eggModel.Root.Position).Unit * 5
    local targetPosition = eggModel.Root.Position + targetOffset + Vector3.new(0, 0.5, 0)

    local lerpSuccess = LerpToPosition(targetPosition, 5.0)

    if lerpSuccess then
        local hatchAmount = self:GetMaxHatchAmount()
        event:FireServer("HatchEgg", quest.task.Egg, hatchAmount)
        task.wait(0.1)
    end
end

function AutoCompetitive:HandleGenericHatchQuest(quest)
    local infinityEgg = self:FindEggModel("Infinity Egg")
    if not infinityEgg or not infinityEgg.Root then
        return
    end

    local targetOffset = (player.Character.HumanoidRootPart.Position - infinityEgg.Root.Position).Unit * 5
    local targetPosition = infinityEgg.Root.Position + targetOffset + Vector3.new(0, 0.5, 0)

    local lerpSuccess = LerpToPosition(targetPosition, 5.0)

    if lerpSuccess then
        local hatchAmount = self:GetMaxHatchAmount()
        event:FireServer("HatchEgg", "Infinity Egg", hatchAmount)
        task.wait(0.1)
    end
end

function AutoCompetitive:FindEggModel(eggName)
    local workspace = game:GetService("Workspace")
    local rendered = workspace.Rendered
    
    if rendered:GetChildren()[12] then
        local eggContainer = rendered:GetChildren()[12]
        
        if eggContainer:FindFirstChild(eggName) then
            return eggContainer:FindFirstChild(eggName)
        end
        
        for _, child in pairs(eggContainer:GetChildren()) do
            if child.Name == eggName then
                return child
            end
        end
    end
    
    for _, model in pairs(rendered:GetChildren()) do
        if model.Name == eggName then
            return model
        end
        
        local found = model:FindFirstChild(eggName)
        if found then
            return found
        end
    end
    
    return nil
end

function AutoCompetitive:GetMaxHatchAmount()
    local playerData = LocalData:Get()
    if not playerData then return 1 end
    
    local statsUtil = require(ReplicatedStorage.Shared.Utils.Stats.StatsUtil)
    return statsUtil:GetMaxEggHatches(playerData) or 1
end

AutoCompetitive:Start()