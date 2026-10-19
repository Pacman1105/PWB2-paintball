C_SLAM = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value found in baseWeap
C_SLAM.model	= "slam.xml" -- Path to the XML model file

C_SLAM.toolID   = "pwb2_pslam"    -- Used by the engine. Lowercase and no spaces
C_SLAM.toolName = "Paint S.L.A.M" -- Shown in killfeed
C_SLAM.toolSlot = 4
C_SLAM.toolPos  = 4			   	  -- placement in the hud column

C_SLAM.ammoLoadedMax    = -1 -- Max clip 	 	-- -1 for no clip (pulls from reserve)
C_SLAM.ammoAltLoadedMax = 0  -- Max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
C_SLAM.ammoPickupSize   = 3  -- Defaults to full mag

C_SLAM.flags = addFlags(0, FWPN_SV_CALLONCE_PRIM,
						   FWPN_SV_CALLONCE_SEC,
						   FWPN_CLICK_PRIM,
						   FWPN_CLICK_SEC,
						   FWPN_NOALTACTIONPOSE) -- Weapon flags
C_SLAM.snds  = 0 -- Prechached SFX list, set on INIT

-- override initVars to add new variables
function C_SLAM:initVars(owner)
	baseWeap.initVars(self, owner)

	if client then
		self.swingNumb 	  = -1 -- 1-3
	end
end

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function C_SLAM:Sounds()
	return {
		{"slam_throw.ogg", "sv", "throw"},
		{"slam_place.ogg", "sv", "place"},
	}
end

--=========================================================================
-- Weapon functions
--=========================================================================
C_SLAM.Satchels = {}

-- Remove satchels
function C_SLAM:Destroy(completely)
	if not completely then return end

	if not C_SLAM.Satchels[self.owner] then
		return
	end

	for index, satchel in pairs(C_SLAM.Satchels[self.owner]) do
		satchel.think = satchel.DeleteThis -- would be funnier to make it explode ngl
		satchel.nextThink = GetTime()
	end

	C_SLAM.Satchels[self.owner] = nil -- might be redudant
end

function C_SLAM:Deploy()
	if client then
		client.PWB_ANIMATOR[self.owner].maxActionPoseTime = 0.1
		client.PWB_ANIMATOR[self.owner].timeSinceFire = 99999 -- don't do throw pose
	end
end

function C_SLAM:Holster()
	if client then
		client.PWB_ANIMATOR[self.owner].maxActionPoseTime = 5.0
	end
end

function C_SLAM:PrimaryAttack(dt)
	if client then
		if self.ammoTotal <= 0 then
			self.nextFire = GetTime() + 0.15
			return
		end

		self.swingNumb = self.swingNumb - 1
		if self.swingNumb == -4 then self.swingNumb = -1 end
		client.PWB_ANIMATOR[self.owner].timeSinceFire = 0.0

		if self.isLocal then
			self:ServerWpnCall("PrimaryAttack", dt)
		end
	end

	local _,pos,_,angThrow = GetPlayerAimInfo(self.eye.pos, 3.0, self.owner)

	local hit, dist, normal = QueryRaycast(pos, TransformToParentVec(self.eye, Vec(0, 0, -1)), 3.0)

	if hit then -- place tripmine
		local GrenTrans = Transform(VecAdd(pos, VecScale(TransformToParentVec(self.eye, Vec(0, 0, -1)), dist + 0.1)), QuatLookAt(Vec(), normal))

		PlaySound(self.snds["place"], GrenTrans.pos, 0.7)

		E_SLAM.Place(GrenTrans, self.owner)
	elseif client then -- throw as satchel
		pos = VecAdd(pos, VecScale(angThrow, 0.25))

		local velocity = VecAdd(GetPlayerVelocity(self.owner), VecScale(angThrow, 6.96))

		local GrenTrans = Transform(pos, QuatLookAt(Vec(), TransformToParentVec(self.eye, Vec(0, 1, 0))))

		if not C_SLAM.Satchels[self.owner] then C_SLAM.Satchels[self.owner] = {} end

		local satchel = E_SLAM.Throw(GrenTrans, velocity, self.owner)
		table.insert(C_SLAM.Satchels[self.owner], satchel)

		PlaySound(self.snds["throw"], self.muzzlePos, 0.7)
	else
		CurEntSlot = CurEntSlot + 1
	end

	baseWeap.DepleteAmmo(self, 1)

	self.nextFire = self:GetNextAttackDelay(1)
end

-- Explode satchels
function C_SLAM:SecondaryAttack(dt)
	if C_SLAM.Satchels[self.owner] then
		for index, satchel in pairs(C_SLAM.Satchels[self.owner]) do
			satchel.think = satchel.Explode
			satchel.nextThink = GetTime() + GetRandomFloat(0.25, 0.75)

			PlaySound(satchel.snds["activate"], satchel.origin)

			-- Have to remove this reference manually
			-- DeleteThis() should be doing it by itself
			-- However it's just not.
			C_SLAM.Satchels[self.owner][index] = nil
		end
	end

	self.nextAltFire = self:GetNextAttackDelay(1)
end

function C_SLAM:MDL_CallAnimator(dt)
	tickToolAnimator(client.PWB_ANIMATOR[self.owner], dt, nil, self.owner, self.swingNumb, nil, true)
end