-- WikiBlox : style commun des écrans (Booster, Collection, et les futurs : Boutique, Quêtes, Codes…)
-- Thème « bibliothèque magique » : bleu nuit, or, parchemin.
--
--   local Style = require(ReplicatedStorage.Shared.WikiBloxStyle)
--   local f = Style.fenetre(gui, { titre = "MA COLLECTION", taille = UDim2.fromScale(0.92, 0.86), max = Vector2.new(1000, 680) })
--   Style.ouvrir(f) / Style.fermer(f)
--   local b = Style.bouton(parent, { texte = "OUVRIR", couleur = Style.C.or_, taille = ..., position = ... })
--   Style.carte(cadre, carte, { mention = "x3" })   -- recto d'une carte (remplit le cadre)
--   Style.dos(cadre)                                -- dos d'une carte

local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Style = {}

------------------------------------------------------------------
-- Couleurs, raretés, polices
------------------------------------------------------------------
Style.C = {
	nuit = Color3.fromRGB(26, 31, 54),
	nuitClair = Color3.fromRGB(46, 55, 92),
	nuitFonce = Color3.fromRGB(14, 17, 32),
	or_ = Color3.fromRGB(240, 190, 75),
	orClair = Color3.fromRGB(255, 224, 140),
	orFonce = Color3.fromRGB(170, 115, 30),
	parchemin = Color3.fromRGB(248, 238, 214),
	parcheminFonce = Color3.fromRGB(222, 200, 160),
	encre = Color3.fromRGB(45, 32, 22),
	blanc = Color3.fromRGB(250, 248, 242),
	rouge = Color3.fromRGB(235, 80, 80),
	rougeFonce = Color3.fromRGB(150, 35, 40),
	bleu = Color3.fromRGB(80, 165, 255),
	gris = Color3.fromRGB(140, 140, 155),
}
local C = Style.C

Style.RARETES = {
	common    = { nom = "COMMUNE",     couleur = Color3.fromRGB(160, 165, 180), clair = Color3.fromRGB(215, 218, 228), etoiles = 1 },
	uncommon  = { nom = "PEU COMMUNE", couleur = Color3.fromRGB(60, 190, 110),  clair = Color3.fromRGB(150, 235, 175), etoiles = 2 },
	rare      = { nom = "RARE",        couleur = Color3.fromRGB(55, 135, 255),  clair = Color3.fromRGB(150, 200, 255), etoiles = 3 },
	epic      = { nom = "ÉPIQUE",      couleur = Color3.fromRGB(165, 75, 255),  clair = Color3.fromRGB(215, 165, 255), etoiles = 4 },
	legendary = { nom = "LÉGENDAIRE",  couleur = Color3.fromRGB(255, 175, 30),  clair = Color3.fromRGB(255, 230, 140), etoiles = 5 },
}
Style.ORDRE = { "common", "uncommon", "rare", "epic", "legendary" }

function Style.rarete(id)
	return Style.RARETES[id] or Style.RARETES.common
end

Style.POLICE_TITRE = Enum.Font.FredokaOne
Style.POLICE = Enum.Font.GothamBold
Style.POLICE_LIVRE = Enum.Font.Merriweather

------------------------------------------------------------------
-- Outils
------------------------------------------------------------------
function Style.new(class, props, enfants)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, enfant in ipairs(enfants or {}) do
		enfant.Parent = inst
	end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end
local new = Style.new

function Style.coins(rayon)
	return new("UICorner", { CornerRadius = typeof(rayon) == "UDim" and rayon or UDim.new(0, rayon or 12) })
end

function Style.degrade(haut, bas, rotation)
	return new("UIGradient", { Rotation = rotation or 90, Color = ColorSequence.new(haut, bas) })
end

