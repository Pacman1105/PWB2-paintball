C_SMG = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value found in baseWeap

C_SMG.model	    = "smg.xml" 			 -- Path to the XML model file

C_SMG.toolID   = "pwb2_psmg" -- Used by the engine. Lowercase and no spaces
C_SMG.toolName = "Paint SMG" -- Shown in killfeed
C_SMG.toolSlot = 3
C_SMG.toolPos  = 4			 -- placement in the hud column

C_SMG.ammoLoadedMax    = 40					 -- Max clip 	 	-- -1 for no clip (pulls from reserve)
C_SMG.ammoAltLoadedMax = 0 				 	 -- Max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
C_SMG.ammoPickupSize   = C_SMG.ammoLoadedMax -- Defaults to full mag
C_SMG.dmg_plyr		   = 0.3				 -- 0.0-1.0

C_SMG.flags = addFlags(0, FWPN_SV_CALLONCE_SEC,
						  FWPN_CLICK_SEC) -- Weapon flags
C_SMG.snds  = 0 -- Prechached SFX list, set on INIT

local ACCURACY_SHOT_PENALTY_TIME	= 0.1	-- Applied amount of time each shot adds to the time we must recover from
local ACCURACY_MAXIMUM_PENALTY_TIME	= 1.0	-- Maximum penalty to deal out

-- override initVars to add new variables
function C_SMG:initVars(owner)
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

function C_SMG:Sounds()
	return {
		{"fire_light.ogg", "sv", "fire"  },
		{"smg_reload.ogg", "cl", "reload"},
		{"smg_reload.ogg", "cl", "reloadLoop", true}
	}
end

--=========================================================================
-- Weapon functions
--=========================================================================

function C_SMG:GetPlayerSpread()
	local ramp = RemapValClamped(	self.accuracyPenalty,
									0.0,
									ACCURACY_MAXIMUM_PENALTY_TIME,
									0.0,
									1.0 )

	-- We lerp from very accurate to inaccurate over time
	return Lerp(GLOBAL_2DEGREES, GLOBAL_7DEGREES, ramp)
end

function C_SMG:PrimaryAttack(dt)
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

		self:muzzleFlash(mt.pos, 0.8, Vec(0.25, 0.25, 0.25))
	else
		PlayFireSound(self.snds["fire"], mt.pos, 300)
	end

	baseWeap.DepleteAmmo(self, 1, 1)

	self:FirePaintballsPlayer(1, GetPlayerEyeTransform(self.owner).pos, self:GetPlayerSpread(), 100, 175, 5)

	self.accuracyPenalty = self.accuracyPenalty + ACCURACY_SHOT_PENALTY_TIME

	self.nextFire = self:GetNextAttackDelay(0.1)
end

function C_SMG:Reload()
	if not self:DefaultReload(2.5) then return end

	if self.isLocal then
		self:PlayFollowingSound(self.snds["reloadLoop"], 2.45)
	else
		PlaySound(self.snds["reload"], GetPlayerPos(self.owner), 1)
	end
end

function C_SMG:WeaponIdle()
	self.playEmptySound = true
end

function C_SMG:tickPlayer_sv(dt)
	-- Check our penalty time decay
	if self.nextFire < GetTime() then
		self.accuracyPenalty = self.accuracyPenalty - dt
		self.accuracyPenalty = clamp(self.accuracyPenalty, 0.0, ACCURACY_MAXIMUM_PENALTY_TIME)
	end

	baseWeap.tickPlayer_sv(self, dt)
end

function C_SMG:tickPlayer_cl(dt)
	-- Check our penalty time decay
	if self.nextFire < GetTime() then
		self.accuracyPenalty = self.accuracyPenalty - dt
		self.accuracyPenalty = clamp(self.accuracyPenalty, 0.0, ACCURACY_MAXIMUM_PENALTY_TIME)
	end

	baseWeap.tickPlayer_cl(self, dt)
end