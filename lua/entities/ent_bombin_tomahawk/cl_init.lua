include("shared.lua")

-- ----------------------------------------------------------------
--  FLAME / SMOKE TUNING  (active from frame 1, for full lifetime)
-- ----------------------------------------------------------------
local FLAME_DELAY    = 0       -- no ignition wait; burn from spawn
local SMOKE_FADE     = 1e9     -- smoke never fades — active whole lifetime

-- ----------------------------------------------------------------
--  SMOKE TRAIL TUNING  (big persistent missile plume)
-- ----------------------------------------------------------------
local SMOKE_EMIT_CHANCE  = 0.85   -- dense emission
local SMOKE_SIZE_MIN     = 90     -- 1.6× original
local SMOKE_SIZE_MAX     = 175
local SMOKE_END_MIN      = 180
local SMOKE_END_MAX      = 280
local SMOKE_ALPHA_START  = 235
local SMOKE_ALPHA_END    = 0
local SMOKE_SPEED_MIN    = 45
local SMOKE_SPEED_MAX    = 110
local SMOKE_DIE_MIN      = 0.65
local SMOKE_DIE_MAX      = 1.40
local SMOKE_SPREAD       = 18     -- slightly wider spread
local SMOKE_BACK_OFFSET  = 65     -- further back for long fuselage

-- ----------------------------------------------------------------
--  STABILIZER TUNING  (scaled up)
-- ----------------------------------------------------------------
local STAB_NOZZLE_DIST   = 24
local STAB_NOZZLE_BACK   = 14
local STAB_JET_LEN       = 85     -- vs 55 original
local STAB_JET_SPREAD    = 7
local STAB_SIZE_MIN      = 5.5    -- vs 3.6 original
local STAB_SIZE_MAX      = 9.5    -- vs 6.4 original
local STAB_ALPHA         = 230
local STAB_DIE_MIN       = 0.07
local STAB_DIE_MAX       = 0.18
local STAB_FIRE_CHANCE   = 0.40
local STAB_DRIFT_THRESH  = 30
local STAB_DRIFT_BOOST   = 0.75

function ENT:Initialize()
    self:SetModelScale(1.6, 0)
    self.NikitaEmitter = ParticleEmitter(self:GetPos(), false)
    self.StabEmitter   = ParticleEmitter(self:GetPos(), false)
    self.SmokeEmitter  = ParticleEmitter(self:GetPos(), false)
    self._spawnTime    = CurTime()
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
    local backDir    = -fwd
    local exhaustPos = pos + backDir * SMOKE_BACK_OFFSET
    local boost      = self:GetNWFloat("TomahawkBoost", 0)

    self.NikitaEmitter:SetPos(pos)
    if IsValid(self.SmokeEmitter) then
        self.SmokeEmitter:SetPos(pos)
    end

    -- --------------------------------------------------------
    --  WHITE SMOKE TRAIL
    -- --------------------------------------------------------
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

    -- --------------------------------------------------------
    --  Dynamic light
    -- --------------------------------------------------------
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

    -- --------------------------------------------------------
    --  Orange flame core
    -- --------------------------------------------------------
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

    -- --------------------------------------------------------
    --  Fuchsia flame layer
    -- --------------------------------------------------------
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

    -- --------------------------------------------------------
    --  Sparks
    -- --------------------------------------------------------
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

    -- --------------------------------------------------------
    --  Smoke wisps
    -- --------------------------------------------------------
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

    -- --------------------------------------------------------
    --  STABILIZER THRUSTERS
    -- --------------------------------------------------------
    if not IsValid(self.StabEmitter) then return end
    self.StabEmitter:SetPos(pos)

    local right = self:GetRight()
    local up    = self:GetUp()
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

    for idx, nozzle in ipairs(nozzles) do
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
end
