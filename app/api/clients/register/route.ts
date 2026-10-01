import { NextRequest, NextResponse } from 'next/server'
import { savePresence, validatePresence } from '@/lib/presence'

const MAX_BODY_BYTES = 4_096

export async function POST(request: NextRequest) {
  const length = Number(request.headers.get('content-length') ?? 0)
  if (length > MAX_BODY_BYTES) {
    return NextResponse.json({ error: 'Requisição muito grande' }, { status: 413 })
  }

  try {
    const body = await request.text()
    if (new TextEncoder().encode(body).byteLength > MAX_BODY_BYTES) {
      return NextResponse.json({ error: 'Requisição muito grande' }, { status: 413 })
    }
    const presence = validatePresence(JSON.parse(body) as Record<string, unknown>)
    try {
      await savePresence(presence)
    } catch {
      return NextResponse.json({ error: 'Armazenamento temporariamente indisponível' }, { status: 503 })
    }
    return NextResponse.json({ ok: true }, { headers: { 'Cache-Control': 'no-store' } })
  } catch (error) {
    const message = error instanceof SyntaxError ? 'JSON inválido' : error instanceof Error ? error.message : 'Dados inválidos'
    return NextResponse.json({ error: message }, { status: 400 })
  }
}

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'
