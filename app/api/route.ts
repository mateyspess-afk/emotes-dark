import { json } from '@/lib/presence/http'
import { PRESENCE_TTL_MS } from '@/lib/presence/service'
import { getPresenceStore } from '@/lib/presence/store'

export const dynamic = 'force-dynamic'

async function checkStorage(): Promise<{ ready: boolean; error?: string }> {
  try {
    await getPresenceStore().ping()
    return { ready: true }
  } catch (error) {
    return { ready: false, error: error instanceof Error ? error.message : 'Falha desconhecida' }
  }
}

export async function GET() {
  const storage = await checkStorage()
  return json(
    {
      ok: storage.ready,
      service: 'emotes-dark-bridge',
      status: storage.ready ? 'online' : 'degraded',
      storage: {
        provider: 'upstash-redis',
        ready: storage.ready,
        ...(storage.error ? { error: storage.error } : {}),
      },
      ttlSeconds: PRESENCE_TTL_MS / 1000,
      time: new Date().toISOString(),
    },
    storage.ready ? 200 : 503,
  )
}
