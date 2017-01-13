ACF.Bullet = {}
ACF.CurBulletIndex = 0
ACF.BulletIndexLimit = 1000
ACF.DeltaTime = engine.TickInterval()
local IndexLimit 	= ACF.BulletIndexLimit
local Bullets 		= ACF.Bullet
local DragDiv 		= ACF.DragDiv
local FlightTr		= {mask = MASK_SHOT}
local Gravity 		= Vector(0, 0, GetConVar("sv_gravity"):GetInt()*-1)
local DeltaTime		= ACF.DeltaTime

local util_TraceLine	= util.TraceLine
local math_Random		= math.random
local util_IsInWorld	= util.IsInWorld
local util_Effect		= util.Effect
local table_Copy		= table.Copy
--local hook_Run = hook.Run, 109
local math_Round		= math.Round
local Alternate

function ACF_CreateBullet( BulletData )
	ACF.CurBulletIndex = ACF.CurBulletIndex == IndexLimit and 1 or ACF.CurBulletIndex + 1
	local Index = ACF.CurBulletIndex

	BulletData["Accel"]			= Gravity		--Those are BulletData settings that are global and shouldn't change round to round
	BulletData["LastThink"]		= SysTime()
	BulletData["FlightTime"] 	= 0
	BulletData["DetTime"]		= BulletData.FuzeTime and CurTime() + BulletData.FuzeTime or nil
	BulletData["Filter"] 		= BulletData["Gun"] and { BulletData["Gun"] } or {}
		
	Bullets[Index] = table_Copy(BulletData)		--Place the bullet at the current index pos
	ACF_BulletClient( Index, Bullets[Index], "Init" , 0 )
	ACF_CalcBulletFlight( Index, Bullets[Index] )

	return BulletData
end


function ACF_ManageBullets()
	for Index, Bullet in pairs(Bullets) do
		ACF_CalcBulletFlight( Index, Bullet )			--This is the bullet entry in the table, the Index var omnipresent refers to this
	end
end
hook.Add("Tick", "ACF_ManageBullets", ACF_ManageBullets)


function ACF_RemoveBullet(Index)
	--local Bullet = Bullets[Index]
	
	Bullets[Index] = nil
	
	--if Bullet and Bullet.OnRemoved then Bullet:OnRemoved() end
end


function ACF_CheckClips(Ent, HitPos)
	if not Ent.ClipData or Ent:GetClass() ~= "prop_physics" then return false end
	
	local Data = Ent.ClipData
	for i = 1, #Data do
		local DataI = Data[i]
		local N = DataI["n"]

		if Ent:LocalToWorldAngles(N):Forward():Dot((Ent:LocalToWorld(N:Forward() * DataI["d"]) - HitPos):GetNormalized()) > 0 then return true end
	end
	
	return false
end


