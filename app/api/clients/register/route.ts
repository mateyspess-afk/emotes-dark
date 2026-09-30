import { assertUrlLength, handleError, HttpError, json, readJsonBody } from '@/lib/presence/http'
import { PRESENCE_TTL_MS, registerPresence } from '@/lib/presence/service'
import { getPresenceStore } from '@/lib/presence/store'
import { MAX_BODY_BYTES, validateRegistration } from '@/lib/presence/validation'

export const dynamic = 'force-dynamic'

export async function POST(request: Request) {
  try {
    assertUrlLength(request)
    const body = await readJsonBody(request, MAX_BODY_BYTES)
    const result = validateRegistration(body)
    if (!result.ok) throw new HttpError(400, result.error)

    const record = await registerPresence(getPresenceStore(), result.data, Date.now())
    return json({ ok: true, client: record, ttlSeconds: PRESENCE_TTL_MS / 1000 })
  } catch (error) {
    return handleError(error)
  }
}
