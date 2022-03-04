local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local BanService = require(ServerStorage.Storage.Modules.BanService)

return function(Context, Victim)
	local Executor = Context.Executor
	local VictimBanned = BanService:GetBanInfo(Victim)

	if Victim == Executor.UserId then
		return "Command failed to execute."
	end

	if not VictimBanned then
		return Players:GetNameFromUserIdAsync(Victim) .. " is not banned."
	end

	local apiResult = BanService:Remove(Victim)
	if apiResult.status == "error" then
		return "Error: " .. apiResult.error
	end

	return ("Unbanned %s (%s) successfully."):format(Players:GetNameFromUserIdAsync(Victim), Victim)
end
