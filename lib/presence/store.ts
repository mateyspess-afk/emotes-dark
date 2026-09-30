import { getStore } from '@netlify/blobs'

export const STORE_NAME = 'emotes-dark-presence'

export type PresenceRecord = {
  userId: number
  username: string
  displayName: string
  sessionId: string
  lastSeen: number
}

export interface PresenceStore {
  put(key: string, record: PresenceRecord): Promise<void>
  get(key: string): Promise<PresenceRecord | null>
  list(prefix: string): Promise<string[]>
  delete(key: string): Promise<void>
}

export class StorageUnavailableError extends Error {
  constructor(cause?: unknown) {
    super('Netlify Blobs não está disponível neste ambiente', { cause })
    this.name = 'StorageUnavailableError'
  }
}

let overrideStore: PresenceStore | null = null

/** Only used by the test suite to swap Netlify Blobs for a fake. */
export function setPresenceStoreForTests(store: PresenceStore | null) {
  overrideStore = store
}

function createNetlifyStore(): PresenceStore {
  const siteID = process.env.NETLIFY_BLOBS_SITE_ID
  const token = process.env.NETLIFY_BLOBS_TOKEN

  let blobs: ReturnType<typeof getStore>
  try {
    blobs =
      siteID && token
        ? getStore({ name: STORE_NAME, siteID, token, consistency: 'strong' })
        : getStore({ name: STORE_NAME, consistency: 'strong' })
  } catch (error) {
    throw new StorageUnavailableError(error)
  }

  return {
    async put(key, record) {
      await blobs.setJSON(key, record)
    },
    async get(key) {
      const value = (await blobs.get(key, { type: 'json' })) as PresenceRecord | null
      return value ?? null
    },
    async list(prefix) {
      const { blobs: entries } = await blobs.list({ prefix })
      return entries.map((entry) => entry.key)
    },
    async delete(key) {
      await blobs.delete(key)
    },
  }
}

export function getPresenceStore(): PresenceStore {
  return overrideStore ?? createNetlifyStore()
}
