include("shared.lua")
include("cl_trailsystem.lua")

-- ----------------------------------------------------------------
--  FLAME / SMOKE TUNING  (active from frame 1, for full lifetime)
-- ----------------------------------------------------------------
local FLAME_DELAY    = 0
local SMOKE_FADE     = 1e9

-- ----------------------------------------------------------------
--  SMOKE TRAIL TUNING
-- ----------------------------------------------------------------
local SMOKE_EMIT_CHANCE  = 0.85
local SMOKE_SIZE_MIN     = 90
local SMOKE_SIZE_MAX     = 175
local SMOKE_END_MIN      = 180
local SMOKE_END_MAX      = 280
local SMOKE_ALPHA_START  = 235
local SMOKE_ALPHA_END    = 0
local SMOKE_SPEED_MIN    = 45
local SMOKE_SPEED_MAX    = 110
local SMOKE_DIE_MIN      = 0.65
local SMOKE_DIE_MAX      = 1.40
local SMOKE_SPREAD       = 18
local SMOKE_BACK_OFFSET  = 65

-- ----------------------------------------------------------------
--  STABILIZER TUNING
-- ----------------------------------------------------------------
local STAB_NOZZLE_DIST   = 24
local STAB_NOZZLE_BACK   = 14
local STAB_JET_LEN       = 85
local STAB_JET_SPREAD    = 7
local STAB_SIZE_MIN      = 5.5
local STAB_SIZE_MAX      = 9.5
local STAB_ALPHA         = 230
local STAB_DIE_MIN       = 0.07
local STAB_DIE_MAX       = 0.18
local STAB_FIRE_CHANCE   = 0.40
local STAB_DRIFT_THRESH  = 30
local STAB_DRIFT_BOOST   = 0.75

-- ----------------------------------------------------------------
--  NOSECONE SHOCK CONE TUNING
--  Sporadic Prandtl-Glauert condensation ring at the missile tip.
--  NOSE_FWD: units forward from entity center to nose tip (local X).
--  SHOCK_INTERVAL_MIN/MAX: seconds between shock events.
--  SHOCK_RING_PARTS: particles per ring burst.
-- ----------------------------------------------------------------
local NOSE_FWD           = 58
local SHOCK_INTERVAL_MIN = 0.35
local SHOCK_INTERVAL_MAX = 1.80
local SHOCK_RING_PARTS   = 10
local SHOCK_VEL_MIN      = 90
local SHOCK_VEL_MAX      = 200
local SHOCK_DIE_MIN      = 0.055
local SHOCK_DIE_MAX      = 0.13
local SHOCK_SIZE_START   = 3
local SHOCK_SIZE_END_MIN = 22
local SHOCK_SIZE_END_MAX = 40
local SHOCK_ALPHA        = 210

-- ----------------------------------------------------------------
--  DAMAGE TIER FX
-- ----------------------------------------------------------------
game.AddParticles("particles/fire_01.pcf")
PrecacheParticleSystem("fire_medium_02")

local TIER_OFFSETS = {
	[1] = {
		Vector(0,  30, 4),
		Vector(0, -30, 4),
	},
	[2] = {
		Vector(0,  30,  4),
		Vector(0, -30,  4),
		Vector(0,  55,  6),
		Vector(0, -55,  6),
	},
}

local TIER_BURST_DELAY = { [1] = 5.0, [2] = 2.5, [3] = 0.9 }
local TIER_BURST_COUNT = { [1] = 1,   [2] = 2,   [3] = 4   }

local TomahawkStates = {}

local function BurstAt(pos, tier)
	local ed = EffectData()
	ed:SetOrigin(pos)
	ed:SetScale(tier == 3 and math.Rand(0.6, 1.2) or math.Rand(0.3, 0.7))
	ed:SetMagnitude(1)
	ed:SetRadius(tier * 15)
	util.Effect("Explosion", ed)

	local ed2 = EffectData()
	ed2:SetOrigin(pos)
	ed2:SetNormal(Vector(0, 0, 1))
	ed2:SetScale(tier * 0.25)
	ed2:SetMagnitude(tier * 0.35)
	ed2:SetRadius(14)
	util.Effect("ManhackSparks", ed2)

	if tier >= 2 then
		local ed3 = EffectData()
		ed3:SetOrigin(pos)
		ed3:SetNormal(VectorRand())
		ed3:SetScale(0.5)
		util.Effect("ElectricSpark", ed3)
	end
end

local function SpawnBurstFX(ent, tier)
	local count = TIER_BURST_COUNT[tier] or 1
	local pos   = ent:GetPos()
	local ang   = ent:GetAngles()
	for _ = 1, count do
		local localOff = Vector(
			math.Rand(-70, 70),
			math.Rand(-15, 15),
			math.Rand( -8, 18)
		)
		BurstAt(LocalToWorld(localOff, Angle(0,0,0), pos, ang), tier)
	end
