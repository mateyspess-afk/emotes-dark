import { timingSafeEqual } from 'node:crypto'
import { assertUrlLength, handleError, HttpError, json, readJsonBody } from '@/lib/presence/http'
import { PRESENCE_TTL_MS, registerPresence } from '@/lib/presence/service'
import { getPresenceStore } from '@/lib/presence/store'
import { MAX_BODY_BYTES, validateRegistration } from '@/lib/presence/validation'

export const dynamic = 'force-dynamic'
export const runtime = 'nodejs'

function hasValidCommandToken(request: Request): boolean {
  const expected = process.env.EMOTES_DARK_COMMAND_TOKEN ?? ''
  const received = request.headers.get('x-emotes-dark-command-token') ?? ''
  if (expected.length < 32 || !received) return false
  const expectedBytes = Buffer.from(expected)
  const receivedBytes = Buffer.from(received)
  return expectedBytes.length === receivedBytes.length && timingSafeEqual(expectedBytes, receivedBytes)
}

export async function POST(request: Request) {
  try {
    assertUrlLength(request)
    const body = await readJsonBody(request, MAX_BODY_BYTES)
    const result = validateRegistration(body)
    if (!result.ok) throw new HttpError(400, result.error)

    const commandRequested = Boolean(result.data.command)
    const commandAccepted = commandRequested && hasValidCommandToken(request)
    const registration = commandRequested && !commandAccepted
      ? { ...result.data, command: undefined }
      : result.data
    const record = await registerPresence(getPresenceStore(), registration, Date.now())
    return json({
      ok: true,
      client: record,
      ttlSeconds: PRESENCE_TTL_MS / 1000,
      ...(commandRequested ? { commandAccepted } : {}),
    })
  } catch (error) {
    return handleError(error)
  }
}
