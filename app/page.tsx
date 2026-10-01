'use client'

import useSWR from 'swr'
import { CheckCircle2, CircleAlert, Copy, Radio, Server } from 'lucide-react'

const fetcher = (url: string) => fetch(url).then((response) => {
  if (!response.ok) throw new Error('offline')
  return response.json()
})

export default function Page() {
  const { data, error } = useSWR('/api', fetcher, { refreshInterval: 15_000 })
  const online = Boolean(data) && !error
  const endpoint = 'https://SEU-SITE.v0l.app/api'

  async function copyEndpoint() {
    await navigator.clipboard?.writeText(endpoint)
  }

  return (
    <main className="min-h-screen overflow-hidden bg-[#090b10] text-slate-100">
      <div className="mx-auto flex min-h-screen w-full max-w-5xl flex-col px-6 py-8 sm:px-10 lg:px-16">
        <header className="flex items-center justify-between border-b border-white/10 pb-6">
          <div className="flex items-center gap-3">
            <div className="flex size-10 items-center justify-center rounded-xl bg-cyan-400/10 text-cyan-300 ring-1 ring-cyan-300/20"><Radio size={20} /></div>
            <span className="font-semibold tracking-tight">Emotes Dark Bridge</span>
          </div>
          <span className="rounded-full border border-white/10 px-3 py-1 text-xs text-slate-400">presença v1</span>
        </header>

        <section className="grid flex-1 items-center gap-12 py-16 lg:grid-cols-[1.1fr_.9fr]">
          <div>
            <p className="mb-5 text-sm font-medium uppercase tracking-[0.22em] text-cyan-300">Bridge de presença</p>
            <h1 className="max-w-xl text-4xl font-semibold leading-tight tracking-tight sm:text-6xl">Presença temporária, sem estado perdido.</h1>
            <p className="mt-6 max-w-lg text-base leading-7 text-slate-400">Uma API leve para o Emotes Dark publicar clientes ativos por servidor e alimentar nametags com segurança.</p>
          </div>

          <div className="rounded-3xl border border-white/10 bg-white/[0.035] p-6 shadow-2xl shadow-cyan-950/20 backdrop-blur sm:p-8">
            <div className="flex items-start justify-between gap-4">
              <div><p className="text-sm text-slate-400">Estado da API</p><p className="mt-2 text-2xl font-semibold">{online ? 'Online' : error ? 'Indisponível' : 'Verificando...'}</p></div>
              {online ? <CheckCircle2 className="text-emerald-400" /> : error ? <CircleAlert className="text-rose-400" /> : <Server className="animate-pulse text-slate-500" />}
            </div>
            <div className="my-7 h-px bg-white/10" />
            <p className="text-xs uppercase tracking-wider text-slate-500">Endpoint após publicar</p>
            <div className="mt-3 flex items-center gap-2 rounded-xl bg-black/30 p-3 font-mono text-xs text-cyan-200"><code className="min-w-0 flex-1 break-all">{endpoint}</code><button onClick={copyEndpoint} aria-label="Copiar endpoint" className="shrink-0 rounded-lg p-2 text-slate-400 hover:bg-white/10 hover:text-white"><Copy size={15} /></button></div>
            <p className="mt-4 text-sm leading-6 text-slate-400">Substitua <code className="text-slate-200">SEU-SITE</code> pelo domínio gerado no v0. Não inclua comandos de sessão: eles são removidos no servidor.</p>
          </div>
        </section>

        <footer className="border-t border-white/10 py-6 text-sm text-slate-500">Persistência em Vercel Blob · expiração automática em 15 segundos</footer>
      </div>
    </main>
  )
}
