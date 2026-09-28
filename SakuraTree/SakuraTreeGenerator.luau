--[[
	Sakura Tree Generator (High Quality)
	====================================
	Builds a detailed cherry blossom (sakura) tree out of regular Parts:
	  - a thick, slightly leaning trunk with flared roots
	  - curved branches that taper smoothly and spread into a wide umbrella
	  - layered blossom clusters: deep pink shaded inside, pale sunlit pink
	    on the top and outer edge
	  - hanging blossom strands
	  - falling petals that drift in the wind
	  - a carpet of fallen petals that follows the ground/terrain

	HOW TO USE:
	  1. In Roblox Studio, point the camera at the spot where you want the tree.
	  2. View > Command Bar.
	  3. Paste this entire file into the Command Bar and press Enter.
	  4. A model called "SakuraTree" appears where you were looking, already
	     selected. Use Move (Ctrl+2) / Rotate (Ctrl+3) to adjust it.
	     Ctrl+Z undoes it. Run again for a new random tree.

	Too laggy with lots of trees? Set QUALITY to "Medium" or "Low".
]]

local QUALITY = "High" -- "High", "Medium" or "Low"

local CONFIG = {
	Position = nil, -- nil = where the camera is looking; or e.g. Vector3.new(0, 0, 0)
	Seed = nil, -- e.g. 42 to always get the same tree; nil = random
	Scale = 1, -- 1.5 = 50% bigger tree, 0.7 = smaller tree

	TrunkHeight = 7,
	TrunkRadius = 1.7,
	MainLimbs = { 3, 4 },
	LimbLength = 9,
	LengthDecay = 0.72, -- each level of branches is this much shorter
	Taper = 0.7, -- a branch's tip is this much thinner than its base
	Spread = 0.45, -- how strongly branches reach outward (wide umbrella shape)
	SegmentLength = 2.2, -- shorter = smoother curves, more parts

	BlossomMaterial = Enum.Material.SmoothPlastic,
	FallingPetals = true,
	-- Swap for a petal image from the Toolbox (e.g. "rbxassetid://123456") if you like
	PetalTexture = "rbxasset://textures/particles/smoke_main.dds",
	PetalCarpet = true, -- soft pink patches on the ground under the tree
}

local PRESETS = {
	High = { Levels = 5, InnerPerTip = 2, BlossomsPerTip = 7, SideBranchChance = 0.5, HangingChance = 0.3, GroundPetals = 140, PetalRate = 12 },
	Medium = { Levels = 4, InnerPerTip = 2, BlossomsPerTip = 6, SideBranchChance = 0.35, HangingChance = 0.2, GroundPetals = 80, PetalRate = 8 },
	Low = { Levels = 4, InnerPerTip = 1, BlossomsPerTip = 4, SideBranchChance = 0.15, HangingChance = 0.1, GroundPetals = 30, PetalRate = 5 },
}

local P = PRESETS[QUALITY] or PRESETS.High
local S = CONFIG.Scale
local TAU = math.pi * 2
local MIN_RADIUS = 0.15 * S

local BARK_BASE = Color3.fromRGB(58, 40, 37)
local BARK_TIP = Color3.fromRGB(112, 66, 58) -- young sakura twigs are reddish
local BARK_ALT = Color3.fromRGB(84, 62, 54)

-- From deep shaded pink (inside the canopy) to almost white (sunlit top)
local BLOSSOM_GRADIENT = {
	Color3.fromRGB(222, 104, 146),
	Color3.fromRGB(242, 146, 178),
	Color3.fromRGB(255, 180, 203),
	Color3.fromRGB(255, 208, 223),
	Color3.fromRGB(255, 234, 241),
}

local RunService = game:GetService("RunService")
local rng = if CONFIG.Seed then Random.new(CONFIG.Seed) else Random.new()

--------------------------------------------------------------------------
-- Where to put the tree
--------------------------------------------------------------------------

