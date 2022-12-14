require([[/script/multiplayer/bot.data]])
require([[/script/multiplayer/bot.wave_system]])

local squadDictionary = {}
local qauntSquadOrderDelay = 180
local nextQuantSquadOrderTime = 0
local emplacementArtillery = {}
local IsHeavyArty = false
local heavyArtyCounter = 0
local artyOrderRotationPeriod = 60 * 500
local totalFlags = 0
local followCustomMapWaypointGraph = true
local flagNamesGreaterThan10 = {}

local Context = {
	Purchase = nil,
	SpawnInfo = nil,
	SpawnWait = {
		CooldownTimer = nil,
		WaitTimer = nil
	},
	SquadTimers = {},
	IsHeavyArty = false
}

function SetSpawnCooldownTimer()
	Context.SpawnWait.CooldownTimer = BotApi.Events:SetQuantTimer(
		function()
			Context.SpawnWait.CooldownTimer = nil
		end,
		math.random(SpawnCooldownTime.Min, SpawnCooldownTime.Max))
end

function KillSpawnCooldownTimer()
	if Context.SpawnWait.CooldownTimer then
		BotApi.Events:KillQuantTimer(Context.SpawnWait.CooldownTimer)
		Context.SpawnWait.CooldownTimer = nil
	end
end

function KillSpawnWaitTimer()
	if Context.SpawnWait.WaitTimer then
		BotApi.Events:KillQuantTimer(Context.SpawnWait.WaitTimer)
		Context.SpawnWait.WaitTimer = nil
	end
end

function GetRandomItem(items, getRate)
	local item_rates = {}
	
	local total = 0
	for i, item in pairs(items) do
		local rate = getRate(item)
		total = total + rate
		table.insert(item_rates, {i = item, r = rate})
	end
	
	local rnd = math.random()
	local bound = 0.0
	
	for j, item_rate in pairs(item_rates) do
		bound = bound + item_rate.r	
		if rnd < bound / total then
			return item_rate.i
		end
	end
end

function IsCapturedFlag(flag)
	return flag.occupant == BotApi.Instance.team
end

function IsEnemyFlag(flag)
	return flag.occupant == BotApi.Instance.enemyTeam
end

function GetFlagPriority(flag)
	if		IsCapturedFlag(flag)then return FlagPriority.Enemy
	elseif	IsEnemyFlag(flag)	then return FlagPriority.Enemy
	else 							 return FlagPriority.Neutral
	end
end

function GetFlagToCapture(flagPoints, getPriority)
	local flags = {}
	
	for i, flag in pairs(flagPoints) do
		-- print("flag name: ", flag.name)
		table.insert(flags, {name = flag.name, k = getPriority(flag)})
	end

	return GetRandomItem(flags, function(f) return f.k end)
end

function GetNextUnitToSpawn(purchase)
	local units = purchase.unlockedUnits
	IsHeavyArty = purchase.isHeavyArty

	if not units then
		print("wave ", purchase.idx, " has no available units")
		return nil
	end
	
	local unit = GetUnitToSpawn(units)
	purchase:moveNext()
	return unit
end

function GetUnitToSpawn(units)
	if not units then
		return nil
	end
	
	local unitsToSpawn = {}
	
	local teamSize = BotApi.Instance.teamSize
	local income = BotApi.Commands:Income(BotApi.Instance.playerId)

	for i, unit in pairs(units) do

		local min_income = unit.min_income
		local min_team = unit.min_team
		
		if not min_income then min_income = -1 end
		if not min_team then min_team = 0 end
		
		if teamSize >= min_team and income >= min_income then
			table.insert(unitsToSpawn, unit)
		end
		
	end
	
	if #unitsToSpawn == 0 then
		return nil
	end
	
	local capturedFlags, enemyFlags = 0, 0
	for i, flag in pairs(BotApi.Scene.Flags) do
		if IsCapturedFlag(flag) then
			capturedFlags = capturedFlags + 1
		end
		if IsEnemyFlag(flag) then
			enemyFlags = enemyFlags + 1
		end
	end
	
	if capturedFlags < enemyFlags then
		choice = 0.3
	elseif capturedFlags == enemyFlags then
		choice = 0.20
	else
		choice = 0.10	-- higher choice(0-1+rnd) = higher % of CaptureFlag(bots going for flags). Lower choice favors SeekAndDestroy.
	end
	
	local enemyHasTanks = BotApi.Commands:EnemyHasTanks();
	
	return GetRandomItem(unitsToSpawn, function(t)
		if capturedFlags <= enemyFlags and (t.class == UnitClass.Tank or
							                t.class == UnitClass.Infantry) then
			return t.priority * 2.0
		end
		
		if enemyHasInfantry and (t.class == UnitClass.Tank or
							    t.class == UnitClass.ArtilleryTank) then
			return t.priority * 1.5
		end

		if enemyHasTanks and (t.class == UnitClass.ATTank or
		                      t.class == UnitClass.Tank or
							  t.class == UnitClass.HeavyTank) then
			return t.priority * 2.0
		end
		return t.priority
	end)