function Style.contour(couleur, epaisseur, transparence)
	return new("UIStroke", {
		Color = couleur,
		Thickness = epaisseur or 2,
		Transparency = transparence or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Style.tween(objet, duree, props, style, direction)
	local t = TweenService:Create(objet, TweenInfo.new(duree, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end
local tween = Style.tween

function Style.eclaircir(c, k)
	return c:Lerp(Color3.new(1, 1, 1), k or 0.35)
end
function Style.assombrir(c, k)
	return c:Lerp(Color3.new(0, 0, 0), k or 0.35)
end

-- Texte. props.Contour = couleur du contour du texte (style cartoon)
function Style.texte(props)
	local contour = props.Contour
	local epaisseur = props.ContourEpaisseur
	local tailleMax = props.TailleMax
	props.Contour, props.ContourEpaisseur, props.TailleMax = nil, nil, nil
	if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
	props.Font = props.Font or Style.POLICE
	props.TextColor3 = props.TextColor3 or C.blanc
	if props.TextScaled == nil then props.TextScaled = true end
	if props.TextWrapped == nil then props.TextWrapped = true end
	local t = new("TextLabel", props)
	if contour then
		new("UIStroke", { Color = contour, Thickness = epaisseur or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = t })
	end
	if tailleMax then
		new("UITextSizeConstraint", { MaxTextSize = tailleMax, Parent = t })
	end
	return t
end

------------------------------------------------------------------
-- Bouton « 3D » : ombre dessous, dégradé, contour foncé, s'enfonce au clic
------------------------------------------------------------------
-- opts : texte, couleur, couleurTexte, taille, position, ancre, max (Vector2), ordre, police, icone (voir Style.icone)
-- Renvoie le TextButton (utiliser .Activated). Style.activerBouton(b, false) pour le griser.
function Style.bouton(parent, opts)
	local couleur = opts.couleur or C.or_
	local cadre = new("Frame", {
		Name = opts.nom or "Bouton",
		AnchorPoint = opts.ancre or Vector2.new(0, 0),
		Position = opts.position or UDim2.new(),
		Size = opts.taille or UDim2.fromOffset(160, 52),
		LayoutOrder = opts.ordre or 0,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	if opts.max then
		new("UISizeConstraint", { MaxSize = opts.max, Parent = cadre })
	end
	-- dessous (donne l'épaisseur)
	local dessous = new("Frame", {
		Name = "Dessous",
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Style.assombrir(couleur, 0.45),
		Parent = cadre,
	}, { Style.coins(14) })
	local b = new("TextButton", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		Parent = cadre,
	}, {
		Style.coins(14),
		Style.degrade(Style.eclaircir(couleur, 0.25), couleur),
		Style.contour(Style.assombrir(couleur, 0.55), 2.5),
	})
	-- reflet
	new("Frame", {
		Name = "Reflet",
		Position = UDim2.new(0, 6, 0, 4),
		Size = UDim2.new(1, -12, 0.38, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Parent = b,
	}, { Style.coins(10) })
	local label = Style.texte({
		Name = "Texte",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -20, 0.58, 0),
		Text = opts.texte or "",
		Font = opts.police or Style.POLICE_TITRE,
		TextColor3 = opts.couleurTexte or C.blanc,
		Contour = Style.assombrir(couleur, 0.6),
		ContourEpaisseur = 2,
		TailleMax = opts.tailleTexte or 28,
		Parent = b,
	})
	-- icône dessinée à gauche du texte (opts.icone = "booster", "collection", "probabilites"…)
	if opts.icone then
		local zone = new("Frame", {
			Name = "Icone",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromScale(0.66, 0.66),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundTransparency = 1,
			ZIndex = b.ZIndex + 1,
			Parent = b,
		})
		Style.icone(zone, opts.icone, { contour = Style.assombrir(couleur, 0.6), epaisseur = 2 })
		local function placer()
			local largeur = zone.AbsoluteSize.X + 10
			label.Position = UDim2.new(0.5, largeur / 2, 0.5, 0)
			label.Size = UDim2.new(1, -(20 + largeur), 0.58, 0)
		end
		zone:GetPropertyChangedSignal("AbsoluteSize"):Connect(placer)
		placer()
	end
	local echelle = new("UIScale", { Parent = cadre })

	local survol = false
	b.MouseEnter:Connect(function()
		survol = true
		if b.Active then tween(echelle, 0.15, { Scale = 1.05 }, Enum.EasingStyle.Back) end
	end)
	b.MouseLeave:Connect(function()
		survol = false
		tween(echelle, 0.15, { Scale = 1 })
		tween(b, 0.08, { Position = UDim2.new() })
	end)
	b.MouseButton1Down:Connect(function()
		if b.Active then tween(b, 0.06, { Position = UDim2.fromOffset(0, 4) }) end
	end)
	b.MouseButton1Up:Connect(function()
		tween(b, 0.12, { Position = UDim2.new() }, Enum.EasingStyle.Back)
		if not survol then tween(echelle, 0.15, { Scale = 1 }) end
	end)

	b:SetAttribute("Couleur", couleur)
	return b, label, dessous
end

-- Change la couleur d'un bouton créé avec Style.bouton
function Style.colorerBouton(b, couleur)
	b:SetAttribute("Couleur", couleur)
	local g = b:FindFirstChildOfClass("UIGradient")
	if g then g.Color = ColorSequence.new(Style.eclaircir(couleur, 0.25), couleur) end
	local s = b:FindFirstChildOfClass("UIStroke")
	if s then s.Color = Style.assombrir(couleur, 0.55) end
	local dessous = b.Parent:FindFirstChild("Dessous")
	if dessous then dessous.BackgroundColor3 = Style.assombrir(couleur, 0.45) end
	local t = b:FindFirstChild("Texte")
	local ts = t and t:FindFirstChildOfClass("UIStroke")
	if ts then ts.Color = Style.assombrir(couleur, 0.6) end
end

function Style.activerBouton(b, actif)
	b.Active = actif
	local couleur = b:GetAttribute("Couleur") or C.or_
	local g = b:FindFirstChildOfClass("UIGradient")
	if g then
		local base = actif and couleur or Color3.fromRGB(120, 120, 130)
		g.Color = ColorSequence.new(Style.eclaircir(base, 0.25), base)
	end
end

------------------------------------------------------------------
-- Fenêtre : fond sombre + flou, cadre bleu nuit à double bordure dorée,
-- ruban-titre en parchemin, bouton fermer rouge, coins ornés
------------------------------------------------------------------
-- opts : titre, taille (UDim2), max (Vector2)
-- Renvoie { fond, fenetre, contenu, fermer, titre, echelle }
function Style.fenetre(gui, opts)
	local fond = new("Frame", {
		Name = "Fond",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.nuitFonce,
		BackgroundTransparency = 0.35,
		Active = true,
		Visible = false,
		Parent = gui,
	})
	local fenetre = new("Frame", {
		Name = "Fenetre",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = opts.taille or UDim2.fromScale(0.9, 0.82),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = fond,
	}, {
		Style.coins(22),
		Style.degrade(C.nuitClair, C.nuit),
		Style.contour(C.or_, 4),
		new("UISizeConstraint", { MaxSize = opts.max or Vector2.new(980, 640) }),
	})
	local echelle = new("UIScale", { Parent = fenetre })
	-- deuxième filet doré à l'intérieur
	new("Frame", {
		Name = "Filet",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -16),
		BackgroundTransparency = 1,
		Parent = fenetre,
	}, { Style.coins(16), Style.contour(C.orFonce, 1.5, 0.3) })
	-- motif léger de pages (lignes horizontales très discrètes)
	local motif = new("Frame", {
		Name = "Motif",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 1, -24),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = fenetre,
	})
	for i = 1, 18 do
		new("Frame", {
			Position = UDim2.fromScale(0, i / 19),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = C.or_,
			BackgroundTransparency = 0.94,
			BorderSizePixel = 0,
			Parent = motif,
		})
	end
	-- coins ornés (losanges dorés)
	for _, coin in ipairs({ Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) }) do
		new("Frame", {
			Name = "Ornement",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(coin.X, coin.X == 0 and 8 or -8, coin.Y, coin.Y == 0 and 8 or -8),
			Size = UDim2.fromOffset(16, 16),
			Rotation = 45,
			BackgroundColor3 = C.or_,
			ZIndex = 3,
			Parent = fenetre,
		}, { Style.contour(C.orFonce, 2) })
	end

	-- ruban-titre
	local ruban = new("Frame", {
		Name = "Ruban",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(330, 56),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
		Parent = fenetre,
	}, {
		Style.coins(12),
		Style.degrade(C.parchemin, C.parcheminFonce),
		Style.contour(C.orFonce, 3),
	})
	for _, cote in ipairs({ -1, 1 }) do
		new("Frame", {
			Name = "Queue",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(cote < 0 and 0 or 1, cote * 6, 0.62, 0),
			Size = UDim2.fromOffset(40, 36),
			BackgroundColor3 = C.parcheminFonce,
			ZIndex = 4,
			Parent = ruban,
		}, { Style.coins(6), Style.contour(C.orFonce, 3) })
	end
	local titre = Style.texte({
		Name = "Titre",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -28, 0.7, 0),
		Text = opts.titre or "",
		Font = Style.POLICE_TITRE,
		TextColor3 = C.encre,
		Contour = C.orClair,
		ContourEpaisseur = 1,
		ZIndex = 6,
		Parent = ruban,
	})

	-- bouton fermer : rond rouge avec X blanc
	local fermerCadre = new("Frame", {
		Name = "Fermer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(50, 50),
		BackgroundColor3 = C.rougeFonce,
		ZIndex = 6,
		Parent = fenetre,
	}, { Style.coins(UDim.new(1, 0)) })
	local fermer = new("TextButton", {
		Name = "Bouton",
		Position = UDim2.fromOffset(0, -4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		ZIndex = 7,
		Parent = fermerCadre,
	}, {
		Style.coins(UDim.new(1, 0)),
		Style.degrade(Color3.fromRGB(255, 120, 115), C.rouge),
		Style.contour(C.blanc, 3),
	})
	Style.texte({
		Size = UDim2.fromScale(1, 1),
		Text = "X",
		Font = Style.POLICE_TITRE,
		TextColor3 = C.blanc,
		Contour = C.rougeFonce,
		ZIndex = 8,
		Parent = fermer,
	}, nil)
	local echelleFermer = new("UIScale", { Parent = fermerCadre })
	fermer.MouseEnter:Connect(function()
		tween(echelleFermer, 0.15, { Scale = 1.12 }, Enum.EasingStyle.Back)
		tween(fermerCadre, 0.15, { Rotation = 90 })
	end)
	fermer.MouseLeave:Connect(function()
		tween(echelleFermer, 0.15, { Scale = 1 })
		tween(fermerCadre, 0.15, { Rotation = 0 })
	end)

	-- zone de contenu (sous le ruban, dans les bordures)
	local contenu = new("Frame", {
		Name = "Contenu",
		Position = UDim2.fromOffset(20, 40),
		Size = UDim2.new(1, -40, 1, -56),
		BackgroundTransparency = 1,
		Parent = fenetre,
	})

	return { fond = fond, fenetre = fenetre, contenu = contenu, fermer = fermer, titre = titre, echelle = echelle }
end

-- Flou de l'arrière-plan (partagé entre les écrans)
local function flou()
	local f = Lighting:FindFirstChild("WikiBloxFlou")
	if not f then
		f = new("BlurEffect", { Name = "WikiBloxFlou", Size = 0, Parent = Lighting })
	end
	return f
end

function Style.ouvrir(f)
	f.fond.Visible = true
	f.fond.BackgroundTransparency = 1
	f.echelle.Scale = 0.6
	tween(f.fond, 0.25, { BackgroundTransparency = 0.35 })
	tween(f.echelle, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(flou(), 0.3, { Size = 14 })
end

function Style.fermer(f, apres)
	tween(flou(), 0.2, { Size = 0 })
	tween(f.fond, 0.18, { BackgroundTransparency = 1 })
	local t = tween(f.echelle, 0.18, { Scale = 0.7 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	t.Completed:Once(function()
		f.fond.Visible = false
		f.echelle.Scale = 1
		if apres then apres() end
	end)
end

------------------------------------------------------------------
-- Effets
------------------------------------------------------------------
-- Reflet qui balaie un élément en boucle (cartes épiques / légendaires)
function Style.brillance(parent, intensite)
	local reflet = new("Frame", {
		Name = "Brillance",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		ZIndex = (parent.ZIndex or 1) + 5,
		Parent = parent,
	}, { Style.coins(10) })
	local g = new("UIGradient", {
		Rotation = 25,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 1 - (intensite or 0.55)),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(-1, 0),
		Parent = reflet,
	})
	TweenService:Create(g, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0.9), {
		Offset = Vector2.new(1, 0),
	}):Play()
	return reflet
end

-- Halo coloré derrière un élément, qui « respire »
function Style.halo(parent, couleur, epaisseur)
	local halo = new("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = parent,
	}, { Style.coins(14) })
	local s = new("UIStroke", { Color = couleur, Thickness = epaisseur or 10, Transparency = 0.45, Parent = halo })
	TweenService:Create(s, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Thickness = (epaisseur or 10) * 1.8,
		Transparency = 0.75,
	}):Play()
	return halo
end

-- Rayons lumineux qui tournent (révélation légendaire)
function Style.rayons(parent, couleur, nombre, longueur)
	local centre = new("Frame", {
		Name = "Rayons",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = parent,
	})
	nombre = nombre or 10
	for i = 1, nombre do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(26, longueur or 700),
			Rotation = i * 180 / nombre,
			BackgroundColor3 = couleur,
			BorderSizePixel = 0,
			ZIndex = 0,
			Parent = centre,
		}, {
			new("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.55),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end
	TweenService:Create(centre, TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
	return centre
end

------------------------------------------------------------------
-- Icônes dessinées (pas d'emojis) : Style.icone(cadre, "booster", { contour = couleur, epaisseur = 2 })
-- Le cadre doit être carré (UIAspectRatioConstraint ou SizeConstraint RelativeYY).
-- Icônes : booster, collection, probabilites, loupe, chargement, alerte
------------------------------------------------------------------
local VIOLET_CLAIR = Color3.fromRGB(165, 110, 250)
local VIOLET_FONCE = Color3.fromRGB(85, 45, 165)

local function forme(parent, props, couleur, contour, epaisseur, rayon)
	props.BackgroundColor3 = couleur
	props.BorderSizePixel = 0
	props.Parent = parent
	local f = new("Frame", props)
	if rayon then Style.coins(rayon).Parent = f end
	if contour then Style.contour(contour, epaisseur or 2).Parent = f end
	return f
end

-- petite étincelle (croix aux bouts arrondis)
local function etincelle(parent, x, y, taille, couleur, contour)
	for _, rotation in ipairs({ 0, 90 }) do
		forme(parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(taille * 0.28, taille),
			Rotation = rotation + 45,
			ZIndex = parent.ZIndex + 3,
		}, couleur, contour, 1, UDim.new(1, 0))
	end
end

Style.ICONES = {}

-- Paquet de booster violet avec médaillon « W » doré
Style.ICONES.booster = function(cadre, contour, ep)
	local z = cadre.ZIndex
	local paquet = forme(cadre, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.48, 0.53),
		Size = UDim2.fromScale(0.6, 0.84),
		Rotation = -12,
		ZIndex = z,
	}, Color3.new(1, 1, 1), contour, ep, UDim.new(0.14, 0))
	Style.degrade(VIOLET_CLAIR, VIOLET_FONCE, 160).Parent = paquet
	-- bandes dorées (haut et bas du paquet)
	for _, y in ipairs({ 0.06, 0.82 }) do
		forme(paquet, {
			Position = UDim2.fromScale(0.08, y),
			Size = UDim2.fromScale(0.84, 0.12),
			ZIndex = z + 1,
		}, C.or_, nil, nil, UDim.new(1, 0))
	end
	-- médaillon
	local medaillon = forme(paquet, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromScale(0.66, 0.66),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		ZIndex = z + 1,
	}, Color3.new(1, 1, 1), contour, math.max(1, ep - 1), UDim.new(1, 0))
	Style.degrade(C.orClair, C.or_, 135).Parent = medaillon
	Style.texte({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.7, 0.7),
		Text = "W",
		Font = Style.POLICE_TITRE,
		TextColor3 = VIOLET_FONCE,
		ZIndex = z + 2,
		Parent = medaillon,
	})
	etincelle(cadre, 0.86, 0.14, 0.3, C.blanc, contour)
