function GetBuildingsOnPlot(iPlayerID :number, iCityID :number, iPlotID :number)
	return CityManager.GetCity(iPlayerID,iCityID):GetBuildings():GetBuildingsAtLocation(iPlotID);
end


function DistrictIsComplete(iPlayerID :number, iCityID :number, iPlotID :number)
	pPlot = Map.GetPlotByIndex(iPlotID);
	ownerCity = Cities.GetPlotPurchaseCity(pPlot);
	local eDistrictType = pPlot:GetDistrictType();
	if (eDistrictType) then
		local cityDistricts = ownerCity:GetDistricts();
		if (cityDistricts) then
			if ((not cityDistricts:IsPillaged(eDistrictType, plotId)) and cityDistricts:IsComplete(eDistrictType, plotId)) then
				return true;
			end
		end
	end
	return false;
end

function HasTrait( traitName:string, playerId:number )
	if playerId == nil then playerId = Game.GetLocalPlayer(); end
	if playerId == -1 then return false; end	-- Autoplay.
	
	local config :table = PlayerConfigurations[playerId];
	if(config ~= nil) then
		local leaderType:string = config:GetLeaderTypeName();
		local civType	:string = config:GetCivilizationTypeName();
		if leaderType then
			for row in GameInfo.LeaderTraits() do
				if row.LeaderType==leaderType and row.TraitType == traitName then
					return true;
				end
			end
		end
		if civType then
			for row in GameInfo.CivilizationTraits() do
				if row.CivilizationType== civType then
					if row.TraitType == traitName then
						return true;
					end
				end
			end
		end
	end
	return false;
end

function OnPlayerTurnStarted(iPlayerID :number)
	ExposedMembers.AquaFlockGameplay.CheckPlotStatus();											--Check Kyouka's Improvements at Turn Start
	if (not HasTrait("TRAIT_LEADER_AQUA_CREST",iPlayerID)) then return end;		--  to cover Unexpected Improvement Acquirement cases

	local pPlayerImprovements :table = Players[iPlayerID]:GetImprovements();
	if (not pPlayerImprovements) then return end;

	for _, iPlotID in pairs(pPlayerImprovements:GetImprovementPlots()) do
		local pPlot = Map.GetPlotByIndex(iPlotID);

		if (pPlot and (pPlot:IsCoastalLand() or pPlot:IsWater()) ) then
			local eImprovement = pPlot:GetImprovementType();
			ExposedMembers.AquaFlockGameplay.OnImprovementChanged(pPlot:GetX(), pPlot:GetY(), eImprovement, iPlayerID);
		end
	end
end


ExposedMembers.AquaFlock = ExposedMembers.AquaFlock or {}
ExposedMembers.AquaFlock.GetBuildingsOnPlot = GetBuildingsOnPlot
ExposedMembers.AquaFlock.DistrictIsComplete = DistrictIsComplete
ExposedMembers.AquaFlock.OnPlayerTurnStarted = OnPlayerTurnStarted

