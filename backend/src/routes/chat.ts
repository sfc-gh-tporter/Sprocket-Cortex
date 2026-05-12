import { Router, Request, Response } from 'express'
import fetch from 'node-fetch'
import { query, getSnowflakeHost, getAuthHeaders } from '../snowflake'

const router = Router()

const AGENT_DB = process.env.AGENT_DB || 'SPROCKET'
const AGENT_SCHEMA = process.env.AGENT_SCHEMA || 'APP'
const AGENT_NAME = process.env.AGENT_NAME || 'SPROCKET_AGENT'

// POST /api/chat
router.post('/', async (req: Request, res: Response) => {
  const { message, bike_id, history = [] } = req.body as {
    message: string
    bike_id: number | null
    history: { role: string; content: string }[]
  }

  // Build preamble from bike context if a bike is selected
  let preamble = ''
  if (bike_id) {
    try {
      const rows = await query<{ GET_BIKE_CONTEXT: string }>(
        `SELECT APP.GET_BIKE_CONTEXT(${bike_id}) AS GET_BIKE_CONTEXT`
      )
      const ctx = JSON.parse(rows[0].GET_BIKE_CONTEXT)
      preamble = ctx.preamble ?? ''
    } catch (err) {
      console.warn('Failed to fetch preamble:', err)
    }
  }

  // Compose messages: optional system preamble + history + new user message
  const agentMessages: { role: string; content: string }[] = []
  if (preamble) {
    agentMessages.push({ role: 'user', content: preamble })
    agentMessages.push({ role: 'assistant', content: 'Understood. I have your bike context.' })
  }
  for (const h of history) {
    agentMessages.push({ role: h.role, content: h.content })
  }
  agentMessages.push({ role: 'user', content: message })

  // Set up SSE response
  res.setHeader('Content-Type', 'text/event-stream')
  res.setHeader('Cache-Control', 'no-cache')
  res.setHeader('Connection', 'keep-alive')
  res.flushHeaders()

  const send = (data: object) => res.write(`data: ${JSON.stringify(data)}\n\n`)

  try {
    const host = getSnowflakeHost()
    const url = `https://${host}/api/v2/databases/${AGENT_DB}/schemas/${AGENT_SCHEMA}/agents/${AGENT_NAME}:run`

    const agentRes = await fetch(url, {
      method: 'POST',
      headers: {
        ...getAuthHeaders(),
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

      for (const line of lines) {
        if (!line.startsWith('data: ')) continue
        const raw = line.slice(6).trim()
        if (!raw || raw === '[DONE]') continue

        try {
          const event = JSON.parse(raw)

          // Text delta
          if (event?.delta?.type === 'text_delta') {
            send({ type: 'delta', text: event.delta.text })
          }

          // Citation / source references
          if (event?.delta?.type === 'tool_result') {
            try {
              const toolContent = JSON.parse(event.delta.content ?? '{}')
              if (toolContent?.results) {
                for (const r of toolContent.results) {
                  if (r?.source_id) sources.push(r.source_id)
                }
              }
            } catch {}
          }

          // Done
          if (event?.type === 'message_stop' || event === '[DONE]') {
            if (sources.length > 0) send({ type: 'sources', sources })
            res.write('data: [DONE]\n\n')
            return res.end()
          }
        } catch {
          // non-JSON SSE line, skip
        }
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
