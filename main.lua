----------------------------------------------- Demo game - Basilio Germán
require("dependencies.index.index")("dependencies")("dynacam-demo") -- Register lib path and namespace (Shortens dependecy require path)
local physics = require("physics")
local widget = require("widget")
local dynacam = require("dynacam")
----------------------------------------------- Variables
local camera1
local camera2

local lightsData

local mapGroup
local healthBox
local smallShip
local otherShip

local controlObject

local holdingKey = {
	right = false,
	left = false,
	up = false,
	down = false,
}
----------------------------------------------- Constants
local SLIDERS_ENABLED = true

local FILLS = {
	[1] = {
		diffuse = "images/wall.png",
		normal = "images/wall_n.png",
		zMult = 1,
	},
	[2] = {
		diffuse = "images/brick.png",
		normal = "images/brick_n.png",
		zMult = 1,
	},
}
local TILE_MAP = {
	{1,1,1,1,1,1,1,2,1,1,2,2},
	{1,1,1,2,1,1,1,1,1,1,1,1},
	{1,1,2,2,2,2,1,2,1,1,1,2},
	{1,2,2,2,2,2,1,2,2,2,2,2},
	{1,2,2,2,2,1,1,1,1,1,1,1},
	{1,2,2,2,2,1,1,1,1,1,1,1},
	{1,2,2,1,1,1,1,1,1,1,1,1},
	{2,1,1,1,1,1,1,1,1,2,2,1},
}

local ACCELERATION = 1000
local FORCES_KEY = {
	right = {torque = ACCELERATION * 5},
	left = {torque = -ACCELERATION * 5},
	up = {force = ACCELERATION},
	down = {force = -ACCELERATION},
}
----------------------------------------------- Caches
----------------------------------------------- Functions
local function keyListener(event)
	if holdingKey[event.keyName] ~= nil then -- Prevent other keys from registering
		if event.phase == "down" then
			holdingKey[event.keyName] = true
		elseif event.phase == "up" then
			holdingKey[event.keyName] = false
		end
	end
end

local function createBackground()
	-- Grid Tiled background
	local size = 500
	for y = 1, #TILE_MAP do
		for x = 1, #TILE_MAP[y] do
			local fillData = FILLS[TILE_MAP[y][x]]
			
			local offsetX = x * size
			local offsetY = y * size
			
			local rect = dynacam.newRect(offsetX, offsetY, size, size)
			rect.fill = {type = "image", filename = fillData.diffuse}
			rect.normal = {type = "image", filename = fillData.normal}
			rect.normal.effect.zMult = fillData.zMult
			
			mapGroup:insert(rect)
		end
	end
end

local function addlights()
	-- Add lights to world
	for lIndex = 1, #lightsData do 
		local lightData = lightsData[lIndex]
		
		local lOptions = {
			color = lightData.color,
		}
		local light = dynacam.newLight(lOptions)
		
		light.x = lightData.position[1]
		light.y = lightData.position[2]
		light.z = lightData.position[3]
		light.attenuationFactors = lightData.attenuationFactors
		mapGroup:insert(light)
	end
end

local function coinTap(event)
	local coinGroup = event.target
	if not coinGroup.collected then
		coinGroup.collected = true -- Avoid double collection
		
		coinGroup:applyAngularImpulse(5000)
		
		transition.to(coinGroup.light, {scale = 0.01, time = 400, transition = easing.inQuad})
		transition.to(coinGroup, {alpha = 0, time = 400, transition = easing.inQuad})
		transition.to(coinGroup, {xScale = 0.1, yScale = 0.1, time = 500, transition = easing.inQuad, onComplete = display.remove})
		transition.to(coinGroup, {xScale = 0.1, yScale = 0.1, time = 500, transition = easing.inQuad, onComplete = display.remove})
	end
	
	return true
end

