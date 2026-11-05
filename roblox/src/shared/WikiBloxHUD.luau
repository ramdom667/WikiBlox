-- WikiBlox : barre de boutons du HUD (à gauche de l'écran), partagée par les écrans Booster et Collection
--
-- Utilisation (dans un LocalScript) :
--   local HUD = require(ReplicatedStorage.Shared.WikiBloxHUD)
--   HUD.ajouterBouton({ id = "Booster", icone = "📦", texte = "BOOSTER", couleur = Color3...,
--                       ordre = 1, raccourci = Enum.KeyCode.B, pulse = true }, ouvrirEcran)
--   HUD.afficher(false) -- cache toute la barre (quand un écran est ouvert)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HUD = {}

local TAILLE = 76
local NAVY_HAUT = Color3.fromRGB(58, 68, 112)
local NAVY_BAS = Color3.fromRGB(20, 24, 42)
local BLANC = Color3.fromRGB(245, 242, 235)

local barre = nil
local raccourcis = {} -- [KeyCode] = fonction

local function new(class, props, enfants)
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

local function tween(objet, duree, props, style)
	TweenService:Create(objet, TweenInfo.new(duree, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

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
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(TAILLE, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 14),
		}),
	})
	return barre
end

-- Ajoute un bouton à la barre. Renvoie le bouton (TextButton).
function HUD.ajouterBouton(options, rappel)
	local parent = obtenirBarre()
	local accent = options.couleur or Color3.fromRGB(235, 188, 80)

	-- Emplacement (contient l'ombre et le bouton)
	local emplacement = new("Frame", {
		Name = "Bouton" .. options.id,
		LayoutOrder = options.ordre or 1,
		Size = UDim2.fromOffset(TAILLE, TAILLE),
		BackgroundTransparency = 1,
		Parent = parent,
	})

	-- Ombre douce
	new("Frame", {
		Name = "Ombre",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		Parent = emplacement,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 18) }) })

	local bouton = new("TextButton", {
		Name = "Bouton",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		Parent = emplacement,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 18) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(NAVY_HAUT, NAVY_BAS) }),
	})
	local echelle = new("UIScale", { Parent = bouton })
	local contour = new("UIStroke", {
		Thickness = 2.5,
		Color = accent,
		Transparency = 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = bouton,
	})

	-- Reflet en haut du bouton
	new("Frame", {
		Name = "Reflet",
		Position = UDim2.fromOffset(6, 5),
		Size = UDim2.new(1, -12, 0.4, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		Parent = bouton,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 13) }) })

	-- Icône
	new("TextLabel", {
		Name = "Icone",
		Position = UDim2.fromScale(0, 0.07),
		Size = UDim2.fromScale(1, 0.56),
		BackgroundTransparency = 1,
		Text = options.icone or "?",
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = BLANC,
		Parent = bouton,
	}, { new("UITextSizeConstraint", { MaxTextSize = 36 }) })

	-- Libellé
	new("TextLabel", {
		Name = "Texte",
		Position = UDim2.new(0, 4, 0.68, 0),
		Size = UDim2.new(1, -8, 0.2, 0),
		BackgroundTransparency = 1,
		Text = options.texte or "",
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = accent,
		Parent = bouton,
	}, { new("UITextSizeConstraint", { MaxTextSize = 12 }) })

	-- Pastille de raccourci clavier (cachée sur mobile)
	if options.raccourci then
		raccourcis[options.raccourci] = rappel
		local pastille = new("Frame", {
			Name = "Touche",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 7, 0, -7),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = accent,
			Visible = UserInputService.KeyboardEnabled,
			ZIndex = 2,
			Parent = emplacement,
		}, {
			new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			new("UIStroke", { Thickness = 2, Color = NAVY_BAS }),
		})
		new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = options.raccourci.Name,
			TextScaled = true,
			Font = Enum.Font.GothamBlack,
			TextColor3 = NAVY_BAS,
			ZIndex = 2,
			Parent = pastille,
		}, { new("UIPadding", {
			PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
		}) })
	end

	-- Halo qui « respire » pour attirer l'œil (ex. bouton Booster)
	if options.pulse then
		TweenService:Create(contour, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Thickness = 4,
		}):Play()
	end

	-- Animations de survol et de clic
	local survol = false
	bouton.MouseEnter:Connect(function()
		survol = true
		tween(echelle, 0.15, { Scale = 1.08 }, Enum.EasingStyle.Back)
		tween(contour, 0.15, { Transparency = 0 })
	end)
	bouton.MouseLeave:Connect(function()
		survol = false
		tween(echelle, 0.15, { Scale = 1 })
		tween(contour, 0.15, { Transparency = 0.2 })
	end)
	bouton.MouseButton1Down:Connect(function()
		tween(echelle, 0.08, { Scale = 0.93 })
	end)
	bouton.MouseButton1Up:Connect(function()
		tween(echelle, 0.15, { Scale = survol and 1.08 or 1 }, Enum.EasingStyle.Back)
	end)

	if rappel then
		bouton.Activated:Connect(rappel)
	end
	return bouton
end

-- Affiche ou cache toute la barre (on la cache quand un écran est ouvert)
function HUD.afficher(visible)
	obtenirBarre().Visible = visible
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
