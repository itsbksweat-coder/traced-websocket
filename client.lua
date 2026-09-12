repeat task.wait() until game:IsLoaded()

local UserInputService = game:GetService("UserInputService")

local WS_URL = "wss://traced-websocket.xyzcheatz.workers.dev/ws"

local socket
local connected = false
local connecting = false

local function getTargetButton()
    local ok, button = pcall(function()
        return gethui()
            .Traced
            .Main
            :GetChildren()[7]
            :GetChildren()[5]
            .TextButton
    end)

    if ok and button then
        return button
    end

    return nil
end

local function runConnections(signal)
    local ok, connections = pcall(getconnections, signal)
    if not ok or type(connections) ~= "table" then
        return 0
    end

    local fired = 0

    for _, connection in ipairs(connections) do
        local success = pcall(function()
            if type(connection.Function) == "function" then
                connection.Function()
                fired += 1
            elseif type(connection.Fire) == "function" then
                connection:Fire()
                fired += 1
            end
        end)

        if not success then
            -- Keep trying the remaining connections.
        end
    end

    return fired
end

local function triggerTracedButton()
    local button = getTargetButton()

    if not button then
        warn("[Traced WS] TextButton was not found")
        return
    end

    -- Use MouseButton1Click first so the same handler is not fired twice.
    local fired = runConnections(button.MouseButton1Click)

    -- Some UIs only connect through Activated.
    if fired == 0 then
        runConnections(button.Activated)
    end
end

local function getConnectFunction()
    if WebSocket and type(WebSocket.connect) == "function" then
        return WebSocket.connect
    end

    if websocket and type(websocket.connect) == "function" then
        return websocket.connect
    end

    if syn and syn.websocket and type(syn.websocket.connect) == "function" then
        return syn.websocket.connect
    end

    return nil
end

local connectWebSocket = getConnectFunction()
assert(connectWebSocket, "[Traced WS] This executor does not expose a WebSocket.connect function")

local function bindSocket(ws)
    socket = ws
    connected = true
    print("[Traced WS] Connected")

    ws.OnMessage:Connect(function(message)
        if tostring(message) == "TRIGGER_T" then
            triggerTracedButton()
        end
    end)

    ws.OnClose:Connect(function()
        if socket ~= ws then
            return
        end

        socket = nil
        connected = false
        warn("[Traced WS] Disconnected; reconnecting")

        task.delay(1, function()
            if not connected then
                task.spawn(function()
                    while not connected do
                        if connecting then
                            task.wait(0.25)
                            continue
                        end

                        connecting = true
                        local ok, newSocket = pcall(connectWebSocket, WS_URL)
                        connecting = false

                        if ok and newSocket then
                            bindSocket(newSocket)
                            break
                        end

                        task.wait(1)
                    end
                end)
            end
        end)
    end)
end

local function connect()
    if connected or connecting then
        return
    end

    connecting = true
    local ok, ws = pcall(connectWebSocket, WS_URL)
    connecting = false

    if ok and ws then
        bindSocket(ws)
        return
    end

    warn("[Traced WS] Initial connection failed; retrying")
    task.delay(1, connect)
end

UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode ~= Enum.KeyCode.T then
        return
    end

    if not connected or not socket then
        warn("[Traced WS] Not connected")
        return
    end

    local ok = pcall(function()
        socket:Send("TRIGGER_T")
    end)

    if not ok then
        connected = false
        socket = nil
        task.spawn(connect)
    end
end)

task.spawn(connect)
