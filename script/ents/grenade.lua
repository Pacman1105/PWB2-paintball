-- SERVER ENTITY

E_Gren = {}

function E_Gren:Sounds()
    return {}
end

function E_Gren:SpawnFlags()
    return addFlag(FENT_NONE, FENT_FAKEPHYSICS)
end

function E_Gren:Spawn()
    self:SetModel("MOD/models/xml/gren_m203.xml", 1)

    self.nextThink = GetTime() + 2.5

    self.think = self.Explode -- either a string or func
    self.touch = self.testTouch
end

function E_Gren:Explode()
    self.origin = VecAdd(self.origin, Vec(0, 0.1, 0)) -- move out of ground

    --DebugPrint(client and " ENT CLIENT" or " ENT SERVER")
    -- PostEvent automatically syncs (I hate you)
    PostEvent("pb_explode", self.origin, self.owner)

    self:DeleteThis()
end

function E_Gren:testTouch()
    DebugPrint("TOUCHED")
    local dist, shape, player, normal = self:GetTouchTrace()
    DebugPrint(dist .. " " .. shape .. " " .. player .. " " .. VecStr(normal))
end

function E_Gren:CollisionSettings()
    QueryRequire('visible physical')
    QueryRejectPlayer(self.owner)
    QueryRejectBody(self.body)
    QueryRejectBody(GetToolBody(self.owner))
end

function server.fireGrenade(transform, owner)
    if client then entTypeError() return end

    local x, y, z = GetQuatEuler(transform.rot)
    local rocket = baseEnt:new(E_Gren, transform.pos, Vec(x, y, z), owner)

    local forward = Vec(0, 0, -1)
	local angThrow = TransformToParentVec(transform, forward)

    rocket.velocity = VecAdd(VecScale(angThrow, 20), Vec(0, 1.27, 0))
end