local function findOrigin()
	if CONFIG.Position then
		return CONFIG.Position
	end
	-- In edit mode (Command Bar), drop the tree where the camera is looking
	local camera = workspace.CurrentCamera
	if camera and not RunService:IsRunning() then
		local hit = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 2000)
		if hit then
			return hit.Position
		end
		return camera.Focus.Position
	end
	return Vector3.zero
end

local origin = findOrigin()

pcall(function()
	game:GetService("ChangeHistoryService"):SetWaypoint("Before SakuraTree")
end)

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------

local tree = Instance.new("Model")
tree.Name = "SakuraTree"

local wood = Instance.new("Model")
wood.Name = "Wood"
wood.Parent = tree

local blossoms = Instance.new("Model")
blossoms.Name = "Blossoms"
blossoms.Parent = tree

local boundsMin = Vector3.new(math.huge, math.huge, math.huge)
local boundsMax = -boundsMin

local function newPart(name, shape, size, cframe, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Decorative parts: nothing can bump into, touch or click them
local function makeDecorative(part)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

local function randomInSphere()
	while true do
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		if v.Magnitude <= 1 then
			return v
		end
	end
end

local function gradient(t)
	local stops = #BLOSSOM_GRADIENT
	t = math.clamp(t, 0, 1) * (stops - 1)
	local i = math.floor(t)
	if i >= stops - 1 then
		return BLOSSOM_GRADIENT[stops]
	end
	return BLOSSOM_GRADIENT[i + 1]:Lerp(BLOSSOM_GRADIENT[i + 2], t - i)
end

local function barkColor(level)
	local base = BARK_BASE:Lerp(BARK_TIP, math.clamp(level / P.Levels, 0, 1))
	return base:Lerp(BARK_ALT, rng:NextNumber(0, 0.3))
end

-- A vector at `angle` radians away from `dir`, rotated `phase` radians around it
local function deviate(dir, angle, basePerp, phase)
	local perp = CFrame.fromAxisAngle(dir, phase):VectorToWorldSpace(basePerp)
	return (dir * math.cos(angle) + perp * math.sin(angle)).Unit
end

local function perpendicularTo(dir)
	local perp = dir:Cross(randomInSphere())
	if perp.Magnitude < 1e-3 then
		perp = dir:Cross(Vector3.xAxis)
	end
	return perp.Unit
end

-- Pushes a direction outward/horizontal so the canopy becomes a wide dome,
-- and stops branches from growing downward
local function spreadOutward(dir, strength)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude > 0.01 then
		dir = (dir + flat.Unit * strength).Unit
	end
	if dir.Y < -0.2 then
		dir = Vector3.new(dir.X, -0.2, dir.Z).Unit
	end
	return dir
end

--------------------------------------------------------------------------
-- Wood
--------------------------------------------------------------------------

local function cylinder(a, b, radius, color, collide)
	local length = (b - a).Magnitude
	if length < 0.05 then
		return
	end
	local part = newPart(
		"Branch",
		Enum.PartType.Cylinder,
		Vector3.new(length, radius * 2, radius * 2),
		-- lookAt points -Z at b; the extra turn lines the cylinder's X axis up with it
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0),
		color,
		Enum.Material.Wood,
		wood
	)
	part.CanCollide = collide
	part.CanTouch = false
end

local function joint(position, radius, color, collide)
	local d = radius * 2
	local part = newPart("Joint", Enum.PartType.Ball, Vector3.new(d, d, d), CFrame.new(position), color, Enum.Material.Wood, wood)
	part.CanCollide = collide
	part.CanTouch = false
end

