-- WikiBlox : pêche (serveur)
--
-- Le serveur décide de tout : où tombe le flotteur, quand ça mord, ce qui est pêché.
-- Le joueur ne fait que l'animation et le mini-jeu ; il ne peut pas choisir sa prise.
--
-- ReplicatedStorage.WikiBloxPeche :
--   Lancer    (RemoteFunction) : Lancer:InvokeServer(charge 0..1) -> { ok, position, zone } ou { ok = false, erreur }
--   Remonter  (RemoteEvent)    : le joueur ramène sa ligne (abandon)
--   Combat    (RemoteFunction) : Combat:InvokeServer(reussi) -> { ok, prise, carte | boosters } / { ok, perdu } / { ok = false, erreur }
--   Evenement (RemoteEvent, serveur -> client) : ("morsure", reglages du mini-jeu) | ("echappe", message)
--
-- Monde (voir tools/build_etang_peche) :
--   tag WikiBloxAirePeche : volume où la canne est donnée (retirée en sortant)
--   tag WikiBloxEauPeche  : surface d'eau pêchable (le flotteur doit tomber dedans)
--   tag WikiBloxZonePeche : zone spéciale, attribut ZonePeche = identifiant de WikiBloxPecheConfig.ZONES
--
-- Réglages et probabilités : ReplicatedStorage.Shared.WikiBloxPecheConfig

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Peche = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WikiBloxPecheConfig"))
local WikiCardsApi = require(script.Parent:WaitForChild("WikiCardsApi"))
local Inventaire = require(script.Parent:WaitForChild("WikiBloxInventaire"))

local DISTANCE_BORD = 30 -- distance horizontale maximale entre le joueur et l'eau pour lancer
local PAUSE_LANCER = 1 -- secondes minimum entre deux lancers
local BOIS = Color3.fromRGB(125, 85, 50)

local rng = Random.new()

------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------
local dossier = Instance.new("Folder")
dossier.Name = "WikiBloxPeche"
local function remote(classe, nom)
	local r = Instance.new(classe)
	r.Name = nom
	r.Parent = dossier
	return r
end
local lancerRemote = remote("RemoteFunction", "Lancer")
local remonterRemote = remote("RemoteEvent", "Remonter")
local combatRemote = remote("RemoteFunction", "Combat")
local evenement = remote("RemoteEvent", "Evenement")
dossier.Parent = ReplicatedStorage

------------------------------------------------------------------
-- Géométrie : volumes tagués
------------------------------------------------------------------
-- Le point est-il au-dessus / au-dessous de la surface de la partie (on ignore la hauteur) ?
local function surSurface(partie, point)
	local l = partie.CFrame:PointToObjectSpace(point)
	return math.abs(l.X) <= partie.Size.X / 2 and math.abs(l.Z) <= partie.Size.Z / 2
end

local function dansVolume(partie, point)
	local l = partie.CFrame:PointToObjectSpace(point)
	local d = partie.Size / 2
	return math.abs(l.X) <= d.X and math.abs(l.Y) <= d.Y and math.abs(l.Z) <= d.Z
end

-- Distance horizontale entre un point et le rectangle d'eau le plus proche
local function distanceEau(point)
	local meilleure = math.huge
	for _, eau in ipairs(CollectionService:GetTagged("WikiBloxEauPeche")) do
		local l = eau.CFrame:PointToObjectSpace(point)
		local dx = math.max(math.abs(l.X) - eau.Size.X / 2, 0)
		local dz = math.max(math.abs(l.Z) - eau.Size.Z / 2, 0)
		meilleure = math.min(meilleure, math.sqrt(dx * dx + dz * dz))
	end
	return meilleure
end

local function eauSous(point)
	for _, eau in ipairs(CollectionService:GetTagged("WikiBloxEauPeche")) do
		if surSurface(eau, point) then
			return eau
		end
	end
	return nil
end

local function zoneSous(point)
	for _, zone in ipairs(CollectionService:GetTagged("WikiBloxZonePeche")) do
		local id = zone:GetAttribute("ZonePeche")
		if id and Peche.ZONES[id] and zone:IsDescendantOf(workspace) and surSurface(zone, point) then
			return id
		end
	end
	return nil
end

local function dansAire(point)
	for _, aire in ipairs(CollectionService:GetTagged("WikiBloxAirePeche")) do
		if dansVolume(aire, point) then
			return true
		end
	end
	return false
end

