C_Shtgn = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value found in baseWeap
C_Shtgn.model	  = "ithaca.xml" 		   -- Path to the XML model file
C_Shtgn.casingOrg = Vec(0.02, 0.066, 0.133) -- Where casings are ejected

C_Shtgn.toolID   = "pwb2_pshtgn"   -- Used by the engine. Lowercase and no spaces
C_Shtgn.toolName = "Paint Shotgun" -- Shown in killfeed
C_Shtgn.toolSlot = 3
C_Shtgn.toolPos	 = 3			   -- placement in the hud column

C_Shtgn.ammoLoadedMax 	 = 6				     -- Max clip 	 	-- -1 for no clip (pulls from reserve)
C_Shtgn.ammoAltLoadedMax = 0 					 -- Max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
C_Shtgn.ammoPickupSize	 = C_Shtgn.ammoLoadedMax -- Defaults to full mag
C_Shtgn.dmg_plyr		 = 0.3					 -- 0.0-1.0

C_Shtgn.flags = addFlags(0, FWPN_SV_CALLONCE_PRIM,
							FWPN_CLICK_PRIM) -- Weapon flags
C_Shtgn.snds = 0 -- Prechached SFX list, set on INIT

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function C_Shtgn:Sounds()
	return {
		{"fire_norm.ogg", 	  "sv", "fire"},

		{"sgcock.ogg", 		  "cl", "pump"},
		{"sgshellin0.ogg",    "cl", "load"},
		{"sgreloadstart.ogg", "cl", "reload"},
	}
end

--=========================================================================
-- Weapon functions
--=========================================================================

function C_Shtgn:PrimaryAttack(dt)
	if client then
		if self.ammoLoaded <= 0 then
			self:PlayEmptySound()
			self:Reload()
			return
		end

		self:MDL_PunchPos(Vec(0, 0.1, GetRandomFloat(0.15, 0.2)))

		if self.isLocal then
			self:ServerWpnCall("PrimaryAttack", dt)

			client.VFX_DynLight(self.owner, 30, 0.25, Vec(0.7, 0.5, 0.3), Vec(), "muzzle")

			self:MDL_PunchAngReset(-15)
			self:MDL_PunchAng(Vec(GetRandomFloat(2, 3), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-2, 1)))

			--client.PUNCHBASIC_Axis(1, 5)
			client.PUNCH_Vec(Vec(5, GetRandomFloat(-0.5, 0.5), 0))
		end

		self:muzzleFlash(self.muzzle, 0.8, Vec(0.25, 0.25, 0.25))

		self.specialReload = 0

		self.pumpTime = GetTime() + 0.2333

		if self.ammoLoaded == 0 then
			self.timeWeaponIdle = 1
		end
	else
		PlayFireSound(self.snds["fire"], self.muzzle, 300)
	end

	self:FirePaintballsPlayer(3, self.eyePos, GLOBAL_5DEGREES, 60, 75, 4)

	baseWeap.DepleteAmmo(self, 1, 1)

	self.nextFire = self:GetNextAttackDelay(0.6)
end

function C_Shtgn:Reload()
	if self.ammoTotal <= 0 or self.ammoLoaded == self.ammoLoadedMax then
		return end

	local curTime = GetTime()

	-- check to see if we're ready to reload
	if self.specialReload == 0 then
		-- don't reload until recoil is done
		if self.nextFire > curTime then
			return end

		if self.isLocal then
			self:MDL_PunchAng(Vec(0, 2, -10))
			PlaySound(self.snds["reload"], self.muzzle, 300)
		end

		if self.ammoLoaded == 0 then self.pumpTime = -1 end

		-- hold gun straight
		client.PWB_ANIMATOR[self.owner].timeSinceFire = 0.0

		self.specialReload = 1

		self.timeWeaponIdle = curTime + 0.6

		self.nextFire = self:GetNextAttackDelay(1.0)
	elseif self.specialReload == 1 then
		-- waiting for gun to move to side
		if self.timeWeaponIdle > curTime then
			return end

		self.ammoLoaded = self.ammoLoaded + 1

		self.specialReload = 2

		PlayFireSound(self.snds["load"], self.muzzle)

		self:MDL_PunchPos(Vec(0, 0.1, 0.1))
		if self.isLocal then
			self:MDL_PunchAng(Vec(GetRandomFloat(3, 4), GetRandomFloat(0, 1), GetRandomFloat(-6, -2)))
			client.PUNCH_Axis(3, -0.33)
			client.PUNCH_Axis(1, -0.33)
		end

		self.timeWeaponIdle = curTime + 0.6
	else
		self.specialReload = 1

		-- hold gun straight
		client.PWB_ANIMATOR[self.owner].timeSinceFire = 0.0
	end
end

function C_Shtgn:WeaponIdle()
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

		if self.pumpTime == -1 then
			self.pumpTime = 0

			-- reload debounce has timed out
			if self.isLocal then
				self:KF_SetAnim(C_Shtgn.ANIM_PUMP)
			end

			PlaySound(self.snds["pump"], self.muzzle)
		end
	end
end

function C_Shtgn:tickPlayer_cl(dt)
	if self.pumpTime > 0 and self.pumpTime <= GetTime() then
		PlaySound(self.snds["pump"], self.muzzle)

		if self.isLocal then
			self:KF_SetAnim(C_Shtgn.ANIM_PUMP)

			-- shell ejection
			client.TENT_EjectShell(self.owner, self.casingOrg, Vec(-0.875, -1.875, -0.625), "MOD/models/xml/shell/casing_shtgn.xml", FSFX_SHTGN)
		end

		self.pumpTime = 0
	end

	baseWeap.tickPlayer_cl(self, dt)
end