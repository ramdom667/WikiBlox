-- WikiBlox : animations de combat « procédurales » (sans fichier d'animation)
-- Utilisé côté client par WikiBloxCombat et WikiBloxDoubleSaut.
-- On anime le mouvement (Transform) des articulations du personnage : marche en R15 et en R6.
--
--   Anim.coup(perso, "droit" | "gauche")  -- coup de poing
--   Anim.salto(perso)                     -- salto avant (double saut)
--   Anim.onde(position)                   -- onde d'air sous les pieds
--   Anim.impact(position, modeleTouche)   -- éclair blanc + cible qui flashe en rouge

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Anim = {}

-- Les articulations d'un personnage ont leur position de repos (C0) verrouillée :
-- on anime donc leur mouvement (Transform), en l'ajoutant PAR-DESSUS les animations
-- normales (marche, saut...). On le fait juste après le calcul des animations (PreSimulation).
local animations = {} -- [moteur] = { debut, duree, fn, base, ecrit }
local connexion = nil

local function proches(a, b)
	if not a or not b then return false end
	local diff = b:Inverse() * a
	local _, angle = diff:ToAxisAngle()
	return diff.Position.Magnitude < 1e-3 and math.abs(angle) < 1e-3
end

local function boucle()
	local maintenant = os.clock()
	for moteur, an in pairs(animations) do
		if not moteur.Parent then
			animations[moteur] = nil
			continue
		end
		-- Si l'Animator n'a pas réécrit Transform depuis notre dernier passage, on repart de l'ancienne base
		local actuel = moteur.Transform
		local baseT = proches(actuel, an.ecrit) and an.base or actuel
		local a = math.clamp((maintenant - an.debut) / an.duree, 0, 1)
		if a >= 1 then
			moteur.Transform = baseT
			animations[moteur] = nil
		else
			local valeur = baseT * an.fn(a)
			moteur.Transform = valeur
			an.base = baseT
			an.ecrit = valeur
		end
	end
	if next(animations) == nil and connexion then
		connexion:Disconnect()
		connexion = nil
	end
end

local function animer(moteur, duree, fn)
	if not moteur then return end
	local precedente = animations[moteur]
	animations[moteur] = {
		debut = os.clock(),
		duree = duree,
		fn = fn,
		base = precedente and precedente.base,
		ecrit = precedente and precedente.ecrit,
	}
	if not connexion then
		connexion = RunService.PreSimulation:Connect(boucle)
	end
end

local function lerp(a, b, t)
	return a + (b - a) * t
end
local function sortie(t) -- démarre vite, finit en douceur
	return 1 - (1 - t) ^ 3
end
local function rebond(t) -- dépasse légèrement puis revient (effet « punch »)
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end
local function douce(t)
	return t < 0.5 and 4 * t ^ 3 or 1 - (-2 * t + 2) ^ 3 / 2
end

-- Courbe d'un coup : 0 -> armé (-1) -> tendu (1) -> tenu -> retour (0)
local function courbeCoup(a)
	if a < 0.17 then
		return lerp(0, -1, sortie(a / 0.17))
	elseif a < 0.4 then
		return lerp(-1, 1, rebond((a - 0.17) / 0.23))
	elseif a < 0.6 then
		return 1
	end
	return lerp(1, 0, douce((a - 0.6) / 0.4))
end

-- Articulations utiles du personnage (R15 ou R6)
local function articulations(perso)
	if perso:FindFirstChild("UpperTorso") then
		local brasD = perso:FindFirstChild("RightUpperArm")
		local brasG = perso:FindFirstChild("LeftUpperArm")
		local bas = perso:FindFirstChild("LowerTorso")
		return {
			r15 = true,
			epauleD = brasD and brasD:FindFirstChild("RightShoulder"),
			epauleG = brasG and brasG:FindFirstChild("LeftShoulder"),
			taille = perso.UpperTorso:FindFirstChild("Waist"),
			racine = bas and bas:FindFirstChild("Root"),
		}
	end
	local torse = perso:FindFirstChild("Torso")
	local hrp = perso:FindFirstChild("HumanoidRootPart")
	return {
		r15 = false,
		epauleD = torse and torse:FindFirstChild("Right Shoulder"),
		epauleG = torse and torse:FindFirstChild("Left Shoulder"),
		racine = hrp and hrp:FindFirstChild("RootJoint"),
	}
end

------------------------------------------------------------------
-- Coup de poing : armer (bras en arrière) -> frapper (bras tendu) -> revenir
------------------------------------------------------------------
local DUREE_COUP = 0.36

function Anim.coup(perso, bras)
	if typeof(perso) ~= "Instance" then return end
	local j = articulations(perso)
	local droit = bras ~= "gauche"
	local epaule = droit and j.epauleD or j.epauleG
	if not epaule then return end
	local cote = droit and 1 or -1

	animer(epaule, DUREE_COUP, function(a)
		local c = courbeCoup(a)
		local avant = math.max(c, 0)    -- 0 -> 1 quand le bras se tend
		local arriere = math.min(c, 0)  -- 0 -> -1 quand on arme
		if j.r15 then
			return CFrame.new(0, 0, -0.3 * avant)
				* CFrame.Angles(math.rad(95 * avant + 25 * arriere), 0, math.rad(-10 * avant * cote))
		end
		return CFrame.Angles(0, 0, math.rad((95 * avant + 25 * arriere) * cote))
	end)

	if j.taille then
		animer(j.taille, DUREE_COUP, function(a)
			return CFrame.Angles(0, math.rad(30 * courbeCoup(a) * cote), 0)
		end)
	end
end

------------------------------------------------------------------
-- Salto avant pendant le double saut
------------------------------------------------------------------
local DUREE_SALTO = 0.55

-- 0 -> 1 -> 0 : on se groupe vite, on tient, puis on se déplie avant la fin du salto
local function groupe(a)
	if a < 0.2 then return sortie(a / 0.2) end
	if a < 0.6 then return 1 end
	return 1 - douce((a - 0.6) / 0.4)
end

function Anim.salto(perso)
	if typeof(perso) ~= "Instance" then return end
	local j = articulations(perso)
	local moteur = j.racine
	if not moteur or animations[moteur] then return end

	-- Rotation complète, lente au début et à la fin, rapide au milieu
	animer(moteur, DUREE_SALTO, function(a)
		return CFrame.new(0, 0.6 * math.sin(math.pi * a), 0) * CFrame.Angles(-douce(a) * math.pi * 2, 0, 0)
	end)

	-- Position groupée : genoux vers la poitrine, bras rentrés
	if j.r15 then
		local function membre(nomPartie, nomMoteur, angle)
			local partie = perso:FindFirstChild(nomPartie)
			local m = partie and partie:FindFirstChild(nomMoteur)
			animer(m, DUREE_SALTO, function(a)
				return CFrame.Angles(math.rad(angle * groupe(a)), 0, 0)
			end)
		end
		membre("RightUpperLeg", "RightHip", 100)
		membre("LeftUpperLeg", "LeftHip", 100)
		membre("RightLowerLeg", "RightKnee", -120)
		membre("LeftLowerLeg", "LeftKnee", -120)
		membre("RightLowerArm", "RightElbow", 80)
		membre("LeftLowerArm", "LeftElbow", 80)
		animer(j.epauleD, DUREE_SALTO, function(a)
			return CFrame.Angles(math.rad(60 * groupe(a)), 0, math.rad(15 * groupe(a)))
		end)
		animer(j.epauleG, DUREE_SALTO, function(a)
			return CFrame.Angles(math.rad(60 * groupe(a)), 0, math.rad(-15 * groupe(a)))
		end)
	else
		local torse = perso:FindFirstChild("Torso")
		if torse then
			for nom, cote in pairs({ ["Right Hip"] = 1, ["Left Hip"] = -1, ["Right Shoulder"] = 1, ["Left Shoulder"] = -1 }) do
				local m = torse:FindFirstChild(nom)
				local angle = nom:find("Hip") and 100 or 60
				animer(m, DUREE_SALTO, function(a)
					return CFrame.Angles(0, 0, math.rad(angle * groupe(a) * cote))
				end)
			end
		end
	end

	-- Traînée lumineuse qui suit le corps pendant le salto
	local hrp = perso:FindFirstChild("UpperTorso") or perso:FindFirstChild("Torso")
	if hrp then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 1.2, 0)
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -1.2, 0)
		local trainee = Instance.new("Trail")
		trainee.Attachment0 = a0
		trainee.Attachment1 = a1
		trainee.Lifetime = 0.25
		trainee.LightEmission = 1
		trainee.FaceCamera = true
		trainee.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255), Color3.fromRGB(150, 120, 255))
		trainee.Transparency = NumberSequence.new(0.4, 1)
		a0.Parent = hrp
		a1.Parent = hrp
		trainee.Parent = hrp
		Debris:AddItem(trainee, DUREE_SALTO + 0.3)
		Debris:AddItem(a0, DUREE_SALTO + 0.3)
		Debris:AddItem(a1, DUREE_SALTO + 0.3)
	end
