-- WikiBlox : barre de boutons du HUD (à gauche de l'écran), partagée par tous les écrans
-- Direction artistique : voir roblox/DA.md et src/shared/WikiBloxStyle.luau
--
-- Utilisation (dans un LocalScript) :
--   local HUD = require(ReplicatedStorage.Shared.WikiBloxHUD)
--   HUD.ajouterBouton({ id = "Booster", icone = "booster", texte = "BOOSTER", couleur = Color3...,
--                       ordre = 1, raccourci = Enum.KeyCode.B, pulse = true }, ouvrirEcran)
--   HUD.afficher(false)            -- cache toute la barre (quand un écran est ouvert)
--   HUD.declencher("Collection")   -- ouvre l'écran d'un autre bouton
--   HUD.pastille("Quetes", 3)      -- pastille rouge « 3 » sur un bouton (nil pour l'enlever, "!" possible)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Style = require(script.Parent:WaitForChild("WikiBloxStyle"))
local C = Style.C
local new, tween = Style.new, Style.tween

local HUD = {}

local TAILLE = 78 -- taille d'un bouton (pixels)

local barre = nil
local raccourcis = {} -- [KeyCode] = fonction
local rappels = {} -- [id] = fonction (pour HUD.declencher)
local pastilles = {} -- [id] = { cadre, texte, echelle }

local function obtenirBarre()
	if barre and barre.Parent then
		return barre
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("WikiBloxHUD")
	if not gui then
		gui = new("ScreenGui", {
			Name = "WikiBloxHUD",
			ResetOnSpawn = false,
			DisplayOrder = 1,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = playerGui,
		})
	end
	barre = new("Frame", {
		Name = "Barre",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(TAILLE, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 22),
		}),
	})
	return barre
end

