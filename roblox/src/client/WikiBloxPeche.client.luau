-- WikiBlox : pêche (côté joueur)
--
--   1. canne en main : maintenir le clic (ou l'écran) charge le lancer, relâcher lance
--      (la jauge monte et descend : plus elle est haute, plus le flotteur part loin)
--   2. attendre que ça morde (cliquer à nouveau remonte la ligne)
--   3. mini-jeu : maintenir E / clic / bouton pour garder le poisson dans le curseur
--   4. la prise s'affiche (carte ou booster)
--
-- Le serveur (ServerScriptService.Server.WikiBloxPeche) décide de tout ce qui compte ;
-- ce script ne fait que l'affichage et les entrées.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared:WaitForChild("WikiBloxStyle"))
local MiniJeu = require(Shared:WaitForChild("WikiBloxPecheMiniJeu"))
local dossier = ReplicatedStorage:WaitForChild("WikiBloxPeche")
local lancerRemote = dossier:WaitForChild("Lancer")
local remonterRemote = dossier:WaitForChild("Remonter")
local combatRemote = dossier:WaitForChild("Combat")
local evenement = dossier:WaitForChild("Evenement")

local C = Style.C
local new, tween, texte = Style.new, Style.tween, Style.texte

local CYCLE_CHARGE = 1.1 -- secondes pour que la jauge de lancer monte en haut

------------------------------------------------------------------
-- Interface
------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "WikiBloxPecheUI",
	ResetOnSpawn = false,
	DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local statut = texte({
	Name = "Statut",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -130),
	Size = UDim2.fromOffset(520, 34),
	Text = "",
	Font = Style.POLICE_TITRE,
	TextColor3 = C.blanc,
	Contour = C.nuitFonce,
	ContourEpaisseur = 2.5,
	TailleMax = 26,
	Visible = false,
	Parent = gui,
})

local cadreCharge = new("Frame", {
	Name = "Charge",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -90),
	Size = UDim2.fromOffset(320, 28),
	BackgroundColor3 = C.nuitFonce,
	Visible = false,
	Parent = gui,
}, { Style.coins(UDim.new(1, 0)), Style.contour(C.or_, 3) })
local remplissageCharge = new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Parent = cadreCharge,
}, { Style.coins(UDim.new(1, 0)), Style.degrade(C.orClair, C.or_, 0) })

local numeroStatut = 0
local function afficherStatut(message, couleur, duree)
	numeroStatut += 1
	local n = numeroStatut
	statut.Text = message or ""
	statut.TextColor3 = couleur or C.blanc
	statut.Visible = message ~= nil and message ~= ""
	if duree then
		task.delay(duree, function()
			if n == numeroStatut then statut.Visible = false end
		end)
	end
end

------------------------------------------------------------------
-- Affichage de la prise
------------------------------------------------------------------
local popup = nil
local function fermerPopup()
	if popup then
		popup:Destroy()
		popup = nil
	end
end