end

-- Trois cartes en éventail (vert, bleu, or)
Style.ICONES.collection = function(cadre, contour, ep)
	local z = cadre.ZIndex
	local couleurs = { Style.RARETES.uncommon.couleur, Style.RARETES.rare.couleur, Style.RARETES.legendary.couleur }
	for i, angle in ipairs({ -20, 0, 20 }) do
		local carte = forme(cadre, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + (i - 2) * 0.17, 0.55 + math.abs(i - 2) * 0.04),
			Size = UDim2.fromScale(0.44, 0.66),
			Rotation = angle,
			ZIndex = z + i,
		}, Color3.new(1, 1, 1), contour, ep, UDim.new(0.14, 0))
		Style.degrade(C.blanc, C.parcheminFonce).Parent = carte
		forme(carte, {
			Size = UDim2.fromScale(1, 0.26),
			ZIndex = z + i,
		}, couleurs[i], nil, nil, UDim.new(0.3, 0))
		forme(carte, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.6),
			Size = UDim2.fromScale(0.5, 0.5),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			ZIndex = z + i,
		}, couleurs[i], nil, nil, UDim.new(1, 0))
	end
end

-- Graphique en barres (probabilités)
Style.ICONES.probabilites = function(cadre, contour, ep)
	local z = cadre.ZIndex
	local barres = {
		{ 0.14, 0.32, Style.RARETES.uncommon.couleur },
		{ 0.42, 0.52, Style.RARETES.rare.couleur },
		{ 0.70, 0.7, Style.RARETES.legendary.couleur },
	}
	for _, b in ipairs(barres) do
		forme(cadre, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(b[1], 0.86),
			Size = UDim2.fromScale(0.2, b[2]),
			ZIndex = z + 1,
		}, b[3], contour, ep, UDim.new(0.25, 0))
	end
	forme(cadre, {
		Position = UDim2.fromScale(0.06, 0.84),
		Size = UDim2.fromScale(0.88, 0.09),
		ZIndex = z + 2,
	}, contour, nil, nil, UDim.new(1, 0))
