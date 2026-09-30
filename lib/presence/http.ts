import { StorageUnavailableError } from './store'
import { MAX_URL_LENGTH } from './validation'

export class HttpError extends Error {
  constructor(
    public readonly status: number,
    message: string,
  ) {
    super(message)
    this.name = 'HttpError'
  }
}

export function json(data: unknown, status = 200): Response {
  return Response.json(data, {
    status,
    headers: { 'Cache-Control': 'no-store' },
  })
}

export function assertUrlLength(request: Request) {
  if (request.url.length > MAX_URL_LENGTH) {
    throw new HttpError(414, 'URL muito longa')
  }
}

export async function readJsonBody(request: Request, maxBytes: number): Promise<unknown> {
  const declared = Number(request.headers.get('content-length') ?? '0')
  if (Number.isFinite(declared) && declared > maxBytes) {
    throw new HttpError(413, `Corpo maior que ${maxBytes} bytes`)
  }
  if (!request.body) throw new HttpError(400, 'Corpo da requisição vazio')

  const reader = request.body.getReader()
  const chunks: Uint8Array[] = []
  let total = 0
  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    total += value.byteLength
    if (total > maxBytes) {
      await reader.cancel().catch(() => {})
      throw new HttpError(413, `Corpo maior que ${maxBytes} bytes`)
    }
    chunks.push(value)
  }

  const bytes = new Uint8Array(total)
  let offset = 0
  for (const chunk of chunks) {
    bytes.set(chunk, offset)
    offset += chunk.byteLength
  }

  try {
    return JSON.parse(new TextDecoder().decode(bytes))
  } catch {
    throw new HttpError(400, 'JSON inválido')
  }
}

export function handleError(error: unknown): Response {
  if (error instanceof HttpError) {
    return json({ ok: false, error: error.message }, error.status)
  }
  if (error instanceof StorageUnavailableError) {
    return json({ ok: false, error: error.message }, 503)
  }
  console.error('[emotes-dark-bridge] erro inesperado', error)
  return json({ ok: false, error: 'Erro interno' }, 500)
}