local function afficherPrise(resultat)
	fermerPopup()
	popup = new("Frame", {
		Name = "Prise",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(250, 360),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = gui,
	}, { Style.coins(18), Style.degrade(C.nuitClair, C.nuit), Style.contour(C.or_, 3) })
	local echelle = new("UIScale", { Scale = 0.3, Parent = popup })
	tween(echelle, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)

	local titre = texte({
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 34),
		Text = "TU AS PÊCHÉ",
		Font = Style.POLICE_TITRE,
		TextColor3 = C.orClair,
		Contour = C.nuitFonce,
		TailleMax = 26,
		Parent = popup,
	})
	local zone = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(196, 280),
		BackgroundTransparency = 1,
		Parent = popup,
	})

	if resultat.prise == "booster" then
		titre.Text = "UN BOOSTER !"
		local icone = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.05),
			Size = UDim2.fromOffset(170, 170),
			BackgroundTransparency = 1,
			Parent = zone,
		})
		Style.icone(icone, "booster", { contour = C.nuitFonce, epaisseur = 3 })
		texte({
			Position = UDim2.fromScale(0, 0.72),
			Size = UDim2.fromScale(1, 0.14),
			Text = ("Boosters : %s"):format(tostring(resultat.boosters or "?")),
			Font = Style.POLICE_TITRE,
			TextColor3 = C.blanc,
			Contour = C.nuitFonce,
			Parent = zone,
		})
	elseif resultat.carte then
		local carte = resultat.carte
		local mention = carte.is_new and "NOUVELLE !" or ("x" .. tostring(carte.copies_owned or 1))
		Style.carte(zone, carte, { mention = mention, nouvelle = carte.is_new == true })
		local r = Style.rarete(carte.rarity)
		if carte.rarity ~= "common" and carte.rarity ~= "uncommon" then
			Style.halo(zone, r.couleur, 8)
		end
	end

	local actuel = popup
	task.delay(4, function()
		if popup == actuel then
			local t = tween(echelle, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			t.Completed:Wait()
			if popup == actuel then fermerPopup() end
		end
	end)
end

------------------------------------------------------------------
-- Flotteur et ligne
------------------------------------------------------------------
local flotteur, ligne, connexionFlotteur = nil, nil, nil

local function retirerFlotteur()
	if connexionFlotteur then
		connexionFlotteur:Disconnect()
		connexionFlotteur = nil
	end
	if flotteur then
		flotteur:Destroy()
		flotteur = nil
	end
	ligne = nil
end

local function poserFlotteur(canne, cible)
	retirerFlotteur()
	local bout = canne:FindFirstChild("Handle") and canne.Handle:FindFirstChild("Bout")
	local depart = bout and bout.WorldPosition or cible

	flotteur = new("Part", {
		Name = "FlotteurPeche",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.8, 0.8, 0.8),
		Color = Color3.fromRGB(230, 50, 50),
		Material = Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Position = depart,
		Parent = workspace,
	})
	local attache = new("Attachment", { Position = Vector3.new(0, 0.3, 0), Parent = flotteur })
	if bout then
		ligne = new("Beam", {
			Attachment0 = bout,
			Attachment1 = attache,
			Width0 = 0.05,
			Width1 = 0.05,
			FaceCamera = true,
			Color = ColorSequence.new(Color3.fromRGB(240, 240, 240)),
			Transparency = NumberSequence.new(0.2),
			CurveSize0 = 0,
			Parent = flotteur,
		})
	end

	-- Vol en cloche jusqu'à l'eau, puis le flotteur dodeline
	local debut = os.clock()
	local DUREE_VOL = 0.55
	local plonge = 0
	flotteur:SetAttribute("Plonge", 0)
	connexionFlotteur = RunService.RenderStepped:Connect(function()
		if not flotteur then return end
		local t = (os.clock() - debut) / DUREE_VOL
		if t < 1 then
			local p = depart:Lerp(cible, t) + Vector3.new(0, math.sin(math.pi * t) * 6, 0)
			flotteur.Position = p
		else
			plonge += ((flotteur:GetAttribute("Plonge") or 0) - plonge) * 0.25
			flotteur.Position = cible + Vector3.new(0, 0.15 + math.sin(os.clock() * 2.5) * 0.12 - plonge, 0)
		end
	end)
end

------------------------------------------------------------------
-- Déroulé
------------------------------------------------------------------
local etat = "repos" -- repos | charge | lancement | attente | combat | resultat
local canne = nil
local debutCharge = 0
local connexionCharge = nil
local partie = nil

local function chargeActuelle()
	local phase = ((os.clock() - debutCharge) / CYCLE_CHARGE) % 2
	return phase <= 1 and phase or 2 - phase
end

local function arreterCharge()
	if connexionCharge then
		connexionCharge:Disconnect()
		connexionCharge = nil
	end
	cadreCharge.Visible = false
end

local function finCombatEntrees()
	ContextActionService:UnbindAction("WikiBloxMoulinet")
	ProximityPromptService.Enabled = true
end

local function remettreAZero()
	arreterCharge()
	if partie then
		partie:arreter()
		partie = nil
	end
	finCombatEntrees()
	retirerFlotteur()
	etat = "repos"
end

local function commencerCharge()
	etat = "charge"
	debutCharge = os.clock()
	cadreCharge.Visible = true
	afficherStatut("Relâche pour lancer !", C.orClair)
	connexionCharge = RunService.RenderStepped:Connect(function()
		remplissageCharge.Size = UDim2.fromScale(chargeActuelle(), 1)
	end)