------------------------------------------------------------------
-- La canne (Tool reconnu par son attribut CannePeche)
------------------------------------------------------------------
local function creerCanne()
	local outil = Instance.new("Tool")
	outil.Name = "Canne à pêche"
	outil.ToolTip = "Maintiens le clic pour lancer"
	outil.CanBeDropped = false
	outil.RequiresHandle = true
	outil:SetAttribute("CannePeche", true)
	outil.Grip = CFrame.new(0, 0, 2.8) * CFrame.Angles(math.rad(-30), 0, 0)

	local manche = Instance.new("Part")
	manche.Name = "Handle"
	manche.Size = Vector3.new(0.25, 0.25, 7)
	manche.Color = BOIS
	manche.Material = Enum.Material.Wood
	manche.CanCollide = false
	manche.CanQuery = false
	manche.Massless = true
	manche.Parent = outil

	local moulinet = Instance.new("Part")
	moulinet.Name = "Moulinet"
	moulinet.Shape = Enum.PartType.Cylinder
	moulinet.Size = Vector3.new(0.3, 0.6, 0.6)
	moulinet.Color = Color3.fromRGB(70, 70, 80)
	moulinet.Material = Enum.Material.Metal
	moulinet.CanCollide = false
	moulinet.CanQuery = false
	moulinet.Massless = true
	moulinet.CFrame = manche.CFrame * CFrame.new(0, -0.35, 2)
	moulinet.Parent = outil
	local soudure = Instance.new("WeldConstraint")
	soudure.Part0 = manche
	soudure.Part1 = moulinet
	soudure.Parent = moulinet

	local bout = Instance.new("Attachment")
	bout.Name = "Bout"
	bout.Position = Vector3.new(0, 0, -3.5)
	bout.Parent = manche
	return outil
end

local function trouverCanne(conteneur)
	if not conteneur then return nil end
	for _, enfant in ipairs(conteneur:GetChildren()) do
		if enfant:IsA("Tool") and enfant:GetAttribute("CannePeche") then
			return enfant
		end
	end
	return nil
end

local function canneEnMain(player)
	return trouverCanne(player.Character)
end

------------------------------------------------------------------
-- État de chaque joueur
------------------------------------------------------------------
-- etats[player] = { phase = "lance" | "combat" | "resultat", position, zone, equipement,
--                   prise, reglages, debut, requestId }
local etats = {}
local dernierLancer = {}

local function annuler(player, message)
	local etat = etats[player]
	if not etat or etat.phase == "resultat" then return end
	etats[player] = nil
	if message and player.Parent then
		evenement:FireClient(player, "echappe", message)
	end
end

-- Équipement actif. Pour l'instant : canne par défaut, sans appât.
-- Plus tard : lire la canne / l'appât équipés dans la sauvegarde du joueur (WikiBloxInventaire).
local function equipement(player, zone)
	return {
		canne = player:GetAttribute("CanneEquipee") or Peche.CANNE_DEFAUT,
		appat = player:GetAttribute("AppatEquipe"),
		zone = zone,
	}
end

local function mordre(player, etat)
	if etats[player] ~= etat or etat.phase ~= "lance" then return end
	if not canneEnMain(player) then
		annuler(player)
		return
	end
	local mods = Peche.modificateurs(etat.equipement)
	etat.prise = Peche.tirer(mods, rng)
	etat.reglages = Peche.reglagesJeu(etat.prise, mods)
	etat.requestId = HttpService:GenerateGUID(false)
	etat.debut = os.clock()
	etat.phase = "combat"
	evenement:FireClient(player, "morsure", etat.reglages)

	task.delay(Peche.DUREE_MAX_COMBAT + 5, function()
		if etats[player] == etat and etat.phase == "combat" then
			annuler(player, "Le poisson s'est lassé et s'est échappé…")
		end
	end)
end

