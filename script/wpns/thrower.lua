C_Spray = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value found in baseWeap

C_Spray.model	  = "gluon.xml" 		   -- Path to the XML model file

C_Spray.toolID   = "pwb2_pspray"  -- Used by the engine. Lowercase and no spaces
C_Spray.toolName = "PaintThrower" -- Shown in killfeed
C_Spray.toolSlot = 3
C_Spray.toolPos  = 4			  -- placement in the hud column

C_Spray.ammoLoadedMax    = -1					 -- Max clip 	 	-- -1 for no clip (pulls from reserve)
C_Spray.ammoAltLoadedMax = 0 				 	 -- Max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
C_Spray.ammoPickupSize   = 20 					 -- Defaults to full mag
C_Spray.dmg_plyr		 = 0.07				 	 -- 0.0-1.0

C_Spray.flags = addFlags(0, FWPN_SV_CALLONCE_SEC,
						  FWPN_CLICK_SEC) -- Weapon flags
C_Spray.snds  = 0 -- Prechached SFX list, set on INIT

local ACCURACY_SHOT_PENALTY_TIME	= 0.2	-- Applied amount of time each shot adds to the time we must recover from
local ACCURACY_MAXIMUM_PENALTY_TIME	= 1.5	-- Maximum penalty to deal out

-- override initVars to add new variables
function C_Spray:initVars(owner)
	baseWeap.initVars(self, owner)

	self.accuracyPenalty = 0

	if client and self.isLocal then
		self.timeFiring = 0
		self.lastFireTime = 0
	end
end

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function C_Spray:Sounds()
	return {
		{"launcher_fire.ogg", "sv", "fire",	true},

		{"smg_reload.ogg", "cl", "reload"},
		{"smg_reload.ogg", "cl", "reloadLoop", true}
	}
end

--=========================================================================
-- Weapon functions
--=========================================================================

function C_Spray:GetPlayerSpread()
	local ramp = RemapValClamped(	self.accuracyPenalty,
									0.0,
									ACCURACY_MAXIMUM_PENALTY_TIME,
									0.0,
									1.0 )

	-- We lerp from very accurate to inaccurate over time
	return Lerp(GLOBAL_5DEGREES, GLOBAL_8DEGREES, ramp)
end

function C_Spray:PrimaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self.nextFire = GetTime() + 0.15
			return
		end

		self:MDL_PunchPos(Vec(0, 0.01, GetRandomFloat(0.133, 0.166)))

		if self.isLocal then
			client.VFX_DynLight(self.owner, 15, 0.08, Vec(0.7, 0.5, 0.3), Vec(), "muzzle")

			if self.lastFireTime < GetTime() - 0.2 then
				self.timeFiring = 0
			else
				self.timeFiring = self.timeFiring + 0.1
			end

			self.lastFireTime = GetTime()
			local punch = client.PUNCH_MachineGunKick(4, self.timeFiring, 1.5)

			self:MDL_PunchAngReset(-15)
			self:MDL_PunchAng(Vec(GetRandomFloat(0.5, 1.1), GetRandomFloat(-1.25, 1), GetRandomFloat(0.3, 1)))
			self:MDL_PunchAng(punch, 33)

			client.PUNCH_Vec(Vec(GetRandomFloat(-0.3, -0.5), GetRandomFloat(-0.6, 0.6), 0))
		end
	else
		PlayFireSound(self.snds["fire"], mt.pos, 300)
	end

	baseWeap.DepleteAmmo(self, 1, 1)

	self:FirePaintballsPlayer(4, GetPlayerEyeTransform(self.owner).pos, self:GetPlayerSpread(), 50, 25, 6)

	SetRandomSeed(shared.seed)
	AIM_RecoilAdd(self.owner, Vec(2, GetRandomFloat(-1.33, 1.33), 0))
	if server then shared.seed = GetRandomInt(0,10000) end

	self.accuracyPenalty = self.accuracyPenalty + ACCURACY_SHOT_PENALTY_TIME

	self.nextFire = self:GetNextAttackDelay(0.1)
end

function C_Spray:WeaponIdle()
	self.playEmptySound = true
end

function C_Spray:tickPlayer_sv(dt)
	-- Check our penalty time decay
	if self.nextFire < GetTime() then
		self.accuracyPenalty = self.accuracyPenalty - dt
		self.accuracyPenalty = clamp(self.accuracyPenalty, 0.0, ACCURACY_MAXIMUM_PENALTY_TIME)
	end

	if self.inPrimary then
		local mt = GetToolLocationWorldTransform("muzzle", self.owner)
		PlayLoop(self.snds["fire"], mt.pos, 300)
	end
	
	baseWeap.tickPlayer_sv(self, dt)
end

function C_Spray:tickPlayer_cl(dt)
	-- Check our penalty time decay
	if self.nextFire < GetTime() then
		self.accuracyPenalty = self.accuracyPenalty - dt
		self.accuracyPenalty = clamp(self.accuracyPenalty, 0.0, ACCURACY_MAXIMUM_PENALTY_TIME)
	end

	baseWeap.tickPlayer_cl(self, dt)
end