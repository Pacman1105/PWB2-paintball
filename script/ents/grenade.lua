-- CLIENT ENTITY

E_Gren = {}

function E_Gren:Sounds()
    return {}
end

function E_Gren:SpawnFlags()
    return addFlag(FENT_NONE, FENT_FAKEPHYSICS)
end

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

function E_Gren.Fire(transform, grenType, owner)
    if server then CurEntSlot = CurEntSlot + 1 return end

    local x, y, z = GetQuatEuler(transform.rot)

    local grenade = baseEnt:Create(E_Gren, transform.pos, Vec(x, y, z), owner)

    if grenType == 1 then
        grenade:MDL_SET("MOD/models/xml/gren_m203.xml", 1)
    else
        grenade:MDL_SET("MOD/models/xml/gren_frag.xml", 1)
    end

	local angThrow = TransformToParentVec(transform, Vec(0, 0, -1))
    grenade.velocity = VecAdd(VecScale(angThrow, 20), Vec(0, 1.27, 0))

    return grenade
end