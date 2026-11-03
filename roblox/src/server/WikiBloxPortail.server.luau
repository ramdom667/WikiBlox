-- WikiBlox : portail JOUER du lobby
local prompt = workspace:WaitForChild("WikiBloxLobby")
	:WaitForChild("Portail")
	:WaitForChild("PortailJouer")
	:WaitForChild("ProximityPrompt")

prompt.Triggered:Connect(function(player)
	print(player.Name .. " veut jouer !")
	-- À FAIRE : téléporter le joueur vers la place de jeu, par exemple :
	-- game:GetService("TeleportService"):TeleportAsync(ID_DE_LA_PLACE, { player })
end)
