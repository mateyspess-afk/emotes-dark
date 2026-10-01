import { Redis } from '@upstash/redis'

export const PRESENCE_TTL_MS = 15_000
const PREFIX = 'emotes-dark:presence:'

export type CommandPacket = {
  action: 'kick' | 'puxar'
  nonce: string
  senderUserId: string
  target: string
  reason: string
}

export type Presence = {
  userId: string
  username: string
  displayName: string
  gameId: string
  placeId: string
  jobId: string
  sessionId: string
  lastSeen: number
}

const limits = {
  userId: 128,
  username: 64,
  displayName: 128,
  gameId: 64,
  placeId: 64,
  jobId: 128,
  sessionId: 512,
} as const

let redis: Redis | undefined
function getRedis() {
  if (!redis) redis = Redis.fromEnv()
  return redis
}

export function cleanText(value: unknown, field: keyof typeof limits): string {
  if (typeof value !== 'string') throw new Error(`${field} deve ser texto`)
  const result = value.trim()
  if (!result || result.length > limits[field]) throw new Error(`${field} inválido`)
  return result
}

export function parseCommandPacket(sessionId: string): CommandPacket | undefined {
  const marker = sessionId.indexOf('_EDK_')
  if (marker < 0) return undefined
  const parts = sessionId.slice(marker + 5).split('_')
  if (parts.length < 6) return undefined
  const [actionCode, nonce, senderUserId, target, ...reasonParts] = parts
  if (!nonce || !senderUserId || !target) return undefined
  if (actionCode !== 'K' && actionCode !== 'P') return undefined
  return {
    action: actionCode === 'K' ? 'kick' : 'puxar',
    nonce,
    senderUserId,
    target,
    reason: reasonParts.join('_'),
  }
}

export function sanitizeSessionId(value: unknown): string {
  return cleanText(value, 'sessionId')
}

export function validatePresence(input: Record<string, unknown>): Presence {
  const sessionId = sanitizeSessionId(input.sessionId)
  return {
    userId: cleanText(input.userId, 'userId'),
    username: cleanText(input.username, 'username'),
    displayName: cleanText(input.displayName, 'displayName'),
    gameId: cleanText(input.gameId, 'gameId'),
    placeId: cleanText(input.placeId, 'placeId'),
    jobId: cleanText(input.jobId, 'jobId'),
    sessionId,
    lastSeen: Date.now(),
  }
}

function serverKey(gameId: string, placeId: string, jobId: string) {
  return `${gameId}:${placeId}:${jobId}`
}

function presenceKey(presence: Pick<Presence, 'gameId' | 'placeId' | 'jobId' | 'userId'>) {
  return `${PREFIX}${serverKey(presence.gameId, presence.placeId, presence.jobId)}:${presence.userId}`
}

function serverIndexKey(gameId: string, placeId: string, jobId: string) {
  return `${PREFIX}index:${serverKey(gameId, placeId, jobId)}`
}

export async function savePresence(presence: Presence) {
  const client = getRedis()
  const key = presenceKey(presence)
  await client.set(key, presence, { px: PRESENCE_TTL_MS })
  await client.sadd(serverIndexKey(presence.gameId, presence.placeId, presence.jobId), key)
  await client.expire(serverIndexKey(presence.gameId, presence.placeId, presence.jobId), Math.ceil(PRESENCE_TTL_MS / 1000))
}

export async function activePresences(gameId: string, placeId: string, jobId: string) {
  const client = getRedis()
  const indexKey = serverIndexKey(gameId, placeId, jobId)
  const keys = await client.smembers<string[]>(indexKey)
  if (!keys.length) return []
  const values = await client.mget<(Presence | null)[]>(...keys)
  const active: Presence[] = []
  const stale: string[] = []
  values.forEach((presence, index) => {
    if (presence && isPresenceActive(presence.lastSeen)) active.push(presence)
    else stale.push(keys[index])
  })
  if (stale.length) await client.srem(indexKey, ...stale)
  return active
}

export function isPresenceActive(lastSeen: number, now = Date.now()) {
  return now - lastSeen < PRESENCE_TTL_MS
}