local function addHealthBox()
	-- Test sprite health box
	healthBox = dynacam.newGroup()
	healthBox.x = 1000
	healthBox.y = 1100
	
	local spriteSheet = {
		sheetData = {width = 64, height = 64, numFrames = 2},
		sequenceData = {{name = "idle", start = 1, count = 2, time = 500}},
		diffuse = "images/powerup_health.png",
		normal = "images/powerup_health_n.png",
	}
	local diffuseSheet = graphics.newImageSheet(spriteSheet.diffuse, spriteSheet.sheetData)
	local normalSheet = graphics.newImageSheet(spriteSheet.normal, spriteSheet.sheetData)
	
	local sprite = dynacam.newSprite(diffuseSheet, normalSheet, spriteSheet.sequenceData)
	sprite:setSequence("idle")
	sprite:play()
	healthBox:insert(sprite)
	
	local healthLight = dynacam.newLight({color = {1, 0, 0, 1}})
	healthLight.x = 0
	healthLight.y = 0
	healthLight.z = 0.1
	healthBox:insert(healthLight)
	
	mapGroup:insert(healthBox)
	dynacam.addBody(healthBox, "dynamic", {friction = 0.5, bounce = 0.1, density = 1, box = {halfWidth = 32, halfHeight = 32}})
	
	healthBox.angularDamping = 0.2
	healthBox.linearDamping = 0.6
end

local function addCoinGrid()
	 -- Test sprite coin
	local coinSpriteSheet = {
		sheetData = {width = 34, height = 34, numFrames = 16},
		sequenceData = {{name = "idle", start = 1, count = 16, time = 1000}},
		diffuse = "images/spinning_coin_gold.png",
		normal = "images/spinning_coin_gold_n.png",
	}
	local cDiffuseSheet = graphics.newImageSheet(coinSpriteSheet.diffuse, coinSpriteSheet.sheetData)
	local cNormalSheet = graphics.newImageSheet(coinSpriteSheet.normal, coinSpriteSheet.sheetData)
	
	local coinGridSize = 8
	local numCoins = 40
	
	local coinGridX = 1500
	local coinGridY = 1200
	local coinGridSpacing = 100
	local coinLightColor = {1, 0.843, 0, 0.25}
	
	for index = 1, numCoins do
		local x = index % coinGridSize
		local y = math.ceil(index * (1 / coinGridSize))
		
		local coinGroup = dynacam.newGroup()
		coinGroup.x = coinGridX + (x * coinGridSpacing)
		coinGroup.y = coinGridY + (y * coinGridSpacing)
		
		local coinSprite = dynacam.newSprite(cDiffuseSheet, cNormalSheet, coinSpriteSheet.sequenceData)
		coinSprite:setSequence("idle")
		coinSprite:play()
		coinGroup:insert(coinSprite)
		
		dynacam.addBody(coinGroup, "dynamic", {friction = 0.5, bounce = 0.1, density = 1, radius = 17})
		
		coinGroup.angularDamping = 0.5
		coinGroup.linearDamping = 0.8
		
		local coinLight = dynacam.newLight({color = coinLightColor})
		coinLight.z = 0.05
		coinLight.scale = 1 / 1.61803398874989
		coinGroup:insert(coinLight)
		coinGroup.light = coinLight
		
		coinGroup:addEventListener("tap", coinTap)
		
		mapGroup:insert(coinGroup)
	end
end

local function pilotBigShip()
	local isStill = (otherShip.angularVelocity < 5) and (otherShip.angularVelocity > -5)
	if isStill then -- Only if ship is not spinning
		controlObject = otherShip
		otherShip.linearDamping = 0.01
	end
end

local function addBigShip()
	otherShip = dynacam.newImage("images/spaceship_carrier_02.png", "images/spaceship_carrier_02_n.png")
	otherShip.x = 2750
	otherShip.y = 1250
	dynacam.addBody(otherShip, "dynamic", {friction = 0.5, bounce = 0, density = 20, box = {halfWidth = otherShip.width * 0.5, halfHeight = otherShip.height * 0.4}})
	
	otherShip.fMult = 100
	otherShip.linearDamping = 0.5
	otherShip:applyAngularImpulse(3000000)
	mapGroup:insert(otherShip)
	
	otherShip:addEventListener("tap", pilotBigShip)
end

local function toggleSmallShipLight(event)
	local pCharacter = event.target
	local light = pCharacter.shipLight
	
	light.state = not light.state
	local intensity = light.state and 1 or 0
	
	light.color[4] = intensity
end

