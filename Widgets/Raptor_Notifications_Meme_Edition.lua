if not (Spring.Utilities.Gametype.IsRaptors() and not Spring.Utilities.Gametype.IsScavengers()) then
	return false
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Raptor Notifications - Meme Edition",
		desc = "Shows warnings for grace period and boss spawns with hilarious social media themed text",
		author = "Altwaal",
		date = "October 15, 2025",
		version = "1.0",
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
	[30] = false,   -- 30 seconds
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
		{"\255\255\50\1DELIVERY HAS ARRIVED!", "\255\255\100\50\1Raptors are at your doorstep", "\255\255\200\100\1You forgot to tip!"},
		{"\255\255\50\1LIVE STREAM STARTING!", "\255\255\100\50\1Raptors going live in 3...2...1...", "\255\255\200\100\1You're the main character!"},
		{"\255\255\50\1NOTIFICATION SPAM INCOMING!", "\255\255\100\50\11000 raptors are now following you", "\255\255\200\100\1Block button disabled!"},
		{"\255\255\50\1YOUR UBER HAS ARRIVED!", "\255\255\100\50\1Driver: Raptor Army", "\255\255\200\100\1Rating: 5 stars of death!"},
		{"\255\255\50\1RAID PARTY ASSEMBLED!", "\255\255\100\50\1Raptors joined the voice chat", "\255\255\200\100\1They're not here to talk!"},
		{"\255\255\50\1DOWNLOAD COMPLETE!", "\255\255\100\50\1Raptor.exe is now running", "\255\255\200\100\1Task Manager won't help!"},
		{"\255\255\50\1FRIEND REQUEST ACCEPTED!", "\255\255\100\50\11000 raptors added you", "\255\255\200\100\1Unfriend option unavailable!"},
		{"\255\255\50\1SUBSCRIPTION ACTIVATED!", "\255\255\100\50\1You're now subscribed to Raptor Pain", "\255\255\200\100\1Cancel anytime... if you survive!"},
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
		"Raptors just ordered takeout. Guess what's on the menu?",
		"Your WiFi password has been leaked to raptors!",
		"Raptors are checking your Yelp reviews... 1 star incoming!",
		"New calendar invite: Raptor Dinner Party at your base",
		"Raptors just RSVPed 'Yes' to destroying you!",
		"Raptors enabled location sharing for your base!",
		"You're in their Amazon cart. Free shipping!",
		"Raptors turned on auto-renewal for your destruction!",
		"New follower: Every single raptor!",
		"Raptors are writing a bad review... about YOU!",
	},
	fiveMinutes = {
		"Raptors just ordered express delivery to your coordinates!",
		"Your base is now in their shopping cart. Checkout soon!",
		"Raptors enabled same-day shipping!",
		"You're pinned on the raptor meal delivery app!",
		"New payment processed: Your base!",
		"Raptors left cart. Just kidding, they're coming!",
		"Order confirmed: 1 base, extra crispy!",
		"Tracking updated: Raptors are on the way!",
	},
	threeMinutes = {
		"Raptors are 3 minutes away according to Google Maps!",
		"ETA: 3 minutes. Raptors never late!",
		"Your base just got added to raptor bookmarks!",
		"Raptors turned on notifications for your destruction!",
		"Driver is approaching. Can't cancel now!",
		"Raptors shared your location with EVERYONE!",
		"3 minutes until your stream gets raided!",
		"Final countdown initiated. Thanks for subscribing!",
		"Last chance to hit that Block button... oh wait!",
		"Raptors sent you a meeting invite. Attendance: Mandatory!",
	},
	oneMinute = {
		"60 SECONDS! Raptors are at your street!",
		"FINAL WARNING: Delete system32? No? Raptors will!",
		"Your notification bell just exploded!",
		"Raptors are knocking. You can't decline this call!",
		"Last minute before your subscription expires... to life!",
		"Delivery driver texted: 'I'm here' - It's 1000 raptors!",
		"You've been tagged in 1000 posts. All bad news!",
		"Auto-play enabled: Raptor Attack Symphony!",
		"Pop-up blocker failed. Raptors incoming!",
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
			messages[2] = textColor .. raptorEventArgs.timeRemaining .. " remaining"
			messages[3] = textColor .. "Grace Period"
			if raptorEventArgs.suggestion then
				messages[4] = "\255\255\150\200\1" .. raptorEventArgs.suggestion
			end
		end
	elseif raptorEventArgs.type == "miniBossSpawn" then
		-- Check if it's a queenling for special VIP message
		local bossName = raptorEventArgs.bossName
		if string.find(bossName, "Queenling") then
			-- Random VIP variants
			local vipMessages = {
				{"\255\255\100\1INFLUENCER SPOTTED!", textColor .. raptorEventArgs.bossName .. " started a livestream!", "\255\255\50\1You're the content!"},
				{"\255\255\100\1VERIFIED ACCOUNT!", textColor .. raptorEventArgs.bossName .. " (Blue checkmark)", "\255\255\50\1Followed by 10 million raptors!"},
				{"\255\255\100\1CELEBRITY ALERT!", textColor .. raptorEventArgs.bossName .. " just landed!", "\255\255\50\1Paparazzi raptors incoming!"},
				{"\255\255\100\1VIP MEMBERSHIP ACTIVATED!", textColor .. raptorEventArgs.bossName .. " has premium access", "\255\255\50\1To your base!"},
				{"\255\255\100\1SPECIAL GUEST!", textColor .. raptorEventArgs.bossName .. " joined the party", "\255\255\50\1Party crasher deluxe!"},
			}
			local variant = vipMessages[math.random(1, #vipMessages)]
			messages[1] = variant[1]
			messages[2] = variant[2]
			messages[3] = variant[3]
		else
			-- Random elite raptor variants
			local eliteMessages = {
				{"\255\255\100\1BOSS FIGHT LOADING!", textColor .. raptorEventArgs.bossName, "\255\255\50\1Dark Souls difficulty: Enabled!"},
				{"\255\255\100\1PREMIUM SUBSCRIBER!", textColor .. raptorEventArgs.bossName .. " paid for express access", "\255\255\50\1No ads, just pain!"},
				{"\255\255\100\1NEW FOLLOWER!", textColor .. raptorEventArgs.bossName .. " is now stalking you", "\255\255\50\1Block button broken!"},
				{"\255\255\100\1SPECIAL DELIVERY!", textColor .. raptorEventArgs.bossName .. " (Signature required)", "\255\255\50\1Return to sender: Denied!"},
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
		return
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
					chatAdvice = "Start preparing defenses and build walls!"
				elseif threshold == 60 then
					chatAdvice = "Build defenses: AA, Dragon's Maw, shields!"
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
