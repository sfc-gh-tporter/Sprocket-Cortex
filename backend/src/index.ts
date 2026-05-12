import express from 'express'
import cors from 'cors'
import path from 'path'
import bikesRouter from './routes/bikes'
import chatRouter from './routes/chat'

const app = express()
const PORT = process.env.PORT || 3001

app.use(cors())
app.use(express.json())

// API routes
app.use('/api/bikes', bikesRouter)
app.use('/api/chat', chatRouter)

// Health check
app.get('/health', (_req, res) => res.json({ status: 'ok' }))

// Serve React frontend — works both locally (../../frontend/dist) and in Docker (/app/frontend/dist)
const distPath = process.env.FRONTEND_DIST
  ? path.resolve(process.env.FRONTEND_DIST)
  : path.join(__dirname, '../../frontend/dist')
app.use(express.static(distPath))
app.get('*', (_req, res) => {
  res.sendFile(path.join(distPath, 'index.html'))
})

app.listen(PORT, () => {
  console.log(`Sprocket backend listening on :${PORT}`)
})
