local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('securityservices:payForGuard', function(duration)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if Player.Functions.RemoveMoney('cash', Config.HireCost) then
        TriggerClientEvent('securityservices:spawnGuard', src, duration)
    else
        TriggerClientEvent('QBCore:Notify', src, "Not enough cash!", "error")
    end
end)