end

local function StopParticles(state)
	if not state.particles then return end
	for _, p in ipairs(state.particles) do
		if IsValid(p) then p:StopEmission() end
	end
	state.particles = {}
end

local function ApplyFlameParticles(ent, state, tier)
	StopParticles(state)
	state.tier = tier
	if not IsValid(ent) or tier == 0 then return end

	local offsets = TIER_OFFSETS[math.min(tier, 2)]
	if not offsets then return end

	for _, off in ipairs(offsets) do
		local p = ent:CreateParticleEffect("fire_medium_02", PATTACH_ABSORIGIN_FOLLOW, 0)
		if IsValid(p) then
			p:SetControlPoint(0, ent:LocalToWorld(off))
			table.insert(state.particles, p)
		end
	end

	state.nextBurst = CurTime() + (TIER_BURST_DELAY[tier] or 4)
end

net.Receive("bombin_tomahawk_damage_tier", function()
	local idx  = net.ReadUInt(16)
	local tier = net.ReadUInt(2)

	local state = TomahawkStates[idx]
	if not state then
		state = { tier = 0, particles = {}, nextBurst = 0 }
		TomahawkStates[idx] = state
	end

	if state.tier == tier then return end

	local ent = Entity(idx)
	if IsValid(ent) then
		ApplyFlameParticles(ent, state, tier)
		if tier > 0 then SpawnBurstFX(ent, tier) end
	else
		state.tier         = tier
		state.pendingApply = true
	end
end)

hook.Add("Think", "bombin_tomahawk_damage_fx", function()
	local ct = CurTime()
	for idx, state in pairs(TomahawkStates) do
		local ent = Entity(idx)
		if not IsValid(ent) then
			StopParticles(state)
			TomahawkStates[idx] = nil
		else
			if state.pendingApply then
				state.pendingApply = false
				ApplyFlameParticles(ent, state, state.tier)
			end

			if state.tier > 0 then
				local pos     = ent:GetPos()
				local ang     = ent:GetAngles()
				local offsets = TIER_OFFSETS[math.min(state.tier, 2)]
				if offsets then
					for i, p in ipairs(state.particles) do
						if IsValid(p) and offsets[i] then
							p:SetControlPoint(0, LocalToWorld(offsets[i], Angle(0,0,0), pos, ang))
						end
					end
				end

				if ct >= state.nextBurst then
					SpawnBurstFX(ent, state.tier)
					state.nextBurst = ct + (TIER_BURST_DELAY[state.tier] or 4)
				end
			end
		end
	end
end)

function ENT:Initialize()
    self:SetModelScale(1.6, 0)
    self.NikitaEmitter = ParticleEmitter(self:GetPos(), false)
    self.StabEmitter   = ParticleEmitter(self:GetPos(), false)
    self.SmokeEmitter  = ParticleEmitter(self:GetPos(), false)
    self.ShockEmitter  = ParticleEmitter(self:GetPos(), false)
    self._spawnTime    = CurTime()
    self._nextShock    = CurTime() + math.Rand(SHOCK_INTERVAL_MIN, SHOCK_INTERVAL_MAX)

	local idx = self:EntIndex()
	TomahawkStates[idx] = { tier = 0, particles = {}, nextBurst = 0 }
end

function ENT:Draw()
    self:DrawModel()
end

