import { assertUrlLength, handleError, HttpError, json } from '@/lib/presence/http'
import { listActivePresence } from '@/lib/presence/service'
import { getPresenceStore } from '@/lib/presence/store'
import { validateScope } from '@/lib/presence/validation'

export const dynamic = 'force-dynamic'

export async function GET(request: Request) {
  try {
    assertUrlLength(request)
    const params = new URL(request.url).searchParams
    const scope = validateScope({
      gameId: params.get('gameId') ?? '',
      placeId: params.get('placeId') ?? '',
      jobId: params.get('jobId') ?? '',
    })
    if (!scope.ok) throw new HttpError(400, scope.error)

    const clients = await listActivePresence(getPresenceStore(), scope.data, Date.now())
    return json({ clients })
  } catch (error) {
    return handleError(error)
  }
}
