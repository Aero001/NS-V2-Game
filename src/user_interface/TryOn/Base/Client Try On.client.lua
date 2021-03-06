--[[

	TryOn Ver. 1.0
	A mannequin interaction system.
	Developed by Aerosphia

]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Market = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Camera = workspace.CurrentCamera

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local Promise = require(ReplicatedStorage.Shared.Promise)
local Util = require(ReplicatedStorage.Shared.Util)
local Debounce = require(ReplicatedStorage.Shared.Debounce)

local Gui = Player.PlayerGui

local ScreenGui = Gui.TryOn

local Base = ScreenGui.Base
local Sidebar = Base.Sidebar
local SidebarStroke = Sidebar.UIStroke
local ThreeDTitle = Sidebar["3DTitle"]
local Viewport = Sidebar.Mannequin
local BuyOutfit = Base.BuyOutfit
local BuyShirt = Base.BuyS
local BuyPant = Base.BuyP
local TryOn = Base.TryOn
local CloseButton = Base.X
local ManType = Sidebar.MannequinType
local Loading = Base.Loading
local ErrorNotif = Base.Error

local AdvView = ScreenGui.Advanced_View
local SpeedInput = AdvView.SpeedInput
local Exit = AdvView.Exit

local AdvTriggFrame = ScreenGui.AV_Trigger
local AdvTrigger = AdvTriggFrame.Trigger

local Notice = ScreenGui.Notice
local NoticeCloseButton = Notice.X
local NoticeDesc = Notice.Desc
local NoticeHeader = Notice.Error
local NoticeAddress = Notice.Address
local NoticeDiscord = Notice.Discord

local TryOnPrompt = ScreenGui.TryOn_Prompt
local ShirtOption = TryOnPrompt.Shirt
local PantsOption = TryOnPrompt.Pants
local BothOption = TryOnPrompt.Both
local TryOnPromptCloseButton = TryOnPrompt.X

local MergePrompt = ScreenGui.Merge_Prompt
local YesMerge = MergePrompt.Merge
local NoMerge = MergePrompt.No
local MergeCloseButton = MergePrompt.X

local TryOnFolder = ReplicatedStorage:FindFirstChild("TryOn")

local Event = TryOnFolder:FindFirstChild("TryOn Event")
local Function = TryOnFolder:FindFirstChild("TryOn Function")
local viewportCharacter = TryOnFolder:FindFirstChild("Character")

local clientConfig = setmetatable({
	key = 0,
	templatePrefix = "http://www.roblox.com/asset/?id=%d",
	buyOutfitFormat = 'Buy Outfit <font color="#3CDD52">R$%d</font>',
	buyShirtFormat = 'Shirt <b><font color="#3CDD52">R$%d</font></b>',
	buyPantFormat = 'Pants <b><font color="#3CDD52">R$%d</font></b>',
	ownedFormat = '<b><font color="#3CDD52">OWNED</font></b>',
	_connections = {
		terminal = {
			close = 0,
			tryOn = 0,
			buyS = 0,
			buyP = 0,
			buyOutfit = 0,
			manType = 0,
		},
		advancedView = {
			trigger = 0,
			speedInputFocusLost = 0,
			speedInputTPCS = 0,
			exit = 0,
		},
		notice = {
			close = 0,
		},
		tryOnOptions = {
			shirt = 0,
			pants = 0,
			both = 0,
			close = 0,
		},
		mergeOptions = {
			yes = 0,
			no = 0,
			close = 0,
		},
		died = 0,
		clientEvent = 0,
	},
	_promise = {
		mainLoad = 0,
	},
	isAdvancedView = false,
	advSpeed = 1,
	connectionBreak3d = false,
	activeSidebarTween = false,
	closeDisabled = false,
	currentPi = 0,
	originalCFrame3d = 0,
	storedViewport = 0,
	previousHumanoidCF = CFrame.new(),
	buyIndividualObjectYScale = 0.395,
	tryOnObjectYScale = 0.14,
	greyOut = Color3.fromRGB(118, 118, 118),
	centeredNoticeDesc = UDim2.new(0.042, 0, 0.148, 0),
	loweredNoticeDesc = UDim2.new(0.042, 0, 0.187, 0),
	tryOnOptionsOpen = false,
	mergePromptOpen = false,
	currentTryOnType = "", -- "Shirt", "Pants", "Both"
	canMerge = false,
	isMerging = false,
	advExFunc = 0,
	globalTemplates = {
		TemplateS = 0,
		TemplateP = 0,
	},
	isTryingOn = false,
	loadText = Loading.Text,
	loadErrorText = "Unknown error",
	noticeExecErrorText = "Please join our Discord server with this screenshot as a bug report. This usually has something to do with your avatar - try removing packages!",
	loadingTimes = {},
	archivedLoads = {},
}, {
	__index = function(_, indx: string)
		error(
			(
				"Try On Client::clientConfigError: Attempt to get clientConfig value with a nil index. -> clientConfig[%s]?\n\n%s"
			):format(indx, debug.traceback())
		)
	end,

	__newindex = function(_, indx: string, val: any)
		error(
			(
				"Try On Client::clientConfigError: New items are disallowed! -> Operation (clientConfig[%s] = %s) failed.\n\n%s"
			):format(indx, tostring(val), debug.traceback())
		)
	end,
})

local function makeLibraryMeta(Name: string): ({ [string]: (...any) -> (nil) })
	return {
		__index = function(_, indx: string)
			error(
				("Try On Client::inBuiltLibraryError: %s is not a function of %s.\n\n%s"):format(
					indx,
					Name,
					debug.traceback()
				)
			)
		end,
	}
end

local Time = setmetatable({}, makeLibraryMeta("Time"))
local Templates = setmetatable({}, makeLibraryMeta("Templates"))
local Core = setmetatable({}, makeLibraryMeta("Core"))

function Time.Set(): ()
	table.insert(clientConfig.loadingTimes, 1, os.clock())
end

function Time.Get(): (number?)
	local loadingTimes = clientConfig.loadingTimes
	local archivedLoads = clientConfig.archivedLoads

	local toReturn = tostring(os.clock() - loadingTimes[1])
	toReturn = toReturn:sub(1, 3)

	table.move(loadingTimes, 1, 1, #archivedLoads, archivedLoads)

	return tonumber(toReturn)
end

function Time.Forget(): ()
	table.remove(clientConfig.loadingTimes, 1)
end

function Templates.New(Shirt: number, Pant: number): ({ [string]: number })
	return {
		TemplateS = Shirt,
		TemplateP = Pant,
	}
end

function Core.elements(Toggle: boolean): ()
	local ok, _, timeout = nil, nil, 0
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, Toggle)
	local function ResetButtonCallback()
		StarterGui:SetCore("ResetButtonCallback", Toggle)
	end
	ok, _ = pcall(ResetButtonCallback)
	if not ok then
		repeat
			timeout += 1
			ok, _ = pcall(ResetButtonCallback)
			task.wait()
		until ok or timeout == 10
		if timeout >= 10 then
			warn("Core.elements: Timeout reached after 10 unsuccessful pcall attempts.")
		end
	end
end

local function fireServer(...: any): ()
	Event:FireServer(clientConfig.key, ...)
end

local function tryOn(...: any): ()
	AdvTriggFrame.Visible = true
	TryOn.Text = "Take Off Outfit"
	clientConfig.isTryingOn = true
	fireServer("TryOn", ...)
end

local function takeOff(): ()
	fireServer("TakeOff")
	TryOn.Text = "Try On Outfit"
	clientConfig.isTryingOn = false
	clientConfig.currentTryOnType = ""
end

local function getPi(mannequin: Model): (string)
	local value = mannequin:GetAttribute("PI")
	assert(value, "getPi: No personal identification value")
	value = tostring(value)
	return value
end

local function getOppositeTryOnType(currentType: string): (string)
	if currentType == "Shirt" then
		return "Pants"
	elseif currentType == "Pants" then
		return "Shirt"
	elseif currentType == "Both" then
		return "Both"
	else
		error("Invalid type")
	end
end

-- This function doesn't work properly in a certain way, but I'm not using it
-- in that way, so I don't care to fix it. Don't rely on it to meet your
-- needs.
local function checkAsset(Proto: boolean, ...: number)
	local Data = { ... }
	return Promise.new(function(resolve)
		for a, b in ipairs(Data) do
			if typeof(Proto) == "boolean" and not Proto then
				if Market:PlayerOwnsAsset(Player, b) then
					resolve(1)
				else
					resolve(2)
				end
			elseif typeof(Proto) == "boolean" and Proto then
				if Market:PlayerOwnsAsset(Player, b) then
					if a == #Data then
						resolve(1)
					end
				else
					resolve(2)
				end
			end
		end
	end)
end

local function productInfo(id: number, enum: any)
	assert(enum.EnumType == Enum.InfoType, "productInfo: Parameter 2 (enum) InfoType Enumerator expected")
	return Promise.new(function(resolve, reject)
		local succ, result = pcall(Market.GetProductInfo, Market, id, enum)
		return if succ then resolve(result) else reject(result)
	end)
end

local function manageIndividuals(toTop: boolean): ()
	if toTop then
		BuyShirt.Position = UDim2.fromScale(BuyShirt.Position.X.Scale, clientConfig.tryOnObjectYScale)
		BuyPant.Position = UDim2.fromScale(BuyPant.Position.X.Scale, clientConfig.tryOnObjectYScale)
	else
		BuyShirt.Position = UDim2.fromScale(BuyShirt.Position.X.Scale, clientConfig.buyIndividualObjectYScale)
		BuyPant.Position = UDim2.fromScale(BuyPant.Position.X.Scale, clientConfig.buyIndividualObjectYScale)
	end
end

local function manageButtons(outfitVisible: boolean, tryOnVisible: boolean): ()
	local exception = false
	if outfitVisible then
		BuyOutfit.Visible = true
	end
	if tryOnVisible then
		TryOn.Visible = true
	else
		exception = true
		manageIndividuals(true)
	end
	if not exception then
		BuyPant.Visible = true
		BuyShirt.Visible = true
	else
		if
			(BuyPant.Position.Y.Scale ~= clientConfig.buyIndividualObjectYScale)
			or (BuyShirt.Position.Y.Scale ~= clientConfig.buyIndividualObjectYScale)
		then
			manageIndividuals(true)
			BuyPant.Visible = true
			BuyShirt.Visible = true
		end
	end
end

local function stillActivated(): (boolean)
	return (BuyShirt.Visible and BuyPant.Visible)
end

local function loadingState(customText: string?): ()
	BuyOutfit.Visible = false
	BuyPant.Visible = false
	BuyShirt.Visible = false
	TryOn.Visible = false
	Loading.Visible = true
	Loading.Text = customText or clientConfig.loadText
end

local function cancelLoading(): ()
	local loadPromise = clientConfig._promise.mainLoad
	loadPromise:cancel()
	loadPromise = nil
end

local function close(Key: string, Type: number?): ()
	if Key == "Base" then
		local vpChar = clientConfig.storedViewport

		cancelLoading()
		Base.Visible = false
		ErrorNotif.Visible = false
		ManType.Text = "2D"
		clientConfig.connectionBreak3d = true

		if not Type or Type == 0 then
			AdvTriggFrame.Visible = false
		end

		pcall(function()
			vpChar.PrimaryPart = vpChar:FindFirstChild("HumanoidRootPart")
			vpChar:SetPrimaryPartCFrame(clientConfig.originalCFrame3d)
		end)

		task.wait(1 / 60)
		clientConfig.connectionBreak3d = false
	elseif Key == "Notice" then
		Notice.Visible = false
		NoticeDesc.Text = ""
	end
end

local function err(text: string?): ()
	Time.Forget()
	ErrorNotif.Visible = true
	Loading.Text = text or clientConfig.loadErrorText
	task.wait()
	if stillActivated() then
		loadingState(clientConfig.loadErrorText)
	end
end

local function isOwned(indivButton: TextButton): (string?)
	return indivButton.Text:lower():match("owned")
end

local function disconnect(Client: Player): ()
	if Client.UserId == Player.UserId then
		for _, outermost in pairs(clientConfig._connections) do
			if typeof(outermost) == "table" then
				for _, innermost in pairs(outermost) do
					if typeof(innermost) == "RBXScriptConnection" then
						pcall(innermost.Disconnect, innermost)
						innermost = nil
					end
				end
			else
				pcall(outermost.Disconnect, outermost)
				outermost = nil
			end
		end
	end
end

local function createViewport(templates: { [string]: number })
	return Promise.new(function(resolve)
		Viewport:ClearAllChildren()

		local clone = Util:Clone(viewportCharacter)
		clone["Pants"].PantsTemplate = clientConfig.templatePrefix:format(templates.TemplateP)
		clone["Shirt"].ShirtTemplate = clientConfig.templatePrefix:format(templates.TemplateS)

		local newModel = Util:Create("Model", { Name = "Character", Parent = Viewport })

		local hrp = clone:FindFirstChild("HumanoidRootPart")
		local head = clone:FindFirstChild("Head")
		head["default face"]:Destroy()

		for _, b in ipairs(clone:GetChildren()) do
			if b:IsA("BasePart") then
				b.CFrame *= CFrame.Angles(0, math.rad(180), 0)
			end
			b.Parent = newModel
		end

		local vpCam = Util:Create("Camera", { FieldOfView = 5, Parent = Viewport })
		Viewport.CurrentCamera = vpCam

		vpCam.CFrame = CFrame.new(Vector3.new(0, 2, 12), hrp.Position)

		clientConfig.storedViewport = newModel
		resolve()
	end)
end

local function tweenSideBar(level: number): ()
	-- 1: In, 2: Out
	if level == 1 then
		clientConfig.activeSidebarTween = false
		SidebarStroke.Enabled = false
		ThreeDTitle.Visible = false
		Sidebar:TweenSizeAndPosition(
			UDim2.new(0.317, 0, 1.006, 0),
			UDim2.new(0.157, 0, 0.497, 0),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Quint,
			0.5
		)
	elseif level == 2 then
		clientConfig.activeSidebarTween = true
		SidebarStroke.Enabled = true
		ThreeDTitle.Visible = true
		Sidebar:TweenSizeAndPosition(
			UDim2.new(0.559, 0, 1.676, 0),
			UDim2.new(0.504, 0, 0.497, 0),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Quint,
			0.5
		)
	end
end

local function tryOnOptionsConnectionUnit(shirtObject: number, pantObject: number)
	for _, b in pairs(clientConfig._connections.tryOnOptions) do
		if typeof(b) == "RBXScriptConnection" then
			b:Disconnect()
			b = nil
		end
	end
	return Promise.new(function(resolve)
		clientConfig._connections.tryOnOptions.shirt = ShirtOption.MouseButton1Click:Connect(function()
			tryOn("Shirt", { Shirt = shirtObject })
			TryOnPrompt.Visible = false
			clientConfig.tryOnOptionsOpen = false
			clientConfig.currentTryOnType = "Shirt"
			clientConfig.canMerge = true
			close("Base", 1)
		end)
		clientConfig._connections.tryOnOptions.pants = PantsOption.MouseButton1Click:Connect(function()
			tryOn("Pants", { Pants = pantObject })
			TryOnPrompt.Visible = false
			clientConfig.tryOnOptionsOpen = false
			clientConfig.currentTryOnType = "Pants"
			clientConfig.canMerge = true
			close("Base", 1)
		end)
		clientConfig._connections.tryOnOptions.both = BothOption.MouseButton1Click:Connect(function()
			tryOn("Both", { Shirt = shirtObject, Pants = pantObject })
			TryOnPrompt.Visible = false
			clientConfig.tryOnOptionsOpen = false
			clientConfig.currentTryOnType = "Both"
			close("Base", 1)
		end)
		clientConfig._connections.tryOnOptions.close = TryOnPromptCloseButton.MouseButton1Click:Connect(function()
			Base.Visible = true
			TryOnPrompt.Visible = false
			clientConfig.tryOnOptionsOpen = false
		end)
		resolve()
	end)
end

local function mergeOptionsConnectionUnit(shirtObject: number, pantObject: number)
	for _, b in pairs(clientConfig._connections.tryOnOptions) do
		if typeof(b) == "RBXScriptConnection" then
			b:Disconnect()
			b = nil
		end
	end
	return Promise.new(function(resolve)
		clientConfig._connections.mergeOptions.yes = YesMerge.MouseButton1Click:Connect(function()
			local oppositeType = getOppositeTryOnType(clientConfig.currentTryOnType)
			tryOn(oppositeType, { Shirt = shirtObject, Pants = pantObject })
			MergePrompt.Visible = false
			clientConfig.mergePromptOpen = false
			clientConfig.canMerge = false
		end)
		clientConfig._connections.mergeOptions.no = NoMerge.MouseButton1Click:Connect(function()
			takeOff()
			MergePrompt.Visible = false
			clientConfig.mergePromptOpen = false
		end)
		clientConfig._connections.mergeOptions.close = MergeCloseButton.MouseButton1Click:Connect(function()
			MergePrompt.Visible = false
			clientConfig.mergePromptOpen = false
		end)
		resolve()
	end)
end

local function noticeConnectionUnit()
	for _, b in pairs(clientConfig._connections.notice) do
		if typeof(b) == "RBXScriptConnection" then
			b:Disconnect()
			b = nil
		end
	end
	return Promise.new(function(resolve)
		clientConfig._connections.notice.close = NoticeCloseButton.MouseButton1Click:Connect(function()
			close("Notice")
		end)
		resolve()
	end)
end

local function newNotice(noticeText: string, options: { [string]: any }): ()
	noticeConnectionUnit():catch(error):await()
	NoticeDesc.Text = noticeText

	if options.headerError and typeof(options.headerError) == "string" then
		NoticeHeader.Text = ("<b>Error:</b> %s"):format(options.headerError)
		NoticeHeader.Visible = true
	end
	if options.address and typeof(options.address) == "table" then
		NoticeAddress.Text = ("@%s %s"):format(options.address.pointer, options.address.context)
		NoticeAddress.Visible = true
	end
	if options.showDiscord and typeof(options.showDiscord) == "boolean" then
		NoticeDiscord.Visible = true
	end

	if NoticeAddress.Visible or NoticeDiscord.Visible then
		NoticeDesc.Position = clientConfig.loweredNoticeDesc
	else
		NoticeDesc.Position = clientConfig.centeredNoticeDesc
	end

	Notice.Visible = true
end

local function advConnectionUnit()
	for _, b in pairs(clientConfig._connections.advancedView) do
		if typeof(b) == "RBXScriptConnection" then
			b:Disconnect()
			b = nil
		end
	end
	return Promise.new(function(resolve)
		clientConfig._connections.advancedView.speedInputTPCS = SpeedInput
			:GetPropertyChangedSignal("Text")
			:Connect(function()
				local function subtract()
					SpeedInput.Text = SpeedInput.Text:sub(0, -2)
				end
				if #SpeedInput.Text > 1 then
					return subtract()
				elseif not tonumber(SpeedInput.Text) then
					return subtract()
				end
			end)
		clientConfig._connections.advancedView.speedInputFocusLost = SpeedInput.FocusLost:Connect(function()
			local clamped = math.clamp(tonumber(SpeedInput.Text) or 0, 0, 5)

			if clamped == 5 then
				SpeedInput.Text = "5"
			end

			clientConfig.advSpeed = clamped
		end)
		clientConfig.advExFunc = function()
			if Debounce:State({ _ID = "advancedExit" }) then
				return
			end

			clientConfig.isAdvancedView = false
			Core.elements(true)

			AdvView.Visible = false
			RunService:UnbindFromRenderStep("CameraRotation")
			SpeedInput.Text = ""
			clientConfig.advSpeed = SpeedInput.PlaceholderText
			AdvTriggFrame.Visible = true
			Player.Character.HumanoidRootPart.CFrame = clientConfig.previousHumanoidCF
			clientConfig.previousHumanoidCF = CFrame.new()
			Player.Character.HumanoidRootPart.Anchored = false

			Debounce:LockState({
				_ID = "advancedTrigger",
				length = 2,
				callback = function()
					AdvTrigger.TextColor3 = Color3.fromRGB(255, 255, 255)
					AdvTrigger.AutoButtonColor = true
				end,
			})

			AdvTrigger.TextColor3 = clientConfig.greyOut
			AdvTrigger.AutoButtonColor = false

			close("Base", 1)
		end
		clientConfig._connections.advancedView.exit = Exit.MouseButton1Click:Connect(clientConfig.advExFunc)
		resolve()
	end)
end

local function mainConnectionUnit(shirtObject: number, pantObject: number)
	for _, b in pairs(clientConfig._connections.terminal) do
		if typeof(b) == "RBXScriptConnection" then
			b:Disconnect()
			b = nil
		end
	end
	return Promise.new(function(resolve)
		clientConfig._connections.terminal.close = CloseButton.MouseButton1Click:Connect(function()
			if Debounce:State({ _ID = "closeBase" }) or clientConfig.closeDisabled then
				return
			end

			close("Base", 1)
		end)
		clientConfig._connections.terminal.tryOn = TryOn.MouseButton1Click:Connect(function()
			if clientConfig.activeSidebarTween then
				return
			end
			if TryOn.Text == "Try On Outfit" then
				tryOnOptionsConnectionUnit(shirtObject, pantObject):catch(error):await()
				Base.Visible = false -- We may need to reopen it.
				TryOnPrompt.Visible = true
				clientConfig.tryOnOptionsOpen = true
			elseif TryOn.Text == "Take Off Outfit" then
				takeOff()
				close("Base")
			end
		end)
		clientConfig._connections.terminal.buyS = BuyShirt.MouseButton1Click:Connect(function()
			if isOwned(BuyShirt) or clientConfig.activeSidebarTween then
				return
			end
			Market:PromptPurchase(Player, shirtObject)
			local temp
			temp = Market.PromptPurchaseFinished:Connect(function(_, assetId, wasPurchased)
				if wasPurchased and assetId == shirtObject then
					BuyShirt.Text = clientConfig.ownedFormat
					BuyOutfit.Visible = false
				end
				temp:Disconnect()
				temp = nil
			end)
		end)
		clientConfig._connections.terminal.buyP = BuyPant.MouseButton1Click:Connect(function()
			if isOwned(BuyPant) or clientConfig.activeSidebarTween then
				return
			end
			Market:PromptPurchase(Player, pantObject)
			local temp
			temp = Market.PromptPurchaseFinished:Connect(function(_, assetId, wasPurchased)
				if wasPurchased and assetId == pantObject then
					BuyPant.Text = clientConfig.ownedFormat
					BuyOutfit.Visible = false
				end
				temp:Disconnect()
				temp = nil
			end)
		end)
		clientConfig._connections.terminal.buyOutfit = BuyOutfit.MouseButton1Click:Connect(function()
			if clientConfig.activeSidebarTween then
				return
			end
			Market:PromptPurchase(Player, shirtObject)
			local temp
			temp = Market.PromptPurchaseFinished:Connect(function(_, assetId, wasPurchased)
				if wasPurchased and assetId == shirtObject then
					BuyShirt.Text = clientConfig.ownedFormat
					BuyOutfit.Visible = false
					task.wait(0.1)
					Market:PromptPurchase(Player, pantObject)
				elseif wasPurchased and assetId == pantObject then
					BuyPant.Text = clientConfig.ownedFormat
					TryOn.Visible = false
					manageIndividuals(true)
					temp:Disconnect()
					temp = nil
				else
					temp:Disconnect()
					temp = nil
				end
			end)
		end)
		clientConfig._connections.terminal.manType = ManType.MouseButton1Click:Connect(function()
			local vpChar = clientConfig.storedViewport
			vpChar.PrimaryPart = vpChar:FindFirstChild("HumanoidRootPart")
			if ManType.Text == "2D" then
				tweenSideBar(2)
				CloseButton.TextColor3 = clientConfig.greyOut
				CloseButton.AutoButtonColor = false
				clientConfig.closeDisabled = true

				local temp
				clientConfig.originalCFrame3d = vpChar:GetPrimaryPartCFrame()
				ManType.Text = "3D"
				temp = RunService.Heartbeat:Connect(function(t)
					local atr = math.rad(180) * t / 3
					if clientConfig.connectionBreak3d then
						temp:Disconnect()
						temp = nil
					end
					vpChar:SetPrimaryPartCFrame(
						vpChar:GetPrimaryPartCFrame() * CFrame.fromEulerAnglesXYZ(0, tonumber(atr) or 0, 0)
					)
				end)
			elseif ManType.Text == "3D" then
				tweenSideBar(1)
				CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
				CloseButton.AutoButtonColor = true
				clientConfig.closeDisabled = false

				clientConfig.connectionBreak3d = true
				vpChar:SetPrimaryPartCFrame(clientConfig.originalCFrame3d)
				ManType.Text = "2D"
				task.wait(1 / 60)
				clientConfig.connectionBreak3d = false
			end
		end)
		clientConfig._connections.adv.trigg = AdvTrigger.MouseButton1Click:Connect(function()
			if Debounce:State({ _ID = "advancedTrigger" }) then
				return
			end
			advConnectionUnit():catch(error):await()

			Debounce:LockState({
				_ID = "advancedExit",
				length = 1,
				callback = function()
					Exit.TextColor3 = Color3.fromRGB(255, 255, 255)
					Exit.AutoButtonColor = true
				end,
			})

			Exit.TextColor3 = clientConfig.greyOut
			Exit.AutoButtonColor = false

			AdvTriggFrame.Visible = false
			AdvView.Visible = true
			close("Base")

			local Character = Player.Character

			clientConfig.isAdvancedView = true
			Core.elements(false)
			Character.HumanoidRootPart.Anchored = true
			clientConfig.previousHumanoidCF = Character.HumanoidRootPart.CFrame

			local centerCFrame = (Character.Head.CFrame + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 180, 0)
			local offsetCFrame = CFrame.new(0, 0, 10) * CFrame.Angles(math.rad(-22.5), 0, 0)
			local currentAngle = 0

			RunService:BindToRenderStep("CameraRotation", Enum.RenderPriority.Camera.Value + 1, function()
				Camera.CFrame = centerCFrame * CFrame.Angles(0, math.rad(currentAngle), 0) * offsetCFrame
				currentAngle += clientConfig.advSpeed
			end)
		end)
		resolve()
	end)
end

clientConfig._connections.clientEvent = Event.OnClientEvent:Connect(function(Key: string, ...: any)
	local Data = { ... }
	if Key == "Open" then
		clientConfig._promise.mainLoad = Promise.new(function(_, _, onCancel)
			local Conditions = {
				Base.Visible,
				Notice.Visible,
				clientConfig.isAdvancedView,
				Debounce:State({ _ID = "openBase" }),
			}
			if Util:Logical_Any(Conditions) then
				return
			end

			Debounce:LockState({ _ID = "openBase", length = 2 })

			CloseButton.TextColor3 = clientConfig.greyOut
			CloseButton.AutoButtonColor = false
			Debounce:LockState({
				_ID = "closeBase",
				length = 1,
				callback = function()
					CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
					CloseButton.AutoButtonColor = true
				end,
			})

			local shirt, pant = Data[1], Data[2]
			local templateTable = Data[3]
			local characterModel = Data[4]
			local characterPi = getPi(characterModel)
			local infoShirt, infoPant

			onCancel(loadingState)

			if characterPi ~= clientConfig.currentPi then
				if clientConfig.isTryingOn then
					if clientConfig.canMerge then
						mergeOptionsConnectionUnit(shirt, pant):catch(error):await()
						MergePrompt.Visible = true
						clientConfig.mergePromptOpen = true
						return
					end
					takeOff()
					AdvTriggFrame.Visible = false
				end
			end

			clientConfig.currentPi = characterPi
			loadingState()
			tweenSideBar(1)
			ManType.Visible = false
			if not Notice.Visible then
				Base.Visible = true
			end

			Time.Set()

			productInfo(shirt, Enum.InfoType.Asset)
				:andThen(function(result: { [string]: any })
					infoShirt = result
				end)
				:catch(error)
				:await()

			productInfo(pant, Enum.InfoType.Asset)
				:andThen(function(result: { [string]: any })
					infoPant = result
				end)
				:catch(error)
				:await()

			local outfitVisible, tryOnVisible = true, true
			local pantOwned, shirtOwned = false, false

			clientConfig.globalTemplates.TemplateS = templateTable.TemplateS
			clientConfig.globalTemplates.TemplateP = templateTable.TemplateP

			manageIndividuals(false)
			createViewport(templateTable):catch(error):await()
			mainConnectionUnit(shirt, pant):catch(error):await()

			checkAsset(true, shirt)
				:andThen(function(Type: number)
					if Type == 1 then
						BuyShirt.Text = clientConfig.ownedFormat
						BuyShirt.AutoButtonColor = false
						outfitVisible = false
						shirtOwned = true
					elseif Type == 2 then
						BuyShirt.Text = clientConfig.buyShirtFormat:format(infoShirt.PriceInRobux)
					end
				end)
				:catch(error)
				:await()

			checkAsset(true, pant)
				:andThen(function(Type: number)
					if Type == 1 then
						BuyPant.Text = clientConfig.ownedFormat
						BuyPant.AutoButtonColor = false
						outfitVisible = false
						pantOwned = true
					elseif Type == 2 then
						BuyPant.Text = clientConfig.buyPantFormat:format(infoShirt.PriceInRobux)
					end
				end)
				:catch(error)
				:await()

			if not pantOwned and not shirtOwned then
				BuyOutfit.Text = clientConfig.buyOutfitFormat:format(infoShirt.PriceInRobux + infoPant.PriceInRobux)
			end
			if pantOwned and shirtOwned then
				tryOnVisible = false
			end

			Loading.Visible = false
			ManType.Visible = true
			manageButtons(outfitVisible, tryOnVisible)

			print(("Took " .. Time.Get() .. " seconds to load on client %s!"):format(Player.Name))
		end):catch(function(errorMsg)
			warn(errorMsg)
			if Base.Visible then
				err()
			else
				newNotice(clientConfig.noticeExecErrorText, {
					headerError = "Execution Error",
					address = { pointer = "mainLoad", context = "ExecError" },
					showDiscord = true,
				})
			end
		end)
	elseif Key == "Config" then
		clientConfig.key = Data[1]
	end
end)

Function.OnClientInvoke = function(Key: string)
	if Key == "MouseTarget" then
		return Mouse.Target
	end
end

Util:WaitForChildOfClass(Player.Character, "Humanoid", 2):andThen(function(result: Humanoid?)
	if result then
		clientConfig._connections.died = result.Died:Connect(function()
			if Base.Visible then
				close("Base")
			end
			if clientConfig.tryOnOptionsOpen then
				TryOnPrompt.Visible = false
				clientConfig.tryOnOptionsOpen = false
			end
			if clientConfig.isTryingOn then
				takeOff()
				AdvTriggFrame.Visible = false
			end
		end)
	end
end)

Players.PlayerRemoving:Connect(disconnect)
