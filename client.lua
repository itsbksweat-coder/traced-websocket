repeat task.wait() until game:IsLoaded()

local UserInputService = game:GetService("UserInputService")

--========================================================
-- CONFIG
--========================================================

local WS_URL = "wss://traced-websocket.xyzcheatz.workers.dev/ws"

local socket
local connected = false
local connecting = false

--========================================================
-- TOP GUI
--========================================================

pcall(function()
    local old = gethui():FindFirstChild("TracedRiddlerWebSocketInfo")
    if old then
        old:Destroy()
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TracedRiddlerWebSocketInfo"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = gethui()

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 470, 0, 103)
Main.Position = UDim2.new(0.5, -235, 0, 12)
Main.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 10)
Corner.Parent = Main

local Stroke = Instance.new("UIStroke")
Stroke.Thickness = 1
Stroke.Color = Color3.fromRGB(40, 130, 255)
Stroke.Transparency = 0.15
Stroke.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 0, 24)
Title.Position = UDim2.new(0, 10, 0, 6)
Title.BackgroundTransparency = 1
Title.Text = "Traced + Riddler WebSocket"
Title.TextColor3 = Color3.fromRGB(90, 170, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.Parent = Main

local TracedInfo = Instance.new("TextLabel")
TracedInfo.Size = UDim2.new(1, -20, 0, 20)
TracedInfo.Position = UDim2.new(0, 10, 0, 31)
TracedInfo.BackgroundTransparency = 1
TracedInfo.Text = "T = run the Traced TextButton on ALL connected clients"
TracedInfo.TextColor3 = Color3.fromRGB(235, 235, 240)
TracedInfo.TextXAlignment = Enum.TextXAlignment.Left
TracedInfo.Font = Enum.Font.Gotham
TracedInfo.TextSize = 12
TracedInfo.Parent = Main

local RiddlerInfo = Instance.new("TextLabel")
RiddlerInfo.Size = UDim2.new(1, -20, 0, 20)
RiddlerInfo.Position = UDim2.new(0, 10, 0, 52)
RiddlerInfo.BackgroundTransparency = 1
RiddlerInfo.Text = "R = run the Riddler TextButton on ALL connected clients"
RiddlerInfo.TextColor3 = Color3.fromRGB(235, 235, 240)
RiddlerInfo.TextXAlignment = Enum.TextXAlignment.Left
RiddlerInfo.Font = Enum.Font.Gotham
RiddlerInfo.TextSize = 12
RiddlerInfo.Parent = Main

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 20)
Status.Position = UDim2.new(0, 10, 0, 75)
Status.BackgroundTransparency = 1
Status.Text = "Status: Connecting..."
Status.TextColor3 = Color3.fromRGB(255, 190, 70)
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Font = Enum.Font.Gotham
Status.TextSize = 12
Status.Parent = Main

--========================================================
-- DRAGGING
--========================================================

local dragging = false
local dragStart
local startPosition

Main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = Main.Position
    end
end)

Main.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local delta = input.Position - dragStart

    Main.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )
end)

local function setStatus(text, color)
    Status.Text = "Status: " .. text
    if color then
        Status.TextColor3 = color
    end
end

--========================================================
-- TARGET BUTTONS
--========================================================

local function getTracedButton()
    local ok, button = pcall(function()
        return gethui()
            .Traced
            .Main
            :GetChildren()[7]
            :GetChildren()[5]
            .TextButton
    end)

    if ok then
        return button
    end

    return nil
end

local function getRiddlerButton()
    local ok, button = pcall(function()
        return gethui()
            .Riddler
            .Main
            :GetChildren()[7]
            :GetChildren()[3]
            .TextButton
    end)

    if ok then
        return button
    end

    return nil
end

--========================================================
-- GETCONNECTIONS
--========================================================

local function runConnections(signal)
    local ok, connections = pcall(getconnections, signal)

    if not ok or type(connections) ~= "table" then
        return 0
    end

    local fired = 0

    for _, connection in ipairs(connections) do
        pcall(function()
            if type(connection.Function) == "function" then
                connection.Function()
                fired += 1
            elseif type(connection.Fire) == "function" then
                connection:Fire()
                fired += 1
            end
        end)
    end

    return fired
end

local function triggerButton(name, getButton)
    local button = getButton()

    if not button then
        setStatus(name .. " button not found", Color3.fromRGB(255, 80, 80))
        warn("[WS] " .. name .. " TextButton not found")
        return
    end

    setStatus("Running " .. name, Color3.fromRGB(90, 200, 255))

    local fired = runConnections(button.MouseButton1Click)

    if fired == 0 then
        runConnections(button.Activated)
    end

    task.delay(0.75, function()
        if connected then
            setStatus("Connected", Color3.fromRGB(90, 255, 130))
        end
    end)
end

local function triggerTraced()
    triggerButton("Traced", getTracedButton)
end

local function triggerRiddler()
    triggerButton("Riddler", getRiddlerButton)
end

--========================================================
-- WEBSOCKET SUPPORT
--========================================================

local function getWebSocketConnect()
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

local connectWebSocket = getWebSocketConnect()

assert(
    connectWebSocket,
    "[WS] This executor does not expose a WebSocket.connect function"
)

--========================================================
-- CONNECT / RECONNECT
--========================================================

local connect

local function bindSocket(ws)
    socket = ws
    connected = true

    setStatus("Connected", Color3.fromRGB(90, 255, 130))
    print("[WS] Connected")

    ws.OnMessage:Connect(function(message)
        message = tostring(message)

        if message == "TRIGGER_T" then
            triggerTraced()
        elseif message == "TRIGGER_R" then
            triggerRiddler()
        end
    end)

    ws.OnClose:Connect(function()
        if socket ~= ws then
            return
        end

        socket = nil
        connected = false

        setStatus("Disconnected - reconnecting", Color3.fromRGB(255, 120, 80))
        warn("[WS] Disconnected; reconnecting")

        task.delay(1, function()
            connect()
        end)
    end)
end

connect = function()
    if connected or connecting then
        return
    end

    connecting = true
    setStatus("Connecting...", Color3.fromRGB(255, 190, 70))

    local ok, ws = pcall(connectWebSocket, WS_URL)

    connecting = false

    if ok and ws then
        bindSocket(ws)
        return
    end

    setStatus("Connection failed - retrying", Color3.fromRGB(255, 80, 80))

    task.delay(1, function()
        connect()
    end)
end

--========================================================
-- BROADCAST
--========================================================

local function broadcast(command, label)
    if not connected or not socket then
        setStatus("Not connected", Color3.fromRGB(255, 80, 80))
        connect()
        return
    end

    setStatus("Broadcasting " .. label, Color3.fromRGB(90, 170, 255))

    local ok = pcall(function()
        socket:Send(command)
    end)

    if not ok then
        connected = false
        socket = nil

        setStatus("Send failed - reconnecting", Color3.fromRGB(255, 80, 80))
        task.spawn(connect)
    end
end

--========================================================
-- HOTKEYS
--========================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.T then
        broadcast("TRIGGER_T", "Traced")
    elseif input.KeyCode == Enum.KeyCode.R then
        broadcast("TRIGGER_R", "Riddler")
    end
end)

--========================================================
-- START
--========================================================

task.spawn(connect)