-- Ajoute un bouton à la barre. Renvoie le bouton (TextButton).
function HUD.ajouterBouton(options, rappel)
	local parent = obtenirBarre()
	local accent = options.couleur or C.or_
	local fonce = Style.assombrir(accent, 0.55)

	-- Emplacement (bouton + son épaisseur)
	local emplacement = new("Frame", {
		Name = "Bouton" .. options.id,
		LayoutOrder = options.ordre or 1,
		Size = UDim2.fromOffset(TAILLE, TAILLE + 6),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local echelle = new("UIScale", { Parent = emplacement })

	-- Dessous coloré foncé : donne l'épaisseur « 3D »
	new("Frame", {
		Name = "Dessous",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(TAILLE, TAILLE),
		BackgroundColor3 = Style.assombrir(accent, 0.45),
		Parent = emplacement,
	}, { Style.coins(20), Style.contour(fonce, 3) })

	-- Face du bouton : dégradé de la couleur d'accent, contour foncé + filet blanc intérieur
	local bouton = new("TextButton", {
		Name = "Bouton",
		Size = UDim2.fromOffset(TAILLE, TAILLE),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		Parent = emplacement,
	}, {
		Style.coins(20),
		Style.degrade(Style.eclaircir(accent, 0.3), accent),
		Style.contour(fonce, 3),
	})
	new("Frame", {
		Name = "Filet",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1,
		Parent = bouton,
	}, { Style.coins(16), Style.contour(C.blanc, 1.5, 0.55) })
	-- reflet en haut
	new("Frame", {
		Name = "Reflet",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0.36, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		Parent = bouton,
	}, { Style.coins(12) })

	-- Icône dessinée (voir Style.icone : "booster", "collection"…), sinon le texte donné
	local iconeLabel = new("Frame", {
		Name = "Icone",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.64, 0.64),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = bouton,
	})
	if not Style.icone(iconeLabel, options.icone, { contour = fonce, epaisseur = 2.5 }) then
		Style.texte({
			Size = UDim2.fromScale(1, 1),
			Text = options.icone or "?",
			Font = Style.POLICE_TITRE,
			TextColor3 = C.blanc,
			Contour = fonce,
			ZIndex = 2,
			Parent = iconeLabel,
		})
	end

	-- Étiquette en bas du bouton, style cartoon (texte blanc contour foncé)
	Style.texte({
		Name = "Texte",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, 16, 0, 22),
		Text = options.texte or "",
		Font = Style.POLICE_TITRE,
		TextColor3 = C.blanc,
		Contour = fonce,
		ContourEpaisseur = 2.5,
		TailleMax = 17,
		ZIndex = 3,
		Parent = bouton,
	})

	-- Pastille de raccourci clavier (cachée sur mobile) : parchemin bordé d'or
	if options.raccourci then
		raccourcis[options.raccourci] = rappel
		local touche = new("Frame", {
			Name = "Touche",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Visible = UserInputService.KeyboardEnabled,
			ZIndex = 4,
			Parent = emplacement,
		}, {
			Style.coins(8),
			Style.degrade(C.parchemin, C.parcheminFonce),
			Style.contour(C.orFonce, 2),
		})
		Style.texte({
			Size = UDim2.fromScale(1, 1),
			Text = options.raccourci.Name,
			Font = Style.POLICE_TITRE,
			TextColor3 = C.encre,
			ZIndex = 5,
			Parent = touche,
		})
	end

	-- Pastille rouge de notification (cachée par défaut, voir HUD.pastille)
	local notif = new("Frame", {
		Name = "Notification",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 6,
		Parent = emplacement,
	}, {
		Style.coins(UDim.new(1, 0)),
		Style.degrade(Color3.fromRGB(255, 110, 105), C.rouge),
		Style.contour(C.blanc, 2.5),
	})
	local notifTexte = Style.texte({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		Text = "",
		Font = Style.POLICE_TITRE,
		TextColor3 = C.blanc,
		ZIndex = 7,
		Parent = notif,
	})
	pastilles[options.id] = { cadre = notif, texte = notifTexte, echelle = new("UIScale", { Parent = notif }) }

	-- Le bouton « respire » doucement pour attirer l'œil (ex. bouton Booster)
	local echelleRespire = new("UIScale", { Parent = bouton })
	if options.pulse then
		TweenService:Create(echelleRespire, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Scale = 1.06,
		}):Play()
		TweenService:Create(iconeLabel, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Rotation = -8,
		}):Play()
	end

	-- Animations de survol et de clic
	local survol = false
	bouton.MouseEnter:Connect(function()
		survol = true
		tween(echelle, 0.18, { Scale = 1.1 }, Enum.EasingStyle.Back)
		tween(emplacement, 0.18, { Rotation = -4 }, Enum.EasingStyle.Back)
	end)
	bouton.MouseLeave:Connect(function()
		survol = false
		tween(echelle, 0.15, { Scale = 1 })
		tween(emplacement, 0.15, { Rotation = 0 })
		tween(bouton, 0.1, { Position = UDim2.new() })
	end)
	bouton.MouseButton1Down:Connect(function()
		tween(bouton, 0.06, { Position = UDim2.fromOffset(0, 5) })
	end)
	bouton.MouseButton1Up:Connect(function()
		tween(bouton, 0.15, { Position = UDim2.new() }, Enum.EasingStyle.Back)
		if not survol then
			tween(echelle, 0.15, { Scale = 1 })
			tween(emplacement, 0.15, { Rotation = 0 })
		end
	end)

	if rappel then
		rappels[options.id] = rappel
		bouton.Activated:Connect(rappel)
	end
	return bouton
end

-- Affiche ou cache toute la barre (on la cache quand un écran est ouvert)
function HUD.afficher(visible)
	obtenirBarre().Visible = visible
end

-- Ouvre l'écran d'un autre bouton (ex. « Voir ma collection » depuis l'écran Booster)
function HUD.declencher(id)
	local rappel = rappels[id]
	if rappel then
		task.spawn(rappel)
		return true
	end
	return false
end

-- Pastille rouge sur un bouton : HUD.pastille("Quetes", 3) / HUD.pastille("Cadeau", "!") / HUD.pastille("Quetes", nil)
function HUD.pastille(id, valeur)
	local p = pastilles[id]
	if not p then return end
	if valeur == nil or valeur == 0 or valeur == false then
		p.cadre.Visible = false
		return
	end
	p.texte.Text = tostring(valeur)
	if not p.cadre.Visible then
		p.cadre.Visible = true
		p.echelle.Scale = 0
		tween(p.echelle, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

-- Raccourcis clavier (ignorés pendant la saisie dans le chat ou une zone de texte)
UserInputService.InputBegan:Connect(function(input, dejaTraite)
	if dejaTraite then return end
	local rappel = raccourcis[input.KeyCode]
	if rappel and barre and barre.Visible then
		rappel()
	end
end)

return HUD
