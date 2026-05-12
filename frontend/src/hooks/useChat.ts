import { useState, useCallback } from 'react'
import { ChatMessage } from '../types'

let idCounter = 0
const uid = () => `msg-${++idCounter}`

export function useChat(bikeId: number | null) {
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [streaming, setStreaming] = useState(false)

  const sendMessage = useCallback(
    async (text: string) => {
      if (streaming) return

      const userMsg: ChatMessage = { id: uid(), role: 'user', content: text }
      const assistantMsg: ChatMessage = {
        id: uid(),
        role: 'assistant',
        content: '',
        streaming: true,
      }

      setMessages((prev) => [...prev, userMsg, assistantMsg])
      setStreaming(true)

      try {
        const res = await fetch('/api/chat', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            message: text,
            bike_id: bikeId,
            history: messages.map((m) => ({ role: m.role, content: m.content })),
          }),
        })

        if (!res.ok || !res.body) throw new Error('Request failed')

        const reader = res.body.getReader()
        const decoder = new TextDecoder()
        let buffer = ''

        while (true) {
          const { done, value } = await reader.read()
          if (done) break
          buffer += decoder.decode(value, { stream: true })

          const lines = buffer.split('\n')
          buffer = lines.pop() ?? ''

          for (const line of lines) {
            if (line.startsWith('data: ')) {
              const data = line.slice(6)
              if (data === '[DONE]') continue
              try {
                const parsed = JSON.parse(data)
                if (parsed.type === 'delta') {
                  setMessages((prev) =>
                    prev.map((m) =>
                      m.id === assistantMsg.id
                        ? { ...m, content: m.content + parsed.text }
                        : m
                    )
                  )
                } else if (parsed.type === 'sources') {
                  setMessages((prev) =>
                    prev.map((m) =>
                      m.id === assistantMsg.id ? { ...m, sources: parsed.sources } : m
                    )
                  )
                }
              } catch {
                // non-JSON line, ignore
              }
            }
          }
        }
      } catch (err) {
        console.error('Chat error:', err)
        setMessages((prev) =>
          prev.map((m) =>
            m.id === assistantMsg.id
              ? { ...m, content: 'Something went wrong. Please try again.', streaming: false }
              : m
          )
        )
      } finally {
        setMessages((prev) =>
          prev.map((m) =>
            m.id === assistantMsg.id ? { ...m, streaming: false } : m
          )
        )
        setStreaming(false)
      }
    },
    [messages, bikeId, streaming]
  )

  const reset = useCallback(() => setMessages([]), [])

  return { messages, streaming, sendMessage, reset }
}
