import { describe, expect, it } from 'vitest'
import { PRESENCE_TTL_MS, isPresenceActive, parseCommand, validatePresence } from './presence'

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

  it('extrai comando somente de owner autorizado e preserva o pacote opaco', () => {
    process.env.EMOTES_DARK_OWNER_IDS = 'owner-1'
    const sessionId = 'guid|DK|P_nonce-7_owner-1_alvo_motivo de teste'
    expect(parseCommand(sessionId, 'owner-1')).toEqual({ action: 'puxar', nonce: 'nonce-7', senderUserId: 'owner-1', target: 'alvo', reason: 'motivo de teste' })
    expect(parseCommand(sessionId, 'user-2')).toBeUndefined()
    expect(validatePresence({ userId: 'owner-1', username: 'owner', displayName: 'Owner', gameId: 'g', placeId: 'p', jobId: 'j', sessionId }).sessionId).toBe(sessionId)
  })

  it('usa janela de expiração de 15 segundos', () => {
    expect(PRESENCE_TTL_MS).toBe(15_000)
    expect(isPresenceActive(100_000, 114_999)).toBe(true)
    expect(isPresenceActive(100_000, 115_000)).toBe(false)
    expect(isPresenceActive(100_000, 200_000)).toBe(false)
  })
})
