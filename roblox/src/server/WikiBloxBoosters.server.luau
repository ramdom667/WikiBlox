-- WikiBlox : boosters et collections exposés aux clients
--
-- Crée ReplicatedStorage.WikiBloxRemotes avec trois RemoteFunction :
--   ProbaBoosters:InvokeServer()                -> { success, boosters }
--   OuvrirBooster:InvokeServer("standard")      -> { success, booster } ou { success = false, error }
--   MaCollection:InvokeServer()                 -> { success, collection } (collection = nil si vide)
--
-- Le client ne parle JAMAIS à l'API : il demande au serveur, qui vérifie puis appelle l'API.
-- Documentation : roblox/API.md

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WikiCardsApi = require(script.Parent.WikiCardsApi)

local COOLDOWN = 3 -- secondes minimum entre deux appels d'un même joueur

local remotes = Instance.new("Folder")
remotes.Name = "WikiBloxRemotes"

local oddsRemote = Instance.new("RemoteFunction")
oddsRemote.Name = "ProbaBoosters"
oddsRemote.Parent = remotes

local openRemote = Instance.new("RemoteFunction")
openRemote.Name = "OuvrirBooster"
openRemote.Parent = remotes

local collectionRemote = Instance.new("RemoteFunction")
collectionRemote.Name = "MaCollection"
collectionRemote.Parent = remotes

remotes.Parent = ReplicatedStorage

-- Anti-spam : un appel à la fois par joueur, avec un délai minimum
local lastCall = {}
local busy = {}

local function tryAcquire(player)
	local now = os.clock()
	if busy[player] or (lastCall[player] and now - lastCall[player] < COOLDOWN) then
		return false
	end
	busy[player] = true
	lastCall[player] = now
	return true
end

local function release(player)
	busy[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
	busy[player] = nil
end)

-- Types de boosters connus (rechargés au démarrage du serveur)
local boosterOdds = nil
local knownBoosters = { standard = true }

task.spawn(function()
	local ok, data = WikiCardsApi.getBoosters()
	if ok then
		boosterOdds = data.boosters
		knownBoosters = {}
		for id in pairs(data.boosters) do
			knownBoosters[id] = true
		end
		print("[WikiBlox] Boosters chargés depuis l'API")
	else
		warn("[WikiBlox] Boosters indisponibles :", data.status, data.message)
	end
end)

oddsRemote.OnServerInvoke = function()
	if not boosterOdds then
		local ok, data = WikiCardsApi.getBoosters()
		if not ok then
			return { success = false, error = "Probabilités indisponibles" }
		end
		boosterOdds = data.boosters
	end
	return { success = true, boosters = boosterOdds }
end

openRemote.OnServerInvoke = function(player, boosterType)
	if typeof(boosterType) ~= "string" or not knownBoosters[boosterType] then
		return { success = false, error = "Type de booster inconnu" }
	end
	if not tryAcquire(player) then
		return { success = false, error = "Patiente un instant" }
	end

	-- À FAIRE : vérifier et débiter la monnaie du jeu ICI, avant l'ouverture.
	-- Pour un booster payant en Robux, passer par ProcessReceipt (voir roblox/API.md).

	local ok, data = WikiCardsApi.openBooster(player, boosterType)
	release(player)

	if not ok then
		warn(("[WikiBlox] Ouverture échouée pour %s (%d) : %s %s"):format(
			player.Name, player.UserId, tostring(data.status), tostring(data.message)))
		return { success = false, error = "Ouverture impossible, réessaie plus tard" }
	end
	return { success = true, booster = data }
end

collectionRemote.OnServerInvoke = function(player)
	if not tryAcquire(player) then
		return { success = false, error = "Patiente un instant" }
	end
	local ok, data = WikiCardsApi.getCollection(player.UserId)
	release(player)

	if ok then
		return { success = true, collection = data }
	end
	if data.status == 404 then
		return { success = true, collection = nil } -- aucun booster ouvert pour l'instant
	end
	warn("[WikiBlox] Collection indisponible :", data.status, data.message)
	return { success = false, error = "Collection indisponible" }
end
