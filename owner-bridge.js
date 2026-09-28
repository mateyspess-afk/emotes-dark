const http = require("http");
const { URL } = require("url");

const PORT = Number(process.env.PORT || 3000);
const CLIENT_TTL_MS = 45_000;
const COMMAND_TTL_MS = 60 * 60 * 1_000;
const OWNER_USER_IDS = new Set(
  String(process.env.OWNER_USER_IDS || "10956940752")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean)
);
const OWNER_CONTROL_TOKEN = String(process.env.OWNER_CONTROL_TOKEN || "").trim();
const ALLOWED_ACTIONS = new Set([
  "kick",
  "jumpscare1",
  "jumpscare2",
  "jumpscare3",
  "message",
  "global_message",
  "next_player",
  "sit",
  "tp_pull",
  "goto",
]);

const clients = new Map();
const commands = [];
let nextCommandId = 1;

function clean(value) {
  return String(value == null ? "" : value).trim();
}

function numberOrNull(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function normalizeName(value) {
  return clean(value)
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

function normalizePosition(value) {
  if (!value || typeof value !== "object") return null;
  const x = numberOrNull(value.x);
  const y = numberOrNull(value.y);
  const z = numberOrNull(value.z);
  return x === null || y === null || z === null ? null : { x, y, z };
}

function clientFrom(body) {
  const userId = clean(body.userId);
  if (!userId) return null;
  return {
    userId,
    username: clean(body.username),
    displayName: clean(body.displayName),
    gameId: clean(body.gameId),
    placeId: clean(body.placeId),
    jobId: clean(body.jobId),
    sessionId: clean(body.sessionId),
    position: normalizePosition(body.position),
    lastSeenAt: Date.now(),
  };
}

function isOwnerRequest(req, body) {
  if (OWNER_CONTROL_TOKEN) {
    const headerToken = clean(req.headers["x-owner-token"]);
    const authorization = clean(req.headers.authorization);
    return headerToken === OWNER_CONTROL_TOKEN || authorization === "Bearer " + OWNER_CONTROL_TOKEN;
  }
  return OWNER_USER_IDS.has(clean(body.userId));
}

function findClient(body, gameId, placeId) {
  const wantedId = clean(body.targetUserId);
  const wantedName = normalizeName(body.targetUsername);
  const active = [...clients.values()].filter(
    (client) => client.gameId === gameId && client.placeId === placeId && Date.now() - client.lastSeenAt <= CLIENT_TTL_MS
  );

  if (wantedId) {
    const client = active.find((candidate) => candidate.userId === wantedId) || null;
    return { client, matches: client ? [client] : [] };
  }
  if (!wantedName) return { client: null, matches: [] };
  if (wantedName.length < 2) {
    return { client: null, matches: [], error: "partial_name_requires_two_letters" };
  }

  const matches = active.filter((client) => {
    const username = normalizeName(client.username);
    const displayName = normalizeName(client.displayName);
    return username.startsWith(wantedName) || displayName.startsWith(wantedName);
  });
  return { client: matches.length === 1 ? matches[0] : null, matches };
}

function prune() {
  const now = Date.now();
  for (const [key, client] of clients) {
    if (now - client.lastSeenAt > CLIENT_TTL_MS) clients.delete(key);
  }
  while (commands.length && (now - commands[0].createdAt > COMMAND_TTL_MS || commands.length > 2_000)) {
    commands.shift();
  }
}

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type, X-Owner-Token, Authorization",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Cache-Control": "no-store",
  });
  res.end(body);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let raw = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => {
      raw += chunk;
      if (raw.length > 1_000_000) {
        reject(new Error("payload_too_large"));
        req.destroy();
      }
    });
    req.on("end", () => {
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(new Error("invalid_json"));
      }
    });
    req.on("error", reject);
  });
}

