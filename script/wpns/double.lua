C_Doub = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value found in baseWeap
C_Doub.model	 = "double.xml" -- Path to the XML model file

C_Doub.toolID   = "pwb2_pdoub"   	    -- Used by the engine. Lowercase and no spaces
C_Doub.toolName = "Paint Double Barrel" -- Shown in killfeed
C_Doub.toolSlot = 3
C_Doub.toolPos	= 2			   		    -- placement in the hud column

C_Doub.ammoLoadedMax 	= 2				       -- Max clip 	 	-- -1 for no clip (pulls from reserve)
C_Doub.ammoAltLoadedMax = 0 				   -- Max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
C_Doub.ammoPickupSize	= C_Doub.ammoLoadedMax -- Defaults to full mag
C_Doub.dmg_plyr		 	= 0.34				   -- 0.0-1.0

C_Doub.flags = addFlags(0, FWPN_SV_CALLONCE_PRIM,
						   FWPN_SV_CALLONCE_SEC,
						   FWPN_CLICK_PRIM,
						   FWPN_CLICK_SEC) -- Weapon flags
C_Doub.snds = 0 -- Prechached SFX list, set on INIT

-- override initVars to add new variables
function C_Doub:initVars(owner)
	baseWeap.initVars(self, owner)
end

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function C_Doub:Sounds()
	return {
		{"fire_norm.ogg", 	  "sv", "fire"},
		{"fire_heavy.ogg",	  "sv",	"fireAlt"},

		{"sgshellin0.ogg",    "cl", "load"},
		{"sgreloadstart.ogg", "cl", "reload"},
	}
end

--=========================================================================
-- Weapon functions
--=========================================================================

function C_Doub:Holster()
	if client then
		client.PWB_ANIMATOR[self.owner].leftHand.transform.pos = Vec()
	end
end

function C_Doub:PrimaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self:Reload()
			return
		end

		self:MDL_PunchPos(Vec(0, 0.1, 0.15))

		if self.isLocal then
			self:ServerWpnCall("PrimaryAttack", dt)

			client.VFX_DynLight(self.owner, 30, 0.25, Vec(0.7, 0.5, 0.3), Vec(), "muzzle")

			self:MDL_PunchAngReset(-15)
			self:MDL_PunchAng(Vec(GetRandomFloat(4, 6), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-2, 1)))

			client.PUNCH_Vec(Vec(5, GetRandomFloat(-0.5, 0.5), 0))
		end

		self:muzzleFlash(mt.pos, 0.8, Vec(0.25, 0.25, 0.25))

		self.specialReload = 0

		if self.ammoLoaded == 0 then
			self.timeWeaponIdle = 1
		end
	else
		PlayFireSound(self.snds["fire"], mt.pos, 300)
	end

	self:FirePaintballsPlayer(4, GetPlayerEyeTransform(self.owner).pos, GLOBAL_15DEGREES, 60, 100, 4)

	baseWeap.DepleteAmmo(self, 1, 1)

	self.nextFire = self:GetNextAttackDelay(0.1)
	self.nextAltFire = self.nextFire
end

function C_Doub:SV_DontFireAltCond()
	return self.ammoLoaded ~= 2
end

function C_Doub:SecondaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self:Reload()
			return
		end

		self:MDL_PunchPos(Vec(0.1, 0.1, 0.2))

		if self.isLocal then
			self:ServerWpnCall("SecondaryAttack", dt)

			client.VFX_DynLight(self.owner, 30, 0.25, Vec(0.7, 0.5, 0.3), Vec(), "muzzle")

			self:MDL_PunchAngReset(-15)
			self:MDL_PunchAng(Vec(10, 3, -3))

			client.PUNCH_Vec(Vec(10, GetRandomFloat(1, 1), 0))
		end

		self:muzzleFlash(mt.pos, 0.9, Vec(0.33, 0.33, 0.33))

		self.specialReload = 0

		if self.ammoLoaded == 0 then
			self.timeWeaponIdle = 1
		end
	else
		PlayFireSound(self.snds["fireAlt"], mt.pos, 300)
	end

	self:FirePaintballsPlayer(8, GetPlayerEyeTransform(self.owner).pos, GLOBAL_20DEGREES, 60, 100, 4)

	baseWeap.DepleteAmmo(self, 2, 2)

	self.nextFire = self:GetNextAttackDelay(0.5)
	self.nextAltFire = self.nextFire
end

function C_Doub:Reload()
	if self.ammoTotal <= 0 or self.ammoLoaded == self.ammoLoadedMax then
		return end

	local curTime = GetTime()

	local mt = GetToolLocationWorldTransform("muzzle", self.owner)

	-- check to see if we're ready to reload
	if self.specialReload == 0 then
		-- don't reload until recoil is done
		if self.nextFire > curTime then
			return end

		if self.isLocal then
			self:KF_SetAnim(C_Doub.ANIM_RELOADSTART)
			self:MDL_PunchAng(Vec(-5, 0, 0))
			self:MDL_PunchPos(Vec(0, -0.1, 0))
			PlaySound(self.snds["reload"], mt.pos, 300)
		end

		-- hold gun straight
		client.PWB_ANIMATOR[self.owner].timeSinceFire = 0.0

		self.specialReload = 1

		self.timeWeaponIdle = curTime + 0.6

		self.nextFire = self:GetNextAttackDelay(2.2)
		self.nextAltFire = self.nextFire
	elseif self.specialReload == 1 then
		-- waiting for gun to move to side
		if self.timeWeaponIdle > curTime then
			return end

		self.ammoLoaded = self.ammoLoaded + 1

		self.specialReload = 2

		PlayFireSound(self.snds["load"], mt.pos, 300)

		self:MDL_PunchPos(Vec(0, 0, 0.1))
		if self.isLocal then
			self:MDL_PunchAng(Vec(GetRandomFloat(-3, -4), GetRandomFloat(0, 1), 0))
			client.PUNCH_Axis(3, -0.33)
			client.PUNCH_Axis(1, -0.33)
		end

		self.timeWeaponIdle = curTime + 0.4
	else
		self.specialReload = 1

		-- hold gun straight
		client.PWB_ANIMATOR[self.owner].timeSinceFire = 0.0
	end
end

function C_Doub:WeaponIdle()
	if server then return end

	self.playEmptySound = true

	local curTime = GetTime()

	if self.timeWeaponIdle > curTime then
		return
	end

	if self.ammoLoaded == 0 and self.specialReload == 0 and self.ammoLoaded ~= self.ammoTotal then
		self:Reload()
	elseif self.specialReload ~= 0 then
		if self.ammoLoaded ~= self.ammoLoadedMax and self.ammoLoaded ~= self.ammoTotal then
			self:Reload()
			return
		end

		self.specialReload = 0
		self.timeWeaponIdle = curTime + 1.5

		if self.isLocal then
			--self.slideTime = 0
			local mt = GetToolLocationWorldTransform("muzzle", self.owner)
			self:KF_SetAnim(C_Doub.ANIM_RELOADEND)
			self:MDL_PunchAng(Vec(5, 0, 0))
			self:MDL_PunchPos(Vec(0, 0.1, 0))
			PlaySound(self.snds["reload"], mt.pos, 300)
		end

		if self.pumpTime == -1 then
			self.pumpTime = 0

			-- reload debounce has timed out
			if self.isLocal then
				self.slideTime = 0
			end

			local mt = GetToolLocationWorldTransform("muzzle", self.owner)
			PlaySound(self.snds["pump"], mt.pos, 300)
		end
	end
end