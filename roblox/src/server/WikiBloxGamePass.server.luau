-- WikiBlox : Pass VIP (game pass à 30 Robux)
-- Donne l'attribut "VIP" = true au joueur qui possède le pass.
-- Les autres scripts peuvent vérifier : player:GetAttribute("VIP")

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local PASS_VIP = 2099610569

local function donnerVIP(player)
	player:SetAttribute("VIP", true)
	print("[WikiBlox] " .. player.Name .. " est VIP")
end

-- À l'arrivée du joueur : il a déjà le pass ?
Players.PlayerAdded:Connect(function(player)
	local ok, possede = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, PASS_VIP)
	end)
	if ok and possede then
		donnerVIP(player)
	end
end)

-- Juste après un achat en jeu
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, achete)
	if achete and passId == PASS_VIP then
		donnerVIP(player)
	end
end)
