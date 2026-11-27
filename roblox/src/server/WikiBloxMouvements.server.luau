-- WikiBlox : parties qui font des va-et-vient (obstacles mobiles du parcours)
--
-- Toute partie qui a l'attribut VaEtVient = true se déplace en boucle entre sa position de départ
-- (celle qu'elle a dans Studio) et un point d'arrivée, à vitesse constante.
--
--   Attributs à poser sur la partie (une vraie Part, ancrée) :
--     VaEtVient (bool, obligatoire)    : coché pour activer le mouvement
--     Amplitude (number, facultatif)   : distance du trajet en studs, avec son signe
--                                        (10 = vers le haut, -10 = vers le bas ; défaut : AMPLITUDE_DEFAUT)
--     Vitesse   (number, facultatif)   : vitesse en studs par seconde (défaut : VITESSE_DEFAUT)
--     Axe       (string, facultatif)   : "Y" (vertical), "X" (defaut) ou "Z" (horizontal)
--     Decalage  (number, facultatif)   : secondes d'attente avant le premier mouvement, pour que
--                                        plusieurs obstacles ne bougent pas tous en même temps
--
-- Le mouvement est calculé côté serveur : le contact avec les joueurs (voir WikiBloxObstacles)
-- se fait donc à la vraie position de la partie. Une partie dans un Model doit être déplacée
-- séparément : mettez les attributs sur chaque partie qui doit bouger.

local TweenService = game:GetService("TweenService")

local AMPLITUDE_DEFAUT = 10 -- studs
local VITESSE_DEFAUT = 8 -- studs par seconde

local branches = {} -- [partie] = true une fois le mouvement lancé (évite les doublons)

-- Direction du mouvement selon l'attribut Axe
local AXES = {
	X = Vector3.xAxis,
	Y = Vector3.yAxis,
	Z = Vector3.zAxis,
}

-- Lance le va-et-vient d'une partie marquée VaEtVient
local function brancher(partie)
	if not partie:IsA("BasePart") or branches[partie] then return end
	if partie:GetAttribute("VaEtVient") ~= true then return end
	branches[partie] = true

	local amplitude = partie:GetAttribute("Amplitude")
	if type(amplitude) ~= "number" then
		amplitude = AMPLITUDE_DEFAUT
	end
	local vitesse = partie:GetAttribute("Vitesse")
	if type(vitesse) ~= "number" then
		vitesse = VITESSE_DEFAUT
	end
	local axe = AXES[partie:GetAttribute("Axe") or "X"] or Vector3.xAxis
	local decalage = partie:GetAttribute("Decalage")

	if amplitude == 0 or vitesse <= 0 then
		warn("[WikiBlox] Mouvement ignoré (Amplitude ou Vitesse invalide) :", partie:GetFullName())
		return
	end

	partie.Anchored = true -- sans ça, la partie tomberait au lieu de suivre le trajet

	-- Durée d'un trajet aller = distance / vitesse, donc vitesse constante (Linear)
	local duree = math.abs(amplitude) / vitesse
	local arrivee = partie.CFrame + axe * amplitude
	local info = TweenInfo.new(duree, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)

	task.spawn(function()
		if type(decalage) == "number" and decalage > 0 then
			task.wait(decalage)
		end
		if partie.Parent then
			TweenService:Create(partie, info, { CFrame = arrivee }):Play()
		end
	end)
end

-- On branche les parties déjà présentes, puis celles qui apparaissent plus tard
for _, objet in ipairs(workspace:GetDescendants()) do
	brancher(objet)
end
workspace.DescendantAdded:Connect(brancher)
