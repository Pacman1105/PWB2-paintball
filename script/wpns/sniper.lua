C_Sniper = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value found in baseWeap

C_Sniper.model	   = "m40a1.xml"		    -- Path to the XML model file
C_Sniper.casingOrg = Vec(0.01, 0.175, -0.1) -- Where casings are ejected

C_Sniper.toolID   = "pwb2_psniper" -- Used by the engine. Lowercase and no spaces
C_Sniper.toolName = "Paint Sniper" -- Shown in killfeed
C_Sniper.toolSlot = 6
C_Sniper.toolPos  = 1		   	   -- placement in the hud column

C_Sniper.ammoLoadedMax 	  = 2					   -- Max clip 	 	-- -1 for no clip (pulls from reserve)
C_Sniper.ammoAltLoadedMax = 0 					   -- Max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
C_Sniper.ammoAltItemID	  = 0 					   -- WpnID of item to drain ammo for when altfiring
C_Sniper.ammoPickupSize	  = C_Sniper.ammoLoadedMax -- Defaults to full mag
C_Sniper.dmg_plyr		  = 0.75				   -- 0.0-1.0

C_Sniper.flags= addFlags(0, FWPN_SV_CALLONCE_PRIM,
							FWPN_SV_CALLONCE_SEC,
							FWPN_CLICK_SEC) -- Weapon flags
C_Sniper.snds = 0 -- Prechached SFX list, set on INIT 

-- override initVars to add new variables
function C_Sniper:initVars(owner)
	baseWeap.initVars(self, owner)

	if server then
		self.ads = false
	end
end

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function C_Sniper:Sounds()
	return {
		{"fire_norm.ogg", "sv", "fire"},

		{"m40r.ogg",	  "cl", "reload_tac"		  },
		{"m40r.ogg",	  "cl", "reloadLoop_tac", true},
		{"m40rfll.ogg",   "cl", "reload"			  },
		{"m40rfll.ogg",   "cl", "reloadLoop", 	  true},

		{"m40bolt.ogg",	  "cl", "pump"},
	}
end

--=========================================================================
-- Weapon functions
--=========================================================================

function C_Sniper:Holster()
	if client then
		client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose = false
		if self.isLocal then client.FOV_set(1) end
	else
		self.ads = false
	end
end

function C_Sniper:PrimaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self.nextFire = GetTime() + 0.15
			return
		end

		if self.isLocal then
			self:ServerWpnCall("PrimaryAttack", 0, dt)

			client.VFX_DynLight(self.owner, 25, 0.1, Vec(0.7, 0.5, 0.3), Vec(), "muzzle")

			self:MDL_PunchAngReset(-4)
			if client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose then
				self:MDL_PunchAng(Vec(GetRandomFloat(1.5, 3), 0.5, GetRandomFloat(0, 0.33)))
			else
				self:MDL_PunchAng(Vec(GetRandomFloat(7, 8), 3, GetRandomFloat(0, 1)))
			end

			local punchVec = Vec(GetRandomFloat(0.0125, 0.025), GetRandomFloat(0.0, -0.0125), 0.3)
			client.PUNCH_Reset()
			for i=1, 3 do
				client.PUNCH_Axis(i, punchVec[4-i] * 10)
			end

			self:MDL_PunchPos(punchVec)
		else
			self:MDL_PunchPos(Vec(GetRandomFloat(-0.05, 0.05), GetRandomFloat(0.0, 0.025), GetRandomFloat(0.05, 0.1)))
		end

		self:muzzleFlash(mt.pos, 1.33, Vec(0.25, 0.25, 0.25))

		self.pumpTime = GetTime() + 0.5
	else
		PlayFireSound(self.snds["fire"], mt.pos, 300)
	end

	baseWeap.DepleteAmmo(self, 1, 1)

	local inAds = (server and self.ads) or (client and client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose)

	self:FirePaintballsPlayer(1, GetPlayerEyeTransform(self.owner).pos, inAds and 0 or GLOBAL_2DEGREES, 500, 300, 5)

	SetRandomSeed(shared.seed)
	AIM_RecoilAdd(self.owner, Vec(2, GetRandomFloat(-0.25, 1.33), 0))
	if server then shared.seed = GetRandomInt(0,10000) end

	self.nextFire = self:GetNextAttackDelay(1)
end

function C_Sniper:Reload()
	if self.ammoLoaded <= 0 then
		if not self:DefaultReload(3) then return end
	else
		if not self:DefaultReload(1.5) then return end
	end

	if self.isLocal then
		--self:KF_SetAnim(C_Sniper.ANIM_RELOAD)

		if self.ammoLoaded <= 0 then
			self:PlayFollowingSound(self.snds["reloadLoop"], 3.05)
		else
			self:PlayFollowingSound(self.snds["reloadLoop_tac"], 1.88)
		end

		if client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose then
			self:ServerWpnCall("SecondaryAttack", 0, false)
			client.FOV_set(1)
		end
	else
		if self.ammoLoaded <= 0 then
			PlaySound(self.snds["reload"], GetPlayerPos(self.owner), 1)
		else
			PlaySound(self.snds["reload_tac"], GetPlayerPos(self.owner), 1)
		end
	end

	client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose = false
end

function C_Sniper:SecondaryAttack(dt, ads)
	if client then
		ads = not client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose
		client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose = ads

		if self.isLocal then
			self:ServerWpnCall("SecondaryAttack", dt, ads)
			if ads then
				client.FOV_set(0.25)

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

	self.nextFire = self:GetNextAttackDelay(0.5)
	self.nextAltFire = self.nextFire
end

function C_Sniper:WeaponIdle()
	self.playEmptySound = true
end

function C_Sniper:tickPlayer_cl(dt)
	if self.isLocal then
		if client.PWB_ANIMATOR[self.owner].forceSecondaryActionPose then
			self.idleCycleScale = 0.05
		end
	end

	if self.pumpTime > 0 and self.pumpTime <= GetTime() then
		local mt = GetToolLocationWorldTransform("muzzle", self.owner)

		PlaySound(self.snds["pump"], mt.pos)

		self:MDL_PunchPos(Vec(0, 0.05, 0.1))
		if self.isLocal then
			self:MDL_PunchAng(Vec(GetRandomFloat(3, 4), GetRandomFloat(0, 1), GetRandomFloat(-6, -2)))
			client.PUNCH_Axis(3, -0.33)
			client.PUNCH_Axis(1, -0.33)

			self.slideTime = 0

			-- shell ejection
			client.TENT_EjectShell(self.owner, self.casingOrg, Vec(0, -0.85, 0), "MOD/models/xml/shell/casing_762.xml", FSFX_BRASS)
		end

		self.pumpTime = 0
	end

	baseWeap.tickPlayer_cl(self, dt)
end