function queueCommand(body, req) {
  if (!isOwnerRequest(req, body)) return { status: 403, body: { ok: false, message: "owner_not_authorized" } };
  const action = clean(body.action);
  if (!ALLOWED_ACTIONS.has(action)) return { status: 422, body: { ok: false, message: "unsupported_action" } };

  const owner = clients.get(clean(body.userId));
  const isGlobalMessage = action === "global_message";
  const gameId = isGlobalMessage ? "*" : clean(body.gameId || owner?.gameId);
  const placeId = isGlobalMessage ? "*" : clean(body.placeId || owner?.placeId);
  if (!isGlobalMessage && (!gameId || !placeId)) return { status: 422, body: { ok: false, message: "gameId_and_placeId_required" } };

  let target = null;
  if (action === "next_player") {
    target = [...clients.values()]
      .filter((client) => client.gameId === gameId && client.placeId === placeId && client.userId !== clean(body.userId) && Date.now() - client.lastSeenAt <= CLIENT_TTL_MS)
      .sort((a, b) => a.lastSeenAt - b.lastSeenAt)[0] || null;
    if (!target) return { status: 404, body: { ok: false, message: "no_active_target" } };
  } else if (action !== "global_message") {
    if (!clean(body.targetUserId) && !clean(body.targetUsername)) {
      return { status: 422, body: { ok: false, message: "target_required" } };
    }
    const resolved = findClient(body, gameId, placeId);
    if (resolved.error) {
      return { status: 422, body: { ok: false, message: resolved.error } };
    }
    if (resolved.matches.length > 1) {
      return {
        status: 409,
        body: {
          ok: false,
          message: "ambiguous_target",
          candidates: resolved.matches.slice(0, 8).map((client) => ({
            userId: client.userId,
            username: client.username,
            displayName: client.displayName,
          })),
        },
      };
    }
    target = resolved.client;
    if (!target) return { status: 404, body: { ok: false, message: "target_not_running_script" } };
  }

  let payload = body.payload && typeof body.payload === "object" ? { ...body.payload } : {};
  if (action === "next_player" && target) {
    payload.nextTarget = {
      userId: target.userId,
      username: target.username,
      displayName: target.displayName,
    };
  }
  if (action === "tp_pull") {
    const ownerPosition = owner?.position;
    if (!ownerPosition) return { status: 422, body: { ok: false, message: "owner_position_unavailable" } };
    payload.position = ownerPosition;
  }
  if (action === "goto") {
    if (!target.position) return { status: 422, body: { ok: false, message: "target_position_unavailable" } };
    payload.position = target.position;
  }

  const command = {
    id: nextCommandId++,
    action,
    payload,
    issuedBy: clean(body.userId),
    gameId,
    placeId,
    targetUserId: action === "goto" || action === "next_player" ? clean(body.userId) : (target ? target.userId : "*"),
    targetJobId: action === "goto" || action === "next_player" ? (owner?.jobId || "") : (target?.jobId || ""),
    createdAt: Date.now(),
  };
  commands.push(command);
  return {
    status: 202,
    body: {
      ok: true,
      commandId: command.id,
      targetUserId: command.targetUserId,
      targetUsername: target?.username || "",
      targetDisplayName: target?.displayName || "",
    },
  };
}

const server = http.createServer(async (req, res) => {
  prune();
  const url = new URL(req.url, "http://localhost");
  if (req.method === "OPTIONS") return sendJson(res, 204, {});

  if (req.method === "GET" && url.pathname === "/health") {
    return sendJson(res, 200, { ok: true, clients: clients.size, queuedCommands: commands.length });
  }

  if (req.method === "POST" && url.pathname === "/clients/register") {
    try {
      const body = await readJson(req);
      const client = clientFrom(body);
      if (!client) return sendJson(res, 422, { ok: false, message: "userId_required" });
      const previous = clients.get(client.userId);
      const newSession = !previous || previous.gameId !== client.gameId || previous.placeId !== client.placeId || previous.jobId !== client.jobId || (client.sessionId && client.sessionId !== previous.sessionId);
      if (newSession) {
        // Sessão nova começa no fim da fila: mensagens e jumpscares antigos não voltam.
        client.sessionCursor = nextCommandId - 1;
        client.deliveredCursor = client.sessionCursor;
      } else {
        client.sessionCursor = previous.sessionCursor || 0;
        client.deliveredCursor = previous.deliveredCursor || client.sessionCursor;
      }
      clients.set(client.userId, client);
      return sendJson(res, 200, { ok: true, serverTime: Date.now(), client: { userId: client.userId, gameId: client.gameId, placeId: client.placeId } });
    } catch (error) {
      return sendJson(res, error.message === "payload_too_large" ? 413 : 400, { ok: false, message: error.message });
    }
  }

  if (req.method === "POST" && url.pathname === "/commands") {
    try {
      const body = await readJson(req);
      const result = queueCommand(body, req);
      return sendJson(res, result.status, result.body);
    } catch (error) {
      return sendJson(res, error.message === "payload_too_large" ? 413 : 400, { ok: false, message: error.message });
    }
  }

  if (req.method === "GET" && url.pathname === "/commands/poll") {
    const userId = clean(url.searchParams.get("userId"));
    const gameId = clean(url.searchParams.get("gameId"));
    const placeId = clean(url.searchParams.get("placeId"));
    const jobId = clean(url.searchParams.get("jobId"));
    const sessionId = clean(url.searchParams.get("sessionId"));
    const requestedCursor = Number(url.searchParams.get("cursor")) || 0;
    if (!userId || !gameId || !placeId) return sendJson(res, 422, { ok: false, message: "userId_gameId_placeId_required" });

    const client = clients.get(userId);
    const cursor = Math.max(requestedCursor, Number(client?.deliveredCursor || client?.sessionCursor || 0));
    if (client) {
      client.lastSeenAt = Date.now();
      client.gameId = gameId;
      client.placeId = placeId;
      client.jobId = jobId || client.jobId;
      client.sessionId = sessionId || client.sessionId;
    }

    const available = commands.filter((command) =>
      command.id > cursor &&
      ((command.gameId === gameId && command.placeId === placeId) ||
        (command.action === "global_message" && command.gameId === "*" && command.placeId === "*")) &&
      (command.targetUserId === "*" || command.targetUserId === userId) &&
      (!command.targetJobId || !jobId || command.targetJobId === jobId)
    );
    const nextCursor = commands.length ? Math.max(cursor, commands[commands.length - 1].id) : cursor;
    if (client) client.deliveredCursor = nextCursor;
    return sendJson(res, 200, { ok: true, commands: available, cursor: nextCursor });
  }

  return sendJson(res, 404, { ok: false, message: "not_found" });
});

server.listen(PORT, "0.0.0.0", () => {
  console.log("Emotes Dark owner bridge listening on port " + PORT);
  console.log("Owner authentication: " + (OWNER_CONTROL_TOKEN ? "token" : "OWNER_USER_IDS"));
});
