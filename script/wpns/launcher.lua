C_GL = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value found in baseWeap
C_GL.model	  = "launcher.xml" -- Path to the XML model file

C_GL.toolID   = "pwb2_pgl"   	         -- Used by the engine. Lowercase and no spaces
C_GL.toolName = "Paint Grenade Launcher" -- Shown in killfeed
C_GL.toolSlot = 4
C_GL.toolPos  = 1			   		     -- placement in the hud column

C_GL.ammoLoadedMax 	  = 6				   -- Max clip 	 	-- -1 for no clip (pulls from reserve)
C_GL.ammoAltLoadedMax = 0 				   -- Max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
C_GL.ammoPickupSize	  = C_GL.ammoLoadedMax -- Defaults to full mag
C_GL.dmg_plyr		  = 0.34			   -- 0.0-1.0

C_GL.flags = addFlags(0, FWPN_SV_CALLONCE_PRIM,
						 FWPN_CLICK_PRIM) -- Weapon flags
C_GL.snds  = 0 -- Prechached SFX list, set on INIT

-- override initVars to add new variables
function C_GL:initVars(owner)
	baseWeap.initVars(self, owner)

	if self.isLocal then
		self.body = nil
		self.cylinder = nil
		self.cylTransform = nil
		self.cylAngle = 0.0
		self.TargetCylAngle = 0.0
	end
end

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function C_GL:Sounds()
	return {
		{"launcher_fire.ogg", "sv", "fire"},

		{"sgshellin0.ogg",    "cl", "load"},
		{"sgreloadstart.ogg", "cl", "reload"},
	}
end

--=========================================================================
-- Weapon functions
--=========================================================================

function C_GL:PrimaryAttack(dt)
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

			self.TargetCylAngle = self.cylAngle + 60
		end

		self:muzzleFlash(self.muzzle, 0.8, Vec(0.25, 0.25, 0.25))

		self.specialReload = 0

		if self.ammoLoaded == 0 then
			self.timeWeaponIdle = 1
		end
	else
		PlayFireSound(self.snds["fire"], self.muzzle, 300)
	end

	self:FirePaintballsPlayer(4, self.eyePos, GLOBAL_15DEGREES, 60, 100, 4)

	baseWeap.DepleteAmmo(self, 1, 1)

	self.nextFire = self:GetNextAttackDelay(0.66)
	self.nextAltFire = self.nextFire
end

function C_GL:Reload()
	if self.ammoTotal <= 0 or self.ammoLoaded == self.ammoLoadedMax then
		return end

	local curTime = GetTime()

	-- check to see if we're ready to reload
	if self.specialReload == 0 then
		-- don't reload until recoil is done
		if self.nextFire > curTime then
			return end

		if self.isLocal then
			--self:KF_SetAnim(C_GL.ANIM_RELOADSTART)
			self:MDL_PunchAng(Vec(-5, 0, 0))
			self:MDL_PunchPos(Vec(0, -0.1, 0))
			PlaySound(self.snds["reload"], self.muzzle, 300)
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

		PlayFireSound(self.snds["load"], self.muzzle)
		self.TargetCylAngle = self.cylAngle - 60

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

function C_GL:WeaponIdle()
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
			--self:KF_SetAnim(C_GL.ANIM_RELOADEND)
			self:MDL_PunchAng(Vec(5, 0, 0))
			self:MDL_PunchPos(Vec(0, 0.1, 0))
			PlaySound(self.snds["reload"], self.muzzle, 300)
		end
	end
end

-- This can't be done (non-wastefully) using the keyframe system
function C_GL:MDL_CustomAnimate(dt)
	if self.isLocal then
		--Animate Slide
		local GunBody = GetToolBody()
		local voxSize = 0.01
		local attach = Transform(Vec(0.5*voxSize, 0.5*voxSize, 0))
		if self.body ~= GunBody then
			self.body = GunBody
			-- Slide is the fourth shape in vox file. Remember original position in attachment frame
			local shapes = GetBodyShapes(GunBody)
			self.cylinder = shapes[4]
			self.cylTransform = GetShapeLocalTransform(self.cylinder)
		end

		if self.cylinder ~= 0 and self.TargetCylAngle ~= self.cylAngle then
			self.cylAngle = lerp(self.cylAngle, self.TargetCylAngle, 10*dt)
			attach.rot = QuatEuler(0, 0, -self.cylAngle)

			local t = TransformToParentTransform(attach, self.cylTransform)
			SetShapeLocalTransform(self.cylinder, t)
		end
	end
end