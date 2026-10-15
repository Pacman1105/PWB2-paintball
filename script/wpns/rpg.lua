C_RPG = {} -- goes in GLOBAL_WEAPONS

--=========================================================================
-- Define the weapon and it's variables
--=========================================================================

-- Static values for this specific weapon
-- These don't need redefined in a weapon if a var is just the default value found in baseWeap
C_RPG.model	= "rpg.xml" -- Path to the XML model file

C_RPG.toolID   = "pwb2_prpg"   	          -- Used by the engine. Lowercase and no spaces
C_RPG.toolName = "Paint Rocket Launcher" -- Shown in killfeed
C_RPG.toolSlot = 4
C_RPG.toolPos  = 1			   		      -- placement in the hud column

C_RPG.ammoLoadedMax    = -1	-- Max clip 	 	-- -1 for no clip (pulls from reserve)
C_RPG.ammoAltLoadedMax = 0 	-- Max alt clip 	-- -1 for no clip (pulls from reserve) 0 for no alt fire
C_RPG.ammoPickupSize   = 3 	-- Defaults to full mag

C_RPG.flags = addFlags(0, FWPN_SV_CALLONCE_PRIM,
						  FWPN_CLICK_PRIM) -- Weapon flags
C_RPG.snds  = 0 -- Prechached SFX list, set on INIT

--=========================================================================
-- Define the weapon's SFX / VFX
--=========================================================================

function C_RPG:Sounds()
	return {
		{"launcher_fire.ogg", "sv", "fire"},

		--{"sgreloadstart.ogg", "cl", "reload"},
	}
end

--=========================================================================
-- Weapon functions
--=========================================================================

function C_RPG:PrimaryAttack(dt)
	if client then
		if self.ammoTotal <= 0 then
			self:PlayEmptySound()
			return
		end

		self:MDL_PunchPos(Vec(0, 0.1, 0.2))

		if self.isLocal then
			self:ServerWpnCall("PrimaryAttack", dt)

			client.VFX_DynLight(self.owner, 30, 0.25, Vec(0.7, 0.5, 0.3), Vec(), "muzzle")

			self:MDL_PunchAngReset(-15)
			self:MDL_PunchAng(Vec(GetRandomFloat(4, 6), GetRandomFloat(-0.5, 0.5), GetRandomFloat(-2, 1)))

			client.PUNCH_Vec(Vec(5, GetRandomFloat(-0.5, 0.5), 0))
		end

		self:muzzleFlash(self.muzzle, 2, Vec(0.7, 0.5, 0.3))
	else
		PlayFireSound(self.snds["fire"], self.muzzle, 300)
	end

	E_Rocket.Fire(Transform(self.muzzle, GetPlayerEyeTransform(self.owner).rot), self.owner)

	baseWeap.DepleteAmmo(self, 1)

	self.nextFire = self:GetNextAttackDelay(1)
end