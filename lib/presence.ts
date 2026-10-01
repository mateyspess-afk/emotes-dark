import { Redis } from '@upstash/redis'

export const PRESENCE_TTL_MS = 30_000
const PREFIX = 'emotes-dark:presence:'


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
  if (redis) return redis

  const url = process.env.KV_REST_API_URL ?? process.env.UPSTASH_REDIS_REST_URL
  const token = process.env.KV_REST_API_TOKEN ?? process.env.UPSTASH_REDIS_REST_TOKEN
  if (!url || !token) throw new Error('Redis não configurado')

  redis = new Redis({ url, token })
  return redis
}

export function cleanText(value: unknown, field: keyof typeof limits): string {
  if (typeof value !== 'string') throw new Error(`${field} deve ser texto`)
  const result = value.trim()
  if (!result || result.length > limits[field]) throw new Error(`${field} inválido`)
  return result
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

function serverPresenceHashKey(gameId: string, placeId: string, jobId: string) {
  return `${PREFIX}server:${serverKey(gameId, placeId, jobId)}`
}

const STORAGE_TIMEOUT_MS = 2_500

async function withStorageTimeout<T>(operation: Promise<T>): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined
  try {
    return await Promise.race([
      operation,
      new Promise<T>((_, reject) => {
        timer = setTimeout(() => reject(new Error('Redis excedeu o tempo limite')), STORAGE_TIMEOUT_MS)
      }),
    ])
  } finally {
    if (timer) clearTimeout(timer)
  }
}

type ServerPresenceState = Record<string, Presence>

export async function savePresence(presence: Presence) {
  const client = getRedis()
  const key = serverPresenceHashKey(presence.gameId, presence.placeId, presence.jobId)
  const current = (await withStorageTimeout(client.get<ServerPresenceState>(key))) ?? {}
  current[presence.userId] = presence
  // Uma leitura e uma escrita por heartbeat, sem SCAN/MGET de chaves dinâmicas.
  await withStorageTimeout(
    client.set(key, JSON.stringify(current), { ex: Math.ceil(PRESENCE_TTL_MS / 1000) }),
  )
}

export async function activePresences(gameId: string, placeId: string, jobId: string) {
  const client = getRedis()
  const key = serverPresenceHashKey(gameId, placeId, jobId)
  const values = await withStorageTimeout(client.get<ServerPresenceState>(key))
  if (!values) return []

  const active: Presence[] = []
  const stale: string[] = []
  for (const [userId, presence] of Object.entries(values)) {
    if (presence.userId === userId && isPresenceActive(presence.lastSeen)) active.push(presence)
    else stale.push(userId)
  }
  if (stale.length) {
    for (const userId of stale) delete values[userId]
    await withStorageTimeout(client.set(key, JSON.stringify(values), { ex: Math.ceil(PRESENCE_TTL_MS / 1000) }))
  }
  return active
}

export function isPresenceActive(lastSeen: number, now = Date.now()) {
  return now - lastSeen < PRESENCE_TTL_MS
}
