import { useEffect, useRef } from 'react'
import ReactMarkdown from 'react-markdown'
import { ChatMessage } from '../types'
import { ChainringIcon } from './ChainringLogo'

interface ChatPanelProps {
  messages: ChatMessage[]
  onSend: (text: string) => void
  streaming: boolean
}

export function ChatPanel({ messages, onSend, streaming }: ChatPanelProps) {
  const bottomRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      submit()
    }
  }

  function submit() {
    const val = inputRef.current?.value.trim()
    if (!val || streaming) return
    onSend(val)
    if (inputRef.current) inputRef.current.value = ''
  }

  return (
    <main className="flex-1 flex flex-col min-w-0">
      {/* Header */}
      <div className="px-6 py-4 border-b border-carbon-700 flex items-center gap-3">
        <span className="w-2 h-2 rounded-full bg-emerald shadow-[0_0_6px_#10b981]" />
        <span className="text-sm text-muted">Sprocket is online</span>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-6 py-6 flex flex-col gap-4">
        {messages.length === 0 && (
          <div className="flex-1 flex items-center justify-center">
            <div className="text-center">
              <ChainringIcon size={48} />
              <p className="mt-4 text-muted text-sm">Ask me anything about your bike.</p>
            </div>
          </div>
        )}

        {messages.map((msg) => (
          <div
            key={msg.id}
            className={`flex gap-3 max-w-[720px] ${
              msg.role === 'user' ? 'self-end flex-row-reverse' : 'self-start'
            }`}
          >
            {/* Avatar */}
            <div
              className={`w-8 h-8 rounded-full flex-shrink-0 flex items-center justify-center text-sm ${
                msg.role === 'user'
                  ? 'bg-emerald-deep text-gray-100'
                  : 'bg-carbon-800 border border-carbon-600'
              }`}
            >
              {msg.role === 'user' ? (
                'T'
              ) : (
                <ChainringIcon size={18} />
              )}
            </div>

            {/* Bubble */}
            <div>
              <div
                className={`px-4 py-3 rounded-xl text-sm leading-relaxed ${
                  msg.role === 'user'
                    ? 'bg-emerald-deep text-gray-100 rounded-br-sm'
                    : 'bg-carbon-800 border border-carbon-700 text-gray-200 rounded-bl-sm'
                }`}
              >
                {msg.streaming && msg.content === '' ? (
                  <TypingIndicator />
                ) : msg.role === 'assistant' ? (
                  <div className="prose-chat">
                    <ReactMarkdown>{msg.content}</ReactMarkdown>
                    {msg.streaming && <span className="inline-block w-1 h-4 bg-emerald ml-0.5 animate-pulse" />}
                  </div>
                ) : (
                  msg.content
                )}
              </div>
              {msg.sources && msg.sources.length > 0 && (
                <div className="mt-1.5 text-[11px] text-emerald opacity-80">
                  {msg.sources.join(' · ')}
                </div>
              )}
            </div>
          </div>
        ))}

        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div className="px-6 py-4 border-t border-carbon-700 flex gap-3 items-center">
        <input
          ref={inputRef}
          type="text"
          placeholder="Ask Sprocket about your bike..."
          onKeyDown={handleKeyDown}
          disabled={streaming}
          className="flex-1 px-4 py-3 bg-carbon-800 border border-carbon-600 rounded-xl text-sm text-gray-200 placeholder-[#4b5563] focus:outline-none focus:border-emerald-dark focus:shadow-[0_0_0_2px_rgba(5,150,105,0.15)] disabled:opacity-50"
        />
        <button
          onClick={submit}
          disabled={streaming}
          className="w-10 h-10 flex items-center justify-center bg-emerald-deep hover:bg-emerald-dark text-gray-100 rounded-xl transition-all hover:-translate-y-px disabled:opacity-50 text-lg"
        >
          ↑
        </button>
      </div>
    </main>
  )
}

function TypingIndicator() {
  return (
    <div className="flex gap-1 items-center py-1">
      {[0, 1, 2].map((i) => (
        <span
          key={i}
          className="w-1.5 h-1.5 rounded-full bg-emerald"
          style={{ animation: `pulse 1.4s infinite ${i * 0.2}s` }}
        />
      ))}
    </div>
  )
}