local function addSmallShip()
	smallShip = dynacam.newGroup()
	smallShip.x = 800
	smallShip.y = 800
	smallShip.fMult = 1
	mapGroup:insert(smallShip)
	
	local shipImage = dynacam.newImage("images/spaceship_carrier_01.png", "images/spaceship_carrier_01_n.png")
	shipImage.fill.effect = "filter.pixelate"
	shipImage.fill.effect.numPixels = 8
	transition.to(shipImage.fill.effect, {time = 10000, numPixels = 1,}) -- Single transition
	smallShip:insert(shipImage)
	smallShip.ship = shipImage
	
	local shipLight = dynacam.newLight({color = {1, 1, 1, 1}})
	shipLight.x = 300 -- Place in front of ship
	shipLight.y = 0
	shipLight.z = 0.15
	shipLight.state = true
	smallShip:insert(shipLight)
	smallShip.shipLight = shipLight
	
	dynacam.addBody(smallShip, "dynamic", {friction = 0.5, bounce = 0.1, density = 1, box = {halfWidth = 120, halfHeight = 64}})
	
	smallShip.angularDamping = 2
	smallShip.linearDamping = 0.5
	
	smallShip:addEventListener("tap", toggleSmallShipLight)
end

local function tapShapeGroup(event)
	local shapesGroup = event.target
	
	transition.cancel(shapesGroup)
	transition.to(shapesGroup, {x = shapesGroup.x + 500, transition = easing.inOutQuad, time = 1600})
	
	return true
end

local function addCommonDisplayObjects()
	-- Text test
	local textOptions = {
		x = 1250,
		y = 300,
		font = native.systemFontBold,
		fontSize = 60,
		text = "Dynacam test playground!",
		normal = {0.5, 0.5, 1},
	}
	local text = dynacam.newText(textOptions)
	mapGroup:insert(text)
	
	-- Mesh test
	local mesh = dynacam.newMesh({
		x = 0,
		y = 0,
		mode = "fan",
		vertices = {
			200,0, 0,0, 0,400, 400,400, 400,0
		}
	})
	mesh:translate(mesh.path:getVertexOffset())  -- Translate mesh so that vertices have proper world coordinates
	mesh.fill = {type = "image", filename = FILLS[2].diffuse}
	mesh.normal = {type = "image", filename = FILLS[2].normal}
	local vertexX, vertexY = mesh.path:getVertex(3)
	mesh.path:setVertex(3, vertexX + 50, vertexY - 50)
	mapGroup:insert(mesh)
	
	-- Normal Line
	local line = dynacam.newLine(0, 0, 1000, 1000)
	line:append(1300, 1000)
	line:append(2000, 2000)
	line:append(2000, 1000)
	line:append(1500, 250)
	line.strokeWidth = 10
	mapGroup:insert(line)
	
	-- Line without normal
	local dLine = display.newLine(50, 100, 1050, 1100)
	dLine:append(1350, 1100)
	dLine:append(2050, 2100)
	dLine:append(2050, 1100)
	dLine:append(1550, 350)
	dLine.strokeWidth = 10
	mapGroup.super:insert(dLine) -- Used to insert displayObjects
	
	-- Line without lighting
	local dAddLine = display.newLine(300, 0, 1300, 1000)
	dAddLine:append(1300, 2000)
	dAddLine:append(2500, 2000)
	dAddLine:append(2750, 1750)
	dAddLine.strokeWidth = 10
	camera1:add(dAddLine) -- Used to insert displayObjects without light
	
	local shapesGroup = dynacam.newGroup()
	mapGroup:insert(shapesGroup)
	
	-- Polygon test
	local vertices = { 0,-110, 27,-35, 105,-35, 43,16, 65,90, 0,45, -65,90, -43,15, -105,-35, -27,-35, }
	local polygon = dynacam.newPolygon(1500, 1250, vertices)
	polygon.fill = {type = "image", filename = FILLS[2].diffuse}
	polygon.normal = {type = "image", filename = FILLS[2].normal}
	polygon.fill.rotation = 90
	shapesGroup:insert(polygon)
	
	-- Circle
	local circle = dynacam.newCircle(1250, 1250, 100)
	circle.fill = {type = "image", filename = FILLS[1].diffuse}
	circle.normal = {type = "image", filename = FILLS[1].normal}
	circle.fill.scaleX = 5
	circle.fill.scaleY = 5
	shapesGroup:insert(circle)
	
	-- RoundedRect
	local roundedRect = dynacam.newRoundedRect(1750, 1250, 200, 150, 50)
	roundedRect.fill = {type = "image", filename = FILLS[2].diffuse}
	roundedRect.normal = {type = "image", filename = FILLS[2].normal}
	shapesGroup:insert(roundedRect)
	
	-- Test removal
	transition.to(roundedRect, {delay = 5000, time = 2000, alpha = 0, xScale = 1.5, yScale = 0.5, onComplete = display.remove})
	-- Test listener grouping
	shapesGroup:addEventListener("tap", tapShapeGroup)

	-- Container
	local container = dynacam.newContainer(200, 200)
	container.x = 2750
	container.y = 1500
	mapGroup:insert(container)
	
	-- newImage & container
	local containerShip = dynacam.newImage("images/spaceship_carrier_02.png", "images/spaceship_carrier_02_n.png")
	container:insert(containerShip)
