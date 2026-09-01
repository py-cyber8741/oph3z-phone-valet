lib.locale()

local function register()
    if GetResourceState('oph3z-phone') ~= 'started' then return end
    exports['oph3z-phone']:RegisterApp(Config.App)
end

CreateThread(function()
    Wait(1000)
    register()
end)
AddEventHandler('oph3z-phone:requestApps', register)

-- ==========================================
-- UIへのロケールデータ送信
-- ==========================================
RegisterNUICallback('getLocales', function(data, cb)
    cb({
        app_name = locale('app_name'),
        app_desc = locale('app_desc'),
        loading = locale('loading'),
        no_vehicles = locale('no_vehicles'),
        status_available = locale('status_available'),
        status_out = locale('status_out'),
        status_impounded = locale('status_impounded'),
        close_app = locale('close_app'),
        dispatch_complete = locale('dispatch_complete'),
        is_on_the_way = locale('is_on_the_way'),
        engine = locale('engine'),
        body = locale('body'),
        fuel = locale('fuel')
    })
end)

-- ==========================================
-- 車両リスト取得コールバック
-- ==========================================
RegisterNUICallback('getValetVehicles', function(data, cb)
    local vehicles = {}
    if Config.GarageSystem == 'ma' then
        vehicles = lib.callback.await('ma_garages:server:GetVehicles', 100)
    elseif Config.GarageSystem == 'qbx' then
        vehicles = lib.callback.await('oph3z-valet:server:GetVehicles', 100)
    end
    cb(vehicles or {})
end)

-- ==========================================
-- 安全なスポーン地点を探すヘルパー (距離短縮版)
-- ==========================================
local function GetSpawnNode(playerCoords)
    local found = false
    local outPos, _ 
    -- 【変更】スポーン距離を 50〜80m に短縮（遠すぎるとAIがバカになるため）
    local distance = math.random(50, 80)
    local angle = math.random() * 2 * math.pi
    local searchX = playerCoords.x + (math.cos(angle) * distance)
    local searchY = playerCoords.y + (math.sin(angle) * distance)
    
    found, outPos, _ = GetClosestVehicleNodeWithHeading(searchX, searchY, playerCoords.z, 0, 3.0, 0)
    
    if not found then
        _, outPos, _ = GetClosestVehicleNodeWithHeading(playerCoords.x, playerCoords.y, playerCoords.z, 0, 3.0, 0)
    end

    local dx = playerCoords.x - outPos.x
    local dy = playerCoords.y - outPos.y
    local headingToPlayer = GetHeadingFromVector_2d(dx, dy)
    
    return vector4(outPos.x, outPos.y, outPos.z, headingToPlayer)
end

-- ==========================================
-- NPCの運転監視・強制デリバリーロジック
-- ==========================================
local function ValetDriveToPlayer(veh, driverPed, playerPed)
    local isArrived = false
    local timeoutTimer = 0
    local stuckTimer = 0
    
    -- 【重要】道(ナビメッシュ)を完全に無視して直線で向かう特殊スタイル
    -- 4194304(道無視) + 16(人回避) + 8(空車回避) + 4(車回避) = 4194332
    local DRIVING_STYLE_OFFROAD = 4194332
    
    SetDriverAbility(driverPed, 1.0)
    SetDriverAggressiveness(driverPed, 1.0)
    
    local blip = AddBlipForEntity(veh)
    SetBlipSprite(blip, 225)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(locale('blip_name') or "配車サービス")
    EndTextCommandSetBlipName(blip)
    
    local targetCoords = GetEntityCoords(playerPed)
    
    -- 初回の運転指示（道路無視モード）
    TaskVehicleDriveToCoord(driverPed, veh, targetCoords.x, targetCoords.y, targetCoords.z, 20.0, 0, GetEntityModel(veh), DRIVING_STYLE_OFFROAD, 2.0)
    
    while DoesEntityExist(veh) and DoesEntityExist(driverPed) do
        Wait(200) -- 0.2秒間隔
        timeoutTimer = timeoutTimer + 0.2
        
        targetCoords = GetEntityCoords(playerPed)
        local vehCoords = GetEntityCoords(veh)
        local distToPlayer = #(targetCoords - vehCoords)
        
        -- 1. 到着判定 (12m以内)
        if distToPlayer < 12.0 then
            isArrived = true
            break
        end
        
        -- 2. スタック判定 (1.0未満の速度)
        if GetEntitySpeed(veh) < 1.0 then
            stuckTimer = stuckTimer + 0.2
        else
            stuckTimer = 0
            -- 動いている間は、2秒ごとに目標座標を現在地に更新
            if math.floor(timeoutTimer * 10) % 20 == 0 then 
                TaskVehicleDriveToCoord(driverPed, veh, targetCoords.x, targetCoords.y, targetCoords.z, 20.0, 0, GetEntityModel(veh), DRIVING_STYLE_OFFROAD, 2.0)
            end
        end
        
        -- 3. 強制リカバリー (5秒間スタック、または30秒経過で即ワープ)
        if stuckTimer >= 5.0 or timeoutTimer >= 30.0 or distToPlayer > 150.0 then
            -- プレイヤーの「10m後ろ」の座標を取得
            local warpPos = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, -10.0, 0.0)
            local foundZ, groundZ = GetGroundZFor_3dCoord(warpPos.x, warpPos.y, warpPos.z + 100.0, false)
            
            if foundZ then 
                warpPos = vector3(warpPos.x, warpPos.y, groundZ) 
            end
            
            -- 背後にワープさせて到着済みにする
            SetEntityCoords(veh, warpPos.x, warpPos.y, warpPos.z, false, false, false, true)
            SetEntityHeading(veh, GetEntityHeading(playerPed))
            
            -- ワープ直後に到着判定を通すためにループを抜ける
            isArrived = true
            break
        end
    end

    if isArrived then
        -- 強制停止
        ClearPedTasks(driverPed)
        SetVehicleForwardSpeed(veh, 0.0)
        
        Wait(500)
        TaskLeaveVehicle(driverPed, veh, 0)
        SetVehicleEngineOn(veh, true, true, false)
        Wait(2000)
        TaskWanderStandard(driverPed, 10.0, 10)
        SetEntityAsNoLongerNeeded(driverPed)
        
        TriggerServerEvent('oph3z-valet:server:notify', locale('notify_title'), locale('notify_body'))
    end

    if DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
