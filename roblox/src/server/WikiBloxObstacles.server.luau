-- WikiBlox : obstacles qui infligent des dégâts (parcours)
--
-- Toute partie qui a l'attribut Degats (nombre) blesse le joueur qui la touche.
-- L'attribut peut aussi être posé sur un Folder ou un Model parent : toutes les parties
-- qu'il contient deviennent dangereuses.
--
--   Attributs :
--     Degats      (number, obligatoire) : points de vie retirés à chaque contact
--     DelaiDegats (number, facultatif)  : secondes avant que la même partie puisse blesser
--                                         de nouveau le même joueur (défaut : DELAI_DEFAUT)
--
--   Les parties peuvent avoir CanCollide = false : le contact (Touched) fonctionne quand même,
--   à condition que CanTouch soit coché.
--
-- Le script tourne côté serveur : le client ne peut pas s'infliger ou éviter les dégâts.
-- Les dégâts sont ignorés pendant l'invincibilité du point d'apparition (ForceField).

local Players = game:GetService("Players")

local DELAI_DEFAUT = 1 -- secondes entre deux blessures d'un même joueur par une même partie

local branches = {} -- [partie] = true une fois branchée (évite les doublons)
local dernierContact = {} -- [partie] = { [player] = os.clock() du dernier dégât }

-- Cherche l'attribut sur la partie, puis sur ses parents (Model, Folder...), jusqu'au Workspace
local function chercherAttribut(objet, nom)
	local courant = objet
	while courant and courant ~= workspace do
		local valeur = courant:GetAttribute(nom)
		if valeur ~= nil then
			return valeur
		end
		courant = courant.Parent
	end
	return nil
end

-- Blesse le joueur dont le personnage a touché la partie
local function blesser(partie, touche)
	local perso = touche:FindFirstAncestorOfClass("Model")
	local player = perso and Players:GetPlayerFromCharacter(perso)
	local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
	if not player or not humanoide or humanoide.Health <= 0 then return end

	local degats = chercherAttribut(partie, "Degats")
	if type(degats) ~= "number" or degats <= 0 then return end

	-- Anti-répétition : Touched se déclenche plusieurs fois par seconde
	local delai = chercherAttribut(partie, "DelaiDegats")
	if type(delai) ~= "number" then
		delai = DELAI_DEFAUT
	end
	local contacts = dernierContact[partie]
	local maintenant = os.clock()
	if contacts[player] and (maintenant - contacts[player]) < delai then return end
	contacts[player] = maintenant

	humanoide:TakeDamage(degats) -- respecte le ForceField, contrairement à Health -= degats
end

-- Branche une partie dangereuse (Degats sur elle ou sur un de ses parents)
local function brancher(partie)
	if not partie:IsA("BasePart") or branches[partie] then return end
	if type(chercherAttribut(partie, "Degats")) ~= "number" then return end
	branches[partie] = true
	dernierContact[partie] = {}

	partie.CanTouch = true -- indispensable pour que Touched se déclenche
	partie.Touched:Connect(function(touche)
		blesser(partie, touche)
	end)
end

-- On branche les parties déjà présentes, puis celles qui apparaissent plus tard
for _, objet in ipairs(workspace:GetDescendants()) do
	brancher(objet)
end
workspace.DescendantAdded:Connect(brancher)

-- Nettoyage quand un joueur quitte
Players.PlayerRemoving:Connect(function(player)
	for _, contacts in pairs(dernierContact) do
		contacts[player] = nil
	end
end)
