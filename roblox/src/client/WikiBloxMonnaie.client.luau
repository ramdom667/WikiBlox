-- WikiBlox : compteur de monnaie en haut à droite de l'écran
--
-- Le nom de la monnaie n'est pas encore choisi : il suffit de changer NOM_MONNAIE ci-dessous.
-- Le montant affiché est l'attribut "Monnaie" du joueur. Le serveur le met à jour, par exemple :
--   player:SetAttribute("Monnaie", 250)
-- (tant qu'aucun script serveur ne le donne, le compteur affiche 0)
--
-- Le bouton « + » ouvre la Boutique.
-- Style commun : src/shared/WikiBloxStyle.luau — règles : roblox/DA.md

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Style = require(Shared:WaitForChild("WikiBloxStyle"))
local HUD = require(Shared:WaitForChild("WikiBloxHUD"))

local C = Style.C
local new, tween, texte = Style.new, Style.tween, Style.texte

local NOM_MONNAIE = "Pièces" -- nom provisoire (affiché au survol)
local ATTRIBUT = "Monnaie"

local function formaterNombre(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local avecEspaces = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1 ")))
	return (string.gsub(avecEspaces, "^ ", ""))
end

------------------------------------------------------------------
-- Compteur
------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "WikiBloxMonnaie",
	ResetOnSpawn = false,
	IgnoreGuiInset = true, -- dans la barre du haut, au même niveau que les boutons Roblox
	DisplayOrder = 1,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Emplacement : petite capsule en parchemin bordée d'or, tout en haut à droite
local cadre = new("Frame", {
	Name = "Compteur",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 10),
	Size = UDim2.fromOffset(132, 38),
	BackgroundTransparency = 1,
	Parent = gui,
})
local echelle = new("UIScale", { Parent = cadre })

-- épaisseur « 3D » sous la capsule
new("Frame", {
	Name = "Dessous",
	Position = UDim2.fromOffset(0, 3),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.orFonce,
	Parent = cadre,
}, { Style.coins(UDim.new(1, 0)) })

local capsule = new("Frame", {
	Name = "Capsule",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Parent = cadre,
}, {
	Style.coins(UDim.new(1, 0)),
	Style.degrade(C.parchemin, C.parcheminFonce),
	Style.contour(C.orFonce, 2.5),
})
-- reflet
new("Frame", {
	Position = UDim2.new(0, 22, 0, 3),
	Size = UDim2.new(1, -58, 0.3, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
	Parent = capsule,
}, { Style.coins(UDim.new(1, 0)) })

-- grosse pièce qui déborde à gauche
local iconeCadre = new("Frame", {
	Name = "Icone",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0, 4, 0.5, 1),
	Size = UDim2.fromOffset(44, 44),
	BackgroundTransparency = 1,
	ZIndex = 3,
	Parent = cadre,
})
Style.icone(iconeCadre, "piece", { contour = C.orFonce, epaisseur = 2 })

-- montant
local montant = texte({
	Name = "Montant",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 30, 0.5, 0),
	Size = UDim2.new(1, -64, 0.58, 0),
	Text = "0",
	Font = Style.POLICE_TITRE,
	TextColor3 = C.encre,
	TextXAlignment = Enum.TextXAlignment.Left,
	TailleMax = 22,
	ZIndex = 2,
	Parent = capsule,
})

