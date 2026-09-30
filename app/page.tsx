import { CodeBlock } from '@/components/bridge/code-block'
import { CurrentAddress } from '@/components/bridge/current-address'
import { StatusCard } from '@/components/bridge/status-card'

const ENDPOINTS = [
  { method: 'GET', path: '/api', description: 'Estado de saúde da API e do armazenamento.' },
  {
    method: 'POST',
    path: '/api/clients/register',
    description: 'Registra a presença: userId, username, displayName, gameId, placeId, jobId e sessionId.',
  },
  {
    method: 'GET',
    path: '/api/clients/active?gameId=…&placeId=…&jobId=…',
    description: 'Devolve { "clients": [...] } somente daquele servidor.',
  },
]

const STEPS = [
  'No v0, clique em Publish (canto superior direito) para publicar na Vercel.',
  'Quando terminar, copie o domínio gerado, por exemplo algo-como-isto.vercel.app.',
  'No executor, antes de carregar o Emotes Dark, defina o endereço trocando SEU-SITE pelo seu domínio:',
]

export default function Page() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-2xl flex-col gap-10 px-5 py-12 sm:py-16">
      <header className="flex flex-col gap-3">
        <p className="font-mono text-xs uppercase tracking-widest text-muted-foreground">
          Emotes Dark · presença
        </p>
        <h1 className="text-balance text-3xl font-semibold tracking-tight sm:text-4xl">
          Emotes Dark Bridge
        </h1>
        <p className="text-pretty leading-relaxed text-muted-foreground">
          Guarda por alguns segundos quem está usando o script em cada servidor, para que as
          nametags apareçam para os outros jogadores. Substitui o antigo bridge hospedado no Replit.
        </p>
      </header>

      <StatusCard />

      <section aria-labelledby="setup-title" className="flex flex-col gap-4">
        <h2 id="setup-title" className="text-lg font-semibold">
          Configurar depois da publicação
        </h2>
        <ol className="flex flex-col gap-3">
          {STEPS.map((step, index) => (
            <li key={step} className="flex gap-3 text-sm leading-relaxed">
              <span className="flex size-6 shrink-0 items-center justify-center rounded-full border border-border font-mono text-xs text-muted-foreground">
                {index + 1}
              </span>
              <span className="pt-0.5">{step}</span>
            </li>
          ))}
        </ol>
        <CodeBlock
          label="linha de configuração"
          code={'getgenv().EMOTES_DARK_PRESENCE_API = "https://SEU-SITE.vercel.app/api"'}
        />
        <CurrentAddress />
        <p className="text-sm leading-relaxed text-muted-foreground">
          O endereço precisa terminar em <code className="font-mono text-foreground">/api</code>. O
          endereço padrão do script não é alterado: sem essa linha ele continua usando o valor
          original.
        </p>
      </section>

      <section aria-labelledby="endpoints-title" className="flex flex-col gap-4">
        <h2 id="endpoints-title" className="text-lg font-semibold">
          Rotas
        </h2>
        <ul className="flex flex-col divide-y divide-border rounded-lg border border-border">
          {ENDPOINTS.map((endpoint) => (
            <li key={endpoint.path} className="flex flex-col gap-1.5 p-4">
              <p className="flex flex-wrap items-baseline gap-2 font-mono text-sm">
                <span className="rounded bg-secondary px-1.5 py-0.5 text-xs text-secondary-foreground">
                  {endpoint.method}
                </span>
                <span className="break-all">{endpoint.path}</span>
              </p>
              <p className="text-sm text-muted-foreground">{endpoint.description}</p>
            </li>
          ))}
        </ul>
      </section>

      <section aria-labelledby="privacy-title" className="flex flex-col gap-3">
        <h2 id="privacy-title" className="text-lg font-semibold">
          O que é guardado
        </h2>
        <ul className="flex list-disc flex-col gap-2 pl-5 text-sm leading-relaxed text-muted-foreground">
          <li>Somente os dados necessários para as nametags, separados por gameId, placeId e jobId.</li>
          <li>Um jogador é considerado inativo após 15 segundos sem sinal e o registro é apagado.</li>
          <li>
            {'Comandos codificados após "|DK|" no sessionId (kick, puxar) são removidos e nunca são retransmitidos.'}
          </li>
          <li>Requisições são validadas e limitadas a 2 KB. Nenhum segredo fica no código.</li>
        </ul>
      </section>
    </main>
  )
}
