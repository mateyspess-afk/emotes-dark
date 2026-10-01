import { NextRequest, NextResponse } from 'next/server'
import { activePresences, cleanText } from '@/lib/presence'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  let gameId: string
  let placeId: string
  let jobId: string
  try {
    const params = request.nextUrl.searchParams
    gameId = cleanText(params.get('gameId'), 'gameId')
    placeId = cleanText(params.get('placeId'), 'placeId')
    jobId = cleanText(params.get('jobId'), 'jobId')
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Parâmetros inválidos'
    return NextResponse.json({ error: message }, { status: 400 })
  }

  try {
    const clients = await activePresences(gameId, placeId, jobId)
    return NextResponse.json({ clients }, { headers: { 'Cache-Control': 'no-store' } })
  } catch {
    return NextResponse.json({ error: 'Armazenamento temporariamente indisponível' }, { status: 503 })
  }
}
