'use client'

import { useSyncExternalStore } from 'react'
import { CodeBlock } from './code-block'

const subscribe = () => () => {}
const getOrigin = () => window.location.origin
const getServerOrigin = () => null

export function CurrentAddress() {
  const origin = useSyncExternalStore(subscribe, getOrigin, getServerOrigin)
  if (!origin || !origin.endsWith('.netlify.app')) return null

  return (
    <div className="flex flex-col gap-2 rounded-md border border-emerald-400/30 bg-emerald-400/5 p-4">
      <p className="text-sm text-emerald-200">
        Você está no site publicado. Use exatamente esta linha no seu executor:
      </p>
      <CodeBlock
        label="endereço deste site"
        code={`getgenv().EMOTES_DARK_PRESENCE_API = "${origin}/api"`}
      />
    </div>
  )
}
