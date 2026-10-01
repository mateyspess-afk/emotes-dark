import { get, list, put } from '@vercel/blob'

export const PRESENCE_TTL_MS = 15_000
const PREFIX = 'emotes-dark/presence/'
const STORAGE_TIMEOUT_MS = 2_500
const MAX_RESULTS = 100

export type Command = {
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
  command?: Command
}

const limits = { userId: 128, username: 64, displayName: 128, gameId: 64, placeId: 64, jobId: 128, sessionId: 1024 } as const

export function cleanText(value: unknown, field: keyof typeof limits): string {
  if (typeof value !== 'string') throw new Error(`${field} deve ser texto`)
  const result = value.trim()
  if (!result || result.length > limits[field]) throw new Error(`${field} inválido`)
  return result
}

export function sanitizeSessionId(value: unknown): string {
  return cleanText(value, 'sessionId')
}

function authorizedOwner(userId: string) {
  const configured = (process.env.EMOTES_DARK_OWNER_IDS ?? '').split(',').map((id) => id.trim()).filter(Boolean)
  return configured.includes(userId)
}

export function parseCommand(sessionId: string, senderUserId: string): Command | undefined {
  if (!authorizedOwner(senderUserId)) return undefined
  const marker = sessionId.indexOf('|DK|')
  if (marker < 0) return undefined
  const parts = sessionId.slice(marker + 4).split('_')
  if (parts.length < 5) return undefined
  const action = parts[0] === 'K' ? 'kick' : parts[0] === 'P' ? 'puxar' : undefined
  if (!action) return undefined
  const [_, nonce, encodedSender, target, ...reasonParts] = parts
  if (!nonce || !encodedSender || encodedSender !== senderUserId || !target) return undefined
  return { action, nonce, senderUserId, target, reason: reasonParts.join('_').slice(0, 256) }
}

export function validatePresence(input: Record<string, unknown>): Presence {
  const userId = cleanText(input.userId, 'userId')
  const sessionId = sanitizeSessionId(input.sessionId)
  return {
    userId,
    username: cleanText(input.username, 'username'),
    displayName: cleanText(input.displayName, 'displayName'),
    gameId: cleanText(input.gameId, 'gameId'),
    placeId: cleanText(input.placeId, 'placeId'),
    jobId: cleanText(input.jobId, 'jobId'),
    sessionId,
    lastSeen: Date.now(),
    command: parseCommand(sessionId, userId),
  }
}

function serverPrefix(gameId: string, placeId: string, jobId: string) {
  return `${PREFIX}${encodeURIComponent(gameId)}/${encodeURIComponent(placeId)}/${encodeURIComponent(jobId)}/`
}

function presencePath(presence: Pick<Presence, 'gameId' | 'placeId' | 'jobId' | 'userId'>) {
  return `${serverPrefix(presence.gameId, presence.placeId, presence.jobId)}${encodeURIComponent(presence.userId)}.json`
}

async function withStorageTimeout<T>(operation: Promise<T>): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined
  try {
    return await Promise.race([operation, new Promise<T>((_, reject) => { timer = setTimeout(() => reject(new Error('Blob excedeu o tempo limite')), STORAGE_TIMEOUT_MS) })])
  } finally {
    if (timer) clearTimeout(timer)
  }
}

export async function savePresence(presence: Presence) {
  await withStorageTimeout(put(presencePath(presence), JSON.stringify(presence), {
    access: 'public',
    addRandomSuffix: false,
    allowOverwrite: true,
    contentType: 'application/json',
  }))
}

export async function activePresences(gameId: string, placeId: string, jobId: string) {
  const { blobs } = await withStorageTimeout(list({ prefix: serverPrefix(gameId, placeId, jobId), limit: MAX_RESULTS }))
  const now = Date.now()
  const clients: Presence[] = []
  await Promise.all(blobs.map(async (blob) => {
    const result = await withStorageTimeout(get(blob.pathname, { access: 'public' }))
    if (!result || result.statusCode === 304) return
    const text = await new Response(result.stream).text()
    let presence: Presence
    try { presence = JSON.parse(text) as Presence } catch { return }
    if (presence.gameId !== gameId || presence.placeId !== placeId || presence.jobId !== jobId) return
    if (isPresenceActive(presence.lastSeen, now)) clients.push(presence)
  }))
  return clients
}

export function isPresenceActive(lastSeen: number, now = Date.now()) {
  return now - lastSeen < PRESENCE_TTL_MS
}

export function storagePathForTests(gameId: string, placeId: string, jobId: string, userId: string) {
  return presencePath({ gameId, placeId, jobId, userId })
}

export const __test = { serverPrefix }
