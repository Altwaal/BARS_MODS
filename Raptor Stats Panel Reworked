if not (Spring.Utilities.Gametype.IsRaptors() and not Spring.Utilities.Gametype.IsScavengers()) then
	return false
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Raptor Stats Panel Reworked",
		desc = "Shows statistics and progress when fighting vs Raptors",
		author = "quantum, Altwaal rework",
		date = "October 14, 2025",
		license = "GNU GPL, v2 or later",
		layer = -9,
		enabled = true
	}
end

local config = VFS.Include('LuaRules/Configs/raptor_spawn_defs.lua')

local customScale = 1
local widgetScale = customScale
local font, font2
local messageArgs, marqueeMessage
local refreshMarqueeMessage = false
local showMarqueeMessage = false

-- New variables for grace period warnings
local gracePeriodWarnings = {
	[300] = false,  -- 5 minutes
	[180] = false,  -- 3 minutes
	[60] = false,   -- 1 minute
}
local lastGracePeriodCheck = 0

-- Track mini boss spawns to avoid duplicate notifications
local miniBossNotifications = {
	raptor_miniq_a = false,
	raptor_miniq_b = false,
	raptor_miniq_c = false,
	raptor_mama_ba = false,
	raptor_mama_fi = false,
	raptor_mama_el = false,
	raptor_mama_ac = false,
	raptor_consort = false,
	raptor_doombringer = false,
}

if not Spring.Utilities.Gametype.IsRaptors() then
	return false
end

if not Spring.GetGameRulesParam("raptorDifficulty") then
	return false
end

local GetGameSeconds = Spring.GetGameSeconds

local displayList
local panelTexture = ":n:LuaUI/Images/raptorpanel.tga"

local panelFontSize = 14
local waveFontSize = 36

local vsx, vsy = Spring.GetViewGeometry()

local viewSizeX, viewSizeY = 0, 0
local w = 300
local h = 210
local x1 = 0
local y1 = 0
local panelMarginX = 30
local panelMarginY = 40
local panelSpacingY = 5
local waveSpacingY = 7
local moving
local capture
local gameInfo
local waveSpeed = 0.1
local waveCount = 0
local waveTime
local bossToastTimer = Spring.GetTimer()
local enabled
local gotScore
local scoreCount = 0
local resistancesTable = {}
local currentlyResistantTo = {}
local currentlyResistantToNames = {}

local guiPanel --// a displayList
local updatePanel
local hasRaptorEvent = false

local difficultyOption = Spring.GetModOptions().raptor_difficulty
local nBosses = Spring.GetModOptions().raptor_queen_count

local rules = {
	"raptorQueenTime",
	"raptorQueenAnger",
	"raptorQueensKilled",
	"raptorTechAnger",
	"raptorGracePeriod",
	"raptorQueenHealth",
	"lagging",
	"raptorDifficulty",
	"raptorCount",
	"raptoraCount",
	"raptorsCount",
	"raptorfCount",
	"raptorrCount",
	"raptorwCount",
	"raptorcCount",
	"raptorpCount",
	"raptorhCount",
	"raptor_turretCount",
	"raptor_dodoCount",
	"raptor_hiveCount",
	"raptorKills",
	"raptoraKills",
	"raptorsKills",
	"raptorfKills",
	"raptorrKills",
	"raptorwKills",
	"raptorcKills",
	"raptorpKills",
	"raptorhKills",
	"raptor_turretKills",
	"raptor_dodoKills",
	"raptor_hiveKills",
}

local waveColor = "\255\255\0\0"
local textColor = "\255\255\255\255"


local raptorTypes = {
	"raptor",
	"raptora",
	"raptorh",
	"raptors",
	"raptorw",
	"raptor_dodo",
	"raptorp",
	"raptorf",
	"raptorc",
	"raptorr",
	"raptor_turret",
}

local function commaValue(amount)
	local formatted = amount
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then
			break
		end
	end
	return formatted
end

local function getRaptorCounts(type)
	local total = 0
	local subtotal

	for _, raptorType in ipairs(raptorTypes) do
		subtotal = gameInfo[raptorType .. type]
		total = total + subtotal
	end

	return total
end

local function updatePos(x, y)
	x1 = math.min((viewSizeX * 0.94) - (w * widgetScale) / 2, x)
	y1 = math.min((viewSizeY * 0.89) - (h * widgetScale) / 2, y)
	updatePanel = true
