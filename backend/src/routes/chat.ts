import { Router, Request, Response } from 'express'
import fetch from 'node-fetch'
import fs from 'fs'
import { query, getSnowflakeHost } from '../snowflake'

const router = Router()

const AGENT_DB = process.env.AGENT_DATABASE || process.env.AGENT_DB || 'SPROCKET'
const AGENT_SCHEMA = process.env.AGENT_SCHEMA || 'APP'
const AGENT_NAME = process.env.AGENT_NAME || 'SPROCKET_AGENT'

// POST /api/chat
router.post('/', async (req: Request, res: Response) => {
  const { message, bike_id, history = [] } = req.body as {
    message: string
    bike_id: string | null
    history: { role: string; content: string }[]
  }

  // Build preamble from bike context if a bike is selected
  let preamble = ''
  if (bike_id) {
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

  // Compose messages: optional system preamble + history + new user message
  type AgentMessage = { role: string; content: { type: string; text: string }[] }
  const toContent = (text: string) => [{ type: 'text', text }]
  const agentMessages: AgentMessage[] = []
  if (preamble) {
    agentMessages.push({ role: 'user', content: toContent(preamble) })
    agentMessages.push({ role: 'assistant', content: toContent('Understood. I have your bike context.') })
  }
  for (const h of history) {
    agentMessages.push({ role: h.role, content: toContent(h.content) })
  }
  agentMessages.push({ role: 'user', content: toContent(message) })

  // Set up SSE response
  res.setHeader('Content-Type', 'text/event-stream')
  res.setHeader('Cache-Control', 'no-cache')
  res.setHeader('Connection', 'keep-alive')
  res.flushHeaders()

  const send = (data: object) => res.write(`data: ${JSON.stringify(data)}\n\n`)

  try {
    const host = getSnowflakeHost()
    const url = `https://${host}/api/v2/databases/${AGENT_DB}/schemas/${AGENT_SCHEMA}/agents/${AGENT_NAME}:run`

    // Use service token directly for Agent REST API (caller's rights combined token is for SDK only)
    const serviceToken = fs.readFileSync('/snowflake/session/token', 'utf8').trim()
    const callerToken = req.headers['sf-context-current-user-token'] as string | undefined
    console.log(`Agent call: host=${host}, callerToken=${callerToken ? 'present' : 'absent'}`)

    const agentRes = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${serviceToken}`,
        'Content-Type': 'application/json',
        Accept: 'text/event-stream',
      },
      body: JSON.stringify({ messages: agentMessages }),
    })

    if (!agentRes.ok || !agentRes.body) {
      const errText = await agentRes.text()
      console.error('Agent API error:', agentRes.status, errText)
      send({ type: 'delta', text: 'Sorry, I ran into an error reaching the agent. Please try again.' })
      res.write('data: [DONE]\n\n')
      return res.end()
    }

    const sources: string[] = []

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

          if (currentEvent === 'response.text.delta' && payload.text) {
            send({ type: 'delta', text: payload.text })
          } else if (currentEvent === 'response.tool_result') {
            try {
              const results = payload.results ?? []
              for (const r of results) {
                if (r?.source_id) sources.push(r.source_id)
              }
            } catch {}
          } else if (currentEvent === 'done' || payload?.type === 'message_stop') {
            if (sources.length > 0) send({ type: 'sources', sources })
            res.write('data: [DONE]\n\n')
            return res.end()
          }
        } catch {
          // non-JSON SSE line, skip
        }
        currentEvent = ''
      }
    }

    if (sources.length > 0) send({ type: 'sources', sources })
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
