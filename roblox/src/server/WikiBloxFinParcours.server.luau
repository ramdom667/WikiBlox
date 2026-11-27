-- WikiBlox : fin du parcours (récompense en boosters + retour au départ)
--
-- Toute partie qui a l'attribut FinParcours = true reçoit un bouton (ProximityPrompt).
-- Quand le joueur l'active : il gagne des boosters, puis il est ramené au départ avec un fondu.
--
--   Attributs à poser sur la partie de fin :
--     FinParcours (bool, obligatoire) : coché pour activer ce script sur la partie
--     Boosters    (number, facultatif) : boosters donnés (défaut : NB_BOOSTERS)
--     Depart      (string, facultatif) : nom de la partie de départ (défaut : ArriveeParcours)
--     NomLieu     (string, facultatif) : texte affiché sous le bouton
--
--   IMPORTANT : ne PAS mettre l'attribut Destination sur cette partie, sinon le script des
--   portails (WikiBloxTeleport) créerait un deuxième bouton de téléportation.
--
-- Les boosters passent par WikiBloxInventaire (stock partagé et sauvegardé dans le DataStore) :
-- le compteur BOOSTER de l'interface se met à jour tout seul.
-- Ce script doit se trouver dans le même dossier que WikiBloxInventaire (ServerScriptService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventaire = require(script.Parent:WaitForChild("WikiBloxInventaire"))

-- Réglages (équilibrage)
local NB_BOOSTERS = 1 -- boosters donnés par défaut à chaque parcours terminé
local DEPASSER_MAX = true -- true : la récompense peut dépasser le plafond de boosters du stock
local DELAI_MINIMUM = 600 -- secondes minimum entre deux récompenses pour un même joueur
local FONDU = 0.4 -- durée du fondu au noir avant de déplacer le joueur
local DEPART_DEFAUT = "ArriveeParcours" -- partie où le joueur revient après le parcours

-- Même RemoteEvent que les portails : le script client affiche le fondu et les messages
local remote = ReplicatedStorage:WaitForChild("WikiBloxMonde", 15)

local enCours = {} -- [player] = true pendant le traitement (évite les doubles clics)
local derniereRecompense = {} -- [player] = os.clock() de la dernière récompense donnée
local branches = {} -- [partie] = true une fois le bouton créé (évite les doublons)

-- Petit message en haut de l'écran du joueur
local function prevenir(player, texte)
	if remote then
		remote:FireClient(player, "message", texte)
	end
end

-- Donne les boosters et renvoie le nombre réellement ajoutés (0 si rien n'a pu être ajouté)
local function donnerBoosters(player, nombre)
	local ok, ajoutes = pcall(Inventaire.ajouter, player, nombre, DEPASSER_MAX)
	if not ok then
		warn("[WikiBlox] Ajout de boosters impossible :", ajoutes)
		return 0
	end
	return ajoutes
end

-- Ramène le joueur à la partie de départ, avec le fondu
local function retourDepart(player, nomDepart)
	local depart = workspace:FindFirstChild(nomDepart, true)
	if not depart or not depart:IsA("BasePart") then
		warn("[WikiBlox] Départ du parcours introuvable :", nomDepart)
		return
	end
	if remote then
		remote:FireClient(player, "fondu", FONDU, nomDepart)
	end
	task.wait(FONDU) -- on attend que l'écran soit noir avant de déplacer le joueur
	local perso = player.Character
	local racine = perso and perso:FindFirstChild("HumanoidRootPart")
	if racine then
		perso:PivotTo(depart.CFrame * CFrame.new(0, 3, 0))
		racine.AssemblyLinearVelocity = Vector3.zero -- on annule la vitesse (pas de chute à l'arrivée)
	end
end

-- Récompense (si le délai minimum est respecté) puis retour au départ
local function terminerParcours(player, objet)
	if enCours[player] then return end
	enCours[player] = true

	local maintenant = os.clock()
	local dernier = derniereRecompense[player]
	local recompense = not dernier or (maintenant - dernier) >= DELAI_MINIMUM

	if recompense then
		local nombre = objet:GetAttribute("Boosters") or NB_BOOSTERS
		local ajoutes = donnerBoosters(player, nombre)
		if ajoutes > 0 then
			derniereRecompense[player] = maintenant
			prevenir(player, "Parcours terminé ! +" .. ajoutes .. " booster" .. (ajoutes > 1 and "s" or ""))
		elseif Inventaire.nombre(player) == nil then
			-- Les données du joueur ne sont pas encore chargées : il pourra réessayer
			prevenir(player, "Tes boosters sont en cours de chargement, réessaie dans un instant.")
		else
			prevenir(player, "Parcours terminé ! Ton stock de boosters est plein.")
		end
	else
		prevenir(player, "Parcours terminé ! Pas de récompense si vite.")
	end

	retourDepart(player, objet:GetAttribute("Depart") or DEPART_DEFAUT)

	-- Petite pause avant de pouvoir réactiver le bouton
	task.delay(1.5, function()
		enCours[player] = nil
	end)
end

-- Crée le bouton « Récupérer et retourner au début » sur une partie marquée FinParcours
local function brancher(objet)
	if not objet:IsA("BasePart") or branches[objet] then return end
	if not objet:GetAttribute("FinParcours") then return end
	branches[objet] = true

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Récupérer et retourner au début"
	prompt.ObjectText = objet:GetAttribute("NomLieu") or "Fin du parcours"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = objet
	prompt.Triggered:Connect(function(player)
		terminerParcours(player, objet)
	end)
end

-- On branche les parties déjà présentes, puis celles qui apparaissent plus tard
for _, objet in ipairs(workspace:GetDescendants()) do
	brancher(objet)
end
workspace.DescendantAdded:Connect(brancher)

-- Nettoyage quand un joueur quitte
Players.PlayerRemoving:Connect(function(player)
	enCours[player] = nil
	derniereRecompense[player] = nil
end)
