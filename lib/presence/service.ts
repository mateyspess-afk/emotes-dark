import type { PresenceRecord, PresenceStore } from './store'
import type { Registration, ServerScope } from './validation'

export const PRESENCE_TTL_MS = 15_000
export const MAX_CLIENTS_PER_SERVER = 200
const KEY_ROOT = 'presence'

export function scopePrefix({ gameId, placeId, jobId }: ServerScope): string {
  return `${KEY_ROOT}/${gameId}/${placeId}/${jobId}/`
}

export function isExpired(record: PresenceRecord | null, now: number): boolean {
  if (!record || typeof record.lastSeen !== 'number') return true
  return now - record.lastSeen > PRESENCE_TTL_MS
}

export async function registerPresence(
  store: PresenceStore,
  registration: Registration,
  now: number,
): Promise<PresenceRecord> {
  const record: PresenceRecord = {
    userId: registration.userId,
    username: registration.username,
    displayName: registration.displayName,
    sessionId: registration.sessionId,
    lastSeen: now,
  }
  await store.put(`${scopePrefix(registration)}${registration.userId}`, record)
  return record
}

async function partitionByExpiry(store: PresenceStore, keys: string[], now: number) {
  const entries = await Promise.all(
    keys.map(async (key) => ({ key, record: await store.get(key).catch(() => null) })),
  )
  const active: PresenceRecord[] = []
  const expiredKeys: string[] = []
  for (const { key, record } of entries) {
    if (isExpired(record, now)) expiredKeys.push(key)
    else active.push(record as PresenceRecord)
  }
  return { active, expiredKeys }
}

async function deleteKeys(store: PresenceStore, keys: string[]) {
  await Promise.allSettled(keys.map((key) => store.delete(key)))
}

export async function listActivePresence(
  store: PresenceStore,
  scope: ServerScope,
  now: number,
): Promise<PresenceRecord[]> {
  const keys = await store.list(scopePrefix(scope))
  const { active, expiredKeys } = await partitionByExpiry(store, keys, now)
  await deleteKeys(store, expiredKeys)
  return active
    .sort((a, b) => b.lastSeen - a.lastSeen)
    .slice(0, MAX_CLIENTS_PER_SERVER)
    .map(({ userId, username, displayName, sessionId, lastSeen }) => ({
      userId,
      username,
      displayName,
      sessionId,
      lastSeen,
    }))
}

export async function cleanupExpiredPresence(store: PresenceStore, now: number) {
  const keys = await store.list(`${KEY_ROOT}/`)
  const { active, expiredKeys } = await partitionByExpiry(store, keys, now)
  await deleteKeys(store, expiredKeys)
  return { removed: expiredKeys.length, remaining: active.length }
}
