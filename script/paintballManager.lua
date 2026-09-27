gpPaintballs = {}
gpDroplets = {}

giCurrDroplets = 0

local MAX_DROPLETS = 600

local function newCLent()
	return {
		--entity_state_t curstate,  -- The state information from the last message received from server

		-- float
		nextThink = 0.0,

		-- Actual render position and angles
		origin = Vec(),
		prevOrigin = Vec(),
		velocity = Vec(),

		traveled = 0,

		owner = -1,
	}
end

local function newPaintBall()
	return {
		-- floats
		die = 0,
		bounceFactor = 1.0,

		paintAmnt = 1, -- Depletes on hit / reflect, paintball is spent once it reaches zero. Damage is based on this

		gunName = "",

		damage = 0,

		color = Vec(1, 0.75, 0),
		colorIsBlack = false,

		entity = newCLent(),
	}
end

function AllocPaintball(org)
	local pPB = newPaintBall()

	pPB.die = 0
	pPB.entity.origin = VecCopy(org)

	local index = findArrayOpening(gpPaintballs)
	gpPaintballs[index] = pPB

	return gpPaintballs[index]
end

function paintBallUpdate(
    frametime,	-- Simulation time
	cl_gravity)	-- True gravity on client

    local uselength = #gpPaintballs
	if uselength == 0 then
		return end

	local client_time = GetTime()

    for i = 1, uselength do
		local pPB = gpPaintballs[i] -- this errors sometimes, seemingly when one is deleted?
		if pPB ~= nil then
			if pPB.die - client_time < 0 then
				table.remove(gpPaintballs, i)
			else
				pPB.entity.prevOrigin = VecCopy(pPB.entity.origin)

				for j = 1, 3 do
					pPB.entity.origin[j] = pPB.entity.origin[j] + (pPB.entity.velocity[j] * frametime)
				end

				local gravity = -frametime * cl_gravity

				-- COLLISIONS
				local betweenDir = VecNormalize(pPB.entity.velocity)
				local betweenLen = VecLength(pPB.entity.velocity) * frametime

				QueryInclude("player")
				QueryInclude("animator") -- this causes LAG, as in LAG (as in LAG [as in LAG])
				QueryRejectPlayer(pPB.entity.owner)
				local hit, dist, traceNormal = QueryRaycast(pPB.entity.prevOrigin, betweenDir, betweenLen)

				if hit == true then
					local proj, damp

					-- Place at contact point
					pPB.entity.origin = VecAdd(pPB.entity.prevOrigin, VecScale(betweenDir, dist))
					pPB.entity.origin = VecAdd(pPB.entity.origin, VecScale(traceNormal, 0.01))

					-- Damp velocity
					damp = pPB.bounceFactor
					damp = damp * 0.5
					if traceNormal[2] > 0.9 then -- Hit floor?
						if pPB.entity.velocity[2] <= 0 and pPB.entity.velocity[2] >= gravity * 2 then
							damp = 0 -- Stop
						end
					end

					if client and damp > 0 and betweenLen / frametime > 1 then
						PlaySound(LoadSound("MOD/snd/crbr_hitplayer0.ogg"), pPB.entity.origin, damp / 2)
					end

					-- Reflect velocity
					if damp ~= 0 then
						proj = VecDot(pPB.entity.velocity, traceNormal)
						local hitDot = VecDot(traceNormal, VecNormalize(pPB.entity.velocity))

						if hitDot < -0.0871 then  -- Impact
							pPB.die = client_time

							local didHit, impdist, shape, playerHit, _, traceNormal2 = QueryShot(pPB.entity.prevOrigin, betweenDir, betweenLen, 0, pPB.entity.owner)
							if didHit then
								if server then
									local body = GetShapeBody(shape)

									if playerHit ~= 0 then
										ApplyPlayerDamage(playerHit, pPB.damage, pPB.gunName, pPB.entity.owner)
									elseif shape ~= 0 then
										if HasTag(body, "grenStyle") then
											SetTag(body, "pb_detonate")
										end
									end

									if pPB.colorIsBlack == false then
										for i = 1, 3 do
											Paint(VecAdd(pPB.entity.origin, GetRandomDirection(0.4)), 0.35, "spraycan", 0.5)
										end
									else
										for i = 1, 3 do
											Paint(VecAdd(pPB.entity.origin, GetRandomDirection(0.4)), 0.35, "explosion", 0.5)
										end
									end

									if giCurrDroplets < MAX_DROPLETS then
										giCurrDroplets = giCurrDroplets + 8
										-- Better RNG
										for i=1, 4 do
											fireDroplet(VecAdd(pPB.entity.origin, VecScale(traceNormal2, 0.2)), GetRandomDirection(),
												math.random()*1.5, 0.75, 0.34, pPB.entity.owner, pPB.color, pPB.colorIsBlack)
										end

										-- More targetted
										for i=1, 4 do
											fireDroplet(VecAdd(pPB.entity.origin, VecScale(traceNormal2, 0.3)), VecAdd(GetRandomDirection(), VecScale(pPB.entity.velocity, 0.05)),
												math.random()*1.5, 0.75, 0.34, pPB.entity.owner, pPB.color, pPB.colorIsBlack)
										end
									end

									ApplyBodyImpulse(GetShapeBody(shape), pPB.entity.origin, VecScale(betweenDir, VecLength(pPB.entity.velocity)))
								else
									client.paintBallImpactVFX(VecAdd(pPB.entity.prevOrigin, VecScale(betweenDir, impdist)), VecScale(traceNormal2, -1), 0.2, playerHit, pPB.color)
								end
							end
						else -- reflect off wall
							if server and giCurrDroplets < MAX_DROPLETS then
								giCurrDroplets = giCurrDroplets + 2
								for i=1, 2 do
									fireDroplet(VecAdd(pPB.entity.origin, VecScale(traceNormal, 0.1)), pPB.entity.velocity, math.random()*0.2, 0.5, 0.34, pPB.entity.owner, pPB.color, pPB.colorIsBlack)
								end
							end

							pPB.entity.velocity = VecAdd(pPB.entity.velocity, VecScale(traceNormal, -proj * 2))
						end
					else -- Just die
						pPB.die = client_time
					end

					if damp ~= 1 then
						pPB.entity.velocity = VecScale(pPB.entity.velocity, damp)
					end
				end

				pPB.entity.velocity[2] = pPB.entity.velocity[2] + gravity

				if IsPointInWater(pPB.entity.origin) == true then
					pPB.die = client_time
				end

				-- Model
				if client then
					ParticleReset()
					ParticleRadius(0.15)
					ParticleGravity(cl_gravity)
					ParticleAlpha(5, 0, "easein") 
					ParticleTile(3)
					ParticleStretch(10)
					ParticleColor(pPB.color[1], pPB.color[2], pPB.color[3])
					ParticleCollide(0)
					SpawnParticle(pPB.entity.origin, VecScale(pPB.entity.velocity, 2 * frametime), 2 * frametime)
				end
			end
		end
	end