end

function UpdateUnitToSpawn(purchase)
	Context.SpawnInfo = GetNextUnitToSpawn(purchase)
end

function checkMapAIMovementLogic(flagName)
	if flagName == "f6" then
		followCustomMapWaypointGraph = false
	elseif flagName == "f7" then
		followCustomMapWaypointGraph = false
	elseif flagName == "f8" then
		followCustomMapWaypointGraph = false
	elseif flagName == "f9" then
		followCustomMapWaypointGraph = false
	elseif flagName == "f10" then
		followCustomMapWaypointGraph = false
	end
end

function OnGameStart()
	print("Player team is ", BotApi.Instance.enemyTeam)
	print("bot team size is ", BotApi.Instance.teamSize)
	print("bot faction is ", BotApi.Instance.army)
	-- print("BotApi.Instance properties:")
	-- local count = 0
	-- for i, inst in pairs((BotApi.Instance)) do 
	-- 	print("stuffs ", inst)
	-- 	count = count + 1
	-- 	print(i, "properties")
	-- 	for j, BotApi[1] in pairs(BotApi[count]) do
	-- 		print(j)
	-- 	end
	-- end


	math.randomseed(os.time()*BotApi.Instance.hostId)
	math.random() math.random() math.random() math.random()
	print("TESTING MODE ACTIVATED = ", testing)
	gameStartTime = os.clock()
	
 	totalFlags = 0


	for i, flag in pairs(BotApi.Scene.Flags) do
		print("i: ", i)
		print("flag name: ", flag.name)
		print("flag occupant: ", flag.occupant)

		if followCustomMapWaypointGraph then
			checkMapAIMovementLogic(flag.name)
		end
		if flag.name == "f11" or flag.name == "f12" or flag.name == "f13" or flag.name == "f14" or flag.name == "f15" then 
			forceLoadEarlyDivisions = false
		end

		totalFlags = totalFlags + 1
	end

	print("Total flags detected:", totalFlags)
	print("followCustomMapWaypointGraph: ", followCustomMapWaypointGraph)

	setFirstWaveOffset(totalFlags, BotApi.Scene.Flags)
	

	if followCustomMapWaypointGraph then 
		setTyphoonWaveMode()
	elseif math.random() < chanceToSetTyphoonWaveMode then -- % chance to for typhoon wave mode 
		setTyphoonWaveMode()
	end

		-- % chance to toggle ingame typhoon wave mode 
	if math.random() < chanceToSetTyphoonWaveModeToggle and not followCustomMapWaypointGraph then
		activateToggleTyphoonWaveMode()
	end


	
	print("first enemy wave will start at ", gameStartTime + firstWaveOffsetTime)
	nextTyphoonWaveTime = gameStartTime + firstWaveOffsetTime
	nextTyphoonWaveToggleTime = gameStartTime + typhoonWaveToggleInterval + firstWaveOffsetTime
	print("Next typhoon wave toggle time will start at ", gameStartTime + firstWaveOffsetTime)

	local purchasesModule = [[/script/multiplayer/bot.data.purchase.]] .. BotApi.Instance.gameMode;
	if module_exists(purchasesModule) then
		require(purchasesModule)
	end

	local purchases = Purchases[BotApi.Instance.gameMode];
	if not purchases then
		purchases = {}
	end
		

	if BotApi.Instance.gameMode == "campaign_capture_the_flag" then
		print("getting ready to load roster")
	    local divisionPurchases = {}
	    local counter = 0
	    local spawnMultiplier = 5 - totalFlags
		local purchaseModel = selectArmyDivision(totalFlags, BotApi.Instance.army)

		if module_exists(purchaseModel) then
	      require(purchaseModel)
		  print("model loading")
	      divisionPurchases = Purchases["campaign_capture_the_flag"]
		  print("model loaded")
	    else
		print("model failed to load")
	      local limit = totalFlags + 1
	      for key, value in pairs(purchases) do
	        if counter < limit then
	          table.insert(divisionPurchases, value)
	          counter = counter + 1
	        end
	      end
	    end
	    
	    SpawnCooldownTime.Min = SpawnCooldownTime.Min * spawnMultiplier
	    SpawnCooldownTime.Max = SpawnCooldownTime.Max * spawnMultiplier
	    defaultSpawnCooldownTime = SpawnCooldownTime

	    print("Spawn multipliers (min, max):", SpawnCooldownTime.Min, SpawnCooldownTime.Max)
	    purchases = divisionPurchases
	end

	Context.Purchase = PIter:new(purchases)
	-- UpdateUnitToSpawn(Context.Purchase)
	SetSpawnCooldownTimer()

	nextQuantSquadOrderTime = os.clock() + qauntSquadOrderDelay 

