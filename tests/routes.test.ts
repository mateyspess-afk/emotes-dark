import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { GET as health } from '@/app/api/route'
import { GET as active } from '@/app/api/clients/active/route'
import { POST as register } from '@/app/api/clients/register/route'
import { SCOPE_KEY_TTL_MS } from '@/lib/presence/service'
import { setPresenceStoreForTests, type PresenceStore } from '@/lib/presence/store'
import { createFakeStore } from './fake-store'

const BASE = 'https://bridge.test/api'
const server = { gameId: '111', placeId: '222', jobId: 'job-a' }

function player(userId: number, overrides: Record<string, unknown> = {}) {
  return {
    userId,
    username: `User${userId}`,
    displayName: `Nome ${userId}`,
    ...server,
    sessionId: `session-${userId}`,
    ...overrides,
  }
}

function postRegister(body: unknown, token?: string) {
  return register(
    new Request(`${BASE}/clients/register`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { 'X-Emotes-Dark-Command-Token': token } : {}),
      },
      body: typeof body === 'string' ? body : JSON.stringify(body),
    }),
  )
}

async function getActive(scope: Record<string, string> = server) {
  const response = await active(new Request(`${BASE}/clients/active?${new URLSearchParams(scope)}`))
  return { status: response.status, body: await response.json() }
}

let fake: ReturnType<typeof createFakeStore>
const COMMAND_TOKEN = 'a'.repeat(64)

beforeEach(() => {
  vi.stubEnv('EMOTES_DARK_COMMAND_TOKEN', COMMAND_TOKEN)
  fake = createFakeStore()
  setPresenceStoreForTests(fake.store)
  vi.useFakeTimers({ toFake: ['Date'] })
  vi.setSystemTime(new Date('2026-01-01T00:00:00Z'))
})

afterEach(() => {
  setPresenceStoreForTests(null)
  vi.unstubAllEnvs()
  vi.useRealTimers()
})

describe('GET /api', () => {
  it('responde com o estado de saúde', async () => {
    const response = await health()
    const body = await response.json()
    expect(response.status).toBe(200)
    expect(body).toMatchObject({ ok: true, status: 'online', ttlSeconds: 15 })
  })

  it('informa quando o armazenamento está indisponível', async () => {
    const broken: PresenceStore = {
      ...fake.store,
      ping: () => Promise.reject(new Error('sem redis')),
    }
    setPresenceStoreForTests(broken)
    const response = await health()
    expect(response.status).toBe(503)
    expect(await response.json()).toMatchObject({ ok: false, status: 'degraded' })
  })
})

describe('POST /api/clients/register', () => {
  it('registra e devolve a presença sem comandos', async () => {
    const response = await postRegister(player(1, { sessionId: 'abc|DK|kick|1|2|alvo|motivo' }))
    expect(response.status).toBe(200)

    const { body } = await getActive()
    expect(body.clients).toEqual([
      {
        userId: 1,
        username: 'User1',
        displayName: 'Nome 1',
        sessionId: 'abc',
        lastSeen: Date.now(),
      },
    ])
  })

  it('rejeita dados inválidos', async () => {
    expect((await postRegister(player(1, { jobId: '' }))).status).toBe(400)
    expect((await postRegister('{nao e json')).status).toBe(400)
    expect((await postRegister([1, 2])).status).toBe(400)
  })

  it('rejeita corpos grandes demais', async () => {
    const response = await postRegister(player(1, { displayName: 'x'.repeat(5000) }))
    expect(response.status).toBe(413)
  })
})

describe('relay de comandos', () => {
  const command = { action: 'kick', nonce: '17672256001234', senderUserId: 1, target: 'alvo', reason: 'motivo' }

  it('publica o comando separado do sessionId somente com token válido', async () => {
    const response = await postRegister(player(1, { command }), COMMAND_TOKEN)
    expect(response.status).toBe(200)
    expect(await response.json()).toMatchObject({ commandAccepted: true })
    const { body } = await getActive()
    expect(body.clients[0].command).toEqual(command)
  })

  it('mantém presença mas não retransmite comando sem token', async () => {
    const response = await postRegister(player(1, { command }))
    expect(response.status).toBe(200)
    expect(await response.json()).toMatchObject({ commandAccepted: false })
    const { body } = await getActive()
    expect(body.clients[0]).not.toHaveProperty('command')
  })
})

describe('GET /api/clients/active', () => {
  it('separa os registros por gameId, placeId e jobId', async () => {
    await postRegister(player(1))
    await postRegister(player(2, { jobId: 'job-b' }))
    await postRegister(player(3, { placeId: '333' }))
    await postRegister(player(4, { gameId: '999' }))

    const { body } = await getActive()
    expect(body.clients.map((c: { userId: number }) => c.userId)).toEqual([1])

    const other = await getActive({ ...server, jobId: 'job-b' })
    expect(other.body.clients.map((c: { userId: number }) => c.userId)).toEqual([2])
  })

  it('exige os três parâmetros', async () => {
    const { status } = await getActive({ gameId: '111', placeId: '222' })
    expect(status).toBe(400)
  })

  it('atualiza o mesmo usuário em vez de duplicar', async () => {
    await postRegister(player(1))
    await postRegister(player(1, { displayName: 'Novo' }))
    const { body } = await getActive()
    expect(body.clients).toHaveLength(1)
    expect(body.clients[0].displayName).toBe('Novo')
  })
})

describe('expiração', () => {
  it('mantém o usuário por até 15 segundos', async () => {
    await postRegister(player(1))
    vi.advanceTimersByTime(15_000)
    expect((await getActive()).body.clients).toHaveLength(1)
  })

  it('considera inativo após 15 segundos e apaga o registro', async () => {
    await postRegister(player(1))
    vi.advanceTimersByTime(15_001)
    expect((await getActive()).body.clients).toEqual([])
    expect(fake.size()).toBe(0)
  })

  it('renovar o sinal mantém o usuário ativo', async () => {
    await postRegister(player(1))
    vi.advanceTimersByTime(10_000)
    await postRegister(player(1))
    vi.advanceTimersByTime(10_000)
    expect((await getActive()).body.clients).toHaveLength(1)
  })

  it('mistura ativos e expirados no mesmo servidor', async () => {
    await postRegister(player(1))
    vi.advanceTimersByTime(10_000)
    await postRegister(player(2))
    vi.advanceTimersByTime(6_000)
    const { body } = await getActive()
    expect(body.clients.map((c: { userId: number }) => c.userId)).toEqual([2])
    expect(fake.size()).toBe(1)
  })

  it('servidores abandonados expiram sozinhos sem ninguém consultar', async () => {
    await postRegister(player(1))
    await postRegister(player(2, { jobId: 'job-b' }))
    vi.advanceTimersByTime(SCOPE_KEY_TTL_MS)
    expect(fake.scopes.size).toBe(2)
    expect(fake.size()).toBe(0)
    expect(fake.scopes.size).toBe(0)
  })
})