end

function server.dropletUpdate(
    frametime,	-- Simulation time
	cl_gravity)	-- True gravity on client

	-- Nothing to simulate
	if giCurrDroplets == 0 then
		return end

	local client_time = GetTime()

    for i = 1, giCurrDroplets do
		local pDrop = gpDroplets[i] -- this errors sometimes, seemingly when one is deleted?
		if pDrop ~= nil then
			if pDrop.die - client_time < 0 then
				table.remove(gpDroplets, i)
				giCurrDroplets = giCurrDroplets - 1
			else
				pDrop.entity.prevOrigin = VecCopy(pDrop.entity.origin)

				for j = 1, 3 do
					pDrop.entity.origin[j] = pDrop.entity.origin[j] + (pDrop.entity.velocity[j] * frametime)
				end

				local gravity = -frametime * cl_gravity

				-- COLLISIONS
				local betweenDir = VecNormalize(pDrop.entity.velocity)
				local betweenLen = VecLength(pDrop.entity.velocity) * frametime

				local hit, dist, traceNormal = QueryRaycast(pDrop.entity.prevOrigin, betweenDir, betweenLen, 0.01)

				if hit == true then
					local proj, damp

					-- Place at contact point
					pDrop.entity.origin = VecAdd(pDrop.entity.prevOrigin, VecScale(betweenDir, dist))
					pDrop.entity.origin = VecAdd(pDrop.entity.origin, VecScale(traceNormal, 0.01))

					-- Damp velocity
					damp = pDrop.bounceFactor
					damp = damp * 0.5
					if traceNormal[2] > 0.9 then -- Hit floor?
						if pDrop.entity.velocity[2] <= 0 and pDrop.entity.velocity[2] >= gravity * 2 then
							damp = 0 -- Stop
						end
					end

					-- Reflect velocity
					if damp ~= 0 then
						proj = VecDot(pDrop.entity.velocity, traceNormal)

						pDrop.entity.velocity = VecAdd(pDrop.entity.velocity, VecScale(traceNormal, -proj * 2))
					else -- Just die
						pDrop.die = client_time
					end

					if damp ~= 1 then
						pDrop.entity.velocity = VecScale(pDrop.entity.velocity, damp)
					end
				end

				pDrop.entity.velocity[2] = pDrop.entity.velocity[2] + gravity

				if IsPointInWater(pDrop.entity.origin) == true then
					pDrop.die = client_time
				end

				--[[
				ParticleReset()
				ParticleRadius(0.05)
				ParticleGravity(cl_gravity)
				ParticleAlpha(5, 0, "easein") 
				ParticleTile(5)
				ParticleStretch(10)
				ParticleColor(pDrop.color[1], pDrop.color[2], pDrop.color[3])
				ParticleCollide(0)
				SpawnParticle(pDrop.entity.origin, VecScale(pDrop.entity.velocity, frametime * 2), frametime * 2)
				]]

				pDrop.traveled = VecLength(VecSub(pDrop.entity.origin, pDrop.entity.prevOrigin))
				if pDrop.paintAmnt < 0.05 then
					pDrop.die = client_time
				elseif pDrop.traveled > 0.04 then
					if pDrop.colorIsBlack == false then
						Paint(pDrop.entity.origin, pDrop.paintAmnt*0.75, "spraycan", 0.5)
					else
						Paint(pDrop.entity.origin, pDrop.paintAmnt*0.75, "explosion", 0.5)
					end
					pDrop.paintAmnt = pDrop.paintAmnt * 0.96
				end
			end
		end
	end
