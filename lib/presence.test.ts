import { describe, expect, it } from 'vitest'
import { PRESENCE_TTL_MS, isPresenceActive, parseCommandPacket, validatePresence } from './presence'

describe('presença', () => {
  it('preserva e serializa um pacote _EDK_', () => {
    const sessionId = 'guid_EDK_K_nonce-1_sender-7_alvo_motivo_do_kick'
    const command = parseCommandPacket(sessionId)
    expect(command).toEqual({
      action: 'kick',
      nonce: 'nonce-1',
      senderUserId: 'sender-7',
      target: 'alvo',
      reason: 'motivo_do_kick',
    })
    expect(validatePresence({ userId: '1', username: 'user', displayName: 'Nome', gameId: 'g', placeId: 'p', jobId: 'j', sessionId }).sessionId).toBe(sessionId)
  })

  it('converte puxar e mantém o alvo para match parcial', () => {
    expect(parseCommandPacket('guid_EDK_P_nonce_sender_alvo_parcial_motivo')).toMatchObject({
      action: 'puxar', target: 'alvo', reason: 'parcial_motivo',
    })
  })

  it('valida e normaliza a presença', () => {
    const presence = validatePresence({ userId: ' 1 ', username: 'user', displayName: 'Nome', gameId: 'g', placeId: 'p', jobId: 'j', sessionId: 's' })
    expect(presence.userId).toBe('1')
    expect(presence.lastSeen).toBeGreaterThan(0)
  })

  it('usa janela de expiração de 15 segundos', () => {
    expect(PRESENCE_TTL_MS).toBe(15_000)
    expect(isPresenceActive(100_000, 114_999)).toBe(true)
    expect(isPresenceActive(100_000, 115_000)).toBe(false)
    expect(isPresenceActive(100_000, 200_000)).toBe(false)
  })
})