lancerRemote.OnServerInvoke = function(player, charge)
	if typeof(charge) ~= "number" or charge ~= charge then
		return { ok = false, erreur = "Lancer invalide" }
	end
	charge = math.clamp(charge, 0, 1)
	if etats[player] then
		return { ok = false, erreur = "Ta ligne est déjà à l'eau" }
	end
	if dernierLancer[player] and os.clock() - dernierLancer[player] < PAUSE_LANCER then
		return { ok = false, erreur = "Doucement !" }
	end
	if not canneEnMain(player) then
		return { ok = false, erreur = "Prends ta canne à pêche en main" }
	end
	local perso = player.Character
	local hum = perso and perso:FindFirstChildOfClass("Humanoid")
	local racine = perso and perso:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not racine then
		return { ok = false, erreur = "Impossible de pêcher maintenant" }
	end
	if distanceEau(racine.Position) > DISTANCE_BORD then
		return { ok = false, erreur = "Approche-toi de l'eau" }
	end
	dernierLancer[player] = os.clock()

	local equip = equipement(player, nil)
	local canne = Peche.CANNES[equip.canne] or Peche.CANNES[Peche.CANNE_DEFAUT]
	local distance = canne.portee.min + (canne.portee.max - canne.portee.min) * charge
	local avant = racine.CFrame.LookVector * Vector3.new(1, 0, 1)
	avant = avant.Magnitude > 0.1 and avant.Unit or Vector3.new(0, 0, -1)
	local point = racine.Position + avant * distance

	local eau = eauSous(point)
	if not eau then
		return { ok = false, erreur = "Raté, vise l'eau !" }
	end
	local surface = (eau.CFrame * CFrame.new(0, eau.Size.Y / 2, 0)).Position.Y
	point = Vector3.new(point.X, surface, point.Z)

	local zone = zoneSous(point)
	equip.zone = zone
	local etat = { phase = "lance", position = point, zone = zone, equipement = equip }
	etats[player] = etat

	local attente = (Peche.ATTENTE.min + rng:NextNumber() * (Peche.ATTENTE.max - Peche.ATTENTE.min)) * (canne.attente or 1)
	task.delay(attente, mordre, player, etat)

	return { ok = true, position = point, zone = zone and Peche.ZONES[zone].nom or nil }
end

remonterRemote.OnServerEvent:Connect(function(player)
	annuler(player)
end)

combatRemote.OnServerInvoke = function(player, reussi)
	local etat = etats[player]
	if not etat or etat.phase ~= "combat" then
		return { ok = false, erreur = "Aucun poisson au bout de la ligne" }
	end
	if reussi ~= true then
		etats[player] = nil
		return { ok = true, perdu = true }
	end
	-- Anti-triche : impossible de gagner plus vite que si le poisson restait toujours dans le curseur
	local duree = os.clock() - etat.debut
	if duree < Peche.dureeMinimale(etat.reglages) * 0.9 then
		etats[player] = nil
		warn(("[WikiBlox] Pêche refusée pour %s (%d) : combat gagné en %.2f s"):format(player.Name, player.UserId, duree))
		return { ok = true, perdu = true }
	end

	etat.phase = "resultat"
	local prise = etat.prise

	if prise == "booster" then
		if Inventaire.nombre(player) == nil then
			etats[player] = nil
			return { ok = false, erreur = "Tes boosters ne sont pas encore chargés, réessaie" }
		end
		Inventaire.ajouter(player, 1, true) -- un booster pêché peut dépasser le maximum
		etats[player] = nil
		print(("[WikiBlox] %s a pêché un booster"):format(player.Name))
		return { ok = true, prise = "booster", boosters = Inventaire.nombre(player) }
	end

	local ok, data = WikiCardsApi.grantCard(player, prise, "peche", etat.requestId)
	etats[player] = nil
	if not ok then
		warn(("[WikiBlox] Carte pêchée non enregistrée pour %s (%d) : %s %s"):format(
			player.Name, player.UserId, tostring(data.status), tostring(data.message)))
		return { ok = false, erreur = "La carte s'est échappée (serveur indisponible), réessaie !" }
	end
	return { ok = true, prise = prise, carte = data.card }
end

------------------------------------------------------------------
-- Distribution de la canne dans l'aire de pêche
------------------------------------------------------------------
local function surveillerCanne(player, outil)
	outil.AncestryChanged:Connect(function()
		-- rangée dans le sac, lâchée ou retirée : la ligne est ramenée
		if outil.Parent ~= player.Character then
			annuler(player)
		end
	end)
end

task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local perso = player.Character
			local racine = perso and perso:FindFirstChild("HumanoidRootPart")
			local sac = player:FindFirstChildOfClass("Backpack")
			if racine and sac then
				local canne = trouverCanne(perso) or trouverCanne(sac)
				if dansAire(racine.Position) then
					if not canne then
						canne = creerCanne()
						surveillerCanne(player, canne)
						canne.Parent = sac
					end
				elseif canne then
					annuler(player)
					canne:Destroy()
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	etats[player] = nil
	dernierLancer[player] = nil
end)
Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function()
		annuler(player)
	end)
end)
for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterRemoving:Connect(function()
		annuler(player)
	end)
end
