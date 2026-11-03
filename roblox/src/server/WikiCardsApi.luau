-- WikiCardsApi : client HTTP de l'API WikiCards (https://wikiblox.omertilki.fr)
--
-- SERVEUR UNIQUEMENT. La clé d'API vient du Secrets Store de Roblox
-- (secret "wikiblox_game_key") et ne doit jamais apparaître dans un script client.
-- Documentation : roblox/API.md
--
-- Chaque fonction renvoie (ok, data) :
--   ok = true  -> data = réponse JSON décodée (table)
--   ok = false -> data = { status = code HTTP (0 = réseau / secret), message = string }

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

assert(RunService:IsServer(), "WikiCardsApi ne doit être utilisé que côté serveur")

local WikiCardsApi = {}

WikiCardsApi.BASE_URL = "https://wikiblox.omertilki.fr"
WikiCardsApi.SECRET_NAME = "wikiblox_game_key"

local MAX_ATTEMPTS = 3
-- Codes pour lesquels on retente (erreurs temporaires du serveur ou du tunnel)
local RETRY_STATUS = { [429] = true, [500] = true, [502] = true, [503] = true, [504] = true }

local cachedKey = nil
local function getApiKey()
	if not cachedKey then
		cachedKey = HttpService:GetSecret(WikiCardsApi.SECRET_NAME)
	end
	return cachedKey
end

local function errorDetail(response, data)
	local detail = type(data) == "table" and data.detail or nil
	if detail == nil then
		return response.StatusMessage
	end
	if type(detail) ~= "string" then
		-- Erreur de validation FastAPI (422) : liste d'erreurs
		return HttpService:JSONEncode(detail)
	end
	return detail
end

local function request(method, path, body)
	local keyOk, key = pcall(getApiKey)
	if not keyOk then
		return false, {
			status = 0,
			message = "Secret '" .. WikiCardsApi.SECRET_NAME .. "' introuvable : " .. tostring(key),
		}
	end

	local options = {
		Url = WikiCardsApi.BASE_URL .. path,
		Method = method,
		Headers = {
			["X-API-Key"] = key,
			["Accept"] = "application/json",
		},
	}
	if body then
		options.Body = HttpService:JSONEncode(body)
		options.Headers["Content-Type"] = "application/json"
	end

	local lastError
	for attempt = 1, MAX_ATTEMPTS do
		local sent, response = pcall(HttpService.RequestAsync, HttpService, options)
		if sent then
			local decoded, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
			if response.Success and decoded then
				return true, data
			end
			lastError = {
				status = response.StatusCode,
				message = response.Success and "Réponse JSON invalide" or errorDetail(response, decoded and data or nil),
			}
			if not response.Success and not RETRY_STATUS[response.StatusCode] then
				return false, lastError -- 401, 403, 404, 409, 422... : inutile de réessayer
			end
		else
			lastError = { status = 0, message = tostring(response) } -- réseau, DNS, HTTP désactivé...
		end
		if attempt < MAX_ATTEMPTS then
			task.wait(attempt * 2)
		end
	end
	return false, lastError
end

-- Types de boosters et probabilités (à afficher en jeu avant l'achat)
function WikiCardsApi.getBoosters()
	return request("GET", "/api/boosters")
end

-- Ouvre un booster pour un joueur.
-- requestId : identifiant unique de CETTE ouverture (GUID, ou PurchaseId d'un achat Robux).
-- Les nouvelles tentatives réutilisent le même requestId : l'API renvoie alors le même
-- booster (replayed = true) au lieu d'en ouvrir un second.
function WikiCardsApi.openBooster(player, boosterType, requestId)
	return request("POST", "/api/boosters/open", {
		roblox_user_id = player.UserId,
		roblox_username = player.Name,
		booster_type = boosterType or "standard",
		request_id = requestId or HttpService:GenerateGUID(false),
	})
end

-- Collection d'un joueur. Code 404 = le joueur n'a encore ouvert aucun booster.
function WikiCardsApi.getCollection(userId)
	return request("GET", "/api/players/" .. tostring(userId) .. "/collection")
end

return WikiCardsApi
