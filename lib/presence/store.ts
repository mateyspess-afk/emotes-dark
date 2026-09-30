import { Redis } from '@upstash/redis'
import type { RelayCommand } from './validation'

export type PresenceRecord = {
  userId: number
  username: string
  displayName: string
  sessionId: string
  lastSeen: number
  command?: RelayCommand
}

/**
 * Each server (gameId + placeId + jobId) has its own scope. Implementations must
 * drop records older than `minLastSeen` and let abandoned scopes expire on their own.
 */
export interface PresenceStore {
  upsert(scope: string, record: PresenceRecord, keyTtlMs: number): Promise<void>
  listActive(scope: string, minLastSeen: number, limit: number): Promise<PresenceRecord[]>
  ping(): Promise<void>
}

export class StorageUnavailableError extends Error {
  constructor(cause?: unknown) {
    super('O Redis (Upstash) não está configurado neste ambiente', { cause })
    this.name = 'StorageUnavailableError'
  }
}

let overrideStore: PresenceStore | null = null
let redisStore: PresenceStore | null = null

/** Only used by the test suite to swap Redis for a fake. */
export function setPresenceStoreForTests(store: PresenceStore | null) {
  overrideStore = store
}

const seenKey = (scope: string) => `${scope}:seen`
const dataKey = (scope: string) => `${scope}:data`

function parseRecord(value: unknown): PresenceRecord | null {
  if (!value) return null
  if (typeof value === 'string') {
    try {
      return JSON.parse(value) as PresenceRecord
    } catch {
      return null
    }
  }
  return value as PresenceRecord
}

function createRedisStore(): PresenceStore {
  const url = process.env.KV_REST_API_URL ?? process.env.UPSTASH_REDIS_REST_URL
  const token = process.env.KV_REST_API_TOKEN ?? process.env.UPSTASH_REDIS_REST_TOKEN
  if (!url || !token) throw new StorageUnavailableError()

  const redis = new Redis({ url, token })

  return {
    async upsert(scope, record, keyTtlMs) {
      const member = String(record.userId)
      await redis
        .multi()
        .hset(dataKey(scope), { [member]: JSON.stringify(record) })
        .zadd(seenKey(scope), { score: record.lastSeen, member })
        .pexpire(dataKey(scope), keyTtlMs)
        .pexpire(seenKey(scope), keyTtlMs)
        .exec()
    },

    async listActive(scope, minLastSeen, limit) {
      const expiredRange = `(${minLastSeen}` as const
      const expired = await redis.zrange<string[]>(seenKey(scope), '-inf', expiredRange, {
        byScore: true,
      })
      if (expired.length > 0) {
        await redis
          .multi()
          .hdel(dataKey(scope), ...expired.map(String))
          .zremrangebyscore(seenKey(scope), '-inf', expiredRange)
          .exec()
      }

      const ids = await redis.zrange<string[]>(seenKey(scope), '+inf', minLastSeen, {
        byScore: true,
        rev: true,
        offset: 0,
        count: limit,
      })
      if (ids.length === 0) return []

      const values = await redis.hmget<Record<string, unknown>>(dataKey(scope), ...ids.map(String))
      if (!values) return []
      return ids
        .map((id) => parseRecord(values[String(id)]))
        .filter((record): record is PresenceRecord => record !== null)
    },

    async ping() {
      await redis.ping()
    },
  }
}

export function getPresenceStore(): PresenceStore {
  if (overrideStore) return overrideStore
  redisStore ??= createRedisStore()
  return redisStore
}
