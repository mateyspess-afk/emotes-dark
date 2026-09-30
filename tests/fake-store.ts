import type { PresenceRecord, PresenceStore } from '@/lib/presence/store'

type Scope = { records: Map<number, PresenceRecord>; expiresAt: number }

/** In-memory stand-in for Redis that mimics key TTLs using Date.now(). */
export function createFakeStore() {
  const scopes = new Map<string, Scope>()

  function liveScope(name: string): Scope | undefined {
    const scope = scopes.get(name)
    if (scope && scope.expiresAt <= Date.now()) {
      scopes.delete(name)
      return undefined
    }
    return scope
  }

  const store: PresenceStore = {
    async upsert(name, record, keyTtlMs) {
      const scope = liveScope(name) ?? { records: new Map(), expiresAt: 0 }
      scope.records.set(record.userId, structuredClone(record))
      scope.expiresAt = Date.now() + keyTtlMs
      scopes.set(name, scope)
    },
    async listActive(name, minLastSeen, limit) {
      const scope = liveScope(name)
      if (!scope) return []
      for (const [id, record] of scope.records) {
        if (record.lastSeen < minLastSeen) scope.records.delete(id)
      }
      if (scope.records.size === 0) scopes.delete(name)
      return [...scope.records.values()]
        .sort((a, b) => b.lastSeen - a.lastSeen)
        .slice(0, limit)
        .map((record) => structuredClone(record))
    },
    async ping() {},
  }

  function size() {
    let total = 0
    for (const name of [...scopes.keys()]) total += liveScope(name)?.records.size ?? 0
    return total
  }

  return { store, scopes, size }
}