end

local function lancer()
	local charge = chargeActuelle()
	arreterCharge()
	etat = "lancement"
	local ok, res = pcall(function()
		return lancerRemote:InvokeServer(charge)
	end)
	if etat ~= "lancement" then return end -- canne rangée entre-temps
	if not ok or type(res) ~= "table" or not res.ok then
		etat = "repos"
		afficherStatut((ok and type(res) == "table" and res.erreur) or "Lancer impossible", C.rouge, 2.5)
		return
	end
	etat = "attente"
	if canne then poserFlotteur(canne, res.position) end
	if res.zone then
		afficherStatut(("Zone spéciale : %s ! Attends que ça morde…"):format(res.zone), C.orClair)
	else
		afficherStatut("Attends que ça morde… (clic pour remonter)", C.blanc)
	end
end

local function terminerCombat(reussi)
	partie = nil
	finCombatEntrees()
	etat = "resultat"
	afficherStatut(reussi and "Remontée de la prise…" or nil)
	local ok, res = pcall(function()
		return combatRemote:InvokeServer(reussi)
	end)
	retirerFlotteur()
	if etat ~= "resultat" then return end
	etat = "repos"
	if not ok or type(res) ~= "table" then
		afficherStatut("La prise s'est échappée…", C.rouge, 3)
	elseif not res.ok then
		afficherStatut(res.erreur or "La prise s'est échappée…", C.rouge, 3)
	elseif res.perdu then
		afficherStatut("Le poisson s'est échappé…", C.rouge, 3)
	else
		afficherStatut(nil)
		afficherPrise(res)
	end
end

local function commencerCombat(reglages)
	if etat ~= "attente" then return end
	etat = "combat"
	if flotteur then flotteur:SetAttribute("Plonge", 0.7) end
	afficherStatut("Ça mord !", C.orClair, 1.2)
	-- La touche E sert au moulinet : on coupe les invites (portails…) pendant le combat
	ProximityPromptService.Enabled = false
	partie = MiniJeu.nouveau(gui, reglages, terminerCombat)
	ContextActionService:BindActionAtPriority("WikiBloxMoulinet", function(_, etatEntree)
		if partie then
			partie.appuye = etatEntree == Enum.UserInputState.Begin
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.E, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonA)
	ContextActionService:SetTitle("WikiBloxMoulinet", "Moulinet")
	ContextActionService:SetPosition("WikiBloxMoulinet", UDim2.new(1, -170, 1, -230))
end

evenement.OnClientEvent:Connect(function(genre, a)
	if genre == "morsure" then
		commencerCombat(a)
	elseif genre == "echappe" then
		remettreAZero()
		afficherStatut(a or "Le poisson s'est échappé…", C.rouge, 3)
	end
end)

------------------------------------------------------------------
-- La canne
------------------------------------------------------------------
local branchees = setmetatable({}, { __mode = "k" }) -- une canne reprise en main ne doit pas être branchée deux fois

local function brancherCanne(outil)
	canne = outil
	afficherStatut("Maintiens le clic pour charger, relâche pour lancer", C.blanc, 4)
	if branchees[outil] then return end
	branchees[outil] = true
	outil.Activated:Connect(function()
		if canne ~= outil then return end
		if etat == "repos" then
			fermerPopup()
			commencerCharge()
		elseif etat == "attente" then
			remonterRemote:FireServer()
			remettreAZero()
			afficherStatut("Ligne remontée", C.parcheminFonce, 1.5)
		end
	end)
	outil.Deactivated:Connect(function()
		if canne == outil and etat == "charge" then
			task.spawn(lancer)
		end
	end)
end

local function surPersonnage(perso)
	remettreAZero()
	canne = nil
	perso.ChildAdded:Connect(function(enfant)
		if enfant:IsA("Tool") and enfant:GetAttribute("CannePeche") then
			brancherCanne(enfant)
		end
	end)
	perso.ChildRemoved:Connect(function(enfant)
		if enfant == canne then
			canne = nil
			if etat ~= "repos" then
				remonterRemote:FireServer()
			end
			remettreAZero()
			afficherStatut(nil)
		end
	end)
end

if player.Character then surPersonnage(player.Character) end
player.CharacterAdded:Connect(surPersonnage)
