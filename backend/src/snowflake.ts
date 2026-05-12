import snowflake from 'snowflake-sdk'
import fs from 'fs'

snowflake.configure({ logLevel: 'ERROR' })

let connection: snowflake.Connection | null = null

function getOAuthToken(): string | null {
  try {
    if (fs.existsSync('/snowflake/session/token')) {
      return fs.readFileSync('/snowflake/session/token', 'utf8').trim()
    }
  } catch {}
  return null
}

export function getSnowflakeHost(): string {
  const account = process.env.SNOWFLAKE_ACCOUNT || ''
  return process.env.SNOWFLAKE_HOST || `${account}.snowflakecomputing.com`
}

export function getAuthHeaders(): Record<string, string> {
  const token = getOAuthToken()
  if (token) return { Authorization: `Snowflake Token="${token}"` }
  throw new Error('No SPCS OAuth token available at /snowflake/session/token')
}

function getConnectionOptions(): snowflake.ConnectionOptions {
  const base = {
    account: process.env.SNOWFLAKE_ACCOUNT!,
    warehouse: process.env.SNOWFLAKE_WAREHOUSE || 'SPROCKET_WH',
    database: process.env.SNOWFLAKE_DATABASE || 'SPROCKET',
    schema: process.env.SNOWFLAKE_SCHEMA || 'APP',
  }

  const token = getOAuthToken()
  if (token) {
    return {
      ...base,
      host: getSnowflakeHost(),
      token,
      authenticator: 'oauth',
    }
  }

  return {
    ...base,
    username: process.env.SNOWFLAKE_USER!,
    authenticator: 'EXTERNALBROWSER',
  }
}

export async function getConnection(): Promise<snowflake.Connection> {
  if (connection) return connection
  const conn = snowflake.createConnection(getConnectionOptions())
  await new Promise<void>((resolve, reject) => {
    conn.connect((err) => (err ? reject(err) : resolve()))
  })
  connection = conn
  return connection
}

export async function query<T>(sql: string, binds?: unknown[]): Promise<T[]> {
  const conn = await getConnection()
  return new Promise<T[]>((resolve, reject) => {
    conn.execute({
      sqlText: sql,
      binds: binds as snowflake.Binds,
      complete: (err, _stmt, rows) => (err ? reject(err) : resolve((rows ?? []) as T[])),
    })
  })
}
