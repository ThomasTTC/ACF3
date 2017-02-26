ACF.BulletEffect = {}

function ACF_ManageBulletEffects()
	
	for Index,Bullet in pairs(ACF.BulletEffect) do
		ACF_SimBulletFlight( Bullet, Index )			--This is the bullet entry in the table, the omnipresent Index var refers to this
	end
	
end
hook.Add("Tick", "ACF_ManageBulletEffects", ACF_ManageBulletEffects)

function ACF_SimBulletFlight( Bullet, Index )
	local Time = CurTime()
	local DeltaTime = Time - Bullet.LastThink
	
	local Drag = Bullet.SimFlight:GetNormalized() * (Bullet.DragCoef * Bullet.SimFlight:LengthSqr())/ACF.DragDiv
	--print(Drag)
	--debugoverlay.Cross(Bullet.SimPos,3,15,Color(255,255,255,32), true)
	Bullet.SimPosLast = Bullet.SimPos
	Bullet.SimPos = Bullet.SimPos + (Bullet.SimFlight * ACF.VelScale * DeltaTime)		--Calculates the next shell position
	Bullet.SimFlight = Bullet.SimFlight + (Bullet.Accel - Drag)*DeltaTime			--Calculates the next shell vector
	
	if Bullet and IsValid(Bullet.Effect) then
		Bullet.Effect:ApplyMovement( Bullet )
	end
	Bullet.LastThink = Time
	
end