end

local function addMoreTestSprites()
	local spriteSheet = {
		sheetData = {width = 90, height = 130, numFrames = 16},
		sequenceData = {{name = "idle", start = 1, count = 16, time = 600}},
		diffuse = "images/arrow_128x88_horizontal_texture.png",
		normal = "images/arrow_128x88_horizontal_normal.png",
	}
	local diffuseSheet = graphics.newImageSheet(spriteSheet.diffuse, spriteSheet.sheetData)
	local normalSheet = graphics.newImageSheet(spriteSheet.normal, spriteSheet.sheetData)
	
	local sprite = dynacam.newSprite(diffuseSheet, normalSheet, spriteSheet.sequenceData)
	sprite.x = 1500
	sprite.y = 1000
	sprite:setSequence("idle")
	sprite:play()
	mapGroup:insert(sprite)
end

local function createWorld()
	display.remove(mapGroup)
	mapGroup = dynacam.newGroup()
	
	createBackground()
	addlights()
	addCommonDisplayObjects()
	addCoinGrid()
	addHealthBox()
	addMoreTestSprites()
	addSmallShip()
	addBigShip()
end

local function sliderListener(event)
	local slider = event.target
	local valueText = slider.valueText
	local index = slider.index
	local value = event.value

	local float = (value * slider.valueScale) + slider.offset
	valueText.text = string.format("%.02f", float)
	
	if slider.listener then
		slider.listener({value = float})
	end
end

local function createSlider(valueScale, offset, label, listener, defValue)
	local sGroup = display.newGroup()
	sGroup.alpha = 0.2
	
	local slider = widget.newSlider({
		x = 0,
		y = 0,
		orientation = "vertical",
		height = 150,
		value = defValue,
		listener = sliderListener
	})
	slider.listener = listener
	slider.valueScale = valueScale
	slider.offset = offset
	sGroup:insert(slider)
	
	local valueTOptions = {
		x = 0,
		y = -100,
		font = native.systemFontBold,
		fontSize = 40,
		text = tostring(offset + defValue * valueScale),
	}
	local valueText = display.newText(valueTOptions)
	valueText.anchorX = 0
	valueText.rotation = -90
	sGroup:insert(valueText)
	slider.valueText = valueText
	
	local labelTOptions = {
		x = 0,
		y = 100,
		font = native.systemFontBold,
		fontSize = 40,
		text = label,
	}
	local labelText = display.newText(labelTOptions)
	sGroup:insert(labelText)
	
	return sGroup
end

local function updateConstant(event)
	smallShip.shipLight.attenuationFactors[1] = event.value
end

local function updateLinear(event)
	smallShip.shipLight.attenuationFactors[2] = event.value
end

local function updateQuadratic(event)
	smallShip.shipLight.attenuationFactors[3] = event.value
end

local function updateScale(event)
	smallShip.shipLight.scale = event.value
end

local function updateColorR(event)
	smallShip.shipLight.color[1] = event.value
end

local function updateColorG(event)
	smallShip.shipLight.color[2] = event.value
end

local function updateColorB(event)
	smallShip.shipLight.color[3] = event.value
end

local function updateZoom(event)
	camera1:setZoom(event.value, 0, 0)
end

local function createSliders()
	if SLIDERS_ENABLED then
		
		local sliderData = {
			{scale = 0.02, offset = 0, label = "Co", listener = updateConstant, defValue = 20}, -- Constant attenuation factor
			{scale = 0.05, offset = 0, label = "Li", listener = updateLinear, defValue = 60}, -- Linear attenuation factor
			{scale = 0.5, offset = 0, label = "Qu", listener = updateQuadratic, defValue = 40}, -- Quadratic attenuation factor
			
			{scale = 0.02, offset = 0.01, label = "Sc", listener = updateScale, defValue = 50}, -- Light scale
			
			{scale = 0.01, offset = 0, label = "Re", listener = updateColorR, defValue = 100}, -- Red
			{scale = 0.01, offset = 0, label = "Gr", listener = updateColorG, defValue = 100}, -- Green
			{scale = 0.01, offset = 0, label = "Bl", listener = updateColorB, defValue = 100}, -- Blue
			
			{scale = 0.02, offset = 0.5, label = "Zo", listener = updateZoom, defValue = 25}, -- Zoom
		}
		
		local currentX = display.screenOriginX
		local currentY = display.screenOriginY + display.actualContentHeight - 150
		for index = 1, #sliderData do
			currentX = currentX + 50
			
			local data = sliderData[index]
			local slider = createSlider(data.scale, data.offset, data.label, data.listener, data.defValue)
			slider.x = currentX
			slider.y = currentY
		end
	end
