--[[

	TryOn Ver. 1.0
	A mannequin interaction system.
	Developed by Aerosphia

]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Event = ReplicatedStorage.TryOn:FindFirstChild("TryOn Event")
local Function = ReplicatedStorage.TryOn:FindFirstChild("TryOn Function")

local Connections = {}
local PermConnections = {}

local Folder = workspace.Mannequins
local Tool = ReplicatedStorage.TryOn["Shopping Bag"]

local Util = require(ReplicatedStorage.Shared.Util)
local Key = require(ServerStorage.Storage.Modules.Key)

do
	for _, model in ipairs(Folder:GetChildren()) do
		model:SetAttribute("PI", Key.new(10))
	end
end

local serverConfig = setmetatable({
	Keys = {},
	templatePrefix = "http://www.roblox.com/asset/?id=%d",
	toolName = "Shopping Bag",
	originalClothes = {},
	bagsEquipped = {},
}, {
	__index = function(_, indx: string)
		error(
			(
				"Try On::serverConfigError: Attempt to get serverConfig value with a nil index. -> serverConfig[%s]?\n\n%s"
			):format(indx, debug.traceback())
		)
	end,

	__newindex = function(_, indx: string, val: any)
		error(
			("Try On::serverConfigError: New items are disallowed! -> Operation (serverConfig[%s] = %s) failed.\n\n%s"):format(
				indx,
				tostring(val),
				debug.traceback()
			)
		)
	end,
})

local function makeLibraryMeta(Name: string): ({ [string]: (...any) -> (nil) })
	return {
		__index = function(_, indx: string)
			error(
				("Try On::inBuiltLibraryError: %s is not a function of %s.\n\n%s"):format(indx, Name, debug.traceback())
			)
		end,
	}
end

local Templates = setmetatable({}, makeLibraryMeta("Templates"))

function Templates.New(Shirt: number, Pant: number): ({ [string]: number })
	return {
		TemplateS = Shirt,
		TemplateP = Pant,
	}
end

local function getId(Object: Instance): (number | string)
	local result = Object:GetAttribute("ID")
	return result or "nil"
end

local function isBagEquipped(Player: Player): (boolean)
	return serverConfig.bagsEquipped[Player.Name]
end

local function onClicked(
	Player: Player,
	shirtId: number,
	pantsId: number,
	templateTable: { [string]: number },
	character: Model
): ()
	if isBagEquipped(Player) then
		Event:FireClient(Player, "Open", shirtId, pantsId, templateTable, character)
	end
end

local function customOnMouseClick(Player: Player, TheirTool: Tool)
	local _, MouseTarget = pcall(Function.InvokeClient, Function, Player, "MouseTarget")
	local shirt, pants
	if isBagEquipped(Player) then
		if
			MouseTarget
			and (
				MouseTarget:FindFirstChildOfClass("ClickDetector")
				or MouseTarget.Parent:FindFirstChildOfClass("ClickDetector")
			)
		then
			local ClickDetector = MouseTarget:FindFirstChildOfClass("ClickDetector")
				or MouseTarget.Parent:FindFirstChildOfClass("ClickDetector")
			shirt, pants = ClickDetector.Parent.Shirt, ClickDetector.Parent.Pants
			if Util:FindAbsoluteAncestor(Folder, ClickDetector) then
				if
					(TheirTool.Handle.Position - MouseTarget.Position).Magnitude <= ClickDetector.MaxActivationDistance
				then
					onClicked(
						Player,
						getId(shirt),
						getId(pants),
						Templates.New(shirt.ShirtTemplate:match("%d+"), pants.PantsTemplate:match("%d+")),
						ClickDetector.Parent.Parent
					)
				end
			end
		end
	end
end

Event.OnServerEvent:Connect(function(Player: Player, ClientKey: string, Starter: string, ...: any)
	local Data = { ... }
	if serverConfig.Keys[Player.UserId] == ClientKey then
		if Starter == "TryOn" then
			local Character = Player.Character
			local cShirt, cPants = Character.Shirt, Character.Pants
			local optionType = Data[1]
			local shirt, pants = Data[2].Shirt or 0, Data[2].Pants or 0
			local formattedShirt = serverConfig.templatePrefix:format(shirt)
			local formattedPants = serverConfig.templatePrefix:format(pants)
			if optionType == "Shirt" then
				serverConfig.originalClothes[Player.Name] = {}
				serverConfig.originalClothes[Player.Name]["Shirt"] = cShirt.ShirtTemplate:match("%d+")
				cShirt.ShirtTemplate = formattedShirt -- error line
			elseif optionType == "Pants" then
				serverConfig.originalClothes[Player.Name] = {}
				serverConfig.originalClothes[Player.Name]["Pants"] = cPants.PantsTemplate:match("%d+")
				cPants.PantsTemplate = formattedPants -- error line
			elseif optionType == "Both" then
				serverConfig.originalClothes[Player.Name] = {}
				serverConfig.originalClothes[Player.Name]["Shirt"] = cShirt.ShirtTemplate:match("%d+")
				serverConfig.originalClothes[Player.Name]["Pants"] = cPants.PantsTemplate:match("%d+")
				cShirt.ShirtTemplate = formattedShirt -- error line
				cPants.PantsTemplate = formattedPants -- error line
			end
		elseif Starter == "TakeOff" then
			local Character = Player.Character
			local cShirt, cPants = Character.Shirt, Character.Pants
			if serverConfig.originalClothes[Player.Name] then
				local shirtData = serverConfig.originalClothes[Player.Name]["Shirt"]
				local pantsData = serverConfig.originalClothes[Player.Name]["Pants"]
				if shirtData then
					cShirt.ShirtTemplate = serverConfig.templatePrefix:format(
						serverConfig.originalClothes[Player.Name]["Shirt"]
					)
				end
				if pantsData then
					cPants.PantsTemplate = serverConfig.templatePrefix:format(
						serverConfig.originalClothes[Player.Name]["Pants"]
					)
				end
				serverConfig.originalClothes[Player.Name] = nil
			end
		end
	end
end)

local function Rewrite(Player: Player, TheirTool: Tool): ()
	for _, b in ipairs(Connections[Player.UserId]) do
		if b ~= nil then
			b:Disconnect()
			b = nil
		end
	end

	table.insert(
		Connections[Player.UserId],
		TheirTool.Equipped:Connect(function()
			serverConfig.bagsEquipped[Player.Name] = true
		end)
	)
	table.insert(
		Connections[Player.UserId],
		TheirTool.Unequipped:Connect(function()
			serverConfig.bagsEquipped[Player.Name] = nil
		end)
	)
	table.insert(
		Connections[Player.UserId],
		TheirTool.Activated:Connect(function()
			customOnMouseClick(Player, TheirTool)
		end)
	)
end

Players.PlayerAdded:Connect(function(Player: Player)
	Connections[Player.UserId] = {}
	PermConnections[Player.UserId] = {}

	local playerKey = Key.new(50)
	serverConfig.Keys[Player.UserId] = playerKey
	Event:FireClient(Player, "Config", playerKey)

	table.insert(
		PermConnections[Player.UserId],
		Player.CharacterAdded:Connect(function()
			local theirTool = Util:Clone(Tool, { Parent = Player:WaitForChild("Backpack") })
			Rewrite(Player, theirTool)
			task.delay(0.2, function()
				Event:FireClient(Player, "Config", playerKey)
			end)
		end)
	)

	local Character = Player.Character or Player.CharacterAdded:Wait()

	Util
		:WaitForChildOfClass(Character, "Shirt", 1)
		:andThen(function(result: Shirt?)
			if not result then
				Util:Create("Shirt", { ShirtTemplate = serverConfig.templatePrefix:format("0"), Parent = Character })
			end
		end)
		:catch(error)
		:await()
	Util
		:WaitForChildOfClass(Character, "Pants", 1)
		:andThen(function(result: Pants?)
			if not result then
				Util:Create("Pants", { PantsTemplate = serverConfig.templatePrefix:format("0"), Parent = Character })
			end
		end)
		:catch(error)
		:await()
end)

Players.PlayerRemoving:Connect(function(Player: Player)
	Connections[Player.UserId] = nil
	serverConfig.Keys[Player.UserId] = nil
end)