end

-- Loupe
Style.ICONES.loupe = function(cadre, contour, ep)
	local z = cadre.ZIndex
	forme(cadre, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.75, 0.75),
		Size = UDim2.fromScale(0.16, 0.46),
		Rotation = -45,
		ZIndex = z,
	}, contour, nil, nil, UDim.new(1, 0))
	local verre = forme(cadre, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.42, 0.42),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundTransparency = 0.35,
		ZIndex = z + 1,
	}, Color3.fromRGB(190, 225, 255), contour, ep + 1.5, UDim.new(1, 0))
	forme(verre, {
		Position = UDim2.fromScale(0.2, 0.18),
		Size = UDim2.fromScale(0.25, 0.25),
		BackgroundTransparency = 0.2,
		ZIndex = z + 2,
	}, C.blanc, nil, nil, UDim.new(1, 0))
end

-- Anneau qui tourne (chargement)
Style.ICONES.chargement = function(cadre, contour, ep)
	local anneau = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		BackgroundTransparency = 1,
		ZIndex = cadre.ZIndex,
		Parent = cadre,
	}, { Style.coins(UDim.new(1, 0)) })
	local trait = new("UIStroke", { Color = C.or_, Thickness = math.max(4, ep * 2.5), Parent = anneau })
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = trait,
	})
	TweenService:Create(anneau, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
end

-- Rond rouge avec « ! »
Style.ICONES.alerte = function(cadre, contour, ep)
	local rond = forme(cadre, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		ZIndex = cadre.ZIndex,
	}, Color3.new(1, 1, 1), C.blanc, ep + 1, UDim.new(1, 0))
	Style.degrade(Color3.fromRGB(255, 120, 115), C.rouge).Parent = rond
	Style.texte({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.7),
		Text = "!",
		Font = Style.POLICE_TITRE,
		TextColor3 = C.blanc,
		Contour = C.rougeFonce,
		ZIndex = cadre.ZIndex + 1,
		Parent = rond,
	})
