import { Router, Request, Response } from 'express'
import { query } from '../snowflake'

const router = Router()

// GET /api/bikes — list user bikes from APP.USER_BIKES
router.get('/', async (_req: Request, res: Response) => {
  try {
    const rows = await query<{
      BIKE_ID: number
      YEAR: number
      BRAND: string
      MODEL: string
      BIKE_TYPE: string
    }>(`SELECT BIKE_ID, YEAR, BRAND, MODEL, BIKE_TYPE FROM APP.USER_BIKES ORDER BY YEAR DESC`)

    res.json(
      rows.map((r: { BIKE_ID: number; YEAR: number; BRAND: string; MODEL: string; BIKE_TYPE: string }) => ({
        bike_id: r.BIKE_ID,
        year: r.YEAR,
        brand: r.BRAND,
        model: r.MODEL,
        bike_type: r.BIKE_TYPE,
        display_name: `${r.YEAR} ${r.BRAND} ${r.MODEL}`,
      }))
    )
  } catch (err) {
    console.error('/api/bikes error:', err)
    res.status(500).json({ error: 'Failed to fetch bikes' })
  }
})

// GET /api/bikes/:id/context — components + maintenance + preamble
router.get('/:id/context', async (req: Request, res: Response) => {
  const bikeId = Number(req.params.id)
  if (isNaN(bikeId)) return res.status(400).json({ error: 'Invalid bike ID' })

  try {
    const rows = await query<{ GET_BIKE_CONTEXT: string }>(
      `SELECT APP.GET_BIKE_CONTEXT(${bikeId}) AS GET_BIKE_CONTEXT`
    )
    const ctx = JSON.parse(rows[0].GET_BIKE_CONTEXT)

    res.json({
      bike: ctx.bike ?? {},
      components: (ctx.components ?? []).map((c: Record<string, unknown>) => ({
        component_id: c.component_id,
        category: c.category,
        brand: c.brand,
        model: c.model,
      })),
      maintenance: (ctx.maintenance ?? []).map((m: Record<string, unknown>) => ({
        task_id: m.task_id,
        task_name: m.task_name,
        component_name: m.component_name,
        interval_description: m.interval_description,
        due_label: m.due_label,
        status: m.status,
      })),
      preamble: ctx.preamble ?? '',
    })
  } catch (err) {
    console.error('/api/bikes/:id/context error:', err)
    res.status(500).json({ error: 'Failed to fetch bike context' })
  }
})

export default router
