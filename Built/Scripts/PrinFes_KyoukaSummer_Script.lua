--[[ Kyouka (Summer) Leader Script - GamePlay Conetext
* Written by Kevin Liu, modified by Uzuki Shimamura
*
* Global Variables and Helper Functions
]]
include("GameCapabilities");

local AQUA_CREST_ENABLED    :string = "PROPERTY_AQUA_CREST";
local AQUA_CREST_SCIENCE    :string = "PROPERTY_AQUA_CREST_SCIENCE";
local AQUA_CREST_CULTURE    :string = "PROPERTY_AQUA_CREST_CULTURE";
local AQUA_CREST_PRODUCTION :string = "PROPERTY_AQUA_CREST_PRODUCTION";
local AQUA_FLOCK_CITY_STACK :string = "PROPERTY_AQUA_FLOCK_STACK";

local AQUA_CREST_MAX_YIELD		       = 2;						--# of Bonus Yield Points in Total to Place on one Tile
local AQUA_FLOCK_STACK_PER_DISTRICT    = 3;						--# of Modifier Stacks per District
local AQUA_FLOCK_STACK_PER_BUILDING    = 1;						--# of Modifier Stacks per Building
local AQUA_FLOCK_STACK_PER_IMPROVEMENT = 1;						--# of Modifier Stacks per Improvement
local AQUA_FLOCK_UNIT_DEBUFF_TURNS     = 3;						--# of Turns in Effect of Aqua Flock Unit Debuff (min = 1)

--[[ Section 1 : Aqua Crest Bonus Yield ]]
--==============================================================================================================================
local aquaCrestPlots :table = {};
local aquaCrestLastUpdated :number = -1;

local function SetAquaCrestOnPlot(iPlotID :number, pPlot :table, eImprovementType :number, eOwner :number)
	if (not pPlot or ((not pPlot:IsCoastalLand()) and (not pPlot:IsWater()))) then return end;

	if (HasTrait("TRAIT_LEADER_AQUA_CREST",eOwner) and eImprovementType >= 0 and not pPlot:IsImprovementPillaged()) then
		if (not aquaCrestPlots[iPlotID] or not pPlot:GetProperty(AQUA_CREST_ENABLED)) then
			pPlot:SetProperty(AQUA_CREST_ENABLED, true);			--Add Aqua Crest Property to Kyouka's Improvements
			table.insert(aquaCrestPlots, iPlotID, pPlot);
			if (pPlot:GetProperty(AQUA_CREST_SCIENCE)) then return end;

			local amount :table = { [0]=0, 0, 0 };				--If Plot acquire Aqua Crest First Time, Generate Random Yields
			for _=0, (AQUA_CREST_MAX_YIELD - 1), 1 do			--Loop AQUA_CREST_MAX_YIELD times, each time for 1 point of yield
				local randomizedYieldType = Game.GetRandNum(3, AQUA_CREST_ENABLED);		-- 3 kinds of yields. GetRandNum generate random numbers in [0, max) range
				amount[randomizedYieldType] = amount[randomizedYieldType] + 1;				
			end													-- No significant perfermance loss for such few loops so seems no need to refactor it
			pPlot:SetProperty(AQUA_CREST_SCIENCE,    amount[0]);
			pPlot:SetProperty(AQUA_CREST_CULTURE,    amount[1]);
			pPlot:SetProperty(AQUA_CREST_PRODUCTION, amount[2]);
		end
	else
		if (aquaCrestPlots[iPlotID] or pPlot:GetProperty(AQUA_CREST_ENABLED)) then
			pPlot:SetProperty(AQUA_CREST_ENABLED, false);		--Remove Aqua Crest Property if Not Valid anymore
			table.remove(aquaCrestPlots, iPlotID);
		end
	end
end

local function CheckPlotStatus()								--Vaidate Plot Status and Remove Invalid Properties
	local currentTurn = Game.GetCurrentGameTurn();
	if (currentTurn <= aquaCrestLastUpdated) then return end;	--Run Once per Turn at Turn Start
	aquaCrestLastUpdated = currentTurn;

	for iPlotID, pPlot in pairs(aquaCrestPlots) do
		SetAquaCrestOnPlot(iPlotID, pPlot, pPlot:GetImprovementType(), pPlot:GetImprovementOwner());
	end
end

--------------------------------------------------------------------------------------------------------------------------------
local function OnImprovementChanged(locX :number, locY :number, eImprovementType :number, eOwner :number)
	local iPlotID = Map.GetPlotIndex(locX, locY);
	SetAquaCrestOnPlot(iPlotID, Map.GetPlotByIndex(iPlotID), eImprovementType, eOwner);
end

local function OnImprovementRemovedFromMap(locX :number, locY :number, eOwner :number)
	local iPlotID = Map.GetPlotIndex(locX, locY);
	SetAquaCrestOnPlot(iPlotID, Map.GetPlotByIndex(iPlotID), -1, eOwner);
end

local function OnPlayerTurnStarted(iPlayerID :number)
	ExposedMembers.AquaFlock.OnPlayerTurnStarted(iPlayerID);
end

