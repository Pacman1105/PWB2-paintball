-- CLIENT ENTITY

E_Gren = {}

--=========================================================================
-- Define the entity and it's variables
--=========================================================================

-- Static values for this specific entity
-- These don't need redefined in a entity if a var is just the default value found in baseEnt

--=========================================================================
-- Define the entity's static functions
--=========================================================================

function E_Gren:Sounds()
    return {}
end

function E_Gren:SpawnFlags()
    return addFlag(FENT_NONE, FENT_FAKEPHYSICS)
end

--=========================================================================
-- Entity's functions
--=========================================================================

function E_Gren:Spawn()
    self.think = self.Explode
    self.nextThink = GetTime() + 2.5
end

function E_Gren:Explode()
    self.origin = VecAdd(self.origin, Vec(0, 0.1, 0)) -- move out of ground

    -- PostEvent automatically syncs (I hate you)
    PostEvent("pb_explode", self.origin, self.owner)

    self:DeleteThis()
end

function E_Gren:PHYS_QuerySettings()
    QueryRequire('visible physical')
    QueryRejectBody(self.body)
    QueryRejectBody(GetToolBody(self.owner))
end

--=========================================================================
-- Custom creation functions
--=========================================================================

-- Fire a GL grenade
function E_Gren.Fire(transform, owner)
    if server then CurEntSlot = CurEntSlot + 1 return end

    local x, y, z = GetQuatEuler(transform.rot)

    local grenade = baseEnt:Create(E_Gren, transform.pos, Vec(x, y, z), owner)

    grenade:MDL_SET("MOD/models/xml/gren_m203.xml", 1)

	local angThrow = TransformToParentVec(transform, Vec(0, 0, -1))
    grenade.velocity = VecAdd(VecScale(angThrow, 20), Vec(0, 1.27, 0))

    return grenade
end

-- Throw a frag grenade
function E_Gren.Throw(origin, angles, velocity, time, owner)
    if server then CurEntSlot = CurEntSlot + 1 return end

    local grenade = baseEnt:Create(E_Gren, origin, nil, owner)

    grenade.flags = 0

    grenade.nextThink = GetTime() + time

    grenade.collideRadius = 0.1

    grenade.velocity = VecCopy(velocity)
    grenade:MDL_SET("MOD/models/xml/gren_frag.xml", 1)

    SetBodyTransform(grenade.body, Transform(origin, QuatEuler(angles[1], angles[2], angles[3])))
    SetBodyVelocity(grenade.body, velocity)
    SetBodyAngularVelocity(grenade.body, TransformToParentVec(GetBodyTransform(grenade.body), angles))
end