end

function OnGameStop()
	KillSpawnCooldownTimer()
	KillSpawnWaitTimer()

	for squad, timer in pairs(Context.SquadTimers) do
		if timer then
			BotApi.Events:KillQuantTimer(timer)
		end
	end
	collectgarbage("collect")
end

function TrySpawnUnit()
	if Context.SpawnWait.CooldownTimer then
		return
	end

	if not BotApi.Commands:CanSpawn() then
		return
	end
	
	if not Context.SpawnInfo then
		UpdateUnitToSpawn(Context.Purchase)
		return
	end

	local unit = Context.SpawnInfo.unit
	
	if not BotApi.Commands:IsUnitAvailable(unit) then
		-- print(unit, "not available, player#" .. BotApi.Instance.playerId)
		KillSpawnWaitTimer()
		UpdateUnitToSpawn(Context.Purchase)
		return
	end
	if currentWaveMaxUnitCount > 0 then
		if BotApi.Commands:Spawn(unit, MaxSquadSize) then
			if IsHeavyArty then 
				heavyArtyCounter = heavyArtyCounter + 1
				print("incrementing arty counter")
			end
			currentWaveMaxUnitCount = currentWaveMaxUnitCount - 1
			
			KillSpawnWaitTimer()
			SetSpawnCooldownTimer()
			UpdateUnitToSpawn(Context.Purchase)
			
			return
		end
	else
		-- print("can't spawn ", unit, ", max number of squads for this wave reached")
		UpdateUnitToSpawn(Context.Purchase)
		return
	end 

	local tts = BotApi.Commands:TimeToSpawnUnit(unit)
	if tts > UnitSpawnWaitTime then
		print(unit, tts, "wait too long, player#" .. BotApi.Instance.playerId)
		KillSpawnWaitTimer()
		UpdateUnitToSpawn(Context.Purchase)
		return
	end

	if not Context.SpawnWait.WaitTimer then
		print(unit, tts, "set wait timer, player#" .. BotApi.Instance.playerId)
		Context.SpawnWait.WaitTimer = BotApi.Events:SetQuantTimer(
			function()
				Context.SpawnWait.WaitTimer = nil
				UpdateUnitToSpawn(Context.Purchase)
			end, UnitSpawnWaitTime + 1000)
	end
end

function OnGameQuant()
	if typhoonWaveModeInGameToggle then
		if os.clock() > nextTyphoonWaveToggleTime then
			if math.random() < chanceToggleTyphoonWaveMode then 
				print("Flipping typhoon wave mode")
				if typhoonWaveMode then
					disableTyphoonWaveMode()
				else
					setTyphoonWaveMode()
				end
			end
			nextTyphoonWaveToggleTime = os.clock() + typhoonWaveToggleInterval
		end 
	end

	if os.clock() > (gameStartTime + firstWaveOffsetTime) then
		if typhoonWaveMode then
			if os.clock() > nextTyphoonWaveTime then
				TrySpawnUnit()
				if os.clock() > nextTyphoonWaveTime + typhoonWaveDuration then
					setNextTyphoonWaveTime()
				end
			end
		else 
			TrySpawnUnit()
		end
	end


	local waypoints = BotApi.Scene.Waypoints

	if nextQuantSquadOrderTime <= os.clock() then
		if #waypoints == 0 then
			for i, squad in pairs(BotApi.Scene.Squads) do

				if not followCustomMapWaypointGraph then
					if not Context.SquadTimers[squad] then
						SetSquadOrder(CaptureFlag, squad, OrderRotationPeriod)
					end
				else
					-- print("squad ", squad, " with unlock time = ", squadDictionary[squad])
					if emplacementArtillery[squad] then 
						if not Context.SquadTimers[squad] then
							SetSquadOrder(CaptureFlag, squad, artyOrderRotationPeriod)
						end
					elseif squadDictionary[squad] and  squadDictionary[squad] <= os.clock() then
						if not Context.SquadTimers[squad] then
							SetSquadOrder(CaptureFlag, squad, OrderRotationPeriod)
						end
					elseif not squadDictionary[squad] then
					 	local squadOrderTime = math.random(180, 300)
					 	print("nil squad ", squad, " with unlock time = ", squadDictionary[squad])
						squadDictionary[squad] = os.clock() + squadOrderTime
					end
				end
			end
		end
		nextQuantSquadOrderTime = os.clock() + qauntSquadOrderDelay
	end


