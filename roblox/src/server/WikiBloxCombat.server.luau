-- WikiBlox : combat au corps à corps (le serveur décide des dégâts)
--
-- ReplicatedStorage.WikiBloxCombat :
--   Frapper (client -> serveur) : FireServer("droit" | "gauche")
--   Salto   (client -> serveur) : FireServer() quand le joueur fait un double saut
--   Effets  (serveur -> clients) : ("coup", perso, bras) | ("salto", perso) | ("impact", position, modele)
--   -> les autres joueurs voient aussi les coups, les saltos et les impacts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEGATS = 10
local RECHARGE = 0.4                     -- secondes minimum entre deux coups (le client attend 0.45)
local ZONE = Vector3.new(5, 5, 6)        -- taille de la zone touchée devant le joueur
local RECUL = 40                         -- force du recul

local dossier = Instance.new("Folder")
dossier.Name = "WikiBloxCombat"
local function remote(nom)
	local r = Instance.new("RemoteEvent")
	r.Name = nom
	r.Parent = dossier
	return r
end
local frapper = remote("Frapper")
local salto = remote("Salto")
local effets = remote("Effets")
dossier.Parent = ReplicatedStorage

-- Envoie un effet à tous les joueurs sauf celui qui l'a déjà joué chez lui
local function diffuserSauf(joueur, ...)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= joueur then
			effets:FireClient(p, ...)
		end
	end
end

local dernierCoup = {}
local dernierSalto = {}

frapper.OnServerEvent:Connect(function(player, bras)
	bras = (bras == "gauche") and "gauche" or "droit"

	local maintenant = os.clock()
	if dernierCoup[player] and maintenant - dernierCoup[player] < RECHARGE then return end
	dernierCoup[player] = maintenant

	local perso = player.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	local racine = perso and perso:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not racine then return end

	diffuserSauf(player, "coup", perso, bras)

	-- Zone juste devant le joueur
	local centre = racine.CFrame * CFrame.new(0, 0, -(ZONE.Z / 2 + 1))
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { perso }

	local dejaTouches = {}
	for _, partie in ipairs(workspace:GetPartBoundsInBox(centre, ZONE, params)) do
		local modele = partie:FindFirstAncestorOfClass("Model")
		local cible = modele and modele:FindFirstChildOfClass("Humanoid")
		if cible and cible.Health > 0 and not dejaTouches[cible] then
			dejaTouches[cible] = true
			cible:TakeDamage(DEGATS) -- ne fait rien si la cible a un bouclier (ForceField)
			local r = modele:FindFirstChild("HumanoidRootPart")
			if r then
				r.AssemblyLinearVelocity = racine.CFrame.LookVector * RECUL + Vector3.new(0, 20, 0)
			end
			local pointImpact = (r and r.Position or partie.Position):Lerp(racine.Position, 0.35)
			effets:FireAllClients("impact", pointImpact, modele)
		end
	end
end)

salto.OnServerEvent:Connect(function(player)
	local maintenant = os.clock()
	if dernierSalto[player] and maintenant - dernierSalto[player] < 0.3 then return end
	dernierSalto[player] = maintenant
	if player.Character then
		diffuserSauf(player, "salto", player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	dernierCoup[player] = nil
	dernierSalto[player] = nil
end)
