C_Pistol = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value found in baseWeap

C_Pistol.model	   = "usp.xml" -- Path to the XML model file

C_Pistol.toolID   = "pwb2_ppistol"  -- Used by the engine. Lowercase and no spaces
C_Pistol.toolName = "Paint Pistol" -- Shown in killfeed
C_Pistol.toolSlot = 3
C_Pistol.toolPos  = 5		   -- placement in the hud column

C_Pistol.ammoLoadedMax 	  = 10					   -- Max clip 	 	-- -1 for no clip (pulls from reserve)
C_Pistol.ammoAltLoadedMax = 0 					   -- Max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
C_Pistol.ammoAltItemID	  = 0 					   -- WpnID of item to drain ammo for when altfiring
C_Pistol.ammoPickupSize	  = C_Pistol.ammoLoadedMax -- Defaults to full mag
C_Pistol.dmg_plyr		  = 0.3				   -- 0.0-1.0

C_Pistol.flags= addFlags(0, FWPN_SV_CALLONCE_PRIM,
							FWPN_SV_CALLONCE_SEC,
							FWPN_CLICK_SEC) -- Weapon flags
C_Pistol.snds = 0 -- Prechached SFX list, set on INIT 

local ACCURACY_SHOT_PENALTY_TIME	= 0.2	-- Applied amount of time each shot adds to the time we must recover from
local ACCURACY_MAXIMUM_PENALTY_TIME	= 1.5	-- Maximum penalty to deal out

-- override initVars to add new variables
function C_Pistol:initVars(owner)
	baseWeap.initVars(self, owner)

	self.soonestFire = math.huge -- Don't use this value until fire
	self.accuracyPenalty = 0

	if server then
		self.ads = false
	end
end

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function C_Pistol:Sounds()
	return {
		{"fire_light.ogg",    "sv", "fire"  },
		{"pistol_reload.ogg", "cl", "reload"},
		{"pistol_reload.ogg", "cl", "reloadLoop", true}
	}
end

--=========================================================================
-- Weapon functions
--=========================================================================

function C_Pistol:Holster()
	self.soonestFire = math.huge -- Don't use this value until fire

	if client then
		client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose = false
		if self.isLocal then client.FOV_set(1) end
	else
		self.ads = false
	end
end

function C_Pistol:GetPlayerSpread()
	local ramp = RemapValClamped(	self.accuracyPenalty,
							    	0.0,
							    	ACCURACY_MAXIMUM_PENALTY_TIME,
							    	0.0,
							    	1.0 )

	-- We lerp from very accurate to inaccurate over time
	return Lerp(GLOBAL_2DEGREES, GLOBAL_7DEGREES, ramp)
end

function C_Pistol:PrimaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self.nextFire = GetTime() + 0.15
			self.soonestFire = self.nextFire
			return
		end

		if self.isLocal then
			self:ServerWpnCall("PrimaryAttack", 0, dt)

			self:KF_SetAnim(C_Pistol.ANIM_FIRE)

			client.VFX_DynLight(self.owner, 25, 0.1, Vec(0.7, 0.5, 0.3), Vec(), "muzzle")

			self:MDL_PunchAngReset(-4)
			if client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose then
				self:MDL_PunchAng(Vec(GetRandomFloat(1.5, 3), 0.5, GetRandomFloat(0, 0.33)))
			else
				self:MDL_PunchAng(Vec(GetRandomFloat(7, 8), 3, GetRandomFloat(0, 1)))
			end

			local punchVec = Vec(GetRandomFloat(0.0125, 0.025), GetRandomFloat(0.0, -0.0125), 0.15)
			client.PUNCH_Reset()
			for i=1, 3 do
				client.PUNCH_Axis(i, punchVec[4-i] * 10)
			end

			self:MDL_PunchPos(punchVec)
		else
			self:MDL_PunchPos(Vec(GetRandomFloat(-0.05, 0.05), GetRandomFloat(0.0, 0.025), GetRandomFloat(0.05, 0.1)))
		end

		self:muzzleFlash(mt.pos, 1, Vec(0.25, 0.25, 0.25))
	else
		PlayFireSound(self.snds["fire"], mt.pos, 300)
	end

	baseWeap.DepleteAmmo(self, 1, 1)

	local inAds = (server and self.ads) or (client and client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose)
	local spread = self:GetPlayerSpread() * (inAds and 0.25 or 1)

	self:FirePaintballsPlayer(1, GetPlayerEyeTransform(self.owner).pos, spread, 100, 150, 5)

	self.accuracyPenalty = self.accuracyPenalty + ACCURACY_SHOT_PENALTY_TIME

	SetRandomSeed(shared.seed)
	AIM_RecoilAdd(self.owner, Vec(2, GetRandomFloat(-0.25, 1.33), 0))
	if server then shared.seed = GetRandomInt(0,10000) end

	self.nextFire = self:GetNextAttackDelay(0.5)
	self.soonestFire = GetTime() + 0.075
end

function C_Pistol:Reload()
	if not self:DefaultReload(1.433) then return end
	self.soonestFire = math.huge

	if self.isLocal then
		--self:KF_SetAnim(C_Pistol.ANIM_RELOAD)

		self:PlayFollowingSound(self.snds["reloadLoop"], 0.9)

		if client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose then
			self:ServerWpnCall("SecondaryAttack", 0, false)
			client.FOV_set(1)
		end
	else
		PlaySound(self.snds["reload"], GetPlayerPos(self.owner), 1)
	end

	client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose = false
end

function C_Pistol:SecondaryAttack(dt, ads)
	if client then
		ads = not client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose
		client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose = ads

		if self.isLocal then
			self:ServerWpnCall("SecondaryAttack", dt, ads)
			if ads then
				client.FOV_set(0.9)

				self:MDL_PunchAngReset()
				self:MDL_PunchAng(Vec(-1, 0, 0.5))
			else
				client.FOV_set(1)

				self:MDL_PunchAngReset()
				self:MDL_PunchAng(Vec(1, 0, -0.5))
			end
		end
	else
		self.ads = ads
	end

	self.nextFire = self:GetNextAttackDelay(0.33)
	self.nextAltFire = self.nextFire
end

function C_Pistol:WeaponIdle()
	self.playEmptySound = true
end

function C_Pistol:tickPlayer_sv(dt)
	if not InputDown("usetool", self.owner) and self.soonestFire < GetTime() then
		self.nextFire = 0
	end

	-- Check our penalty time decay
	if self.nextFire < GetTime() then
		self.accuracyPenalty = self.accuracyPenalty - dt
		self.accuracyPenalty = clamp(self.accuracyPenalty, 0.0, ACCURACY_MAXIMUM_PENALTY_TIME)
	end

	baseWeap.tickPlayer_sv(self, dt)
end

function C_Pistol:tickPlayer_cl(dt)
	if not InputDown("usetool", self.owner) and self.soonestFire < GetTime() then
		self.nextFire = 0
	end

	-- Check our penalty time decay
	if self.nextFire < GetTime() then
		self.accuracyPenalty = self.accuracyPenalty - dt
		self.accuracyPenalty = clamp(self.accuracyPenalty, 0.0, ACCURACY_MAXIMUM_PENALTY_TIME)
	end

	if self.isLocal then
		if client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose then
			self.idleCycleScale = 0.05
		end
	end

	baseWeap.tickPlayer_cl(self, dt)
end