function ENT:Think()
    if not IsValid(self.NikitaEmitter) then return end

    local now        = CurTime()
    local age        = now - (self._spawnTime or now)
    local flameOn    = age >= FLAME_DELAY
    local smokeOn    = age < (FLAME_DELAY + SMOKE_FADE)

    local pos        = self:GetPos()
    local fwd        = self:GetForward()
    local right      = self:GetRight()
    local up         = self:GetUp()
    local backDir    = -fwd
    local exhaustPos = pos + backDir * SMOKE_BACK_OFFSET
    local boost      = self:GetNWFloat("TomahawkBoost", 0)

    self.NikitaEmitter:SetPos(pos)
    if IsValid(self.SmokeEmitter) then
        self.SmokeEmitter:SetPos(pos)
    end

    -- ----------------------------------------------------------------
    --  NOSECONE SHOCK CONE  (sporadic Prandtl-Glauert ring)
    -- ----------------------------------------------------------------
    if IsValid(self.ShockEmitter) and now >= self._nextShock then
        self._nextShock = now + math.Rand(SHOCK_INTERVAL_MIN, SHOCK_INTERVAL_MAX)
        local nosePos = pos + fwd * NOSE_FWD
        self.ShockEmitter:SetPos(nosePos)
        for i = 1, SHOCK_RING_PARTS do
            local angle  = (i / SHOCK_RING_PARTS) * math.pi * 2
            local radDir = right * math.cos(angle) + up * math.sin(angle)
            local part   = self.ShockEmitter:Add(
                "particle/particle_smokegrenade",
                nosePos + radDir * math.Rand(2, 6)
            )
            if part then
                part:SetVelocity( radDir * math.Rand(SHOCK_VEL_MIN, SHOCK_VEL_MAX)
                                + fwd * math.Rand(-20, 8) )
                part:SetDieTime( math.Rand(SHOCK_DIE_MIN, SHOCK_DIE_MAX) )
                part:SetStartAlpha( SHOCK_ALPHA )
                part:SetEndAlpha( 0 )
                part:SetStartSize( SHOCK_SIZE_START )
                part:SetEndSize( math.Rand(SHOCK_SIZE_END_MIN, SHOCK_SIZE_END_MAX) )
                part:SetColor( 210, 230, 255 )
                part:SetRoll( math.Rand(0, 360) )
                part:SetRollDelta( 0 )
                part:SetGravity( Vector(0, 0, 0) )
                part:SetCollide( false )
            end
        end
    end

    if smokeOn and IsValid(self.SmokeEmitter) then
        if math.random() < SMOKE_EMIT_CHANCE then
            local spread = VectorRand() * SMOKE_SPREAD
            spread.x = spread.x * 0.4
            local part = self.SmokeEmitter:Add(
                "particle/particle_smokegrenade",
                exhaustPos + spread
            )
            if part then
                part:SetVelocity(backDir * math.Rand(SMOKE_SPEED_MIN, SMOKE_SPEED_MAX)
                                 + VectorRand() * 12)
                part:SetDieTime(math.Rand(SMOKE_DIE_MIN, SMOKE_DIE_MAX))
                part:SetStartAlpha(SMOKE_ALPHA_START)
                part:SetEndAlpha(SMOKE_ALPHA_END)
                part:SetStartSize(math.Rand(SMOKE_SIZE_MIN, SMOKE_SIZE_MAX))
                part:SetEndSize(math.Rand(SMOKE_END_MIN, SMOKE_END_MAX))
                part:SetColor(248, 248, 248)
                part:SetRoll(math.Rand(0, 360))
                part:SetRollDelta(math.Rand(-1.5, 1.5))
                part:SetGravity(Vector(0, 0, 26))
                part:SetCollide(false)
            end
        end
    end

    if not flameOn then return end

    local dlight = DynamicLight(self:EntIndex())
    if dlight then
        dlight.pos        = exhaustPos
        dlight.r          = 255
        dlight.g          = 120
        dlight.b          = 20
        dlight.brightness = 4
        dlight.Decay      = 1200
        dlight.Size       = Lerp(boost, 280, 380)
        dlight.DieTime    = CurTime() + 0.05
    end

    for i = 1, 7 do
        local part = self.NikitaEmitter:Add(
            "particles/flamelet" .. math.random(1, 5),
            exhaustPos + VectorRand() * 8
        )
        if part then
            part:SetVelocity(backDir * math.Rand(100, 260) + VectorRand() * 22)
            part:SetDieTime(math.Rand(0.09, 0.22))
            part:SetStartAlpha(230)
            part:SetEndAlpha(0)
            part:SetStartSize(math.Rand(26, 48))
            part:SetEndSize(math.Rand(6, 15))
            part:SetColor(255, math.random(100, 180), 0)
            part:SetRoll(math.Rand(0, 360))
            part:SetRollDelta(math.Rand(-2, 2))
            part:SetGravity(Vector(0, 0, 12))
            part:SetCollide(false)
        end
    end

    local fuchsiaMin = Lerp(boost, 52, 67)
    local fuchsiaMax = Lerp(boost, 67, 82)

    for i = 1, 5 do
        local part = self.NikitaEmitter:Add(
            "particles/flamelet" .. math.random(1, 5),
            exhaustPos + VectorRand() * 10
        )
        if part then
            part:SetVelocity(backDir * math.Rand(80, 210) + VectorRand() * 28)
            part:SetDieTime(math.Rand(0.11, 0.26))
            part:SetStartAlpha(190)
            part:SetEndAlpha(0)
            part:SetStartSize(math.Rand(fuchsiaMin, fuchsiaMax))
            part:SetEndSize(math.Rand(3, 12))
            part:SetColor(220, 0, 200)
            part:SetRoll(math.Rand(0, 360))
            part:SetRollDelta(math.Rand(-3, 3))
            part:SetGravity(Vector(0, 0, 8))
            part:SetCollide(false)
        end
    end

    for i = 1, 6 do
        local part = self.NikitaEmitter:Add(
            "effects/spark",
            exhaustPos + VectorRand() * 5
        )
        if part then
            part:SetVelocity(backDir * math.Rand(300, 700) + VectorRand() * 55)
            part:SetDieTime(math.Rand(0.14, 0.36))
            part:SetStartAlpha(255)
            part:SetEndAlpha(0)
            part:SetStartSize(math.Rand(1.5, 4))
            part:SetEndSize(0)
            part:SetColor(255, 230, 180)
            part:SetGravity(Vector(0, 0, -280))
            part:SetCollide(true)
            part:SetBounce(0.2)
        end
    end

    if math.random(1, 2) == 1 then
        local part = self.NikitaEmitter:Add(
            "particle/particle_smokegrenade",
            exhaustPos + backDir * math.Rand(6, 28)
        )
        if part then
            part:SetVelocity(backDir * math.Rand(25, 80) + VectorRand() * 14)
            part:SetDieTime(math.Rand(0.5, 1.1))
            part:SetStartAlpha(55)
            part:SetEndAlpha(0)
            part:SetStartSize(math.Rand(12, 24))
            part:SetEndSize(math.Rand(32, 65))
            part:SetColor(180, 180, 180)
            part:SetRoll(math.Rand(0, 360))
            part:SetRollDelta(math.Rand(-1, 1))
            part:SetGravity(Vector(0, 0, 22))
            part:SetCollide(false)
        end
    end

    if not IsValid(self.StabEmitter) then return end
    self.StabEmitter:SetPos(pos)

    local nozzleBase = pos + backDir * STAB_NOZZLE_BACK

    local nozzles = {
        {  right,  nozzleBase + right * STAB_NOZZLE_DIST },
        { -right,  nozzleBase - right * STAB_NOZZLE_DIST },
        {  up,     nozzleBase + up    * STAB_NOZZLE_DIST },
        { -up,     nozzleBase - up    * STAB_NOZZLE_DIST },
    }

    local vel      = self:GetVelocity()
    local driftX   = vel.x
    local driftY   = vel.y
    local driftLen = math.sqrt(driftX * driftX + driftY * driftY)
    local driftVec = Vector(0, 0, 0)
    if driftLen > STAB_DRIFT_THRESH then
        driftVec = Vector(driftX / driftLen, driftY / driftLen, 0)
    end

    for _, nozzle in ipairs(nozzles) do
        local outDir  = nozzle[1]
        local nozzPos = nozzle[2]
        local drift2D = Vector(outDir.x, outDir.y, 0)
        local dot     = drift2D:Dot(driftVec)
        local chance  = STAB_FIRE_CHANCE
        if dot < -0.35 then chance = chance + STAB_DRIFT_BOOST end

        if math.random() < chance then
            local part = self.StabEmitter:Add(
                "particles/flamelet" .. math.random(1, 5),
                nozzPos + VectorRand() * 3
            )
            if part then
                local jitter = Vector(
                    math.Rand(-STAB_JET_SPREAD, STAB_JET_SPREAD),
                    math.Rand(-STAB_JET_SPREAD, STAB_JET_SPREAD),
                    math.Rand(-STAB_JET_SPREAD, STAB_JET_SPREAD)
                )
                part:SetVelocity(outDir * math.Rand(STAB_JET_LEN * 0.7, STAB_JET_LEN) + jitter)
                part:SetDieTime(math.Rand(STAB_DIE_MIN, STAB_DIE_MAX))
                part:SetStartAlpha(STAB_ALPHA)
                part:SetEndAlpha(0)
                part:SetStartSize(math.Rand(STAB_SIZE_MIN, STAB_SIZE_MAX))
                part:SetEndSize(0)
                part:SetColor(255, 255, 255)
                part:SetRoll(math.Rand(0, 360))
                part:SetRollDelta(math.Rand(-2, 2))
                part:SetGravity(Vector(0, 0, 0))
                part:SetCollide(false)
            end
        end
    end
end

function ENT:OnRemove()
    if IsValid(self.NikitaEmitter) then self.NikitaEmitter:Finish() end
    if IsValid(self.StabEmitter)   then self.StabEmitter:Finish()   end
    if IsValid(self.SmokeEmitter)  then self.SmokeEmitter:Finish()  end
    if IsValid(self.ShockEmitter)  then self.ShockEmitter:Finish()  end

	local idx   = self:EntIndex()
	local state = TomahawkStates[idx]
	if state then
		StopParticles(state)
		TomahawkStates[idx] = nil
	end
end
