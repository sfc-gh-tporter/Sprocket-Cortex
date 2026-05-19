import { Router, Request, Response } from 'express'
import fetch from 'node-fetch'
import fs from 'fs'
import { query, getSnowflakeHost } from '../snowflake'

const router = Router()

const AGENT_DB = process.env.AGENT_DATABASE || process.env.AGENT_DB || 'SPROCKET'
const AGENT_SCHEMA = process.env.AGENT_SCHEMA || 'APP'
const AGENT_NAME = process.env.AGENT_NAME || 'SPROCKET_AGENT'

function getServiceToken(): string {
  return fs.readFileSync('/snowflake/session/token', 'utf8').trim()
}

// POST /api/chat/thread — create a new Cortex thread
router.post('/thread', async (_req: Request, res: Response) => {
  try {
    const host = getSnowflakeHost()
    const r = await fetch(`https://${host}/api/v2/cortex/threads`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${getServiceToken()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ origin_application: 'sprocket' }),
    })
    if (!r.ok) {
      const err = await r.text()
      console.error('Thread create error:', r.status, err)
      return res.status(500).json({ error: 'Failed to create thread' })
    }
    const data = await r.json() as { thread_id: string }
    res.json({ thread_id: data.thread_id })
  } catch (err) {
    console.error('Thread create error:', err)
    res.status(500).json({ error: 'Failed to create thread' })
  }
})

// POST /api/chat — stream agent response using thread
router.post('/', async (req: Request, res: Response) => {
  const { message, bike_id, thread_id, parent_message_id = 0 } = req.body as {
    message: string
    bike_id: string | null
    thread_id: string
    parent_message_id: number
  }

  // Fetch bike preamble on first turn only
  let preamble = ''
  if (bike_id && parent_message_id === 0) {
    try {
      const rows = await query<{ GET_BIKE_CONTEXT: unknown }>(
        `CALL APP.GET_BIKE_CONTEXT(?)`, [bike_id]
      )
      const raw = rows[0]?.GET_BIKE_CONTEXT
      const ctx: Record<string, unknown> = typeof raw === 'string' ? JSON.parse(raw) : (raw as Record<string, unknown>) ?? {}
      preamble = (ctx.preamble ?? '') as string
    } catch (err) {
      console.warn('Failed to fetch preamble:', err)
    }
  }

  type AgentMessage = { role: string; content: { type: string; text: string }[] }
  const toContent = (text: string) => [{ type: 'text', text }]
  const agentMessages: AgentMessage[] = []

  if (preamble) {
    agentMessages.push({ role: 'user', content: toContent(preamble) })
    agentMessages.push({ role: 'assistant', content: toContent('Understood. I have your bike context.') })
  }
  agentMessages.push({ role: 'user', content: toContent(message) })

  res.setHeader('Content-Type', 'text/event-stream')
  res.setHeader('Cache-Control', 'no-cache')
  res.setHeader('Connection', 'keep-alive')
  res.flushHeaders()

  const send = (data: object) => res.write(`data: ${JSON.stringify(data)}\n\n`)

  try {
    const host = getSnowflakeHost()
    const url = `https://${host}/api/v2/databases/${AGENT_DB}/schemas/${AGENT_SCHEMA}/agents/${AGENT_NAME}:run`
    const callerToken = req.headers['sf-context-current-user-token'] as string | undefined
    console.log(`Agent call: thread=${thread_id}, parent_msg=${parent_message_id}, callerToken=${callerToken ? 'present' : 'absent'}`)

    const agentRes = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${getServiceToken()}`,
        'Content-Type': 'application/json',
        Accept: 'text/event-stream',
      },
      body: JSON.stringify({
        thread_id,
        parent_message_id,
        messages: agentMessages,
      }),
    })

    if (!agentRes.ok || !agentRes.body) {
      const errText = await agentRes.text()
      console.error('Agent API error:', agentRes.status, errText)
      send({ type: 'delta', text: 'Sorry, I ran into an error reaching the agent. Please try again.' })
      res.write('data: [DONE]\n\n')
      return res.end()
    }

    const sources: string[] = []
    let assistantMessageId: number | null = null

    for await (const chunk of agentRes.body) {
      const text = chunk.toString()
      const lines = text.split('\n')
      let currentEvent = ''

      for (const line of lines) {
        if (line.startsWith('event: ')) {
          currentEvent = line.slice(7).trim()
          continue
        }
        if (!line.startsWith('data: ')) continue
        const raw = line.slice(6).trim()
        if (!raw || raw === '[DONE]') continue

        try {
          const payload = JSON.parse(raw)

          if (currentEvent === 'metadata' && payload.metadata?.role === 'assistant') {
            assistantMessageId = payload.metadata.message_id
          } else if (currentEvent === 'response') {
            if (payload.metadata?.assistant_message_id != null) {
              assistantMessageId = payload.metadata.assistant_message_id
            }
            if (sources.length > 0) send({ type: 'sources', sources })
            send({ type: 'done', assistant_message_id: assistantMessageId })
            res.write('data: [DONE]\n\n')
            return res.end()
          } else if (currentEvent === 'response.text.delta' && payload.text) {
            send({ type: 'delta', text: payload.text })
          } else if (currentEvent === 'response.tool_result') {
            const results = payload.results ?? []
            for (const r of results) {
              if (r?.source_id) sources.push(r.source_id)
            }
          }
        } catch {
          // non-JSON SSE line, skip
        }
        currentEvent = ''
      }
    }

    if (sources.length > 0) send({ type: 'sources', sources })
    send({ type: 'done', assistant_message_id: assistantMessageId })
    res.write('data: [DONE]\n\n')
    res.end()
  } catch (err) {
    console.error('Chat proxy error:', err)
    send({ type: 'delta', text: 'Connection error. Please try again.' })
    res.write('data: [DONE]\n\n')
    res.end()
  }
})

export default router
