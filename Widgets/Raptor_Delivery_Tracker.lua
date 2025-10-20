if not (Spring.Utilities.Gametype.IsRaptors() and not Spring.Utilities.Gametype.IsScavengers()) then
	return false
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Raptor_Delivery_Tracker",
		desc = "You're on the menu! Get notifications when raptors order delivery to your base",
		author = "Altwaal",
		date = "October 15, 2025",
		version = "2.3",
		license = "GNU GPL, v2 or later",
		layer = 5,
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
	[30] = false,   -- 30 seconds
	[0] = false,    -- Grace period ends
}

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

-- Track queen anger notifications
local queenAngerNotifications = {
	[53] = false,  -- Matronas pre-warning (2% before)
	[55] = false,  -- Matronas incoming
	[68] = false,  -- Queenling Prima pre-warning (2% before)
	[70] = false,  -- Queenling Prima incoming
	[88] = false,  -- Queenling Secunda pre-warning (2% before)
	[90] = false,  -- Queenling Secunda incoming
	[108] = false, -- Queenling Tertia pre-warning (2% before)
	[110] = false, -- Queenling Tertia incoming
	[98] = false,  -- Queen pre-warning (2% before)
	[100] = false, -- Queen spawning soon
}

-- Sound files
local sounds = {
	gracePeriod = "sounds/ui/mappoint2.wav",
	miniBoss = "sounds/ui/mappoint2.wav",
	queenAnger = "sounds/ui/mappoint2.wav",
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
		},
		{
			"\255\255\50\1DELIVERY HAS ARRIVED!",
			"\255\255\100\50\1Raptors are at your doorstep",
			"\255\255\200\100\1You forgot to tip!"
		},
		{
			"\255\255\50\1LIVE STREAM STARTING!",
			"\255\255\100\50\1Raptors going live in 3...2...1...",
			"\255\255\200\100\1You're the main character!"
		},
		{
			"\255\255\50\1NOTIFICATION SPAM INCOMING!",
			"\255\255\100\50\11000 raptors are now following you",
			"\255\255\200\100\1Block button disabled!"
		},
		{
			"\255\255\50\1YOUR UBER HAS ARRIVED!",
			"\255\255\100\50\1Driver: Raptor Army",
			"\255\255\200\100\1Rating: 5 stars of death!"
		},
	},
	twelveMinutes = {
		"Raptors just tagged you on Facebook!",
		"You've been added to the raptor hunting party group chat!",
		"Raptors are dropping pins on your location!",
		"Your base just got 5 stars on Raptor Yelp!",
		"Raptors swiped right on your base!",
		"New notification: 1000 raptors interested in your location!",
		"Raptors shared your post in 47 groups!",
		"Your base is trending on Raptor Reddit!",
		"Raptors just bookmarked your coordinates!",
		"You got a Super Like from the Raptor Queen!",
	},
	elevenMinutes = {
		"Raptors are calling an Uber... to YOUR base!",
		"Your address just went viral on raptor TikTok!",
		"Raptors added your base to Google Maps favorites!",
		"New friend request from: Raptor Army (1000 mutual friends)",
		"Raptors are livestreaming the attack prep!",
		"You're trending #1 on Raptor Twitter!",
		"Raptors enabled push notifications for your base!",
		"Your WiFi signal detected by raptor GPS!",
		"Raptors just subscribed to your channel... of doom!",
		"Breaking: You're viral on Raptor Instagram!",
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
		"Better start cooking... before YOU'RE the meal!",
		"Raptors just ordered takeout. Guess what's on the menu?",
		"Your WiFi password has been leaked to raptors!",
		"New calendar invite: Raptor Dinner Party at your base",
		"Raptors just RSVPed 'Yes' to destroying you!",
	},
	fiveMinutes = {
		"Time to get serious!",
		"Raptors are doing stretches!",
		"They smell weakness... or is that you?",
		"Cook or be cooked - your choice!",
		"Raptors voted: Your base looks tasty!",
		"5 minutes to show what you're made of!",
		"Are you the chef or the ingredient?",
		"Dinner bells are about to ring!",
		"Raptors just ordered express delivery to your coordinates!",
		"You're pinned on the raptor meal delivery app!",
		"Order confirmed: 1 base, extra crispy!",
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
		"Reservation for 1000 confirmed. Table: Your base!",
		"Raptors are 3 minutes away according to Google Maps!",
		"ETA: 3 minutes. Raptors never late!",
		"Driver is approaching. Can't cancel now!",
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
		"They're bringing the hot sauce! BUILD EVERYTHING!",
		"60 SECONDS! Raptors are at your street!",
		"Your notification bell just exploded!",
		"Raptors are knocking. You can't decline this call!",
		"Delivery driver texted: 'I'm here' - It's 1000 raptors!",
	},
	thirtySeconds = {
		"30 SECONDS! They're in your driveway!",
		"DOORBELL RANG! It's not Amazon...",
		"Raptors bypassed your firewall!",
		"Connection established. Raptors.exe loading...",
		"Final boss music started playing!",
		"You have 1 new voicemail: ROAAAAR!",
		"Raptors just entered your ZIP code!",
		"System alert: Raptors detected at front door!",
	},
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
			messages[2] = textColor .. raptorEventArgs.timeRemaining
			messages[3] = textColor .. "Remaining"
			if raptorEventArgs.suggestion then
				messages[4] = "\255\255\150\200\1" .. raptorEventArgs.suggestion
			end
		end
	elseif raptorEventArgs.type == "queenAnger" then
		-- Queen anger threshold warnings
		messages[1] = "\255\255\200\50\1" .. raptorEventArgs.title
		messages[2] = "\255\255\255\100\1" .. raptorEventArgs.message
		if raptorEventArgs.subtitle then
			messages[3] = "\255\255\150\100\1" .. raptorEventArgs.subtitle
		end
	elseif raptorEventArgs.type == "miniBossSpawn" then
		-- Check if it's a queenling for special VIP message
		local bossName = raptorEventArgs.bossName
		if string.find(bossName, "Queenling") then
			-- Random VIP variants
			local vipMessages = {
				{"\255\255\100\1VIP GUESTS HAVE ARRIVED!", textColor .. raptorEventArgs.bossName, "\255\255\50\1" .. raptorEventArgs.bossDescription},
				{"\255\255\100\1BORDER ALERT!", textColor .. raptorEventArgs.bossName .. " has crossed the border!", "\255\255\50\1Secure your perimeter!"},
				{"\255\255\100\1ILLEGAL ALIEN DETECTED!", textColor .. "Unauthorized entry: " .. raptorEventArgs.bossName, "\255\255\50\1No passport, no problem... for them!"},
				{"\255\255\100\1IMMIGRATION VIOLATION!", textColor .. raptorEventArgs.bossName .. " bypassed customs!", "\255\255\50\1Build that wall!"},
				{"\255\255\100\1RAPTOR ROYALTY INCOMING!", textColor .. raptorEventArgs.bossName .. " doesn't need a visa", "\255\255\50\1" .. raptorEventArgs.bossDescription},
				{"\255\255\100\1INFLUENCER SPOTTED!", textColor .. raptorEventArgs.bossName .. " started a livestream!", "\255\255\50\1You're the content!"},
				{"\255\255\100\1VERIFIED ACCOUNT!", textColor .. raptorEventArgs.bossName .. " (Blue checkmark)", "\255\255\50\1Followed by 10 million raptors!"},
				{"\255\255\100\1CELEBRITY ALERT!", textColor .. raptorEventArgs.bossName .. " just landed!", "\255\255\50\1Paparazzi raptors incoming!"},
			}
			local variant = vipMessages[math.random(1, #vipMessages)]
			messages[1] = variant[1]
			messages[2] = variant[2]
			messages[3] = variant[3]
		else
			-- Random elite raptor variants
			local eliteMessages = {
				{"\255\255\100\1ELITE RAPTOR DETECTED!", textColor .. raptorEventArgs.bossName, "\255\255\50\1" .. raptorEventArgs.bossDescription},
				{"\255\255\100\1SPECIAL DELIVERY!", textColor .. raptorEventArgs.bossName .. " has arrived", "\255\255\50\1Return to sender not available!"},
				{"\255\255\100\1BORDER BREACH!", textColor .. raptorEventArgs.bossName .. " has entered illegally!", "\255\255\50\1Where's border patrol?"},
				{"\255\255\100\1UNAUTHORIZED ENTRY!", textColor .. "Illegal immigrant: " .. raptorEventArgs.bossName, "\255\255\50\1No documentation required!"},
				{"\255\255\100\1THE BOSS HAS ARRIVED!", textColor .. raptorEventArgs.bossName, "\255\255\50\1" .. raptorEventArgs.bossDescription},
				{"\255\255\100\1BOSS FIGHT LOADING!", textColor .. raptorEventArgs.bossName, "\255\255\50\1Dark Souls difficulty: Enabled!"},
				{"\255\255\100\1DLC UNLOCKED!", textColor .. raptorEventArgs.bossName .. " - Extra Hard Mode", "\255\255\50\1No refunds!"},
			}
			local variant = eliteMessages[math.random(1, #eliteMessages)]
			messages[1] = variant[1]
			messages[2] = variant[2]
			messages[3] = variant[3]
		end
	end

	refreshMarqueeMessage = false
	return messages
end

local function checkGracePeriodWarnings()
	if not enabled or not gameInfo then
		return
	end
	
	local currentTime = GetGameSeconds()
	
	-- Check if grace period just ended
	if currentTime >= gameInfo.raptorGracePeriod and not gracePeriodWarnings[0] then
		gracePeriodWarnings[0] = true
		
		-- Show TIME TO COOK message
		messageArgs = {
			type = "gracePeriodWarning",
			timeRemaining = "0",
			suggestion = nil,
			timeToCook = true
		}
		
		showMarqueeMessage = true
		refreshMarqueeMessage = true
		waveTime = Spring.GetTimer()
		
		-- Play warning sound
		Spring.PlaySoundFile(sounds.gracePeriod, 0.8, 'ui')
		
		-- Send notification to chat
		Spring.Echo("\255\255\50\1RAPTORS INCOMING! \255\255\255\1Grace period has ended!")
		-- Don't return here! Let other notifications continue
	end
	
	-- Only check during grace period
	if currentTime < gameInfo.raptorGracePeriod then
		local timeRemaining = gameInfo.raptorGracePeriod - currentTime
		
		-- Check each warning threshold
		for threshold, alreadyWarned in pairs(gracePeriodWarnings) do
			if threshold > 0 and not alreadyWarned and timeRemaining <= threshold and timeRemaining > (threshold - 5) then
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
				
				-- Pick random variant based on time
				local suggestion = nil
				if threshold == 720 then
					local variants = messageVariants.twelveMinutes
					suggestion = variants[math.random(1, #variants)]
				elseif threshold == 660 then
					local variants = messageVariants.elevenMinutes
					suggestion = variants[math.random(1, #variants)]
				elseif threshold == 360 then
					local variants = messageVariants.sixMinutes
					suggestion = variants[math.random(1, #variants)]
				elseif threshold == 300 then
					local variants = messageVariants.fiveMinutes
					suggestion = variants[math.random(1, #variants)]
				elseif threshold == 180 then
					local variants = messageVariants.threeMinutes
					suggestion = variants[math.random(1, #variants)]
				elseif threshold == 60 then
					local variants = messageVariants.oneMinute
					suggestion = variants[math.random(1, #variants)]
				elseif threshold == 30 then
					local variants = messageVariants.thirtySeconds
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
					chatAdvice = "TIER 2 WALLS UP! Tier 1 walls are raptor desserts!"
				elseif threshold == 60 then
					chatAdvice = "Build AA, Dragon's Maw (Cortex), and shields NOW!"
				elseif threshold == 300 then
					chatAdvice = "Get ready - plan your defense strategy!"
				elseif threshold == 360 then
					chatAdvice = "Time to plan your defense!"
				elseif threshold == 30 then
					chatAdvice = "FINAL SECONDS! GET READY!"
				end
				
				if chatAdvice ~= "" then
					Spring.Echo("\255\255\200\1Warning: \255\255\255\1" .. timeText .. " remaining - \255\255\150\200\1" .. chatAdvice)
				else
					Spring.Echo("\255\255\200\1Warning: \255\255\255\1" .. timeText .. " remaining!")
				end
			end
		end
	else
		-- Reset warnings when grace period ends (except the 0 marker)
		for threshold, _ in pairs(gracePeriodWarnings) do
			if threshold > 0 then
				gracePeriodWarnings[threshold] = false
			end
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
	if not gameInfo then
		gameInfo = {}
	end

	gameInfo.raptorGracePeriod = Spring.GetGameRulesParam("raptorGracePeriod") or 0
	gameInfo.raptorQueenAnger = Spring.GetGameRulesParam("raptorQueenAnger") or 0
	gameInfo.raptorTechAnger = Spring.GetGameRulesParam("raptorTechAnger") or 0
end

local function checkQueenAngerWarnings()
	if not enabled or not gameInfo then
		return
	end
	
	-- Use TechAnger instead of QueenAnger for boss spawns!
	local currentAnger = gameInfo.raptorTechAnger
	
	-- Check each anger threshold
	for threshold, alreadyWarned in pairs(queenAngerNotifications) do
		if not alreadyWarned and currentAnger >= threshold then
			queenAngerNotifications[threshold] = true
			
			local warningArgs
			if threshold == 53 then
				local preWarnings = {
					{title = "RESTAURANT RESERVATION CONFIRMED!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Matronas around the corner!"},
					{title = "DELIVERY DRIVERS EN ROUTE!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Elite Matriarchs taking last turn!"},
					{title = "YOUR FOOD IS BEING PREPARED!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Kitchen staff almost here!"},
					{title = "UBER DRIVER 2 MINUTES AWAY!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Better tip well!"},
				}
				local variant = preWarnings[math.random(1, #preWarnings)]
				warningArgs = {type = "queenAnger", title = variant.title, message = variant.message, subtitle = variant.subtitle}
			elseif threshold == 55 then
				warningArgs = {
					type = "queenAnger",
					title = "MATRONAS INCOMING!",
					message = "Evolution: " .. math.floor(currentAnger) .. "%",
					subtitle = "Elite Matriarch raptors are spawning!"
				}
			elseif threshold == 68 then
				local preWarnings = {
					{title = "VIP GUESTS ON THE WAY!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Queenling Prima around the corner!"},
					{title = "RED CARPET BEING ROLLED OUT!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "First royal guest at your street!"},
					{title = "PRIVATE JET LANDING SOON!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Elite passenger descending!"},
					{title = "LIMO SERVICE DISPATCHED!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Premium delivery pulling up!"},
					{title = "GPS SAYS YOU'RE NEXT STOP!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Driver making last turn!"},
				}
				local variant = preWarnings[math.random(1, #preWarnings)]
				warningArgs = {type = "queenAnger", title = variant.title, message = variant.message, subtitle = variant.subtitle}
			elseif threshold == 70 then
				local spawnMessages = {
					{title = "QUEENLING PRIMA ALERT!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "First royal raptor is coming!"},
					{title = "VIP HAS ARRIVED!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Prima is checking in!"},
					{title = "INFLUENCER JUST LANDED!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "10 million followers incoming!"},
				}
				local variant = spawnMessages[math.random(1, #spawnMessages)]
				warningArgs = {type = "queenAnger", title = variant.title, message = variant.message, subtitle = variant.subtitle}
			elseif threshold == 88 then
				local preWarnings = {
					{title = "SECOND VIP GUEST ON THE WAY!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Queenling Secunda almost here!"},
					{title = "ANOTHER RESERVATION CONFIRMED!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Table ready, guest at door!"},
					{title = "PRIORITY SHIPPING ACTIVE!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Express delivery on your street!"},
					{title = "CELEBRITY #2 EN ROUTE!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Paparazzi swarming your base!"},
					{title = "SECOND UBER ARRIVING!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Driver is circling the block!"},
				}
				local variant = preWarnings[math.random(1, #preWarnings)]
				warningArgs = {type = "queenAnger", title = variant.title, message = variant.message, subtitle = variant.subtitle}
			elseif threshold == 90 then
				local spawnMessages = {
					{title = "QUEENLING SECUNDA ALERT!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Second royal raptor is coming!"},
					{title = "DOUBLE VIP BOOKING!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Secunda has entered the chat!"},
					{title = "PREMIUM MEMBERSHIP ACTIVATED!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Elite customer #2!"},
				}
				local variant = spawnMessages[math.random(1, #spawnMessages)]
				warningArgs = {type = "queenAnger", title = variant.title, message = variant.message, subtitle = variant.subtitle}
			elseif threshold == 108 then
				local preWarnings = {
					{title = "FINAL VIP ON THE WAY!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Queenling Tertia turning the corner!"},
					{title = "TRIPLE THREAT INCOMING!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Last royal at your doorstep!"},
					{title = "EXCLUSIVE RESERVATION!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Tertia pulling into driveway!"},
					{title = "LUXURY PACKAGE DELIVERED!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Premium service knocking!"},
					{title = "FINAL DELIVERY INCOMING!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Can you hear the footsteps?"},
				}
				local variant = preWarnings[math.random(1, #preWarnings)]
				warningArgs = {type = "queenAnger", title = variant.title, message = variant.message, subtitle = variant.subtitle}
			elseif threshold == 110 then
				local spawnMessages = {
					{title = "QUEENLING TERTIA ALERT!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "Third royal raptor is coming!"},
					{title = "TRIPLE VIP COMPLETE!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "All royalty has arrived!"},
					{title = "FINAL BOSS UNLOCKED!", message = "Evolution: " .. math.floor(currentAnger) .. "%", subtitle = "DLC complete!"},
				}
				local variant = spawnMessages[math.random(1, #spawnMessages)]
				warningArgs = {type = "queenAnger", title = variant.title, message = variant.message, subtitle = variant.subtitle}
			elseif threshold == 98 then
				local preWarnings = {
					{title = "THE QUEEN IS WAKING UP!", message = "Queen Anger: " .. math.floor(gameInfo.raptorQueenAnger) .. "%", subtitle = "Final boss almost awake!"},
					{title = "BOSS FIGHT LOADING...", message = "Queen Anger: " .. math.floor(gameInfo.raptorQueenAnger) .. "%", subtitle = "Health bar appearing!"},
					{title = "FINAL WARNING!", message = "Queen Anger: " .. math.floor(gameInfo.raptorQueenAnger) .. "%", subtitle = "The Queen is stirring!"},
					{title = "SHE'S COMING!", message = "Queen Anger: " .. math.floor(gameInfo.raptorQueenAnger) .. "%", subtitle = "Ground is shaking!"},
					{title = "EARTHQUAKE DETECTED!", message = "Queen Anger: " .. math.floor(gameInfo.raptorQueenAnger) .. "%", subtitle = "Something big approaches!"},
				}
				local variant = preWarnings[math.random(1, #preWarnings)]
				warningArgs = {type = "queenAnger", title = variant.title, message = variant.message, subtitle = variant.subtitle}
			elseif threshold == 100 then
				local spawnMessages = {
					{title = "QUEEN IS SPAWNING!", message = "Queen Anger: " .. math.floor(gameInfo.raptorQueenAnger) .. "%", subtitle = "The final boss approaches!"},
					{title = "FINAL BOSS HAS ARRIVED!", message = "Queen Anger: " .. math.floor(gameInfo.raptorQueenAnger) .. "%", subtitle = "Good luck!"},
					{title = "THE QUEEN AWAKENS!", message = "Queen Anger: " .. math.floor(gameInfo.raptorQueenAnger) .. "%", subtitle = "This is it!"},
					{title = "ENDGAME ACTIVATED!", message = "Queen Anger: " .. math.floor(gameInfo.raptorQueenAnger) .. "%", subtitle = "Show her what you've got!"},
				}
				local variant = spawnMessages[math.random(1, #spawnMessages)]
				warningArgs = {type = "queenAnger", title = variant.title, message = variant.message, subtitle = variant.subtitle}
			end
			
			if warningArgs then
				messageArgs = warningArgs
				showMarqueeMessage = true
				refreshMarqueeMessage = true
				waveTime = Spring.GetTimer()
				
				-- Play warning sound
				Spring.PlaySoundFile(sounds.queenAnger, 0.8, 'ui')
				
				-- Send notification to chat
				Spring.Echo("\255\255\200\50\1" .. warningArgs.title)
			end
		end
	end
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
	
	-- Register to intercept RaptorEvent before other widgets
	widgetHandler:RegisterGlobal("RaptorEvent", RaptorEvent)
end

function RaptorEvent(raptorEventArgs)
	-- Intercept and suppress wave notifications from original widget
	-- Only allow queen and boss events through
	if raptorEventArgs.type == "wave" or raptorEventArgs.type == "airWave" or raptorEventArgs.type == "firstWave" then
		-- Suppress these - don't show wave notifications
		return true  -- Event handled, don't pass to other widgets
	end
	-- Let other events (queen, resistance) pass through
	return false
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("RaptorEvent")
end

function widget:GameFrame(n)
	if n % 30 < 1 then
		UpdateRules()
		if not enabled and n > 1 then
			enabled = true
		end
		-- Check for warnings every second
		checkGracePeriodWarnings()
		checkQueenAngerWarnings()
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
