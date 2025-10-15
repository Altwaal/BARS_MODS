if not (Spring.Utilities.Gametype.IsRaptors() and not Spring.Utilities.Gametype.IsScavengers()) then
	return false
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Raptor Notifications",
		desc = "Shows warnings for grace period and boss spawns with big scrolling text",
		author = "Altwaal",
		date = "October 15, 2025",
		license = "GNU GPL, v2 or later",
		layer = -8,
		enabled = true
	}
end

if not Spring.Utilities.Gametype.IsRaptors() then
	return false
end

if not Spring.GetGameRulesParam("raptorDifficulty") then
	return false
end

local GetGameSeconds = Spring.GetGameSeconds

local font2
local messageArgs, marqueeMessage
local refreshMarqueeMessage = false
local showMarqueeMessage = false

-- Grace period warnings
local gracePeriodWarnings = {
	[720] = false,  -- 12 minutes
	[660] = false,  -- 11 minutes
	[360] = false,  -- 6 minutes
	[300] = false,  -- 5 minutes
	[180] = false,  -- 3 minutes
	[60] = false,   -- 1 minute
	[0] = false,    -- Grace period ends
}

-- Track mini boss spawns
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

-- Sound files
local sounds = {
	gracePeriod = "sounds/reply/warning-critical.wav",
	miniBoss = "sounds/reply/alert-response.wav",
}

local vsx, vsy = Spring.GetViewGeometry()
local viewSizeX, viewSizeY = 0, 0
local waveFontSize = 36
local waveSpacingY = 7
local waveSpeed = 0.1
local waveTime
local enabled = false
local nBosses = Spring.GetModOptions().raptor_queen_count or 1

local textColor = "\255\255\255\255"

