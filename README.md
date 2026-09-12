# Traced WebSocket Relay

Cloudflare Worker + Durable Object relay for broadcasting a `TRIGGER_T` event to every connected client, including the client that sent it.

## Cloudflare build

This repository is ready for a Cloudflare Workers Git build.

- Build command: `npm install`
- Deploy command: `npm run deploy`

The Worker entrypoint is `src/index.js` and the Durable Object binding/migration is already defined in `wrangler.toml`.

## Endpoints

- `/` - basic online message
- `/health` - JSON health response
- `/ws` - WebSocket endpoint

## Roblox client

Open `client.lua` and change:

```lua
local WS_URL = "wss://YOUR-WORKER.workers.dev/ws"
```

to your deployed Cloudflare Worker hostname.

Every client should run the same `client.lua`.

When any connected client presses **T**, it sends `TRIGGER_T` to Cloudflare. The Durable Object broadcasts that message to all currently connected clients, including the sender. Each client then runs `getconnections` on:

```lua
gethui().Traced.Main:GetChildren()[7]:GetChildren()[5].TextButton
```

It tries `MouseButton1Click` first and falls back to `Activated` if there are no click connections.
