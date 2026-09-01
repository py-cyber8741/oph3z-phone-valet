lib.locale()

RegisterNetEvent('oph3z-valet:server:notify', function(title, body)
    local src = source
    if GetResourceState('oph3z-phone') ~= 'started' then return end
    
    exports['oph3z-phone']:PushNotification(src, {
        app   = Config.App.id,
        title = title or locale('notify_title'),
        body  = body or locale('notify_body'),
        route = { app = Config.App.id },
    })
end)

-- ==========================================
-- qbx_garages 用コールバック (DB直接操作)
-- ==========================================
lib.callback.register('oph3z-valet:server:GetVehicles', function(source)
    if Config.GarageSystem ~= 'qbx' then return {} end
    
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end
    
    -- Qboxの player_vehicles テーブルから取得
    local vehicles = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', {player.PlayerData.citizenid})
    local result = {}
    
    for _, v in ipairs(vehicles) do
        table.insert(result, {
            plate = v.plate,
            vehicle = v.vehicle, 
            custom_name = v.hash or v.vehicle,
            state = v.state, 
            engine = v.engine,
            body = v.body,
            fuel = v.fuel
        })
    end
    return result
end)

lib.callback.register('oph3z-valet:server:SpawnVehicle', function(source, plate, spawnCoords)
    if Config.GarageSystem ~= 'qbx' then return false end
    
    local vehicle = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ?', {plate})
    if not vehicle[1] or vehicle[1].state ~= 1 then return false end
    
    -- サーバー側でモデルハッシュを計算
    local modelHash = type(vehicle[1].vehicle) == 'number' and vehicle[1].vehicle or joaat(vehicle[1].vehicle)
    
    -- サーバー側で車両を生成 (引数: model, x, y, z, heading, isNetwork, netMissionEntity)
    local veh = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, true)
    
    -- エンティティが完全に実体化するまで待機
    local timeout = 0
    while not DoesEntityExist(veh) and timeout < 50 do
        Wait(50)
        timeout = timeout + 1
    end
    
    if not DoesEntityExist(veh) then return false end

    -- サーバー側でナンバープレートをセット
    SetVehicleNumberPlateText(veh, plate)
    
    -- ネットワークIDを取得
    local netId = NetworkGetNetworkIdFromEntity(veh)
    
    -- qbx_garages仕様: 出庫状態(0)に更新
    MySQL.update.await('UPDATE player_vehicles SET state = 0 WHERE plate = ?', {plate})
    
    return {
        plate = vehicle[1].plate,
        vehicle = vehicle[1].vehicle,
        fuel = vehicle[1].fuel,
        engine = vehicle[1].engine,
        body = vehicle[1].body,
        mods = vehicle[1].mods,
        useNetwork = true,
        netId = netId
    }
end)