-- Random message variants for different notifications
local messageVariants = {
	timeToCook = {
		{
			"\255\255\50\1TIME TO COOK!",
			"\255\255\100\50\1Grace Period Over",
			"\255\255\200\100\1Prepare for Battle!"
		},
		{
			"\255\255\50\1LET'S GOOOOO!",
			"\255\255\100\50\1Grace Period Ended",
			"\255\255\200\100\1Show them what you've got!"
		},
		{
			"\255\255\50\1HERE THEY COME!",
			"\255\255\100\50\1No more safety",
			"\255\255\200\100\1Fight for survival!"
		},
		{
			"\255\255\50\1GAME ON!",
			"\255\255\100\50\1The hunt begins",
			"\255\255\200\100\1Time to shine!"
		},
		{
			"\255\255\50\1SHOWTIME!",
			"\255\255\100\50\1Raptors are coming",
			"\255\255\200\100\1Make every shot count!"
		},
		{
			"\255\255\50\1DINNER TIME!",
			"\255\255\100\50\1Raptors are sharpening their forks",
			"\255\255\200\100\1You're on the menu!"
		},
		{
			"\255\255\50\1CHEF RAPTOR IS READY!",
			"\255\255\100\50\1The boiling pot is waiting",
			"\255\255\200\100\1Commander soup is on special!"
		},
		{
			"\255\255\50\1BREAKFAST IS SERVED!",
			"\255\255\100\50\1Raptors want their energy",
			"\255\255\200\100\1Your metal looks delicious!"
		},
		{
			"\255\255\50\1HUNGRY HUNGRY RAPTORS!",
			"\255\255\100\50\1They've been fasting",
			"\255\255\200\100\1Time for the feast!"
		},
		{
			"\255\255\50\1RESTAURANT IS OPEN!",
			"\255\255\100\50\1Table for 1000 raptors",
			"\255\255\200\100\1Hope you made reservations!"
		},
		{
			"\255\255\50\1COOKING SHOW STARTS NOW!",
			"\255\255\100\50\1Today's recipe: Grilled Commander",
			"\255\255\200\100\1Season with lasers!"
		},
		{
			"\255\255\50\1ALL YOU CAN EAT!",
			"\255\255\100\50\1Raptor buffet is open",
			"\255\255\200\100\1Your base is the menu!"
		}
	},
	threeMinutes = {
		"Consider building walls!",
		"Wall up now before it's too late!",
		"Time to secure your perimeter!",
		"Defense time - build those walls!",
		"Raptors are checking their GPS to your base!",
		"They're doing warmup exercises... BUILD WALLS!",
		"Raptors are putting on their napkins!",
		"They're marinating the sauce... you're the main course!",
		"Raptors just left a 5-star review for your base!",
		"Restaurant opening in 3 minutes - Are YOU the menu?",
		"Who will be on the menu first?",
		"Raptors are reading the menu... it's YOU!",
		"Chef Raptor: '3 minutes until dinner service!'",
		"Reservation for 1000 confirmed. Table: Your base!"
	},
	sixMinutes = {
		"Raptors are getting hungry...",
		"They're writing the menu. Guess who's on it?",
		"Raptor chefs are preheating the ovens!",
		"Kitchen staff meeting in progress!",
		"Raptors putting on their chef hats!",
		"Someone just ordered 'Commander Flambé'!",
		"Raptors checking their recipe books...",
		"The appetizer arrives in 6 minutes. You're the main course!",
		"Are you ready to COOK or BE COOKED?",
		"Raptors are sharpening their claws and knives!",
		"Better start cooking... before YOU'RE the meal!"
	},
	fiveMinutes = {
		"Time to get serious!",
		"Raptors are doing stretches!",
		"They smell weakness... or is that you?",
		"Cook or be cooked - your choice!",
		"Raptors voted: Your base looks tasty!",
		"5 minutes to show what you're made of!",
		"Are you the chef or the ingredient?",
		"Dinner bells are about to ring!"
	},
	twelveMinutes = {
		"Raptors woke up hungry today!",
		"Morning coffee for raptors = YOUR METAL!",
		"They're planning the attack... and the menu!",
		"Raptor breakfast shift just started!",
		"Someone call Gordon Ramsay Raptor!",
		"Will you cook them or will they cook you?",
		"Early bird gets the worm. Early raptor gets YOU!",
		"Raptors are meal prepping... guess the meal?"
	},
	elevenMinutes = {
		"Raptors just checked the forecast: Cloudy with a chance of YOU!",
		"They're making a grocery list. You're on it!",
		"Raptor Uber Eats delivery time: 11 minutes!",
		"Better hurry - they're getting impatient!",
		"Cook or be cooked? Clock's ticking!",
		"Raptors are leaving their cave. Hungry!",
		"Someone left a bad Yelp review... time for revenge!",
		"Your coordinates have been shared in raptor group chat!"
	},
	oneMinute = {
		"Build defenses, shields, anti-air, Dragon's Maw!",
		"Last chance for defenses! AA, shields, Dragon's Maw!",
		"Final preparations! Get those defenses up!",
		"Build everything NOW! Shields, AA, turrets!",
		"Raptors are licking their lips! BUILD DEFENSES!",
		"They can smell your metal from here! DEFENSES NOW!",
		"Raptors are setting the table! PANIC BUILD!",
		"Chef Raptor says you're almost ready! SHIELDS UP!",
		"They're bringing the hot sauce! BUILD EVERYTHING!"
	}
}

local gameInfo = {}

local function WaveRow(n)
	return n * (waveFontSize + waveSpacingY)
end

-- Mini boss data
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

