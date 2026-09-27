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

-- override initVars to add new variables
function C_Shtgn:initVars(owner)
	baseWeap.initVars(self, owner)

	if client and self.isLocal then
		self.body = 0
		self.slide = 0
		self.slideTransform = Transform()

		self.slideTime = nil
	end
end

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

function C_Shtgn:Holster()
	if client then
		client.PWB_ANIMATOR[self.owner].leftHand.transform.pos = Vec()
	end
end

function C_Shtgn:PrimaryAttack(dt)
	local mt = GetToolLocationWorldTransform("muzzle", self.owner)
	if not mt then return end

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

		self:muzzleFlash(mt.pos, 0.8, Vec(0.25, 0.25, 0.25))

		self.specialReload = 0

		self.pumpTime = GetTime() + 0.2333

		if self.ammoLoaded == 0 then
			self.timeWeaponIdle = 1
		end
	else
		PlayFireSound(self.snds["fire"], mt.pos, 300)
	end

	self:FirePaintballsPlayer(3, GetPlayerEyeTransform(self.owner).pos, GLOBAL_5DEGREES, 60, 75, 4)

	baseWeap.DepleteAmmo(self, 1, 1)

	self.nextFire = self:GetNextAttackDelay(0.6)
end

function C_Shtgn:Reload()
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
			self:MDL_PunchAng(Vec(0, 2, -10))
			PlaySound(self.snds["reload"], mt.pos, 300)
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

		PlayFireSound(self.snds["load"], mt.pos, 300)

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
				self.slideTime = 0
			end

			local mt = GetToolLocationWorldTransform("muzzle", self.owner)
			PlaySound(self.snds["pump"], mt.pos, 300)
		end
	end
end

function C_Shtgn:tickPlayer_cl(dt)
	if self.pumpTime > 0 and self.pumpTime <= GetTime() then
		local mt = GetToolLocationWorldTransform("muzzle", self.owner)

		PlaySound(self.snds["pump"], mt.pos, 300)

		if self.isLocal then
			self.slideTime = 0

			-- shell ejection
			client.TENT_EjectShell(self.owner, self.casingOrg, Vec(-0.875, -1.875, -0.625), "MOD/models/xml/shell/casing_shtgn.xml", FSFX_SHTGN)
		end

		self.pumpTime = 0
	end

	baseWeap.tickPlayer_cl(self, dt)
end

function C_Shtgn:MDL_CustomAnimate(dt)
	if not self.isLocal then return end

	--Animate Slide
	local GunBody = GetToolBody()
	if self.body ~= GunBody then
		self.body = GunBody
		-- Slide is the third shape in vox file. Remember original position in attachment frame
		local shapes = GetBodyShapes(GunBody)
		self.slide = shapes[2]
		self.slideTransform = GetShapeLocalTransform(self.slide)
	end

	if self.slide and self.slideTime ~= nil then
		self.slideTime = self.slideTime + dt

		local UseValue = self.slideTime

		-- don't go over, add a delay between the pump forward!
		if self.slideTime >= 0.375 then
			self.slideTime = 0.375
		elseif self.slideTime > 0.125 and self.slideTime < 0.25 then
			UseValue = 0.125 -- lock back for a little
		elseif self.slideTime >= 0.25 then
			UseValue = self.slideTime - 0.125
		end

		-- Slide has returned
		if self.slideTime >= 0.375 then
			SetShapeLocalTransform(self.slide, self.slideTransform) -- force back just in case
			self.slideTime = nil
		else
			local position = Vec(0, 0, 0.10 * math.sin(4 * math.pi * UseValue))
			local TOffset = Transform(position)
			client.PWB_ANIMATOR[self.owner].leftHand.transform.pos = position

			local t = TransformToParentTransform(TOffset, self.slideTransform)
			SetShapeLocalTransform(self.slide, t)
		end
	end
end