-- Grows a curved, tapering limb made of short straight pieces.
-- Returns every point along it (with radius) plus the final direction.
local function limb(start, dir, length, r0, r1, bend, upCurve, level)
	local steps = math.clamp(math.floor(length / (CONFIG.SegmentLength * S)) + 1, 1, 6)
	local stepLength = length / steps
	local collide = level <= 1
	local color = barkColor(level)
	local points = { { start, r0 } }
	local position = start

	for step = 1, steps do
		local radius = r0 + (r1 - r0) * ((step - 1) / steps)
		dir = (dir + randomInSphere() * bend + Vector3.yAxis * upCurve).Unit
		local nextPosition = position + dir * stepLength
		if radius > 0.25 * S or step == 1 then
			joint(position, radius, color, collide)
		end
		cylinder(position, nextPosition, radius, color, collide)
		position = nextPosition
		table.insert(points, { position, radius })
	end
	joint(position, r1, color, collide)
	return points, dir
end

local tips = {}

local function branch(start, dir, level, r0)
	local length = CONFIG.LimbLength * CONFIG.LengthDecay ^ (level - 1) * rng:NextNumber(0.85, 1.1) * S
	local r1 = math.max(r0 * CONFIG.Taper, MIN_RADIUS)
	-- Outer twigs curl slightly upward, like real sakura
	local upCurve = if level >= 3 then 0.1 else 0.03
	local points, endDir = limb(start, dir, length, r0, r1, 0.22, upCurve, level)
	local tip = points[#points][1]

	if level >= P.Levels then
		table.insert(tips, { Position = tip, Fill = false })
		return
	end

	-- Fork at the tip
	local count = rng:NextInteger(2, if level <= 2 then 3 else 2)
	local basePerp = perpendicularTo(endDir)
	local phase = rng:NextNumber(0, TAU)
	for i = 1, count do
		local childDir = deviate(endDir, rng:NextNumber(0.35, 0.75), basePerp, phase + (i - 1) * TAU / count)
		childDir = spreadOutward(childDir, CONFIG.Spread)
		local childRadius = math.max(r1 * (if i == 1 then 0.95 else 0.8), MIN_RADIUS)
		branch(tip, childDir, level + 1, childRadius)
	end

	-- Occasional side branch from partway along the limb
	if #points >= 3 and rng:NextNumber() < P.SideBranchChance then
		local point = points[rng:NextInteger(2, #points - 1)]
		local sideDir = spreadOutward(deviate(endDir, rng:NextNumber(0.7, 1.1), perpendicularTo(endDir), 0), CONFIG.Spread)
		branch(point[1], sideDir, level + 1, math.max(point[2] * 0.6, MIN_RADIUS))
	end

	-- Extra blossoms near the outer branches fill out the canopy
	if level >= P.Levels - 1 then
		table.insert(tips, { Position = tip, Fill = true })
	end
end

local R = CONFIG.TrunkRadius * S

-- Trunk with a slight lean
local leanDir = (Vector3.yAxis + Vector3.new(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))).Unit
local trunkPoints = limb(origin, leanDir, CONFIG.TrunkHeight * S, R, R * 0.8, 0.1, 0, 0)
local trunkTop = trunkPoints[#trunkPoints][1]

-- Main limbs fan out evenly from the top of the trunk
local limbCount = rng:NextInteger(CONFIG.MainLimbs[1], CONFIG.MainLimbs[2])
local limbYaw = rng:NextNumber(0, TAU)
for i = 1, limbCount do
	local yaw = limbYaw + (i - 1) * TAU / limbCount + rng:NextNumber(-0.25, 0.25)
	local tilt = rng:NextNumber(0.55, 0.85)
	local dir = (CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, 0)).UpVector
	branch(trunkTop, dir, 1, R * rng:NextNumber(0.6, 0.72))
end

-- Flared roots at the base
joint(origin + Vector3.new(0, R * 0.2, 0), R * 1.15, BARK_BASE, true)
local rootCount = 5
for i = 1, rootCount do
	local yaw = (i - 1) * TAU / rootCount + rng:NextNumber(-0.3, 0.3)
	local outward = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	limb(origin + Vector3.new(0, R * 0.9, 0), (outward + Vector3.new(0, -0.55, 0)).Unit, R * 2.8, R * 0.55, R * 0.2, 0.15, 0, 0)
end

--------------------------------------------------------------------------
-- Blossoms
--------------------------------------------------------------------------

local minY, maxY, maxDistance = math.huge, -math.huge, 1
for _, tip in tips do
	local p = tip.Position
	minY = math.min(minY, p.Y)
	maxY = math.max(maxY, p.Y)
	maxDistance = math.max(maxDistance, Vector3.new(p.X - origin.X, 0, p.Z - origin.Z).Magnitude)
end
local heightRange = math.max(maxY - minY, 1)

local function addBlossom(position, size, color, castShadow)
	local blossom = newPart("Blossom", Enum.PartType.Ball, Vector3.new(size, size, size), CFrame.new(position), color, CONFIG.BlossomMaterial, blossoms)
	makeDecorative(blossom)
	blossom.CastShadow = castShadow

	local half = Vector3.new(size, size, size) / 2
	boundsMin = boundsMin:Min(position - half)
	boundsMax = boundsMax:Max(position + half)
end

for _, tip in tips do
	local p = tip.Position
	local flat = Vector3.new(p.X - origin.X, 0, p.Z - origin.Z)
	local outward = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zero
	-- Higher and further out = more sunlight = paler pink
	local tone = 0.55 * ((p.Y - minY) / heightRange) + 0.45 * (flat.Magnitude / maxDistance)
	local amount = if tip.Fill then 0.5 else 1

	-- Big, darker balls inside give the canopy its volume
	for _ = 1, math.max(1, math.round(P.InnerPerTip * amount)) do
		addBlossom(p + randomInSphere() * 1.2 * S, rng:NextNumber(3.2, 4.6) * S, gradient(tone - 0.35 + rng:NextNumber(-0.1, 0.1)), true)
	end

	-- Smaller, lighter balls on the outside give it a fluffy, flowery surface
	for _ = 1, math.max(1, math.round(P.BlossomsPerTip * amount)) do
		local offset = randomInSphere() * 2.6 * S + (outward * 0.6 + Vector3.yAxis * 0.8) * S
		addBlossom(p + offset, rng:NextNumber(1.6, 3) * S, gradient(tone + rng:NextNumber(-0.15, 0.2)), true)
	end

	-- Hanging strands of blossoms
	if not tip.Fill and rng:NextNumber() < P.HangingChance then
		local position = p + randomInSphere() * 1.5 * S + outward * 1.5 * S
		local size = rng:NextNumber(1.3, 1.7) * S
		for _ = 1, rng:NextInteger(3, 6) do
			position += Vector3.new(rng:NextNumber(-0.25, 0.25) * S, -size * 0.75, rng:NextNumber(-0.25, 0.25) * S)
			addBlossom(position, size, gradient(tone + 0.1 + rng:NextNumber(-0.1, 0.1)), false)
			size *= 0.88
		end
	end
end

--------------------------------------------------------------------------
-- Falling petals
--------------------------------------------------------------------------

local hasCanopy = boundsMin.X < math.huge

if CONFIG.FallingPetals and hasCanopy then
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "PetalEmitter"
	emitterPart.Size = boundsMax - boundsMin
	emitterPart.CFrame = CFrame.new((boundsMin + boundsMax) / 2)
	emitterPart.Transparency = 1
	emitterPart.Anchored = true
	emitterPart.CastShadow = false
	makeDecorative(emitterPart)
	emitterPart.Parent = tree

	local petals = Instance.new("ParticleEmitter")
	petals.Name = "FallingPetals"
	petals.Texture = CONFIG.PetalTexture
	petals.Color = ColorSequence.new(BLOSSOM_GRADIENT[3], BLOSSOM_GRADIENT[5])
	petals.Size = NumberSequence.new(0.35 * S)
	petals.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.08, 0),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	petals.Rate = P.PetalRate
	petals.Lifetime = NumberRange.new(7, 11)
	petals.Speed = NumberRange.new(0.5, 1.5)
	petals.SpreadAngle = Vector2.new(180, 180)
	petals.Acceleration = Vector3.new(0.6, -1.4, 0.3) -- a light breeze
	petals.Drag = 0.5
	petals.Rotation = NumberRange.new(0, 360)
	petals.RotSpeed = NumberRange.new(-150, 150)
	petals.LightInfluence = 1
	-- Newer properties: oval petal shape and following Workspace wind
	pcall(function()
		petals.Squash = NumberSequence.new(0.5)
		petals.WindAffectsDrag = true
	end)
	petals.Parent = emitterPart
end

--------------------------------------------------------------------------
-- Fallen petals on the ground
--------------------------------------------------------------------------

local canopyRadius = if hasCanopy
	then math.max(boundsMax.X - boundsMin.X, boundsMax.Z - boundsMin.Z) / 2
	else 10 * S

-- The tree isn't in Workspace yet, so these rays only hit the real ground
local function groundAt(x, z)
	local from = Vector3.new(x, origin.Y + 8 * S, z)
	local hit = workspace:Raycast(from, Vector3.new(0, -30 * S, 0))
	return if hit then hit.Position else Vector3.new(x, origin.Y, z)
end

local ground = Instance.new("Model")
ground.Name = "GroundPetals"
ground.Parent = tree

if CONFIG.PetalCarpet then
	for i = 1, 3 do
		local angle = rng:NextNumber(0, TAU)
		local distance = rng:NextNumber(0, canopyRadius * 0.3)
		local center = groundAt(origin.X + math.cos(angle) * distance, origin.Z + math.sin(angle) * distance)
		local diameter = canopyRadius * rng:NextNumber(0.9, 1.5)
		local carpet = newPart(
			"PetalCarpet",
			Enum.PartType.Cylinder,
			Vector3.new(0.05, diameter, diameter),
			CFrame.new(center + Vector3.new(0, 0.03 + i * 0.015, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			gradient(0.6 + i * 0.1),
			Enum.Material.SmoothPlastic,
			ground
		)
		carpet.Transparency = 0.45 + i * 0.1
		carpet.CastShadow = false
		makeDecorative(carpet)
	end
end

for _ = 1, P.GroundPetals do
	local angle = rng:NextNumber(0, TAU)
	local distance = math.sqrt(rng:NextNumber()) * canopyRadius * 1.1
	local position = groundAt(origin.X + math.cos(angle) * distance, origin.Z + math.sin(angle) * distance)
	local petal = newPart(
		"Petal",
		Enum.PartType.Block,
		Vector3.new(rng:NextNumber(0.35, 0.6), 0.04, rng:NextNumber(0.25, 0.4)) * S,
		CFrame.new(position + Vector3.new(0, 0.08, 0))
			* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, TAU), rng:NextNumber(-0.2, 0.2)),
		gradient(rng:NextNumber(0.4, 1)),
		Enum.Material.SmoothPlastic,
		ground
	)
	petal.CastShadow = false
	makeDecorative(petal)
end

--------------------------------------------------------------------------
-- Finish
--------------------------------------------------------------------------

tree.WorldPivot = CFrame.new(origin) -- move/rotate the tree around its base
tree.Parent = workspace

-- Studio niceties when run from the Command Bar: select it and allow Ctrl+Z
pcall(function()
	game:GetService("Selection"):Set({ tree })
	game:GetService("ChangeHistoryService"):SetWaypoint("Create SakuraTree")
end)

local partCount = 0
for _, item in tree:GetDescendants() do
	if item:IsA("BasePart") then
		partCount += 1
	end
end
print(("SakuraTree created (%s quality, %d parts)"):format(QUALITY, partCount))
