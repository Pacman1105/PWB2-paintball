-- SHARED ENTITY

E_Rocket = {}

--=========================================================================
-- Define the entity and it's variables
--=========================================================================

-- Static values for this specific entity
-- These don't need redefined in a entity if a var is just the default value found in baseEnt

--=========================================================================
-- Define the entity's static functions
--=========================================================================

function E_Rocket:Sounds()
    return {}
end

function E_Rocket:SpawnFlags()
    return addFlag(FENT_NONE, FENT_FAKEPHYSICS)
end

--=========================================================================
-- Entity's functions
--=========================================================================

function E_Rocket:Spawn()
    self.think = self.Ignite
    self.nextThink = GetTime() + 0.33

    self.gravityMult = 0.75
end

function E_Rocket:Ignite()
    self.gravityMult = 0.05

    self.think = self.Fly
    self.nextThink = GetTime()
    self.startFlightTime = GetTime()
    self.velocity = self.idealVel
end

function E_Rocket:Fly()
    if self.startFlightTime + 8 <= GetTime() then
        self:Explode()
        return
    end

    if client then
        PointLight(self.origin, 0.7, 0.5, 0.3, 1)

        ParticleReset()
        ParticleRadius(0.2, 0.5)
        ParticleAlpha(5, 0, "easein")
        ParticleTile(1)
        ParticleColor(0.66, 0.66, 0.66)
        ParticleCollide(0)
        ParticleGravity(-0.1)
        for i=1, 4 do
            SpawnParticle(self.origin, Vec(), 0.66)
        end
    end

    self.nextThink = 0 -- think instantly
end

function E_Rocket:Explode()
    if client then
        self.origin = VecAdd(self.origin, Vec(0, 0.1, 0)) -- move out of ground

        -- PostEvent automatically syncs (I hate you)
        PostEvent("pb_explode", self.origin, self.owner)
    end

    self:DeleteThis()
end

function E_Rocket:PHYS_QuerySettings()
    QueryRequire('visible physical')
    QueryRejectBody(self.body)
    QueryRejectBody(GetToolBody(self.owner))
end

--=========================================================================
-- Custom creation functions
--=========================================================================

function E_Rocket.Fire(transform, owner)
    local x, y, z = GetQuatEuler(transform.rot)

    local rocket = baseEnt:Create(E_Rocket, transform.pos, Vec(x, y, z), owner)

    rocket:MDL_SET("MOD/models/xml/gren_m203.xml", 1)
    rocket.collideRadius = 0.02

    local angThrow = TransformToParentVec(transform, Vec(0, 0, -1))

    rocket.velocity = VecScale(angThrow, 10)
    rocket.idealVel = VecScale(VecNormalize(rocket.velocity), 50)

    rocket.touch = rocket.Explode

    return rocket
end