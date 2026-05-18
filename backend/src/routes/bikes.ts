import { Router, Request, Response } from 'express'
import { query } from '../snowflake'

const router = Router()

router.get('/', async (_req: Request, res: Response) => {
  try {
    const rows = await query<{
      BIKE_ID: string
      MODEL_YEAR: number
      MAKE: string
      MODEL: string
      CATEGORY: string
      DISPLAY_NAME: string
    }>(`SELECT BIKE_ID, MODEL_YEAR, MAKE, MODEL, CATEGORY, DISPLAY_NAME FROM APP.USER_BIKES ORDER BY MODEL_YEAR DESC`)

    res.json(
      rows.map((r: { BIKE_ID: string; MODEL_YEAR: number; MAKE: string; MODEL: string; CATEGORY: string; DISPLAY_NAME: string }) => ({
        bike_id: r.BIKE_ID,
        year: r.MODEL_YEAR,
        brand: r.MAKE,
        model: r.MODEL,
        bike_type: r.CATEGORY,
        display_name: r.DISPLAY_NAME ?? `${r.MODEL_YEAR} ${r.MAKE} ${r.MODEL}`,
      }))
    )
  } catch (err) {
    console.error('/api/bikes error:', err)
    res.status(500).json({ error: 'Failed to fetch bikes' })
  }
})

router.get('/:id/context', async (req: Request, res: Response) => {
  const bikeId = req.params.id
  if (!bikeId) return res.status(400).json({ error: 'Invalid bike ID' })

  try {
    const rows = await query<{ GET_BIKE_CONTEXT: unknown }>(
      `CALL APP.GET_BIKE_CONTEXT(?)`,[bikeId]
    )
    const raw = rows[0]?.GET_BIKE_CONTEXT
    const ctx: Record<string, unknown> = typeof raw === 'string' ? JSON.parse(raw) : (raw as Record<string, unknown>) ?? {}

    const bike = (ctx.bike ?? {}) as Record<string, unknown>
    const components = ((ctx.components ?? []) as Record<string, unknown>[]).map((c) => ({
      category: c.category,
      brand: c.make,
      model: c.model,
      year: c.model_year,
      is_stock: c.is_stock,
      notes: c.notes,
    }))

    res.json({
      bike,
      components,
      maintenance: [],
      preamble: (ctx.preamble ?? '') as string,
    })
  } catch (err) {
    console.error('/api/bikes/:id/context error:', err)
    res.status(500).json({ error: 'Failed to fetch bike context' })
  }
})

export default router
