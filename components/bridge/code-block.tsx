'use client'

import { useState } from 'react'
import { Button } from '@/components/ui/button'

export function CodeBlock({ code, label }: { code: string; label: string }) {
  const [copied, setCopied] = useState(false)

  async function copy() {
    try {
      await navigator.clipboard.writeText(code)
      setCopied(true)
      setTimeout(() => setCopied(false), 1500)
    } catch {
      setCopied(false)
    }
  }

  return (
    <div className="flex items-start gap-2 rounded-md border border-border bg-background p-3">
      <pre className="min-w-0 flex-1 overflow-x-auto font-mono text-xs leading-relaxed sm:text-sm">
        <code>{code}</code>
      </pre>
      <Button variant="ghost" size="sm" onClick={copy} aria-label={`Copiar ${label}`}>
        {copied ? 'Copiado' : 'Copiar'}
      </Button>
    </div>
  )
}
