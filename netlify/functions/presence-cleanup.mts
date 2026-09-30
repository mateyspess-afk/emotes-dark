import { cleanupExpiredPresence } from '../../lib/presence/service'
import { getPresenceStore } from '../../lib/presence/store'

export default async function presenceCleanup() {
  const result = await cleanupExpiredPresence(getPresenceStore(), Date.now())
  console.log('[emotes-dark-bridge] limpeza agendada', result)
}

// Removes presence left behind by servers that nobody polls anymore.
export const config = {
  schedule: '*/5 * * * *',
}