end

function SeekAndDestroy(squad)
	BotApi.Commands:SeekAndDestroy(squad)
end

function GotoNextWaypoint(squad)
	local waypoints = BotApi.Scene.Waypoints
	BotApi.Commands:CaptureFlag(squad, waypoints[math.random(#waypoints)]) --captureflag is basically gothereandattack
	print("#captureFlag call inside GoToNextWaypoint")
end

function OnWaypoint(args)
	print("#GotoNextWaypoint call inside OnWaypoint")
	GotoNextWaypoint(args.squadId)
end

function CaptureFlag(squad)
	local flag = GetFlagToCapture(BotApi.Scene.Flags, GetFlagPriority)
	local rnd = math.random() + choice

	if flag then
		if not followCustomMapWaypointGraph then
			if rnd < 0.7 then
			print(rnd, "+SeekAndDestroy with squad", squad)
			BotApi.Commands:SeekAndDestroy(squad)
		else
			print(rnd, "+CaptureFlag with squad", squad)
			BotApi.Commands:CaptureFlag(squad, flag.name)
		end

		else
			if rnd < 0.9 then
				print(rnd, "+SeekAndDestroy with squad", squad)
				BotApi.Commands:SeekAndDestroy(squad)
			else
				print(rnd, "+CaptureFlag with squad", squad)
				BotApi.Commands:CaptureFlag(squad, flag.name)
			end
		end
	else
		print(rnd, "!SeekAndDestroy with squad", squad)
		BotApi.Commands:SeekAndDestroy(squad)
	end
	
end

function SetSquadOrder(order, squad, delay)
	order(squad)
	local setTimer = function(callback)
		Context.SquadTimers[squad] = BotApi.Events:SetQuantTimer(
			function()
				order(squad)
				Context.SquadTimers[squad] = nil
				if BotApi.Scene:IsSquadExists(squad) then
					callback(callback)
				end
			end,
			delay)
	end
	print("squad timer: ", Context.SquadTimers[squad] )
	setTimer(setTimer)--
end

function OnGameSpawn(args)

	-- When there's only 1 flag, we want the ai to just attack the player and flag directly to keep the game interesting
	if totalFlags <= 1 or not followCustomMapWaypointGraph then
		local waypoints = BotApi.Scene.Waypoints
		if #waypoints == 0 then
			SetSquadOrder(CaptureFlag, args.squadId, artyOrderRotationPeriod)
		else
			GotoNextWaypoint(args.squadId)
			print("#waypoints != 0")
		end
	else
		if heavyArtyCounter > 0 then
			emplacementArtillery[args.squadId] = args
			print("added ", args.squadId, " to heavy arty list")
			IsHeavyArty = false
			heavyArtyCounter = heavyArtyCounter - 1
			local waypoints = BotApi.Scene.Waypoints

			if #waypoints == 0 then
				SetSquadOrder(CaptureFlag, args.squadId, artyOrderRotationPeriod)
			else
				GotoNextWaypoint(args.squadId)
				print("#waypoints != 0")
			end
		else 
			local squadOrderTime = math.random(240, 300)
			squadDictionary[args.squadId] = os.clock() + squadOrderTime
			
		end
	end
end

BotApi.Events:Subscribe(BotApi.Events.GameStart, OnGameStart)
BotApi.Events:Subscribe(BotApi.Events.GameEnd, OnGameStop)
BotApi.Events:Subscribe(BotApi.Events.Quant, OnGameQuant)
BotApi.Events:Subscribe(BotApi.Events.GameSpawn, OnGameSpawn)
BotApi.Events:Subscribe(BotApi.Events.Waypoint, OnWaypoint)
