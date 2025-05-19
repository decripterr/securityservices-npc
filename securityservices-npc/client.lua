local QBCore = exports['qb-core']:GetCoreObject()
local hiredGuards = {}

-- Helper: EnumeratePeds
function EnumeratePeds()
    return coroutine.wrap(function()
        local handle, ped = FindFirstPed()
        local success
        repeat
            coroutine.yield(ped)
            success, ped = FindNextPed(handle)
        until not success
        EndFindPed(handle)
    end)
end

-- Create HQ Ped with qb-target
CreateThread(function()
    local hash = GetHashKey("s_m_m_security_01")
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end

    local ped = CreatePed(0, hash, Config.SecurityPedLocation.x, Config.SecurityPedLocation.y, Config.SecurityPedLocation.z - 1.0, Config.SecurityPedLocation.w, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            {
                type = "client",
                icon = "fas fa-user-shield",
                label = "Hire Bodyguards",
                event = "securityservices:openHireMenu"
            }
        },
        distance = 2.0,
    })
end)

-- Hire Menu
RegisterNetEvent('securityservices:openHireMenu', function()
    local input = exports['qb-input']:ShowInput({
        header = "Hire Bodyguards",
        submitText = "Hire",
        inputs = {
            { type = 'number', name = 'count', text = 'Number of Guards (1-3)', isRequired = true },
            { type = 'number', name = 'duration', text = 'Minutes of Protection', isRequired = true }
        }
    })

    if input then
        local count = math.min(tonumber(input.count) or 1, Config.MaxGuards)
        local duration = tonumber(input.duration) or 5

        if #hiredGuards + count > Config.MaxGuards then
            QBCore.Functions.Notify("Too many guards already hired.", "error")
            return
        end

        for _ = 1, count do
            TriggerServerEvent('securityservices:payForGuard', duration)
        end
    end
end)

-- Spawn Guard
RegisterNetEvent('securityservices:spawnGuard', function(duration)
    local model = Config.BodyguardModel
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local playerPed = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(playerPed, math.random(1, 2), math.random(1, 2), 0)
    local guard = CreatePed(4, model, coords.x, coords.y, coords.z, GetEntityHeading(playerPed), true, true)

    GiveWeaponToPed(guard, GetHashKey(Config.BodyguardWeapon), 255, true, true)
    SetPedAsGroupMember(guard, GetPedGroupIndex(playerPed))
    SetPedCombatAttributes(guard, 46, true)
    SetPedCombatAbility(guard, 2)
    SetPedCombatMovement(guard, 2)
    SetPedCombatRange(guard, 2)
    SetPedCanUseCover(guard, true)
    SetPedFleeAttributes(guard, 0, false)
    SetPedDropsWeaponsWhenDead(guard, false)
    SetEntityAsMissionEntity(guard, true, true)

    TaskFollowToOffsetOfEntity(guard, playerPed, 1.5, 1.0, 0.0, 1.0, -1, 1.0, true)
    table.insert(hiredGuards, guard)

    QBCore.Functions.Notify("Guard hired for " .. duration .. " minutes", "success")

    SetTimeout(duration * 60000, function()
        if DoesEntityExist(guard) then DeletePed(guard) end
        for i = #hiredGuards, 1, -1 do
            if hiredGuards[i] == guard then table.remove(hiredGuards, i) end
        end
        QBCore.Functions.Notify("A guard has finished their shift.", "info")
    end)
end)

-- PvP/NPC defense loop
CreateThread(function()
    while true do
        Wait(500)
        local player = PlayerPedId()
        for _, ped in EnumeratePeds() do
            if ped ~= player and HasEntityClearLosToEntity(player, ped, 17) and HasEntityBeenDamagedByEntity(player, ped, true) then
                for _, guard in pairs(hiredGuards) do
                    if DoesEntityExist(guard) and not IsPedDeadOrDying(guard) then
                        TaskCombatPed(guard, ped, 0, 16)
                    end
                end
                ClearEntityLastDamageEntity(player)
                break
            end
        end
    end
end)

-- Escort Guards to Vehicle
RegisterCommand('escortvehicle', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle and vehicle ~= 0 then
        local seats = GetVehicleMaxNumberOfPassengers(vehicle)
        for _, guard in pairs(hiredGuards) do
            if DoesEntityExist(guard) and not IsPedInAnyVehicle(guard, false) then
                for i = 0, seats - 1 do
                    if IsVehicleSeatFree(vehicle, i) then
                        TaskEnterVehicle(guard, vehicle, 10000, i, 1.0, 1, 0)
                        break
                    end
                end
            end
        end
        QBCore.Functions.Notify("Guards entering vehicle.", "primary")
    else
        QBCore.Functions.Notify("You must be in a vehicle.", "error")
    end
end)

-- Guard Control Menu
RegisterCommand("guardmenu", function()
    local menu = {
        { header = "👮 Security Team", isMenuHeader = true },
        { header = "📍 Recall to Me", txt = "Teleport all guards to you.", params = { event = "securityservices:recallGuards" }},
        { header = "🛑 Hold Position", txt = "Freeze all guards in place.", params = { event = "securityservices:holdPosition" }},
        { header = "🏃 Resume Follow", txt = "Make all guards follow again.", params = { event = "securityservices:resumeFollow" }},
        { header = "❌ Dismiss All", txt = "Fire all hired guards.", params = { event = "securityservices:dismissGuards" }},
        { header = "⬅️ Close", params = { event = "" } },
    }

    exports['qb-menu']:openMenu(menu)
end)

RegisterKeyMapping("guardmenu", "Open Guard Control Menu", "keyboard", "F6")

-- Menu Actions
RegisterNetEvent("securityservices:recallGuards", function()
    local coords = GetEntityCoords(PlayerPedId())
    for _, guard in pairs(hiredGuards) do
        if DoesEntityExist(guard) then
            ClearPedTasks(guard)
            SetEntityCoords(guard, coords.x + math.random(-2, 2), coords.y + math.random(-2, 2), coords.z)
            TaskFollowToOffsetOfEntity(guard, PlayerPedId(), 1.5, 1.0, 0.0, 1.0, -1, 1.0, true)
        end
    end
    QBCore.Functions.Notify("Guards recalled.", "primary")
end)

RegisterNetEvent("securityservices:holdPosition", function()
    for _, guard in pairs(hiredGuards) do
        if DoesEntityExist(guard) then
            ClearPedTasks(guard)
            TaskStandStill(guard, -1)
        end
    end
    QBCore.Functions.Notify("Guards holding position.", "info")
end)

RegisterNetEvent("securityservices:resumeFollow", function()
    for _, guard in pairs(hiredGuards) do
        if DoesEntityExist(guard) then
            ClearPedTasks(guard)
            TaskFollowToOffsetOfEntity(guard, PlayerPedId(), 1.5, 1.0, 0.0, 1.0, -1, 1.0, true)
        end
    end
    QBCore.Functions.Notify("Guards resumed following.", "success")
end)

RegisterNetEvent("securityservices:dismissGuards", function()
    for _, guard in pairs(hiredGuards) do
        if DoesEntityExist(guard) then DeletePed(guard) end
    end
    hiredGuards = {}
    QBCore.Functions.Notify("All guards dismissed.", "error")
end)

-- Clear on death
AddEventHandler('onClientPlayerDied', function()
    for _, guard in pairs(hiredGuards) do
        if DoesEntityExist(guard) then DeletePed(guard) end
    end
    hiredGuards = {}
end)