end

-- Dessine l'icône « nom » dans « cadre ». Renvoie true si l'icône existe.
function Style.icone(cadre, nom, opts)
	opts = opts or {}
	local dessin = Style.ICONES[nom]
	if not dessin then return false end
	dessin(cadre, opts.contour or C.encre, opts.epaisseur or 2)
	return true
end

------------------------------------------------------------------
-- Cartes
------------------------------------------------------------------
local function initialeDe(titre)
	titre = (type(titre) == "string" and titre ~= "") and titre or "?"
	local ok, code = pcall(utf8.codepoint, titre, 1)
	return ok and string.upper(utf8.char(code)) or "?"
end
Style.initiale = initialeDe

-- Dessine le recto d'une carte dans « cadre » (qui doit avoir le format d'une carte, ratio ~0.7).
-- opts.mention : texte du bas (« x3 », « NOUVELLE ! »…) ; opts.nouvelle = true pour la pastille dorée
-- opts.brillance = false pour désactiver le reflet animé (sinon actif sur épique / légendaire)
function Style.carte(cadre, carte, opts)
	opts = opts or {}
	local r = Style.rarete(carte.rarity)
	local z = cadre.ZIndex or 1

	local base = new("Frame", {
		Name = "Recto",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		ZIndex = z,
		Parent = cadre,
	}, {
		Style.coins(12),
		Style.degrade(C.parchemin, C.parcheminFonce),
	})
	local contour = new("UIStroke", { Color = r.couleur, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = base })
	-- filet intérieur
	new("Frame", {
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = base,
	}, { Style.coins(9), Style.contour(r.couleur, 1, 0.45) })

	-- bandeau de rareté
	local bandeau = new("Frame", {
		Name = "Bandeau",
		Size = UDim2.fromScale(1, 0.15),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z + 1,
		Parent = base,
	}, { Style.degrade(Style.eclaircir(r.couleur, 0.2), r.couleur) })
	Style.texte({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.9, 0.72),
		Text = r.nom,
		Font = Style.POLICE_TITRE,
		TextColor3 = C.blanc,
		Contour = Style.assombrir(r.couleur, 0.55),
		ZIndex = z + 2,
		Parent = bandeau,
	})
	-- étoiles
	Style.texte({
		Position = UDim2.fromScale(0.1, 0.165),
		Size = UDim2.fromScale(0.8, 0.07),
		Text = string.rep("★", r.etoiles),
		Font = Style.POLICE_TITRE,
		TextColor3 = r.couleur,
		Contour = Style.assombrir(r.couleur, 0.5),
		ContourEpaisseur = 1,
		ZIndex = z + 1,
		Parent = base,
	})

	-- médaillon avec l'initiale du titre
	local medaillon = new("Frame", {
		Name = "Medaillon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.25),
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = z + 1,
		Parent = base,
	}, {
		new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Style.coins(UDim.new(1, 0)),
		Style.degrade(r.clair, r.couleur, 135),
		Style.contour(C.blanc, 3),
	})
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.78, 0.78),
		BackgroundTransparency = 1,
		ZIndex = z + 2,
		Parent = medaillon,
	}, { Style.coins(UDim.new(1, 0)), Style.contour(C.blanc, 1.5, 0.4) })
	Style.texte({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		Text = initialeDe(carte.title),
		Font = Style.POLICE_TITRE,
		TextColor3 = C.blanc,
		Contour = Style.assombrir(r.couleur, 0.5),
		ContourEpaisseur = 2.5,
		ZIndex = z + 3,
		Parent = medaillon,
	})

	-- titre
	Style.texte({
		Name = "TitreCarte",
		Position = UDim2.fromScale(0.07, 0.65),
		Size = UDim2.fromScale(0.86, 0.17),
		Text = carte.title or "?",
		Font = Style.POLICE_LIVRE,
		TextColor3 = C.encre,
		TailleMax = 22,
		ZIndex = z + 1,
		Parent = base,
	})

	-- pastille du bas
	if opts.mention then
		local nouvelle = opts.nouvelle == true
		local pastille = new("Frame", {
			Name = "Pastille",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.84),
			Size = UDim2.fromScale(nouvelle and 0.78 or 0.42, 0.105),
			BackgroundColor3 = nouvelle and C.or_ or C.encre,
			BackgroundTransparency = nouvelle and 0 or 0.15,
			ZIndex = z + 1,
			Parent = base,
		}, { Style.coins(UDim.new(1, 0)), nouvelle and Style.contour(C.orFonce, 2) or nil })
		Style.texte({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.86, 0.75),
			Text = opts.mention,
			Font = Style.POLICE_TITRE,
			TextColor3 = C.blanc,
			Contour = nouvelle and C.orFonce or nil,
			ContourEpaisseur = 1.5,
			ZIndex = z + 2,
			Parent = pastille,
		})
	end

	if opts.brillance ~= false and (carte.rarity == "epic" or carte.rarity == "legendary") then
		Style.brillance(base, carte.rarity == "legendary" and 0.6 or 0.4)
	end
	return base, contour
