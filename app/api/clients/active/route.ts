import { NextRequest, NextResponse } from 'next/server'
import { activePresences, cleanText } from '@/lib/presence'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  try {
    const params = request.nextUrl.searchParams
    const gameId = cleanText(params.get('gameId'), 'gameId')
    const placeId = cleanText(params.get('placeId'), 'placeId')
    const jobId = cleanText(params.get('jobId'), 'jobId')
    const clients = await activePresences(gameId, placeId, jobId)
    return NextResponse.json({ clients }, { headers: { 'Cache-Control': 'no-store' } })
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Parâmetros inválidos'
    return NextResponse.json({ error: message }, { status: 400 })
  }
}
