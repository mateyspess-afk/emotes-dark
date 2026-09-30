import type { Metadata, Viewport } from 'next'
import { Geist, Geist_Mono } from 'next/font/google'
import './globals.css'

const geist = Geist({ subsets: ['latin'], variable: '--font-sans' })
const geistMono = Geist_Mono({ subsets: ['latin'], variable: '--font-mono' })

export const metadata: Metadata = {
  title: 'Emotes Dark Bridge',
  description:
    'API de presença temporária do Emotes Dark: guarda quem está online em cada servidor para exibir as nametags.',
  generator: 'v0.app',
  icons: {
    icon: [
      { url: '/icon-dark-32x32.png' },
      { url: '/icon.svg', type: 'image/svg+xml' },
    ],
    apple: '/apple-icon.png',
  },
}

export const viewport: Viewport = {
  colorScheme: 'dark',
  themeColor: '#0a0a0a',
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="pt-BR" className={`dark ${geist.variable} ${geistMono.variable}`}>
      <body className="bg-background font-sans text-foreground antialiased">{children}</body>
    </html>
  )
}