end

-- ==========================================
-- 車両呼び出しイベント
-- ==========================================
RegisterNUICallback('callVehicle', function(data, cb)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local spawnCoords = GetSpawnNode(playerCoords)

    local vehData
    if Config.GarageSystem == 'ma' then
        vehData = lib.callback.await('ma_garages:server:SpawnVehicle', false, data.plate, spawnCoords)
    elseif Config.GarageSystem == 'qbx' then
        vehData = lib.callback.await('oph3z-valet:server:SpawnVehicle', false, data.plate, spawnCoords)
    end
    
    if not vehData then 
        lib.notify({type = 'error', description = locale('err_dispatch_failed')})
        return cb({ok = false}) 
    end
    
    lib.notify({type = 'info', description = locale('info_dispatching')})

    CreateThread(function()
        local veh
        local model = type(vehData.vehicle) == 'number' and vehData.vehicle or joaat(vehData.vehicle)
        lib.requestModel(model)

        if vehData.useNetwork then
            local netId = vehData.netId
            local timeout = 0
            while not NetworkDoesNetworkIdExist(netId) and timeout < 50 do Wait(50); timeout = timeout + 1 end
            if not NetworkDoesNetworkIdExist(netId) then
                lib.notify({type = 'error', description = locale('err_network_sync')})
                return
            end
            veh = NetToVeh(netId)
            NetworkRequestControlOfEntity(veh)
            timeout = 0
            while not NetworkHasControlOfEntity(veh) and timeout < 20 do Wait(50); timeout = timeout + 1 end
        else
            veh = CreateVehicle(model, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
            local timeout = 0
            while not DoesEntityExist(veh) and timeout < 50 do Wait(50); timeout = timeout + 1 end
            SetVehicleNumberPlateText(veh, vehData.plate)
        end

        if not DoesEntityExist(veh) then
            lib.notify({type = 'error', description = locale('err_spawn_failed')})
            return
        end

        local fuelLevel = vehData.fuel and (vehData.fuel + 0.0) or 100.0
        SetVehicleFuelLevel(veh, fuelLevel)
        if vehData.useNetwork then Entity(veh).state.fuel = fuelLevel end
        if vehData.mods then lib.setVehicleProperties(veh, json.decode(vehData.mods)) end
        SetVehicleEngineHealth(veh, vehData.engine + 0.0)
        SetVehicleBodyHealth(veh, vehData.body + 0.0)
        
        local pedModel = `s_m_y_valet_01`
        lib.requestModel(pedModel)
        
        local driver = CreatePedInsideVehicle(veh, 4, pedModel, -1, true, false)
        SetBlockingOfNonTemporaryEvents(driver, true)
        SetEntityAsMissionEntity(driver, true, true)

        SetModelAsNoLongerNeeded(model)
        SetModelAsNoLongerNeeded(pedModel)

        SetTimeout(500, function()
            if DoesEntityExist(veh) then
                local actualPlate = string.gsub(GetVehicleNumberPlateText(veh), "^%s*(.-)%s*$", "%1")
                TriggerEvent("vehiclekeys:client:SetOwner", actualPlate)
                SetVehicleDoorsLocked(veh, 1)
            end
        end)

        ValetDriveToPlayer(veh, driver, playerPed)
    end)
    
    cb({ ok = true })
end)