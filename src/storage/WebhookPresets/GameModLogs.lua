local GameModLogs = {}

local Http = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local secrets = require(ServerStorage.Storage.Modules.secrets)

local PROXY_URL = "https://ns-api-nnrz4.ondigitalocean.app/api/remote/proxy/discord"
local GLOBAL_COLOR = 6798026

function GameModLogs:__Push(Template)
	local RESPONSE_DATA = {
		["webhookURL"] = secrets["NS_GAME_MOD_WEBHOOK"],
		["webhookPayload"] = Http:JSONEncode(Template),
	}

	local response = Http:PostAsync(
		PROXY_URL,
		Http:JSONEncode(RESPONSE_DATA),
		Enum.HttpContentType.ApplicationJson,
		false,
		{
			["Authorization"] = secrets["NS_API_AUTHORIZATION"],
		}
	)
	response = Http:JSONDecode(response)

	if response and response.status ~= "ok" then
		return true, response
	end

	return false
end

-- Returns a tuple, first boolean representing the success of the operation and second the error response if there is any.
function GameModLogs:SendBan(options: { [string]: any })
	local TEMPLATE = {
		["embeds"] = {
			{
				["title"] = "Player Banned!",
				["description"] = ('**%s** banned **%s (%d)**: "%s"'):format(
					options.ExecutorName,
					options.VictimName,
					options.VictimID,
					options.Reason
				),
				["color"] = GLOBAL_COLOR,
			},
		},
	}

	return GameModLogs:__Push(TEMPLATE)
end

-- Returns a tuple, first boolean representing the success of the operation and second the error response if there is any.
function GameModLogs:SendUnban(options: { [string]: any })
	local TEMPLATE = {
		["embeds"] = {
			{
				["title"] = "Player Unbanned!",
				["description"] = ("**%s** unbanned **%s (%d)**"):format(
					options.ExecutorName,
					options.VictimName,
					options.VictimID
				),
				["color"] = GLOBAL_COLOR,
			},
		},
	}

	return GameModLogs:__Push(TEMPLATE)
end

-- Returns a tuple, first boolean representing the success of the operation and second the error response if there is any.
function GameModLogs:SendKick(options: { [string]: any })
	local TEMPLATE = {
		["embeds"] = {
			{
				["title"] = "Player Kicked!",
				["description"] = ('**%s** kicked **%s (%d)**: "%s"'):format(
					options.ExecutorName,
					options.VictimName,
					options.VictimID,
					options.Reason
				),
				["color"] = GLOBAL_COLOR,
			},
		},
	}

	return GameModLogs:__Push(TEMPLATE)
end

return GameModLogs
