-- SERVER ENTITY

E_SLAM = {}

--=========================================================================
-- Define the entity and it's variables
--=========================================================================

-- Static values for this specific entity
-- These don't need redefined in a entity if a var is just the default value found in baseEnt

--=========================================================================
-- Define the entity's static functions
--=========================================================================

function E_SLAM:Sounds()
    return {
		{"mine_activate.ogg", "sv", "activate"},
	}
end

--=========================================================================
-- Entity's functions
--=========================================================================

function E_SLAM:Spawn()
end

function E_SLAM:Activate()
    if client and not E_SLAM.laserSPR then
        E_SLAM.laserSPR = LoadSprite("gfx/laser.png")
    end

    PlaySound(self.snds["activate"], self.origin)

    self.bodyTransform = Transform(self.origin)

    self.think = self.Tripwire
    self.nextThink = 0
end

local END_SPRITE = false
local function endSpr(pos, size, color)
	color = color or Vec(1, 1, 1)
	local t = Transform(pos, GetCameraTransform().rot)

	if not END_SPRITE then END_SPRITE = LoadSprite("gfx/glare.png") end

	DrawSprite(END_SPRITE, t, size, size, color[1], color[2], color[3], 0.125, true, true, true)
end

function E_SLAM:Tripwire()
    -- Must save this because server gets deleted before client explodes
    if IsHandleValid(self.body) then
        self.bodyTransform = GetBodyTransform(self.body)
    end

    self.nextThink = 0

    local raycastStartTrans = TransformToParentTransform(self.bodyTransform, Transform(Vec(-0.14, 0.2, -0.3), self.bodyTransform.rot))
    local direction = TransformToParentVec(self.bodyTransform, Vec(0, 0, -1))

    QueryRejectBody(self.body)
    QueryInclude("player")
    local _, pDist = QueryRaycast(raycastStartTrans.pos, direction, 48, 0.0, true)

    if not self.laserDist then self.laserDist = pDist end

    -- Check explode conditions
    if server and math.abs(pDist - self.laserDist) > 0.25 then self:Explode() return end
    if IsBodyBroken(self.body) or not IsHandleValid(self.body) then self:Explode() return end

    if client then
        local laserStartTrans = TransformToParentTransform(self.bodyTransform, Transform(Vec(-0.14, 0.2, -0.21), self.bodyTransform.rot))
        local laserStartVec = laserStartTrans.pos

        local endPos = VecAdd(laserStartVec, VecScale(direction, pDist))
        local t = Transform(VecLerp(laserStartVec, endPos, 0.5))

		local xAxis = VecNormalize(VecSub(VecAdd(laserStartVec, VecScale(direction, pDist)), laserStartVec))
		local zAxis = VecNormalize(VecSub(laserStartVec, GetCameraTransform().pos))

		t.rot = QuatAlignXZ(xAxis, zAxis)

        -- Draw the laser, mix in a DrawLine to make it contrast
		DrawSprite(E_SLAM.laserSPR, t, pDist, 0.04, 1.0, 0.0, 0.0, 0.125, true, true)
        DrawLine(laserStartVec, endPos, 1.0, 0.0, 0.0, 0.1)

        -- Draw flares at the beginning and end
		endSpr(endPos, 0.4, Vec(1, 0, 0))
        endSpr(laserStartVec, 0.4, Vec(1, 0, 0))
    end
end

function E_SLAM:Explode()
    if self.hit then return end

    self.hit = true

    -- PostEvent automatically syncs (I hate you)
    if client then
        if not self.laserDist then
            self.bodyTransform = GetBodyTransform(self.body)
        end

        local laserMineOrg = TransformToParentTransform(self.bodyTransform, Transform(Vec(-0.14, 0.2, -0.3), self.bodyTransform.rot))
        self.origin = self.laserDist and laserMineOrg.pos or VecAdd(self.origin, Vec(0, 0.1, 0)) -- move out of ground

        local dir = self.laserDist and TransformToParentVec(self.bodyTransform, Vec(0, 0, -1)) or false

        PostEvent("pb_explode", self.origin, self.owner, dir)
    end

    self:DeleteThis()
end

--=========================================================================
-- Custom creation functions
--=========================================================================

-- Place a tripmine
function E_SLAM.Place(transform, owner)
    local grenade = baseEnt:Create(E_SLAM, transform.origin, nil, owner)

    grenade.flags = 0

    grenade:MDL_SET_SV("MOD/models/xml/gren_trip.xml", 1, false, true, transform)

    grenade.think = grenade.Activate
    grenade.nextThink = GetTime() + 2.5

    SetBodyTransform(grenade.body, transform)
    return grenade
end

-- Throw a satchel
function E_SLAM.Throw(transform, velocity, owner)
    local x, y, z = GetQuatEuler(transform.rot)
    local grenade = baseEnt:Create(E_SLAM, transform.pos, Vec(x,y,z), owner)

    grenade:MDL_SET("MOD/models/xml/gren_satch.xml", 1)

    SetTag(grenade.body, "thrownSlam")

    SetBodyVelocity(grenade.body, velocity)
    SetBodyAngularVelocity(grenade.body, TransformToParentVec(GetPlayerEyeTransform(owner), Vec(0, 10.16, 0)))

    return grenade
end