-- bouton « + » vert : ouvre la Boutique
local plusCadre = new("Frame", {
	Name = "Plus",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -5, 0.5, 0),
	Size = UDim2.fromOffset(28, 28),
	BackgroundTransparency = 1,
	ZIndex = 3,
	Parent = cadre,
})
new("Frame", {
	Position = UDim2.fromOffset(0, 3),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Style.assombrir(C.vert, 0.45),
	ZIndex = 3,
	Parent = plusCadre,
}, { Style.coins(UDim.new(1, 0)) })
local plus = new("TextButton", {
	Name = "Bouton",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	AutoButtonColor = false,
	Text = "",
	ZIndex = 4,
	Parent = plusCadre,
}, {
	Style.coins(UDim.new(1, 0)),
	Style.degrade(Style.eclaircir(C.vert, 0.3), C.vert),
	Style.contour(Style.assombrir(C.vert, 0.55), 2),
})
texte({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.46),
	Size = UDim2.fromScale(0.8, 0.8),
	Text = "+",
	Font = Style.POLICE_TITRE,
	TextColor3 = C.blanc,
	Contour = Style.assombrir(C.vert, 0.55),
	ZIndex = 5,
	Parent = plus,
})
local echellePlus = new("UIScale", { Parent = plusCadre })
plus.MouseEnter:Connect(function()
	tween(echellePlus, 0.15, { Scale = 1.15 }, Enum.EasingStyle.Back)
end)
plus.MouseLeave:Connect(function()
	tween(echellePlus, 0.15, { Scale = 1 })
	tween(plus, 0.08, { Position = UDim2.new() })
end)
plus.MouseButton1Down:Connect(function()
	tween(plus, 0.06, { Position = UDim2.fromOffset(0, 3) })
end)
plus.MouseButton1Up:Connect(function()
	tween(plus, 0.12, { Position = UDim2.new() }, Enum.EasingStyle.Back)
end)
plus.Activated:Connect(function()
	HUD.declencher("Boutique")
end)

-- bulle avec le nom de la monnaie au survol de la capsule
local bulle = texte({
	Name = "Nom",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 8),
	Size = UDim2.fromOffset(100, 22),
	BackgroundTransparency = 0.15,
	BackgroundColor3 = C.nuit,
	Text = NOM_MONNAIE,
	Font = Style.POLICE_TITRE,
	TextColor3 = C.orClair,
	TailleMax = 16,
	Visible = false,
	ZIndex = 6,
	Parent = cadre,
})
Style.coins(8).Parent = bulle
Style.contour(C.or_, 1.5).Parent = bulle
local zone = new("TextButton", {
	Size = UDim2.new(1, -34, 1, 0),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 2,
	Parent = cadre,
})
zone.MouseEnter:Connect(function() bulle.Visible = true end)
zone.MouseLeave:Connect(function() bulle.Visible = false end)

-- la pièce se balance doucement
TweenService:Create(iconeCadre, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
	Rotation = 10,
}):Play()

-- plus petit sur petit écran (mobile)
local function adapterTaille()
	local camera = workspace.CurrentCamera
	local largeur = camera and camera.ViewportSize.X or 1000
	echelle.Scale = largeur < 700 and 0.8 or 1
end
adapterTaille()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(adapterTaille)
end

------------------------------------------------------------------
-- Valeur : attribut "Monnaie" du joueur, avec compteur qui défile
------------------------------------------------------------------
local affiche = 0
local animation = 0

local function afficher(valeur)
	valeur = math.max(0, math.floor(tonumber(valeur) or 0))
	animation += 1
	local numero = animation
	local depart = affiche
	if valeur ~= depart then
		-- petit « pop » de la pièce et du montant quand ça change
		iconeCadre.Size = UDim2.fromOffset(54, 54)
		tween(iconeCadre, 0.3, { Size = UDim2.fromOffset(44, 44) }, Enum.EasingStyle.Back)
		montant.TextColor3 = valeur > depart and Style.assombrir(C.vert, 0.25) or C.rouge
		tween(montant, 0.6, { TextColor3 = C.encre })
	end
	task.spawn(function()
		local duree, t0 = 0.5, os.clock()
		while numero == animation do
			local k = math.min(1, (os.clock() - t0) / duree)
			affiche = math.floor(depart + (valeur - depart) * k + 0.5)
			montant.Text = formaterNombre(affiche)
			if k >= 1 then break end
			task.wait()
		end
	end)
end

afficher(player:GetAttribute(ATTRIBUT) or 0)
player:GetAttributeChangedSignal(ATTRIBUT):Connect(function()
	afficher(player:GetAttribute(ATTRIBUT) or 0)
end)
