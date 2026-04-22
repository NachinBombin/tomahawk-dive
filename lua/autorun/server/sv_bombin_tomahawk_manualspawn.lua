if not SERVER then return end

util.AddNetworkString("BombinTomahawk_ManualSpawn")

net.Receive("BombinTomahawk_ManualSpawn", function(len, ply)
    if not IsValid(ply) then return end

    local tr = util.TraceLine({
        start  = ply:EyePos(),
        endpos = ply:EyePos() + ply:EyeAngles():Forward() * 3000,
        filter = ply,
    })

    local centerPos = tr.Hit and tr.HitPos or (ply:GetPos() + Vector(0, 0, 100))
    local callDir   = ply:EyeAngles():Forward()
    callDir.z = 0
    if callDir:LengthSqr() <= 1 then callDir = Vector(1, 0, 0) end
    callDir:Normalize()

    if not scripted_ents.GetStored("ent_bombin_tomahawk") then
        ply:PrintMessage(HUD_PRINTCENTER, "[Bombin Tomahawk] Entity not registered!")
        return
    end

    local ent = ents.Create("ent_bombin_tomahawk")
    if not IsValid(ent) then
        ply:PrintMessage(HUD_PRINTCENTER, "[Bombin Tomahawk] Spawn failed!")
        return
    end

    ent:SetPos(centerPos)
    ent:SetAngles(callDir:Angle())
    ent:SetVar("CenterPos",            centerPos)
    ent:SetVar("CallDir",              callDir)
    ent:SetVar("Lifetime",             GetConVar("npc_bombintomahawk_lifetime"):GetFloat())
    ent:SetVar("Speed",                GetConVar("npc_bombintomahawk_speed"):GetFloat())
    ent:SetVar("OrbitRadius",          GetConVar("npc_bombintomahawk_radius"):GetFloat())
    ent:SetVar("SkyHeightAdd",         GetConVar("npc_bombintomahawk_height"):GetFloat())
    ent:SetVar("DIVE_ExplosionDamage", GetConVar("npc_bombintomahawk_dive_damage"):GetFloat())
    ent:SetVar("DIVE_ExplosionRadius", GetConVar("npc_bombintomahawk_dive_radius"):GetFloat())
    ent:Spawn()
    ent:Activate()

    ply:PrintMessage(HUD_PRINTCENTER, "[Bombin Tomahawk] Missile inbound!")
end)