end

local function PanelRow(n)
	return h - panelMarginY - (n - 1) * (panelFontSize + panelSpacingY)
end

local function WaveRow(n)
	return n * (waveFontSize + waveSpacingY)
end

local function CreatePanelDisplayList()
	gl.PushMatrix()
	gl.Translate(x1, y1, 0)
	gl.Scale(widgetScale, widgetScale, 1)
	gl.CallList(displayList)
	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:SetOutlineColor(0, 0, 0, 1)
	local currentTime = GetGameSeconds()
	if currentTime > gameInfo.raptorGracePeriod then
		if gameInfo.raptorQueenAnger < 100 then

			local gain = 0
			if Spring.GetGameRulesParam("RaptorQueenAngerGain_Base") then
				font:Print(textColor .. Spring.I18N('ui.raptors.queenAngerBase', { value = math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Base"), 3) }), panelMarginX+5, PanelRow(3), panelFontSize, "")
				font:Print(textColor .. Spring.I18N('ui.raptors.queenAngerAggression', { value = math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Aggression"), 3) }), panelMarginX+5, PanelRow(4), panelFontSize, "")
				--font:Print(textColor .. Spring.I18N('ui.raptors.queenAngerEco', { value = math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Eco"), 3) }), panelMarginX+5, PanelRow(5), panelFontSize, "")
				gain = math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Base"), 3) + math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Aggression"), 3) + math.round(Spring.GetGameRulesParam("RaptorQueenAngerGain_Eco"), 3)
			end
			--font:Print(textColor .. Spring.I18N('ui.raptors.queenAngerWithGain', { anger = gameInfo.raptorQueenAnger, gain = math.round(gain, 3) }), panelMarginX, PanelRow(1), panelFontSize, "")
			font:Print(textColor .. Spring.I18N('ui.raptors.queenAngerWithTech', { anger = math.floor(0.5+gameInfo.raptorQueenAnger), techAnger = gameInfo.raptorTechAnger}), panelMarginX, PanelRow(1), panelFontSize, "")

			local totalSeconds = (100 - gameInfo.raptorQueenAnger) / gain
			time = string.formatTime(totalSeconds)
			if totalSeconds < 1800 or revealedQueenEta then
				if not revealedQueenEta then revealedQueenEta = true end
				font:Print(textColor .. Spring.I18N('ui.raptors.queenETA', { count = nBosses, time = time }), panelMarginX+5, PanelRow(2), panelFontSize, "")
			end
			if #currentlyResistantToNames > 0 then
				currentlyResistantToNames = {}
				currentlyResistantTo = {}
			end
		else
			font:Print(textColor .. Spring.I18N('ui.raptors.queenHealth', {count = nBosses, health = gameInfo.raptorQueenHealth }), panelMarginX, PanelRow(1), panelFontSize, "")
			if nBosses > 1 then
				font:Print(textColor .. Spring.I18N('ui.raptors.queensKilled', { nKilled = gameInfo.raptorQueensKilled, nTotal = nBosses }), panelMarginX, PanelRow(2), panelFontSize, "")
			end
			for i = 1,#currentlyResistantToNames do
				if i == 1 then
					font:Print(textColor .. Spring.I18N('ui.raptors.queenResistantToList', {count = nBosses}), panelMarginX, PanelRow(11), panelFontSize, "")
				end
				font:Print(textColor .. currentlyResistantToNames[i], panelMarginX+20, PanelRow(11+i), panelFontSize, "")
			end
		end
	else
		font:Print(textColor .. Spring.I18N('ui.raptors.gracePeriod', { time = string.formatTime(math.ceil(((currentTime - gameInfo.raptorGracePeriod) * -1) - 0.5)) }), panelMarginX, PanelRow(1), panelFontSize, "")
	end

	font:Print(textColor .. Spring.I18N('ui.raptors.raptorKillCount', { count = gameInfo.raptorKills }), panelMarginX, PanelRow(6), panelFontSize, "")
	local endless = ""
	if Spring.GetModOptions().raptor_endless then
		endless = ' (' .. Spring.I18N('ui.raptors.difficulty.endless') .. ')'
	end
	local difficultyCaption = Spring.I18N('ui.raptors.difficulty.' .. difficultyOption)
	font:Print(textColor .. Spring.I18N('ui.raptors.mode', { mode = difficultyCaption }) .. endless, 80, h - 170, panelFontSize, "")
	font:End()

	gl.Texture(false)
	gl.PopMatrix()
end

local function getMarqueeMessage(raptorEventArgs)
	local messages = {}
	if raptorEventArgs.type == "firstWave" then
		messages[1] = textColor .. Spring.I18N('ui.raptors.firstWave1')
		messages[2] = textColor .. Spring.I18N('ui.raptors.firstWave2')
	elseif raptorEventArgs.type == "queen" then
		messages[1] = textColor .. Spring.I18N('ui.raptors.queenIsAngry1', {count = nBosses})
		messages[2] = textColor .. Spring.I18N('ui.raptors.queenIsAngry2')
	elseif raptorEventArgs.type == "airWave" then
		messages[1] = textColor .. Spring.I18N('ui.raptors.wave1', {waveNumber = raptorEventArgs.waveCount})
		messages[2] = textColor .. Spring.I18N('ui.raptors.airWave1')
		messages[3] = textColor .. Spring.I18N('ui.raptors.airWave2', {unitCount = raptorEventArgs.number})
	elseif raptorEventArgs.type == "wave" then
		messages[1] = textColor .. Spring.I18N('ui.raptors.wave1', {waveNumber = raptorEventArgs.waveCount})
		messages[2] = textColor .. Spring.I18N('ui.raptors.wave2', {unitCount = raptorEventArgs.number})
	elseif raptorEventArgs.type == "gracePeriodWarning" then
		-- New warning type for grace period
		messages[1] = "\255\255\200\1WARNING!"
		messages[2] = textColor .. raptorEventArgs.timeRemaining .. " remaining"
		messages[3] = textColor .. "in Grace Period"
		if raptorEventArgs.suggestion then
			messages[4] = "\255\255\150\200\1" .. raptorEventArgs.suggestion
		end
	elseif raptorEventArgs.type == "miniBossSpawn" then
		-- New warning type for mini bosses
		messages[1] = "\255\255\100\1ELITE RAPTOR DETECTED!"
		messages[2] = textColor .. raptorEventArgs.bossName
		messages[3] = "\255\255\50\1" .. raptorEventArgs.bossDescription
	end

	refreshMarqueeMessage = false

	return messages
end

local function getResistancesMessage()
	local messages = {}
	messages[1] = textColor .. Spring.I18N('ui.raptors.resistanceUnits', {count = nBosses})
	for i = 1,#resistancesTable do
		local attackerName = UnitDefs[resistancesTable[i]].name
		if UnitDefNames[attackerName].customParams.i18nfromunit then
			attackerName = UnitDefNames[attackerName].customParams.i18nfromunit
		end
		messages[i+1] = textColor .. Spring.I18N('units.names.' .. attackerName)
		currentlyResistantToNames[#currentlyResistantToNames+1] = Spring.I18N('units.names.' .. attackerName)
	end
	resistancesTable = {}

	refreshMarqueeMessage = false


	return messages
end

-- New function to check grace period warnings
local function checkGracePeriodWarnings()
	if not gameInfo or not enabled then
		return
	end
	
	local currentTime = GetGameSeconds()
	
	-- Only check during grace period
	if currentTime < gameInfo.raptorGracePeriod then
		local timeRemaining = gameInfo.raptorGracePeriod - currentTime
		
		-- Check each warning threshold
		for threshold, alreadyWarned in pairs(gracePeriodWarnings) do
			if not alreadyWarned and timeRemaining <= threshold and timeRemaining > (threshold - 5) then
				-- Mark this warning as shown
				gracePeriodWarnings[threshold] = true
				
				-- Create the warning message
				local minutes = math.floor(threshold / 60)
				local seconds = threshold % 60
				local timeText
				
				if minutes > 0 and seconds > 0 then
					timeText = minutes .. "m " .. seconds .. "s"
				elseif minutes > 0 then
					timeText = minutes .. " minute" .. (minutes > 1 and "s" or "")
				else
					timeText = seconds .. " seconds"
				end
				
				-- Add suggestions based on time remaining
				local suggestion = nil
				if threshold == 180 then
					suggestion = "Consider building walls!"
				elseif threshold == 60 then
					suggestion = "Build defenses, shields, anti-air, Dragon's Maw!"
				end
				
				-- Show the warning as a marquee message
				local warningArgs = {
					type = "gracePeriodWarning",
					timeRemaining = timeText,
					suggestion = suggestion
				}
				
				messageArgs = warningArgs
				showMarqueeMessage = true
				refreshMarqueeMessage = true
				waveTime = Spring.GetTimer()
			end
		end
	else
		-- Reset warnings when grace period ends (for potential restart scenarios)
		for threshold, _ in pairs(gracePeriodWarnings) do
			gracePeriodWarnings[threshold] = false
		end
	end
end

-- New function to check for mini boss spawns
local miniBossNames = {
	raptor_miniq_a = "Queenling Prima",
	raptor_miniq_b = "Queenling Secunda",
	raptor_miniq_c = "Queenling Tertia",
	raptor_mama_ba = "Matrona",
	raptor_mama_fi = "Pyro Matrona",
	raptor_mama_el = "Paralyzing Matrona",
	raptor_mama_ac = "Acid Matrona",
	raptor_consort = "Raptor Consort",
	raptor_doombringer = "Doombringer",
}

local miniBossDescriptions = {
	raptor_miniq_a = "Majestic and bold, ruler of the hunt.",
	raptor_miniq_b = "Swift and sharp, a noble among raptors.",
	raptor_miniq_c = "Refined tastes. Likes her prey rare.",
	raptor_mama_ba = "Claws charged with vengeance.",
	raptor_mama_fi = "A firestorm of maternal wrath.",
	raptor_mama_el = "Crackling with rage, ready to strike.",
	raptor_mama_ac = "Acid-fueled, melting everything in sight.",
	raptor_consort = "Sneaky powerful little terror.",
	raptor_doombringer = "Your time is up. The Queens called for backup.",
}

local function checkMiniBossSpawns()
	if not enabled then
		return
	end
	
	-- Get all raptor units
	local allUnits = Spring.GetTeamUnits(Spring.GetGaiaTeamID())
	
	for _, unitID in ipairs(allUnits) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if unitDefID then
			local unitDef = UnitDefs[unitDefID]
			local unitName = unitDef.name
			
			-- Check if this is a mini boss that hasn't been notified yet
			if miniBossNames[unitName] and not miniBossNotifications[unitName] then
				miniBossNotifications[unitName] = true
				
				-- Show the mini boss spawn message
				local bossArgs = {
					type = "miniBossSpawn",
					bossName = miniBossNames[unitName],
					bossDescription = miniBossDescriptions[unitName]
				}
				
				messageArgs = bossArgs
				showMarqueeMessage = true
				refreshMarqueeMessage = true
				waveTime = Spring.GetTimer()
				
				-- Only show one notification at a time
				break
			end
		end
	end
end

local function Draw()
	if not enabled or not gameInfo then
		return
	end

	if updatePanel then
		if (guiPanel) then
			gl.DeleteList(guiPanel);
			guiPanel = nil
		end
		guiPanel = gl.CreateList(CreatePanelDisplayList)
		updatePanel = false
	end

	if guiPanel then
		gl.CallList(guiPanel)
	end

	if showMarqueeMessage then
		local t = Spring.GetTimer()

		local waveY = viewSizeY - Spring.DiffTimers(t, waveTime) * waveSpeed * viewSizeY
		if waveY > 0 then
			if refreshMarqueeMessage or not marqueeMessage then
				marqueeMessage = getMarqueeMessage(messageArgs)
			end

			font2:Begin()
			for i, message in ipairs(marqueeMessage) do
				font2:Print(message, viewSizeX / 2, waveY - (WaveRow(i) * widgetScale), waveFontSize * widgetScale, "co")
			end
			font2:End()
		else
			showMarqueeMessage = false
			messageArgs = nil
			waveY = viewSizeY
		end
	elseif #resistancesTable > 0 then
		marqueeMessage = getResistancesMessage()
		waveTime = Spring.GetTimer()
		showMarqueeMessage = true
	end
end

local function UpdateRules()
	if not gameInfo then
		gameInfo = {}
	end

	for _, rule in ipairs(rules) do
		gameInfo[rule] = Spring.GetGameRulesParam(rule) or 0
	end
	gameInfo.raptorCounts = getRaptorCounts('Count')
	gameInfo.raptorKills = getRaptorCounts('Kills')

	updatePanel = true
end

function RaptorEvent(raptorEventArgs)
	if raptorEventArgs.type == "firstWave" or (raptorEventArgs.type == "queen" and Spring.DiffTimers(Spring.GetTimer(), bossToastTimer) > 10) then
		showMarqueeMessage = true
		refreshMarqueeMessage = true
		messageArgs = raptorEventArgs
		waveTime = Spring.GetTimer()
		if raptorEventArgs.type == "queen" then
			bossToastTimer = Spring.GetTimer()
		end
	end

	if raptorEventArgs.type == "queenResistance" then
		if raptorEventArgs.number then
			if not currentlyResistantTo[raptorEventArgs.number] then
				table.insert(resistancesTable, raptorEventArgs.number)
				currentlyResistantTo[raptorEventArgs.number] = true
			end
		end
	end

	if (raptorEventArgs.type == "wave" or raptorEventArgs.type == "airWave") and config.useWaveMsg and gameInfo.raptorQueenAnger <= 99 then
		waveCount = waveCount + 1
		raptorEventArgs.waveCount = waveCount
		showMarqueeMessage = true
		refreshMarqueeMessage = true
		messageArgs = raptorEventArgs
		waveTime = Spring.GetTimer()
	end
end

function widget:Initialize()
	widget:ViewResize()

	displayList = gl.CreateList(function()
		gl.Blending(true)
		gl.Color(1, 1, 1, 1)
		gl.Texture(panelTexture)
		gl.TexRect(0, 0, w, h)
	end)

	widgetHandler:RegisterGlobal("RaptorEvent", RaptorEvent)
	UpdateRules()
	viewSizeX, viewSizeY = gl.GetViewSizes()
	local x = math.abs(math.floor(viewSizeX - 320))
	local y = math.abs(math.floor(viewSizeY - 300))

	-- reposition if scavengers panel is shown as well
	if Spring.Utilities.Gametype.IsScavengers() then
		x = x - 315
	end

	updatePos(x, y)
end

function widget:Shutdown()
	if hasRaptorEvent then
		Spring.SendCommands({ "luarules HasRaptorEvent 0" })
	end

	if guiPanel then
		gl.DeleteList(guiPanel);
		guiPanel = nil
	end

	gl.DeleteList(displayList)
	gl.DeleteTexture(panelTexture)
	widgetHandler:DeregisterGlobal("RaptorEvent")
end

function widget:GameFrame(n)
	if not hasRaptorEvent and n > 1 then
		Spring.SendCommands({ "luarules HasRaptorEvent 1" })
		hasRaptorEvent = true
	end
	if n % 30 < 1 then
		UpdateRules()
		if not enabled and n > 1 then
			enabled = true
		end
		-- Check for grace period warnings every second (30 frames)
		checkGracePeriodWarnings()
		-- Check for mini boss spawns every second
		checkMiniBossSpawns()
	end
	if gotScore then
		local sDif = gotScore - scoreCount
		if sDif > 0 then
			scoreCount = scoreCount + math.ceil(sDif / 7.654321)
			if scoreCount > gotScore then
				scoreCount = gotScore
			else
				updatePanel = true
			end
		end
	end
end



function widget:DrawScreen()
	Draw()
end

function widget:MouseMove(x, y, dx, dy, button)
	if enabled and moving then
		updatePos(x1 + dx, y1 + dy)
	end
end

function widget:MousePress(x, y, button)
	if enabled and
		x > x1 and x < x1 + (w * widgetScale) and
		y > y1 and y < y1 + (h * widgetScale)
	then
		capture = true
		moving = true
	end
	return capture
end

function widget:MouseRelease(x, y, button)
	if not enabled then
		return
	end
	capture = nil
	moving = nil
	return capture
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()

	font = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(2)

	x1 = math.floor(x1 - viewSizeX)
	y1 = math.floor(y1 - viewSizeY)
	viewSizeX, viewSizeY = vsx, vsy
	widgetScale = (0.75 + (viewSizeX * viewSizeY / 10000000)) * customScale
	x1 = viewSizeX + x1 + ((x1 / 2) * (widgetScale - 1))
	y1 = viewSizeY + y1 + ((y1 / 2) * (widgetScale - 1))
end

function widget:LanguageChanged()
	refreshMarqueeMessage = true
	updatePanel = true
end