end

------------------------------------------------------------------
-- Effets visuels (créés seulement chez ce joueur)
------------------------------------------------------------------
local function partieEffet(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for k, v in pairs(props) do p[k] = v end
	p.Parent = workspace
	return p
end

-- Onde d'air qui s'élargit sous les pieds
function Anim.onde(position)
	local disque = partieEffet({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, 2, 2),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(200, 230, 255),
		Transparency = 0.25,
	})
	TweenService:Create(disque, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.15, 9, 9),
		Transparency = 1,
	}):Play()
	Debris:AddItem(disque, 0.4)
end

-- Éclair d'impact + la cible flashe en rouge
function Anim.impact(position, modele)
	if typeof(position) == "Vector3" then
		local boule = partieEffet({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.6, 0.6, 0.6),
			Position = position,
			Color = Color3.fromRGB(255, 245, 220),
			Transparency = 0.1,
		})
		TweenService:Create(boule, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(4, 4, 4),
			Transparency = 1,
		}):Play()
		Debris:AddItem(boule, 0.25)
	end
	if typeof(modele) == "Instance" and modele.Parent then
		local h = Instance.new("Highlight")
		h.FillColor = Color3.fromRGB(255, 60, 60)
		h.FillTransparency = 0.35
		h.OutlineTransparency = 1
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = modele
		Debris:AddItem(h, 0.15)
	end
end

return Anim
