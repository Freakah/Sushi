--[[
	Sakura Tree Generator
	=====================
	Builds a cherry blossom (sakura) tree out of regular Parts: a bark trunk,
	branches that fork and spread wide, pink blossom clusters, falling petal
	particles and a scatter of petals on the ground.

	HOW TO USE (recommended):
	  1. Open your place in Roblox Studio.
	  2. View > Command Bar.
	  3. Paste this entire file into the Command Bar and press Enter.
	  4. A model called "SakuraTree" appears in Workspace (and gets selected).
	     Move it wherever you like. Run it again for a different random tree,
	     or set CONFIG.Seed to get the same tree every time.
	  5. Optional: right-click the model > "Save to Roblox" to reuse it in
	     other games, or drag it into ReplicatedStorage/ServerStorage.

	You can also put this in a Script inside ServerScriptService - it will then
	build a fresh tree every time the game starts.
]]

local CONFIG = {
	Position = Vector3.new(0, 0, 0), -- where the base of the trunk sits
	Seed = nil, -- e.g. 42 to always get the same tree; nil = random

	-- Trunk & branches
	TrunkHeight = 8,
	TrunkRadius = 1.4,
	BranchLevels = 4, -- how many times the branches fork (4-5 looks good)
	MinSplits = 2,
	MaxSplits = 3,
	LengthScale = { 0.72, 0.88 }, -- each branch is this much shorter than its parent
	RadiusScale = 0.62, -- each branch is this much thinner than its parent
	MinBranchRadius = 0.18,
	BaseTilt = 0.55, -- radians from vertical for the first branches
	TiltPerLevel = 0.2, -- outer branches spread flatter, giving the wide sakura shape
	MaxTilt = 1.35,
	Roots = 4,

	-- Blossoms
	BlossomsPerTip = 6,
	BlossomSize = { 2.5, 4.5 },
	BlossomSpread = 2.5,
	BlossomMaterial = Enum.Material.SmoothPlastic,

	-- Falling petals (particles)
	FallingPetals = true,
	PetalRate = 8,
	-- Swap this for a petal image from the Toolbox (e.g. "rbxassetid://123456")
	-- for extra detail; the default soft blob already reads as petals at this size.
	PetalTexture = "rbxasset://textures/particles/smoke_main.dds",

	-- Petals lying on the ground
	GroundPetals = 60,
}

local BARK_COLOR = Color3.fromRGB(74, 52, 46)
local PINKS = {
	Color3.fromRGB(255, 183, 197),
	Color3.fromRGB(255, 197, 211),
	Color3.fromRGB(250, 160, 185),
	Color3.fromRGB(255, 215, 225),
	Color3.fromRGB(245, 140, 170),
}

local rng = if CONFIG.Seed then Random.new(CONFIG.Seed) else Random.new()
local TAU = math.pi * 2

local tree = Instance.new("Model")
tree.Name = "SakuraTree"

local wood = Instance.new("Model")
wood.Name = "Wood"
wood.Parent = tree

local blossoms = Instance.new("Model")
blossoms.Name = "Blossoms"
blossoms.Parent = tree

local boundsMin = Vector3.new(math.huge, math.huge, math.huge)
local boundsMax = Vector3.new(-math.huge, -math.huge, -math.huge)

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

