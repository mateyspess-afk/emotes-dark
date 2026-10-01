import { describe, expect, it } from 'vitest'
import { PRESENCE_TTL_MS, isPresenceActive, validatePresence } from './presence'

describe('presença', () => {
  it('preserva sessionId integralmente como identificador opaco', () => {
    const sessionId = 'guid_EDK_K_nonce-1_sender-7_alvo_motivo_do_kick'
    expect(validatePresence({ userId: '1', username: 'user', displayName: 'Nome', gameId: 'g', placeId: 'p', jobId: 'j', sessionId }).sessionId).toBe(sessionId)
  })


  it('valida e normaliza a presença', () => {
    const presence = validatePresence({ userId: ' 1 ', username: 'user', displayName: 'Nome', gameId: 'g', placeId: 'p', jobId: 'j', sessionId: 's' })
    expect(presence.userId).toBe('1')
    expect(presence.lastSeen).toBeGreaterThan(0)
  })

  it('usa janela de expiração de 30 segundos', () => {
    expect(PRESENCE_TTL_MS).toBe(30_000)
    expect(isPresenceActive(100_000, 129_999)).toBe(true)
    expect(isPresenceActive(100_000, 130_000)).toBe(false)
    expect(isPresenceActive(100_000, 200_000)).toBe(false)
  })
})