Events.ImprovementAddedToMap	.Add(OnImprovementChanged);
Events.ImprovementRemovedFromMap.Add(OnImprovementRemovedFromMap);
Events.ImprovementChanged		.Add(OnImprovementChanged);
GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStarted);
ExposedMembers.AquaFlockGameplay = ExposedMembers.AquaFlockGameplay or {}
ExposedMembers.AquaFlockGameplay.OnImprovementChanged = OnImprovementChanged
ExposedMembers.AquaFlockGameplay.CheckPlotStatus = CheckPlotStatus

--[[ Section 2 : Aqua Flock Yield Bonus ]]
--==============================================================================================================================
local function OnTurnEnd(iPlayerID :number)
	if (not (HasTrait("TRAIT_LEADER_SUMMER_AQUA_FLOCK",iPlayerID) and (HasTrait("TRAIT_CIVILIZATION_PRINCESS_KNIGHT_OF_LANDSOL",iPlayerID)))) then return end;
	local stack = 0;

	for _, pCity in Players[iPlayerID]:GetCities():Members() do
		local pCityCenter = Map.GetPlot(pCity:GetX(), pCity:GetY());
		local stack = 0;
		for _, pPlot in pairs(pCity:GetOwnedPlots()) do			--Stacks by improvements
			if (pPlot:GetProperty(AQUA_CREST_ENABLED)) then
				stack = stack + AQUA_FLOCK_STACK_PER_IMPROVEMENT;

			else												
				if (pPlot:GetDistrictType()>=0 and (pPlot:IsCoastalLand() or pPlot:IsWater())) then
					local iPlotID :number = pPlot:GetIndex();
					local iCityID :number = pCity:GetID();
					if (not pPlot:IsCity() and (ExposedMembers.AquaFlock.DistrictIsComplete(iPlayerID, iCityID, iPlotID))) then stack = stack + AQUA_FLOCK_STACK_PER_DISTRICT end; --Stacks by districts
					local pBuildingTypes :table = ExposedMembers.AquaFlock.GetBuildingsOnPlot(iPlayerID, iCityID, iPlotID); --Stacks by buildings
					for _, iBuildingType in ipairs(pBuildingTypes) do
						if (not pCity:GetBuildings():IsPillaged(iBuildingType)) then
							stack = stack + AQUA_FLOCK_STACK_PER_BUILDING;
						end
					end
				end
			end
		end														
		pCityCenter:SetProperty(AQUA_FLOCK_CITY_STACK, stack); --Apply Property Stack Number
	end
end

Events.LocalPlayerTurnEnd.Add(function() OnTurnEnd(Game.GetLocalPlayer()) end);
Events.RemotePlayerTurnEnd.Add(OnTurnEnd);


--[[ Section 3 : Aqua Flock Unit Ability ]]
--==============================================================================================================================
local aquaFlockActivatedUnits :table = {};

local function OnCombatOccurred(attackerPlayerID :number, attackerUnitID :number, defenderPlayerID :number, defenderUnitID :number, attackerDistrictID :number, defenderDistrictID :number)
	if (not attackerUnitID or not defenderPlayerID or not Players[attackerPlayerID] or not Players[defenderPlayerID]) then return end;
	
	local pUnit :table = Players[attackerPlayerID]:GetUnits():FindID(attackerUnitID);
	if (not pUnit or pUnit:GetAbility():GetAbilityCount("ABILITY_AQUA_FLOCK")<=0) then return end;
	pUnit = Players[defenderPlayerID]:GetUnits():FindID(defenderUnitID);

	local activation  :number = pUnit:GetAbility():GetAbilityCount("ABILITY_AQUA_FLOCK_DEBUFF");

	if (activation == 0) then
		if (not aquaFlockActivatedUnits[attackerPlayerID]) then	--Grant Aqua Flock if Not in effect
			aquaFlockActivatedUnits[attackerPlayerID] = {};
		end
		table.insert(aquaFlockActivatedUnits[attackerPlayerID], { [0]=defenderPlayerID, defenderUnitID });
		Game.AddWorldViewText(0, "{LOC_ABILITY_AQUA_FLOCK_DEBUFF_NAME}", pUnit:GetX(), pUnit:GetY());
	end															--Otherwise Refresh turn counter
	
	pUnit:GetAbility():ChangeAbilityCount("ABILITY_AQUA_FLOCK_DEBUFF", AQUA_FLOCK_UNIT_DEBUFF_TURNS-activation);
end

--------------------------------------------------------------------------------------------------------------------------------
local function OnPlayerTurnActivated(iPlayerID :number)
	if (not aquaFlockActivatedUnits[iPlayerID]) then return end;
	local activatedUnits_new :table = {};

	for _,v in pairs(aquaFlockActivatedUnits[iPlayerID]) do		--Reduce Aqua Flock turn counter, and Deactivate effect
		local pUnit :table = Players[v[0]]:GetUnits():FindID(v[1]);
		if (pUnit) then
			pUnit:GetAbility():ChangeAbilityCount("ABILITY_AQUA_FLOCK_DEBUFF", -1);
			if (pUnit:GetAbility():GetAbilityCount("ABILITY_AQUA_FLOCK_DEBUFF")>=1) then
				table.insert(activatedUnits_new, v);
			end
		end
	end
	aquaFlockActivatedUnits[iPlayerID] = activatedUnits_new;
end

GameEvents.OnCombatOccurred.Add(OnCombatOccurred);
GameEvents.PlayerTurnStarted.Add(OnPlayerTurnActivated);