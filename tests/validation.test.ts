import { describe, expect, it } from 'vitest'
import { stripSessionCommands, validateRegistration } from '@/lib/presence/validation'

const valid = {
  userId: 123456,
  username: 'Dark_User',
  displayName: 'Dark',
  gameId: '111',
  placeId: '222',
  jobId: '0f8fad5b-d9cb-469f-a165-70867728950e',
  sessionId: 'A1B2C3D4-E5F6-4711-8899-AABBCCDDEEFF',
}

describe('stripSessionCommands', () => {
  it('remove comandos após |DK|', () => {
    expect(stripSessionCommands('abc-123|DK|kick|999|1|alvo|motivo')).toBe('abc-123')
  })

  it('remove o formato compacto _EDK_', () => {
    expect(stripSessionCommands('abc-123_EDK_P_42_1_alvo_motivo')).toBe('abc-123')
  })

  it('remove caracteres não permitidos e limita o tamanho', () => {
    expect(stripSessionCommands('a b<c>d')).toBe('abcd')
    expect(stripSessionCommands('x'.repeat(200))).toHaveLength(64)
    expect(stripSessionCommands(42)).toBe('')
  })
})

describe('validateRegistration', () => {
  it('aceita um registro válido e remove comandos', () => {
    const result = validateRegistration({ ...valid, sessionId: `${valid.sessionId}|DK|kick|1|2|x|y` })
    expect(result).toEqual({ ok: true, data: { ...valid } })
  })

  it('aceita ids numéricos como string', () => {
    const result = validateRegistration({ ...valid, userId: '123456', gameId: 111 })
    expect(result.ok).toBe(true)
  })

  it.each([
    ['userId', 0],
    ['userId', 'abc'],
    ['username', 'nome com espaço'],
    ['gameId', '-1'],
    ['placeId', 'x'],
    ['jobId', ''],
    ['jobId', '../../etc'],
  ])('rejeita %s = %j', (field, value) => {
    expect(validateRegistration({ ...valid, [field]: value }).ok).toBe(false)
  })

  it('usa username quando displayName é inválido', () => {
    const result = validateRegistration({ ...valid, displayName: '\u202E\u0000' })
    expect(result.ok && result.data.displayName).toBe('Dark_User')
  })
})