end

-- Dos d'une carte (avant le retournement)
function Style.dos(cadre)
	local z = cadre.ZIndex or 1
	local dos = new("Frame", {
		Name = "Dos",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = z,
		Parent = cadre,
	}, {
		Style.coins(12),
		Style.degrade(C.nuitClair, C.nuitFonce, 135),
		Style.contour(C.or_, 4),
	})
	new("Frame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = dos,
	}, { Style.coins(8), Style.contour(C.orFonce, 1.5, 0.2) })
	local embleme = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.58, 0.58),
		Rotation = 45,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = z + 1,
		Parent = dos,
	}, {
		new("UIAspectRatioConstraint", { AspectRatio = 1 }),
		Style.coins(10),
		Style.degrade(C.orClair, C.orFonce, 135),
		Style.contour(C.nuitFonce, 2),
	})
	Style.texte({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.42, 0.3),
		Text = "W",
		Font = Style.POLICE_TITRE,
		TextColor3 = C.nuit,
		ZIndex = z + 2,
		Parent = dos,
	})
	Style.texte({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.fromScale(0.8, 0.08),
		Text = "WIKIBLOX",
		Font = Style.POLICE_TITRE,
		TextColor3 = C.or_,
		ZIndex = z + 1,
		Parent = dos,
	})
	TweenService:Create(embleme, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 55 }):Play()
	return dos
end

return Style