local function randomPink()
	return PINKS[rng:NextInteger(1, #PINKS)]
end

local function randomRange(range)
	return rng:NextNumber(range[1], range[2])
end

-- A cylinder running from baseCF along its up (Y) axis, with a ball at the
-- joint so the gaps between branch pieces are hidden.
local function woodSegment(baseCF, length, radius)
	local diameter = radius * 2
	local segment = newPart(
		"Branch",
		Enum.PartType.Cylinder,
		Vector3.new(length, diameter, diameter),
		-- Roblox cylinders run along X; rotate so they run along Y instead
		baseCF * CFrame.new(0, length / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		BARK_COLOR,
		Enum.Material.Wood,
		wood
	)
	newPart(
		"Joint",
		Enum.PartType.Ball,
		Vector3.new(diameter, diameter, diameter),
		baseCF,
		BARK_COLOR,
		Enum.Material.Wood,
		wood
	)
	return segment
end

local function blossomCluster(center, spread, count)
	for _ = 1, count do
		local offset = Vector3.new(
			rng:NextNumber(-1, 1),
			rng:NextNumber(-0.4, 0.8),
			rng:NextNumber(-1, 1)
		) * spread
		local position = center + offset
		local size = randomRange(CONFIG.BlossomSize)

		local blossom = newPart(
			"Blossom",
			Enum.PartType.Ball,
			Vector3.new(size, size, size),
			CFrame.new(position),
			randomPink(),
			CONFIG.BlossomMaterial,
			blossoms
		)
		blossom.CanCollide = false

		local half = Vector3.new(size, size, size) / 2
		local low, high = position - half, position + half
		boundsMin = Vector3.new(math.min(boundsMin.X, low.X), math.min(boundsMin.Y, low.Y), math.min(boundsMin.Z, low.Z))
		boundsMax = Vector3.new(math.max(boundsMax.X, high.X), math.max(boundsMax.Y, high.Y), math.max(boundsMax.Z, high.Z))
	end
end

-- Recursively grows a branch, then forks it until BranchLevels is reached.
-- Tilt is measured from world vertical so the tree spreads out wide instead
-- of curling back down on itself.
local function grow(basePosition, yaw, tilt, length, radius, level)
	local baseCF = CFrame.new(basePosition) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, 0)
	woodSegment(baseCF, length, radius)
	local tip = (baseCF * CFrame.new(0, length, 0)).Position

	if level >= CONFIG.BranchLevels then
		blossomCluster(tip, CONFIG.BlossomSpread, CONFIG.BlossomsPerTip)
		return
	end

	local splits = rng:NextInteger(CONFIG.MinSplits, CONFIG.MaxSplits)
	local startYaw = rng:NextNumber(0, TAU)
	for i = 1, splits do
		local childLevel = level + 1
		local childYaw
		if level == 0 then
			-- Main limbs fan out evenly around the trunk
			childYaw = startYaw + (i - 1) * (TAU / splits) + rng:NextNumber(-0.3, 0.3)
		else
			childYaw = yaw + rng:NextNumber(-0.9, 0.9)
		end
		local childTilt = math.min(
			CONFIG.BaseTilt + (childLevel - 1) * CONFIG.TiltPerLevel + rng:NextNumber(-0.15, 0.15),
			CONFIG.MaxTilt
		)
		grow(
			tip,
			childYaw,
			childTilt,
			length * randomRange(CONFIG.LengthScale),
			math.max(radius * CONFIG.RadiusScale, CONFIG.MinBranchRadius),
			childLevel
		)
	end

	-- Extra blossoms on the second-to-last branches fill out the canopy
	if level == CONFIG.BranchLevels - 1 then
		blossomCluster(tip, CONFIG.BlossomSpread * 0.8, math.ceil(CONFIG.BlossomsPerTip / 2))
	end
end

local origin = CONFIG.Position

-- Trunk (with a slight random lean) and everything above it
grow(origin, rng:NextNumber(0, TAU), rng:NextNumber(0.03, 0.1), CONFIG.TrunkHeight, CONFIG.TrunkRadius, 0)
tree.PrimaryPart = wood:FindFirstChild("Branch")

-- Root flares at the base
for i = 1, CONFIG.Roots do
	local yaw = (i - 1) * (TAU / CONFIG.Roots) + rng:NextNumber(-0.3, 0.3)
	-- Pointing downward and outward, starting a little above the ground
	local rootCF = CFrame.new(origin + Vector3.new(0, CONFIG.TrunkRadius * 0.9, 0))
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(math.pi - 1.1, 0, 0)
	woodSegment(rootCF, CONFIG.TrunkRadius * 2.2, CONFIG.TrunkRadius * 0.45)
end

-- Falling petals: an invisible box around the canopy that emits particles
if CONFIG.FallingPetals and boundsMin.X < math.huge then
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "PetalEmitter"
	emitterPart.Size = boundsMax - boundsMin
	emitterPart.CFrame = CFrame.new((boundsMin + boundsMax) / 2)
	emitterPart.Transparency = 1
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.CastShadow = false
	emitterPart.Parent = tree

	local petals = Instance.new("ParticleEmitter")
	petals.Name = "FallingPetals"
	petals.Texture = CONFIG.PetalTexture
	petals.Color = ColorSequence.new(PINKS[1], PINKS[5])
	petals.Size = NumberSequence.new(0.35)
	petals.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	petals.Rate = CONFIG.PetalRate
	petals.Lifetime = NumberRange.new(6, 9)
	petals.Speed = NumberRange.new(0.5, 1.5)
	petals.SpreadAngle = Vector2.new(180, 180)
	petals.Acceleration = Vector3.new(0.6, -1.5, 0.3) -- a light breeze
	petals.Drag = 0.5
	petals.Rotation = NumberRange.new(0, 360)
	petals.RotSpeed = NumberRange.new(-120, 120)
	petals.LightInfluence = 1
	petals.Parent = emitterPart
end

-- Petals scattered on the ground under the canopy
if CONFIG.GroundPetals > 0 then
	local groundPetals = Instance.new("Model")
	groundPetals.Name = "GroundPetals"
	groundPetals.Parent = tree

	local canopyRadius = if boundsMin.X < math.huge
		then math.max(boundsMax.X - boundsMin.X, boundsMax.Z - boundsMin.Z) / 2
		else 8
	for _ = 1, CONFIG.GroundPetals do
		local angle = rng:NextNumber(0, TAU)
		local distance = math.sqrt(rng:NextNumber()) * canopyRadius
		local position = origin + Vector3.new(math.cos(angle) * distance, 0.03, math.sin(angle) * distance)
		local petal = newPart(
			"Petal",
			Enum.PartType.Block,
			Vector3.new(rng:NextNumber(0.4, 0.7), 0.05, rng:NextNumber(0.3, 0.5)),
			CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
			randomPink(),
			Enum.Material.SmoothPlastic,
			groundPetals
		)
		petal.CanCollide = false
		petal.CanQuery = false
		petal.CastShadow = false
	end
end

tree.Parent = workspace

-- Select the new tree when run from the Studio Command Bar
pcall(function()
	game:GetService("Selection"):Set({ tree })
end)

print(("SakuraTree created (%d objects)"):format(#tree:GetDescendants()))
