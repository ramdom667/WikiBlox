-- WikiBlox : stock de boosters de chaque joueur (sauvegardé dans le DataStore)
--
--   * première visite : 10 boosters offerts
--   * +1 booster toutes les 10 minutes, même quand le joueur n'est pas connecté
--   * 10 boosters au maximum : tant que le stock est plein, le minuteur est en pause
--
-- Attributs posés sur le joueur (lus par l'interface) :
--   Boosters         = nombre de boosters
--   BoostersMax      = stock maximum
--   ProchainBooster  = date (os.time) du prochain booster, 0 si le stock est plein
--   InventaireErreur = true si la sauvegarde n'a pas pu être chargée
--
-- Utilisation (côté serveur uniquement) :
--   local Inventaire = require(script.Parent.WikiBloxInventaire)
--   Inventaire.retirer(player)                -> true, ou false + raison
--   Inventaire.ajouter(player, n, depasserMax) -> nombre de boosters réellement ajoutés
--   Inventaire.nombre(player)                 -> nombre de boosters (nil si pas chargé)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MAX = 10
local BIENVENUE = 10
local INTERVALLE = 10 * 60 -- secondes entre deux boosters

-- En Studio, on utilise un DataStore à part pour ne pas toucher aux vraies sauvegardes
local NOM_STORE = RunService:IsStudio() and "WikiBloxInventaire_Studio" or "WikiBloxInventaire"
local store = DataStoreService:GetDataStore(NOM_STORE)

local Inventaire = {}
Inventaire.MAX = MAX
Inventaire.INTERVALLE = INTERVALLE

local donnees = {} -- [player] = { boosters, dernierGain }
local pret = {} -- [player] = true une fois la sauvegarde chargée
local enCours = {} -- [player] = true pendant une sauvegarde
local aRefaire = {} -- [player] = true si une sauvegarde a été demandée pendant la précédente

local function cle(player)
	return "joueur_" .. player.UserId
end

local function reessayer(fn)
	local ok, resultat
	for essai = 1, 3 do
		ok, resultat = pcall(fn)
		if ok then
			return true, resultat
		end
		if essai < 3 then
			task.wait(essai * 2)
		end
	end
	return false, resultat
end

-- Ajoute les boosters gagnés depuis dernierGain. Renvoie true si le stock a changé.
local function recharger(d, maintenant)
	if d.dernierGain > maintenant then
		d.dernierGain = maintenant
	end
	if d.boosters >= MAX then
		d.dernierGain = maintenant -- stock plein : le minuteur repartira au prochain booster dépensé
		return false
	end
	local gagnes = math.floor((maintenant - d.dernierGain) / INTERVALLE)
	if gagnes <= 0 then
		return false
	end
	d.boosters = math.min(MAX, d.boosters + gagnes)
	if d.boosters >= MAX then
		d.dernierGain = maintenant
	else
		d.dernierGain += gagnes * INTERVALLE -- on garde les secondes déjà écoulées
	end
	return true
end

local function publier(player)
	local d = donnees[player]
	if not d then
		return
	end
	player:SetAttribute("BoostersMax", MAX)
	player:SetAttribute("Boosters", d.boosters)
	player:SetAttribute("ProchainBooster", d.boosters >= MAX and 0 or d.dernierGain + INTERVALLE)
end

-- Sauvegarde en arrière-plan. Les sauvegardes d'un même joueur passent l'une après l'autre,
-- pour qu'une ancienne valeur n'écrase jamais une plus récente.
local function sauvegarder(player)
	if not pret[player] then
		return
	end
	if enCours[player] then
		aRefaire[player] = true
		return
	end
	enCours[player] = true
	repeat
		aRefaire[player] = nil
		local d = donnees[player]
		local copie = { boosters = d.boosters, dernierGain = d.dernierGain, bienvenue = true }
		local ok, err = reessayer(function()
			store:UpdateAsync(cle(player), function()
				return copie
			end)
		end)
		if not ok then
			warn(("[WikiBlox] Sauvegarde des boosters impossible pour %s (%d) : %s"):format(
				player.Name, player.UserId, tostring(err)))
		end
	until not aRefaire[player]
	enCours[player] = nil
end

local function charger(player)
	local ok, sauvegarde = reessayer(function()
		return store:GetAsync(cle(player))
	end)
	if not player.Parent then
		return -- le joueur est déjà parti
	end
	if not ok then
		-- On ne donne rien et on ne sauvegarde rien, pour ne pas écraser sa vraie sauvegarde
		warn(("[WikiBlox] Chargement des boosters impossible pour %s (%d) : %s"):format(
			player.Name, player.UserId, tostring(sauvegarde)))
		player:SetAttribute("InventaireErreur", true)
		return
	end

	local maintenant = os.time()
	local d
	if type(sauvegarde) == "table" and sauvegarde.bienvenue then
		d = {
			boosters = math.max(0, math.floor(tonumber(sauvegarde.boosters) or 0)),
			dernierGain = tonumber(sauvegarde.dernierGain) or maintenant,
		}
	else
		d = { boosters = BIENVENUE, dernierGain = maintenant }
		print(("[WikiBlox] Première visite de %s : %d boosters offerts"):format(player.Name, BIENVENUE))
	end
	recharger(d, maintenant)

	donnees[player] = d
	pret[player] = true
	publier(player)
	sauvegarder(player)
end

function Inventaire.nombre(player)
	local d = donnees[player]
	return d and d.boosters or nil
end

function Inventaire.retirer(player)
	local d = donnees[player]
	if not pret[player] or not d then
		return false, "Tes boosters sont en cours de chargement"
	end
	recharger(d, os.time())
	if d.boosters <= 0 then
		return false, "Plus de booster ! Le prochain arrive bientôt"
	end
	d.boosters -= 1
	publier(player)
	task.spawn(sauvegarder, player)
	return true
end

-- depasserMax = true pour rendre un booster même si le stock est plein (ex. ouverture ratée)
function Inventaire.ajouter(player, n, depasserMax)
	local d = donnees[player]
	if not pret[player] or not d then
		return 0
	end
	local maintenant = os.time()
	recharger(d, maintenant)
	local avant = d.boosters
	d.boosters = depasserMax and (avant + n) or math.min(MAX, avant + n)
	if d.boosters >= MAX then
		d.dernierGain = maintenant
	end
	publier(player)
	task.spawn(sauvegarder, player)
	return d.boosters - avant
end

------------------------------------------------------------------
-- Arrivée / départ des joueurs
------------------------------------------------------------------
Players.PlayerAdded:Connect(charger)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(charger, player)
end

Players.PlayerRemoving:Connect(function(player)
	sauvegarder(player)
	while enCours[player] do
		task.wait()
	end
	donnees[player], pret[player], aRefaire[player] = nil, nil, nil
end)

game:BindToClose(function()
	for player in pairs(donnees) do
		task.spawn(sauvegarder, player)
	end
	local limite = os.clock() + 25
	while next(enCours) and os.clock() < limite do
		task.wait()
	end
end)

-- Minuteur : chaque seconde, on distribue les boosters gagnés
task.spawn(function()
	while true do
		task.wait(1)
		local maintenant = os.time()
		for player, d in pairs(donnees) do
			if pret[player] and recharger(d, maintenant) then
				publier(player)
				task.spawn(sauvegarder, player)
			end
		end
	end
end)

return Inventaire