local function getMarqueeMessage(raptorEventArgs)
	local messages = {}
	
	if raptorEventArgs.type == "gracePeriodWarning" then
		if raptorEventArgs.timeToCook then
			-- Pick a random "Time to Cook" variant
			local variants = messageVariants.timeToCook
			local randomVariant = variants[math.random(1, #variants)]
			messages[1] = randomVariant[1]
			messages[2] = randomVariant[2]
			messages[3] = randomVariant[3]
		else
			messages[1] = "\255\255\200\1WARNING!"
			messages[2] = textColor .. raptorEventArgs.timeRemaining .. " remaining"
			messages[3] = textColor .. "in Grace Period"
			if raptorEventArgs.suggestion then
				messages[4] = "\255\255\150\200\1" .. raptorEventArgs.suggestion
			end
		end
	elseif raptorEventArgs.type == "miniBossSpawn" then
		messages[1] = "\255\255\100\1ELITE RAPTOR DETECTED!"
		messages[2] = textColor .. raptorEventArgs.bossName
		messages[3] = "\255\255\50\1" .. raptorEventArgs.bossDescription
	end

	refreshMarqueeMessage = false
	return messages
end

local function checkGracePeriodWarnings()
	if not enabled or not gameInfo then
		return
	end
	
	local currentTime = GetGameSeconds()
	
	-- Only check during grace period
	if currentTime < gameInfo.raptorGracePeriod then
		local timeRemaining = gameInfo.raptorGracePeriod - currentTime
		
		-- Check each warning threshold
		for threshold, alreadyWarned in pairs(gracePeriodWarnings) do
			if not alreadyWarned and timeRemaining <= threshold and timeRemaining > (threshold - 5) then
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
				if threshold == 720 then
					-- Pick random 12-minute variant
					local variants = messageVariants.twelveMinutes
					suggestion = variants[math.random(1, #variants)]
				elseif threshold == 660 then
					-- Pick random 11-minute variant
					local variants = messageVariants.elevenMinutes
					suggestion = variants[math.random(1, #variants)]
				elseif threshold == 360 then
					-- Pick random 6-minute variant
					local variants = messageVariants.sixMinutes
					suggestion = variants[math.random(1, #variants)]
				elseif threshold == 300 then
					-- Pick random 5-minute variant
					local variants = messageVariants.fiveMinutes
					suggestion = variants[math.random(1, #variants)]
				elseif threshold == 180 then
					-- Pick random 3-minute variant
					local variants = messageVariants.threeMinutes
					suggestion = variants[math.random(1, #variants)]
				elseif threshold == 60 then
					-- Pick random 1-minute variant
					local variants = messageVariants.oneMinute
					suggestion = variants[math.random(1, #variants)]
				end
				
				-- Show the warning
				messageArgs = {
					type = "gracePeriodWarning",
					timeRemaining = timeText,
					suggestion = suggestion
				}
				
				showMarqueeMessage = true
				refreshMarqueeMessage = true
				waveTime = Spring.GetTimer()
				
				-- Play warning sound
				Spring.PlaySoundFile(sounds.gracePeriod, 0.8, 'ui')
				
				-- Also send notification to chat with proper advice
				local chatAdvice = ""
				if threshold == 180 then
					chatAdvice = "Build walls now!"
				elseif threshold == 60 then
					chatAdvice = "Build defenses: AA, Dragon's Maw, shields!"
				elseif threshold == 300 then
					chatAdvice = "Start preparing defenses!"
				elseif threshold == 360 then
					chatAdvice = "Time to plan your defense!"
				end
				
				if chatAdvice ~= "" then
					Spring.Echo("\255\255\200\1Warning: \255\255\255\1" .. timeText .. " remaining - \255\255\150\200\1" .. chatAdvice)
				else
					Spring.Echo("\255\255\200\1Warning: \255\255\255\1" .. timeText .. " remaining in grace period!")
				end
			end
		end
	else
		-- Reset warnings when grace period ends
		for threshold, _ in pairs(gracePeriodWarnings) do
			gracePeriodWarnings[threshold] = false
		end
	end
end

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
				messageArgs = {
					type = "miniBossSpawn",
					bossName = miniBossNames[unitName],
					bossDescription = miniBossDescriptions[unitName]
				}
				
				showMarqueeMessage = true
				refreshMarqueeMessage = true
				waveTime = Spring.GetTimer()
				
				-- Play elite raptor sound
				Spring.PlaySoundFile(sounds.miniBoss, 0.8, 'ui')
				
				-- Send notification to chat
				Spring.Echo("\255\255\100\1Elite Raptor: \255\255\255\1" .. miniBossNames[unitName] .. " has spawned!")
				
				-- Only show one notification at a time
				break
			end
		end
	end
end

local function UpdateRules()
	gameInfo.raptorGracePeriod = Spring.GetGameRulesParam("raptorGracePeriod") or 0
end

local function Draw()
	if not enabled then
		return
	end

	if showMarqueeMessage then
		local t = Spring.GetTimer()
		local widgetScale = (0.75 + (viewSizeX * viewSizeY / 10000000))
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
	end
end

function widget:Initialize()
	widget:ViewResize()
	UpdateRules()
	viewSizeX, viewSizeY = gl.GetViewSizes()
end

function widget:Shutdown()
	-- Cleanup
end

function widget:GameFrame(n)
	if n % 30 < 1 then
		UpdateRules()
		if not enabled and n > 1 then
			enabled = true
		end
		-- Check for warnings every second
		checkGracePeriodWarnings()
		checkMiniBossSpawns()
	end
end

function widget:DrawScreen()
	Draw()
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	font2 = WG['fonts'].getFont(2)
	viewSizeX, viewSizeY = vsx, vsy
end

function widget:LanguageChanged()
	refreshMarqueeMessage = true
end
