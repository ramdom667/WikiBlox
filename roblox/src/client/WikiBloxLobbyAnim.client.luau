-- WikiBlox : animations du lobby (pages en orbite, cartes de rareté, orbe, portail)
local RunService = game:GetService("RunService")
local lobby = workspace:WaitForChild("WikiBloxLobby")
local CENTER = Vector3.new(0, 14, 0)

local pages = lobby:WaitForChild("Pages"):GetChildren()
local orb = lobby:WaitForChild("Orbe")
local portal = lobby:WaitForChild("Portail"):WaitForChild("PortailJouer")

local cards = {}
for _, m in ipairs(lobby:WaitForChild("Raretes"):GetChildren()) do
	local c = m:WaitForChild("Carte")
	table.insert(cards, { part = c, base = c.Position })
end

local t = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt
	for i, p in ipairs(pages) do
		local a = t * 0.5 + (i / #pages) * math.pi * 2
		local pos = CENTER + Vector3.new(math.cos(a) * 9, math.sin(t * 1.3 + i) * 1.2, math.sin(a) * 9)
		p.CFrame = CFrame.lookAt(pos, CENTER) * CFrame.Angles(0, 0, math.sin(t + i) * 0.25)
	end
	for i, c in ipairs(cards) do
		c.part.CFrame = CFrame.new(c.base + Vector3.new(0, math.sin(t * 2 + i) * 0.4, 0)) * CFrame.Angles(0, t * 1.1 + i, 0)
	end
	orb.Size = Vector3.one * (7 + math.sin(t * 2) * 0.3)
	portal.Transparency = 0.35 + math.sin(t * 3) * 0.12
end)
