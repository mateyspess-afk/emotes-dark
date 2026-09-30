import type { PresenceRecord, PresenceStore } from './store'
import type { Registration, ServerScope } from './validation'

export const PRESENCE_TTL_MS = 15_000
/** Whole server scopes vanish from Redis once nobody has sent a signal for this long. */
export const SCOPE_KEY_TTL_MS = 60_000
export const MAX_CLIENTS_PER_SERVER = 200
const KEY_ROOT = 'emotes-dark:presence'

export function scopeKey({ gameId, placeId, jobId }: ServerScope): string {
  return `${KEY_ROOT}:${gameId}:${placeId}:${jobId}`
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
    ...(registration.command ? { command: registration.command } : {}),
  }
  await store.upsert(scopeKey(registration), record, SCOPE_KEY_TTL_MS)
  return record
}

export async function listActivePresence(
  store: PresenceStore,
  scope: ServerScope,
  now: number,
): Promise<PresenceRecord[]> {
  const records = await store.listActive(
    scopeKey(scope),
    now - PRESENCE_TTL_MS,
    MAX_CLIENTS_PER_SERVER,
  )
  return records
    .filter((record) => !isExpired(record, now))
    .sort((a, b) => b.lastSeen - a.lastSeen)
    .map(({ userId, username, displayName, sessionId, lastSeen, command }) => ({
      userId,
      username,
      displayName,
      sessionId,
      lastSeen,
      ...(command ? { command } : {}),
    }))
}
