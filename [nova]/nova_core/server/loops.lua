-- Snapshot the source list each tick: saving yields, and players can join or
-- leave while we iterate.

-- Autosave
CreateThread(function()
    local interval = math.max(1, ServerConfig.SaveInterval) * 60000
    while true do
        Wait(interval)
        for _, src in ipairs(Nova.GetPlayerSources()) do
            if Nova.Players[src] then Nova.SavePlayer(src) end
        end
    end
end)

-- Paychecks
if ServerConfig.PaycheckInterval > 0 then
    CreateThread(function()
        local interval = ServerConfig.PaycheckInterval * 60000
        while true do
            Wait(interval)
            for _, src in ipairs(Nova.GetPlayerSources()) do
                local player = Nova.Players[src]
                if player and player.spawned then
                    local job = player.PlayerData.job
                    local jobData = Nova.Jobs[job.name]
                    local payment = tonumber(job.payment) or 0
                    if payment > 0 and (job.onduty or (jobData and jobData.offDutyPay)) then
                        player.Functions.AddMoney(Config.Money.paycheckAccount, payment, 'paycheck')
                        Nova.Notify(src, ('You received your paycheck of $%s'):format(payment), 'success')
                    end
                end
            end
        end
    end)
end

-- Hunger / thirst decay
if Config.Status.enabled then
    CreateThread(function()
        local interval = math.max(1, ServerConfig.StatusInterval) * 60000
        while true do
            Wait(interval)
            for _, src in ipairs(Nova.GetPlayerSources()) do
                local player = Nova.Players[src]
                if player and player.spawned then
                    local md = player.PlayerData.metadata
                    md.hunger = Utils.Clamp((md.hunger or 100) - Config.Status.hungerRate, 0, 100)
                    md.thirst = Utils.Clamp((md.thirst or 100) - Config.Status.thirstRate, 0, 100)
                    player.Functions.UpdatePlayerData()
                    TriggerClientEvent('hud:client:UpdateNeeds', src, md.hunger, md.thirst)
                end
            end
        end
    end)
end
