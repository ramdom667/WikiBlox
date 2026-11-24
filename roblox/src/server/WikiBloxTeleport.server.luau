-- WikiBlox : portails (couloir <-> Nexus) et portes des mini-jeux
--
-- Toute partie qui a l'attribut Destination = "NomDePartie" téléporte le joueur qui la touche
-- vers la partie de ce nom (cherchée dans tout le Workspace), avec un fondu à l'écran.
-- Toute partie qui a l'attribut MiniJeu reçoit un bouton « Entrer » (ProximityPrompt).
--   -> Pour brancher un vrai mini-jeu plus tard : mettre l'attribut Destination sur le Voile de la porte
--      (une partie d'arrivée dans ce place) ou l'attribut PlaceId (un autre place du jeu).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local FONDU = 0.4 -- durée du fondu au noir avant de déplacer le joueur

local remote = ReplicatedStorage:FindFirstChild("WikiBloxMonde")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "WikiBloxMonde"
	remote.Parent = ReplicatedStorage
end

local enCours = {}

local function teleporter(player, nomDestination)
	if enCours[player] then return end
	local destination = workspace:FindFirstChild(nomDestination, true)
	if not destination or not destination:IsA("BasePart") then
		warn("[WikiBlox] Destination introuvable :", nomDestination)
		return
	end
	enCours[player] = true
	remote:FireClient(player, "fondu", FONDU, nomDestination)
	task.wait(FONDU)
	local perso = player.Character
	local racine = perso and perso:FindFirstChild("HumanoidRootPart")
	if racine then
		perso:PivotTo(destination.CFrame * CFrame.new(0, 3, 0))
		racine.AssemblyLinearVelocity = Vector3.zero
	end
	task.delay(1.2, function()
		enCours[player] = nil
	end)
end

local function brancher(objet)
	if not objet:IsA("BasePart") then return end

	if objet:GetAttribute("Destination") and not objet:GetAttribute("MiniJeu") then
		local action = objet:GetAttribute("Interaction")
		if action then
			-- Portail : il faut interagir (E / appui) pour entrer
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = action
			prompt.ObjectText = objet:GetAttribute("NomLieu") or ""
			prompt.HoldDuration = 0.4
			prompt.MaxActivationDistance = 14
			prompt.RequiresLineOfSight = false
			prompt.Parent = objet
			prompt.Triggered:Connect(function(player)
				teleporter(player, objet:GetAttribute("Destination"))
			end)
		else
			-- Zone invisible (ex. filet de sécurité) : on est téléporté en la touchant
			objet.Touched:Connect(function(touche)
				local perso = touche.Parent
				local player = perso and Players:GetPlayerFromCharacter(perso)
				if player then
					teleporter(player, objet:GetAttribute("Destination"))
				end
			end)
		end
	end

	if objet:GetAttribute("MiniJeu") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Entrer"
		prompt.ObjectText = objet:GetAttribute("NomMiniJeu") or "Mini-jeu"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = objet
		prompt.Triggered:Connect(function(player)
			local placeId = objet:GetAttribute("PlaceId")
			local destination = objet:GetAttribute("Destination")
			if destination then
				teleporter(player, destination)
			elseif placeId then
				remote:FireClient(player, "message", "Téléportation vers " .. prompt.ObjectText .. "…")
				local ok, err = pcall(function()
					TeleportService:TeleportAsync(placeId, { player })
				end)
				if not ok then
					warn("[WikiBlox] Téléportation impossible :", err)
					remote:FireClient(player, "message", "Impossible de lancer ce mini-jeu pour l'instant.")
				end
			else
				remote:FireClient(player, "message", prompt.ObjectText .. " arrive bientôt !")
			end
		end)
	end
end

for _, objet in ipairs(workspace:GetDescendants()) do
	brancher(objet)
end
workspace.DescendantAdded:Connect(brancher)

Players.PlayerRemoving:Connect(function(player)
	enCours[player] = nil
end)
