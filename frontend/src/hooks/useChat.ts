import { useState, useCallback, useRef } from 'react'
import { ChatMessage } from '../types'

let idCounter = 0
const uid = () => `msg-${++idCounter}`

export function useChat(bikeId: string | null) {
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [streaming, setStreaming] = useState(false)
  const threadRef = useRef<string | null>(null)
  const parentMsgRef = useRef<number>(0)

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
        // Create thread on first message of a conversation
        if (!threadRef.current) {
          const threadRes = await fetch('/api/chat/thread', { method: 'POST' })
          if (!threadRes.ok) throw new Error('Failed to create thread')
          const { thread_id } = await threadRes.json() as { thread_id: string }
          threadRef.current = thread_id
          parentMsgRef.current = 0
        }

        const res = await fetch('/api/chat', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            message: text,
            bike_id: bikeId,
            thread_id: threadRef.current,
            parent_message_id: parentMsgRef.current,
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

        // Increment parent_message_id for next turn
        parentMsgRef.current += 1

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
    [bikeId, streaming]
  )

  const reset = useCallback(() => {
    setMessages([])
    threadRef.current = null
    parentMsgRef.current = 0
  }, [])

  return { messages, streaming, sendMessage, reset }
}
