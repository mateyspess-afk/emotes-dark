import type { PresenceRecord, PresenceStore } from '@/lib/presence/store'

export function createFakeStore() {
  const data = new Map<string, PresenceRecord>()
  const store: PresenceStore = {
    async put(key, record) {
      data.set(key, structuredClone(record))
    },
    async get(key) {
      const record = data.get(key)
      return record ? structuredClone(record) : null
    },
    async list(prefix) {
      return [...data.keys()].filter((key) => key.startsWith(prefix))
    },
    async delete(key) {
      data.delete(key)
    },
  }
  return { store, data }
}
