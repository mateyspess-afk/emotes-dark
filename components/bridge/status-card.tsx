'use client'

import useSWR from 'swr'
import { cn } from '@/lib/utils'

type Health = {
  ok: boolean
  status: 'online' | 'degraded'
  storage: { provider: string; ready: boolean; error?: string }
  ttlSeconds: number
  time: string
}

async function fetchHealth(url: string): Promise<Health> {
  const response = await fetch(url, { cache: 'no-store' })
  return response.json()
}

const STATES = {
  loading: { label: 'Verificando…', dot: 'bg-muted-foreground', text: 'text-muted-foreground' },
  online: { label: 'API online', dot: 'bg-emerald-400', text: 'text-emerald-400' },
  degraded: { label: 'Armazenamento indisponível', dot: 'bg-amber-400', text: 'text-amber-400' },
  offline: { label: 'API offline', dot: 'bg-red-400', text: 'text-red-400' },
} as const

export function StatusCard() {
  const { data, error, isLoading } = useSWR('/api', fetchHealth, { refreshInterval: 15_000 })

  const state = isLoading ? 'loading' : error || !data ? 'offline' : data.ok ? 'online' : 'degraded'
  const view = STATES[state]

  return (
    <section
      aria-labelledby="status-title"
      className="flex flex-col gap-4 rounded-lg border border-border bg-card p-5"
    >
      <div className="flex items-center justify-between gap-4">
        <h2 id="status-title" className="text-sm font-medium text-muted-foreground">
          Estado da API
        </h2>
        <span className="font-mono text-xs text-muted-foreground">GET /api</span>
      </div>

      <p className={cn('flex items-center gap-3 text-2xl font-semibold', view.text)} aria-live="polite">
        <span className={cn('size-2.5 rounded-full', view.dot, state === 'online' && 'animate-pulse')} />
        {view.label}
      </p>

      <dl className="grid grid-cols-2 gap-4 border-t border-border pt-4 text-sm sm:grid-cols-3">
        <div className="flex flex-col gap-1">
          <dt className="text-muted-foreground">Armazenamento</dt>
          <dd className="font-mono">{data?.storage.ready ? 'Netlify Blobs' : '—'}</dd>
        </div>
        <div className="flex flex-col gap-1">
          <dt className="text-muted-foreground">Expiração</dt>
          <dd className="font-mono">{data ? `${data.ttlSeconds}s` : '—'}</dd>
        </div>
        <div className="col-span-2 flex flex-col gap-1 sm:col-span-1">
          <dt className="text-muted-foreground">Última verificação</dt>
          <dd className="font-mono">
            {data ? new Date(data.time).toLocaleTimeString('pt-BR') : '—'}
          </dd>
        </div>
      </dl>

      {state === 'degraded' && (
        <p className="rounded-md bg-amber-400/10 p-3 text-sm leading-relaxed text-amber-200">
          {
            'A API respondeu, mas o Netlify Blobs não está acessível. Isso é esperado no preview do v0; depois de publicar na Netlify o armazenamento é configurado automaticamente.'
          }
        </p>
      )}
    </section>
  )
}
