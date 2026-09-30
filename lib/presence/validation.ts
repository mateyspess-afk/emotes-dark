export const MAX_BODY_BYTES = 2048
export const MAX_URL_LENGTH = 1024
export const MAX_SESSION_ID_LENGTH = 64
export const MAX_DISPLAY_NAME_LENGTH = 32

const NUMERIC_ID = /^\d{1,20}$/
const JOB_ID = /^[A-Za-z0-9-]{1,64}$/
const USERNAME = /^[A-Za-z0-9_]{1,20}$/
const SESSION_ID_ALLOWED = /[^A-Za-z0-9\-:.]/g
const UNSAFE_TEXT = /[\u0000-\u001F\u007F-\u009F\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]/g

const COMMAND_MARKERS = ['|DK|', '_EDK_']

export type ServerScope = {
  gameId: string
  placeId: string
  jobId: string
}

export type RelayCommand = {
  action: 'kick' | 'puxar'
  nonce: string
  senderUserId: number
  target: string
  reason: string
}

export type Registration = ServerScope & {
  userId: number
  username: string
  displayName: string
  sessionId: string
  command?: RelayCommand
}

export type ValidationResult<T> = { ok: true; data: T } | { ok: false; error: string }

export function stripSessionCommands(raw: unknown): string {
  let value = typeof raw === 'string' ? raw : ''
  for (const marker of COMMAND_MARKERS) {
    const index = value.indexOf(marker)
    if (index >= 0) value = value.slice(0, index)
  }
  const pipeIndex = value.indexOf('|')
  if (pipeIndex >= 0) value = value.slice(0, pipeIndex)
  return value.replace(SESSION_ID_ALLOWED, '').slice(0, MAX_SESSION_ID_LENGTH)
}

function toIdString(value: unknown): string | null {
  if (typeof value === 'number' && Number.isSafeInteger(value) && value >= 0) {
    return String(value)
  }
  if (typeof value === 'string') {
    const trimmed = value.trim()
    return NUMERIC_ID.test(trimmed) ? trimmed : null
  }
  return null
}

function toUserId(value: unknown): number | null {
  const id = toIdString(value)
  if (id === null) return null
  const parsed = Number(id)
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null
}

function toDisplayName(value: unknown, fallback: string): string {
  if (typeof value !== 'string') return fallback
  const cleaned = Array.from(value.replace(UNSAFE_TEXT, '').trim())
    .slice(0, MAX_DISPLAY_NAME_LENGTH)
    .join('')
  return cleaned || fallback
}

export function validateScope(input: Record<string, unknown>): ValidationResult<ServerScope> {
  const gameId = toIdString(input.gameId)
  if (gameId === null) return { ok: false, error: 'gameId inválido' }

  const placeId = toIdString(input.placeId)
  if (placeId === null) return { ok: false, error: 'placeId inválido' }

  const jobId = typeof input.jobId === 'string' ? input.jobId.trim() : ''
  if (!JOB_ID.test(jobId)) return { ok: false, error: 'jobId inválido' }

  return { ok: true, data: { gameId, placeId, jobId } }
}

const COMMAND_NONCE = /^\d{10,20}$/
const COMMAND_TARGET = /^[A-Za-z0-9_]{1,20}$/
const COMMAND_REASON = /^(?:[A-Za-z0-9.~-]|%[0-9A-Fa-f]{2})*$/

function validateRelayCommand(input: unknown, userId: number): ValidationResult<RelayCommand | undefined> {
  if (input === undefined) return { ok: true, data: undefined }
  if (typeof input !== 'object' || input === null || Array.isArray(input)) {
    return { ok: false, error: 'command inválido' }
  }
  const command = input as Record<string, unknown>
  const action = command.action
  if (action !== 'kick' && action !== 'puxar') return { ok: false, error: 'ação de command inválida' }
  const nonce = typeof command.nonce === 'string' ? command.nonce : ''
  if (!COMMAND_NONCE.test(nonce)) return { ok: false, error: 'nonce de command inválido' }
  const senderUserId = toUserId(command.senderUserId)
  if (senderUserId === null || senderUserId !== userId) return { ok: false, error: 'senderUserId de command não corresponde ao cliente' }
  const target = typeof command.target === 'string' ? command.target : ''
  if (!COMMAND_TARGET.test(target)) return { ok: false, error: 'target de command inválido' }
  const reason = typeof command.reason === 'string' ? command.reason : ''
  if (reason.length > 28 || !COMMAND_REASON.test(reason)) return { ok: false, error: 'reason de command inválido' }
  return { ok: true, data: { action, nonce, senderUserId, target, reason } }
}

export function validateRegistration(input: unknown): ValidationResult<Registration> {
  if (typeof input !== 'object' || input === null || Array.isArray(input)) {
    return { ok: false, error: 'O corpo precisa ser um objeto JSON' }
  }
  const body = input as Record<string, unknown>

  const userId = toUserId(body.userId)
  if (userId === null) return { ok: false, error: 'userId inválido' }

  const username = typeof body.username === 'string' ? body.username.trim() : ''
  if (!USERNAME.test(username)) return { ok: false, error: 'username inválido' }

  const scope = validateScope(body)
  if (!scope.ok) return scope

  const command = validateRelayCommand(body.command, userId)
  if (!command.ok) return command

  return {
    ok: true,
    data: {
      ...scope.data,
      userId,
      username,
      displayName: toDisplayName(body.displayName, username),
      sessionId: stripSessionCommands(body.sessionId),
      ...(command.data ? { command: command.data } : {}),
    },
  }
}