end

local function AllocDroplet()
	local pDrop = newPaintBall()

	local index = findArrayOpening(gpDroplets)
	gpDroplets[index] = pDrop

	return gpDroplets[index]
end

function fireDroplet(pos, dir, speed, life, paintAmnt, p, rgb, isBlack)
	local velocity = VecScale(dir, speed)

	local pDrop = AllocDroplet()

	pDrop.bounceFactor = 1.0
	pDrop.entity.origin = pos
	pDrop.entity.velocity = velocity
	pDrop.die = life + GetTime()

	pDrop.color = VecCopy(rgb)
	pDrop.colorIsBlack = isBlack

	pDrop.paintAmnt = paintAmnt

	pDrop.entity.owner = p
end

function client.paintBallImpactVFX(pos, dir, damage, playerhit, col)
	local impactsize = damage
	if impactsize > 0.3 then
		impactsize = 0.3
	end

	local size = impactsize/5
	if size > 0.035 then
		size = 0.035
	elseif size <= 0.02 then
		size = 0.02
	end

	local playervel = playerhit ~= 0 and GetPlayerVelocity(playerhit) or Vec(0,0,0)

	local blooddir = VecScale(dir, -1)

	local cloudsize = size*10

	local dropsize = damage/3
	if dropsize > 0.4 then dropsize = 0.4 end

	for i=0, 4 do
		ParticleReset()
		ParticleRadius(dropsize)
		ParticleGravity(GetRandomFloat(-5, -10))
		ParticleAlpha(5, 0, "easein") 
		ParticleTile(5)
		ParticleStretch(10)
		ParticleColor(col[1], col[2], col[3])
		ParticleCollide(0)
		local direct = VecAdd(blooddir, GetRandomDirection(0.25))
		SpawnParticle(pos, VecScale(direct, GetRandomFloat(0.8, 3.0), playervel), 0.75)

		ParticleReset()
		ParticleRadius(cloudsize, 0.35)
		ParticleAlpha(5, 0, "easein") 
		ParticleTile(1)
		ParticleStretch(10)
		ParticleColor(col[1], col[2], col[3])
		ParticleCollide(0)
		SpawnParticle(pos, VecAdd(VecScale(direct, math.random()*1.5), playervel), 0.75)
	end
end