function ACF_Trace(Table)
	local TraceRes = util_TraceLine(Table or FlightTr)
	
	if TraceRes.HitNonWorld and ( not ACF_Check(TraceRes.Entity) or ACF_CheckClips(TraceRes.Entity, TraceRes.HitPos) ) then
		FlightTr.filter[#FlightTr.filter + 1] = TraceRes.Entity
		
		return ACF_Trace(FlightTr)
	end
	
	return TraceRes
end


function ACF_CalcBulletFlight(Index, Bullet, Override)	
	local Drag = Bullet.Flight:GetNormalized() * Bullet.DragCoef * Bullet.Flight:LengthSqr() / DragDiv
	
	Bullet.Step = Bullet.Flight * DeltaTime
	Bullet.NextPos = Bullet.Pos + Bullet.Step	--Calculates the next shell position
	Bullet.Flight = Bullet.Flight + (Bullet.Accel - Drag) * DeltaTime				--Calculates the next shell vector
	
	ACF_DoBulletsFlight( Index, Bullet )
end

function ACF_DoBulletsFlight(Index, Bullet)
	--if hook_Run("ACF_BulletsFlight", Index, Bullet ) == false then return end
	
	if Bullet.DetTime and CurTime() >= Bullet.DetTime then
		if not util_IsInWorld(Bullet.Pos) then
			ACF_RemoveBullet( Index )
		else
				FlightTr.start  = Bullet.Pos -- Bullet.Step * 0.5
				FlightTr.endpos = Bullet.NextPos
				FlightTr.filter = Bullet.Filter
			local FlightRes = ACF_Trace()

			Bullet.Pos = LerpVector(math_Random(), Bullet.Pos, FlightRes.HitPos)

			--if Bullet.OnEndFlight then Bullet.OnEndFlight(Index, Bullet, FlightRes) end
			
			ACF_BulletClient( Index, Bullet, "Update" , 1 , Bullet.Pos  )
			ACF_BulletEndFlight = ACF.RoundTypes[Bullet.Type]["endflight"]
			ACF_BulletEndFlight( Index, Bullet, Bullet.Pos, Bullet.Flight:GetNormalized() )
		end

		return
	end
	
	if Bullet.SkyLvL then
		if CurTime() - Bullet.LifeTime > 30 then			 -- We don't want to calculate bullets that will never come back to map.
			ACF_RemoveBullet( Index )
			
			return
		elseif Bullet.NextPos.z > Bullet.SkyLvL then 
			Bullet.Pos = Bullet.NextPos
			
			return
		elseif not util_IsInWorld(Bullet.NextPos) then
			ACF_RemoveBullet( Index )
			
			return
		else
			Bullet.SkyLvL = nil
			Bullet.LifeTime = nil
			Bullet.Pos = Bullet.NextPos
			Bullet.SkipNextHit = true
			
			return
		end
	end

		FlightTr.start  = Bullet.Pos -- Bullet.Step * 0.5
		FlightTr.endpos = Bullet.NextPos + Bullet.Step * 2
		FlightTr.filter = Bullet.Filter
	local FlightRes = ACF_Trace()

	
	if Bullet.SkipNextHit then
		if not FlightRes.StartSolid and not FlightRes.HitNoDraw then Bullet.SkipNextHit = nil end
		Bullet.Pos = Bullet.NextPos

	elseif FlightRes.Hit and FlightRes.Fraction <= 0.3334 then
		debugoverlay.Line( FlightTr.start, FlightRes.HitPos, 20, Color(255, 255, 0), false )
		debugoverlay.Line( FlightRes.HitPos, FlightTr.endpos, 20, Color(255, 0, 0), false)

		
		if FlightRes.HitWorld then
			if FlightRes.HitSky then
				if FlightRes.HitNormal == Vector(0, 0, -1) then
					Bullet.SkyLvL = FlightRes.HitPos.z 						-- Lets save height on which bullet went through skybox. So it will start tracing after falling bellow this level. This will prevent from hitting higher levels of map
					Bullet.LifeTime = CurTime()
					Bullet.Pos = Bullet.NextPos
				else 
					ACF_RemoveBullet( Index )
				end
			else
				local Retry = ACF.RoundTypes[Bullet.Type]["worldimpact"]( Index, Bullet, FlightRes.HitPos, FlightRes.HitNormal )
				if Retry == "Penetrated" then 								--if it is, we soldier on	
					--if Bullet.OnPenetrated then Bullet.OnPenetrated(Index, Bullet, FlightRes) end
					
					ACF_BulletClient( Index, Bullet, "Update" , 2 , FlightRes.HitPos  )
					ACF_CalcBulletFlight( Index, Bullet )
				elseif Retry == "Ricochet"  then
					--if Bullet.OnRicocheted then Bullet.OnRicocheted(Index, Bullet, FlightRes) end
					
					ACF_BulletClient( Index, Bullet, "Update" , 3 , FlightRes.HitPos  )
					ACF_CalcBulletFlight( Index, Bullet )
				else														--If not, end of the line, boyo
					--if Bullet.OnEndFlight then Bullet.OnEndFlight(Index, Bullet, FlightRes) end
					
					ACF_BulletClient( Index, Bullet, "Update" , 1 , FlightRes.HitPos  )
					ACF_BulletEndFlight = ACF.RoundTypes[Bullet.Type]["endflight"]
					ACF_BulletEndFlight( Index, Bullet, FlightRes.HitPos, FlightRes.HitNormal )	
				end
			end
		else -- Hit entity	
			local Retry = ACF.RoundTypes[Bullet.Type]["propimpact"]( Index, Bullet, FlightRes.Entity , FlightRes.HitNormal , FlightRes.HitPos , FlightRes.HitGroup )				--If we hit stuff then send the resolution to the damage function	
			if Retry == "Penetrated" then		--If we should do the same trace again, then do so
				--if Bullet.OnPenetrated then Bullet.OnPenetrated(Index, Bullet, FlightRes) end
				
				ACF_BulletClient( Index, Bullet, "Update" , 2 , FlightRes.HitPos  )
				ACF_DoBulletsFlight( Index, Bullet )
			elseif Retry == "Ricochet"  then
				--if Bullet.OnRicocheted then Bullet.OnRicocheted(Index, Bullet, FlightRes) end
				
				ACF_BulletClient( Index, Bullet, "Update" , 3 , FlightRes.HitPos  )
				ACF_CalcBulletFlight( Index, Bullet )
			else						--Else end the flight here
				--if Bullet.OnEndFlight then Bullet.OnEndFlight(Index, Bullet, FlightRes) end
				
				ACF_BulletClient( Index, Bullet, "Update" , 1 , FlightRes.HitPos  )
				ACF_BulletEndFlight = ACF.RoundTypes[Bullet.Type]["endflight"]
				ACF_BulletEndFlight( Index, Bullet, FlightRes.HitPos, FlightRes.HitNormal )	
			end
		end
	else
		Alternate = not Alternate
		debugoverlay.Line( FlightTr.start, FlightTr.endpos, 20, Alternate and Color(0, 255, 0) or Color(0, 0, 255), false )
		Bullet.Pos = Bullet.NextPos
	end
end


function ACF_BulletClient( Index, Bullet, Type, Hit, HitPos )
	if Type == "Update" then
		local Effect = EffectData()
			Effect:SetAttachment( Index )		--Bulet Index
			Effect:SetStart( Bullet.Flight/10 )	--Bullet Direction
			Effect:SetOrigin(Hit > 0 and HitPos or Bullet.Pos)
			Effect:SetScale( Hit )	--Hit Type 
		util_Effect( "ACF_BulletEffect", Effect, true, true )
	else
		local Effect = EffectData()
			Effect:SetAttachment( Index )		--Bulet Index
			Effect:SetStart( Bullet.Flight/10 )	--Bullet Direction
			Effect:SetOrigin( Bullet.Pos )
			Effect:SetEntity( Entity(Bullet["Crate"]) )
			Effect:SetScale( 0 )
		util_Effect( "ACF_BulletEffect", Effect, true, true )
	end
end