end

local function startGame()
	dynacam.start()
	
	local bg = display.newImage("images/bg1.png")
	bg.x = 0
	bg.y = 500
	camera1:add(bg, nil, true)
	
	camera1:add(mapGroup)
	camera1:setFocus(smallShip)
	
--	camera2:add(mapGroup)
--	camera2:setFocus(otherShip, {trackRotation = false})
	camera1:setZoom(0.825, 0, 0)
	
	controlObject = smallShip
	Runtime:addEventListener("enterFrame", function(event)
--		local counter = (event.frame + 1) % (360 * 4)
--		local angle = math.rad(counter * 0.25)
--		camera1.lights[4].x = 700 + math.cos(angle) * 600
--		camera1.lights[4].y = 700 + math.sin(angle) * 600
--		camera1.lights[4].color[1] = math.cos(angle * 4)
		
		for key, holding in pairs(holdingKey) do
			local force = holding and FORCES_KEY[key].force
			if force then
				force = force * (controlObject.fMult or 1)
				
				local fX = math.cos(math.rad(controlObject.rotation)) * force
				local fY = math.sin(math.rad(controlObject.rotation)) * force
				
				controlObject:applyForce(fX, fY, controlObject.x, controlObject.y)
			end
			
			if holding and FORCES_KEY[key].torque then
				controlObject:applyTorque(FORCES_KEY[key].torque * (controlObject.fMult or 1))
			end
		end
	end)
end

local function cleanUp()
	dynacam.stop()
end

local function initialize()
	display.setStatusBar( display.HiddenStatusBar )
	
--	local hWidth = display.viewableContentWidth * 0.5
--	local vertices1 = {0, 0, 0.625, 0, 0.375, 1, 0, 1}
	camera1 = dynacam.newCamera({
		damping = 10, 
--		width = hWidth,
--		vertices = vertices1,
	})

	-- Auto Mode switcher
	local mIndex = 0
	local modes = {false, "normal", "diffuse", "light", "listeners"}
	timer.performWithDelay(2500, function()
		mIndex = mIndex + 1
		if mIndex > #modes then
			mIndex = 1
		end
		camera1:setDrawMode(modes[mIndex])
	end, -1)
	
--	camera1.anchorChildren = true
--	camera1.anchorX = 0
--	camera1.x = display.screenOriginX
	camera1.x = display.contentCenterX
	camera1.y = display.contentCenterY
	
	local vertices2 = {0.625, 0, 1, 0, 1, 1, 0.375, 1}
--	camera2 = dynacam.newCamera({damping = 10, width = hWidth, vertices = vertices2})
--	camera2.anchorChildren = true
--	camera2.anchorX = 1
--	camera2.x = display.screenOriginX + display.viewableContentWidth
--	camera2.y = display.contentCenterY
	
	physics.start()
	physics.setGravity(0, 0)
	
	lightsData = {
		{position = {400, 400, 0.2}, color = {1, 1, 1, 1}},
		{position = {700, 900, 0.2}, color = {1, 1, 1, 1}},
		{position = {900, 900, 0.2}, color = {1, 1, 0, 1}},
		{position = {0, 0, 0.2}, color = {1, 0, 1, 1}},
		{position = {500, 2000, 0.05}, color = {0.1, 0.1, 0.1, 1}},
		{position = {2500, 800, 0.25}, color = {0, 1, 0, 1}},
		{position = {2200, 1200, 0.15}, color = {0, 0.5, 1, 1}},
		{position = {1400, 1800, 0.1}, color = {0, 0.5, 1, 1}},
		{position = {3000, 2000, 0.1}, color = {1, 1, 1, 1}, attenuationFactors = {0.1, 2, 5}},
	}
	
	Runtime:addEventListener("key", keyListener)
end
----------------------------------------------- Execution
initialize()
createWorld()
createSliders()
startGame()
