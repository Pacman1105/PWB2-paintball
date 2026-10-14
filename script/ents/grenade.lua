-- SERVER ENTITY

E_Gren = {}

function E_Gren:Sounds()
    return {}
end

function E_Gren:SpawnFlags()
    return addFlag(FENT_NONE, FENT_FAKEPHYSICS)
end

function E_Gren:Spawn()
    self.think = self.Explode
end

function E_Gren:Explode()
    self.origin = VecAdd(self.origin, Vec(0, 0.1, 0)) -- move out of ground

    --DebugPrint(client and " ENT CLIENT" or " ENT SERVER")
    -- PostEvent automatically syncs (I hate you)
    PostEvent("pb_explode", self.origin, self.owner)

    self:DeleteThis()
end

function E_Gren:QuerySettings()
    QueryRequire('visible physical')
    QueryRejectPlayer(self.owner)
    QueryRejectBody(self.body)
    QueryRejectBody(GetToolBody(self.owner))
end

function server.fireExplosive(transform, grenType, owner)
    if client then entTypeError() return end

    local x, y, z = GetQuatEuler(transform.rot)

    local rocket = baseEnt:Create(E_Gren, transform.pos, Vec(x, y, z), owner)

    if grenType == 1 then
        rocket:SetModel("MOD/models/xml/gren_m203.xml", 1)
    elseif grenType == 2 then
        rocket:SetModel("MOD/models/xml/gren_frag.xml", 1)
    else
        rocket:SetModel("MOD/models/xml/gren_m203.xml", 1)
        rocket.gravityMult = 0 -- fly STRAIHGHTB WAUGAIUGQIEI
    end

    local forward = Vec(0, 0, -1)
	local angThrow = TransformToParentVec(transform, forward)

    if grenType ~= 3 then
        rocket.nextThink = GetTime() + 2.5
        rocket.velocity = VecAdd(VecScale(angThrow, 20), Vec(0, 1.27, 0))
    else 
        rocket.nextThink = GetTime() + 10
        rocket.velocity = VecScale(angThrow, 40)
        rocket.touch = rocket.Explode
    end
end