export class TriggerRoom {
  constructor(ctx, env) {
    this.ctx = ctx;
    this.env = env;
  }

  async fetch(request) {
    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("WebSocket upgrade required", { status: 426 });
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    this.ctx.acceptWebSocket(server);
    server.send("CONNECTED");

    return new Response(null, {
      status: 101,
      webSocket: client,
    });
  }

  webSocketMessage(ws, message) {
    if (typeof message !== "string") return;

    const command = message.trim().toUpperCase();

    if (command !== "TRIGGER_T" && command !== "TRIGGER_R") {
      return;
    }

    // Broadcast to every connected client, including the sender.
    for (const socket of this.ctx.getWebSockets()) {
      try {
        socket.send(command);
      } catch {}
    }
  }

  webSocketClose(ws, code, reason) {
    try {
      ws.close(code, reason);
    } catch {}
  }

  webSocketError(ws) {
    try {
      ws.close(1011, "WebSocket error");
    } catch {}
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return Response.json({
        ok: true,
        websocket: "/ws",
        commands: ["TRIGGER_T", "TRIGGER_R"],
      });
    }

    if (url.pathname === "/") {
      return new Response("Traced + Riddler WebSocket relay is online.", {
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    }

    if (url.pathname !== "/ws") {
      return new Response("Not found", { status: 404 });
    }

    const id = env.TRIGGER_ROOM.idFromName("global");
    const room = env.TRIGGER_ROOM.get(id);
    return room.fetch(request);
  },
};
