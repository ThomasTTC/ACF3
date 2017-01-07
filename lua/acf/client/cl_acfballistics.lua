ACF.BulletEffect = {}
local DeltaTime = engine.TickInterval()

function ACF_ManageBulletEffects()
	
	for Index,Bullet in pairs(ACF.BulletEffect) do
		ACF_SimBulletFlight( Bullet, Index )			--This is the bullet entry in the table, the omnipresent Index var refers to this
	end
	
end
hook.Add("Tick", "ACF_ManageBulletEffects", ACF_ManageBulletEffects)

function ACF_SimBulletFlight( Bullet, Index )
	
	local Drag = Bullet.SimFlight:GetNormalized() * Bullet.DragCoef * Bullet.SimFlight:LengthSqr() / ACF.DragDiv
	--print(Drag)

	Bullet.SimPos = Bullet.SimPos + (Bullet.SimFlight * ACF.VelScale * DeltaTime)		--Calculates the next shell position
	Bullet.SimFlight = Bullet.SimFlight + (Bullet.Accel - Drag)*DeltaTime			--Calculates the next shell vector
	
	if Bullet and IsValid(Bullet.Effect) then
		Bullet.Effect:ApplyMovement( Bullet )
	end
end
