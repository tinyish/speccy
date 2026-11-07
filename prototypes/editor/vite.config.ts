import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'
import { readFileSync, writeFileSync, unlinkSync, existsSync } from 'node:fs'
import { resolve, join, relative } from 'node:path'
import { pathToFileURL } from 'node:url'

const dir = resolve(process.env.SPEC_DIR ?? resolve(import.meta.dirname, '../spec-format'))
// Only spec item files may be written: the request body comes from the browser.
const SAFE = /^(components|screens|data)\/[^/\\.][^/\\]*\.json$/

type Write = { path: string; content?: unknown; delete?: boolean }

function specServer(): Plugin {
  let checker: { load: (d: string) => unknown; check: (s: unknown) => string[] } | undefined
  const getChecker = async () => (checker ??= await import(pathToFileURL(join(dir, 'check.mjs')).href))
  // What the editor itself last wrote (null = deleted), so the watcher ignores its echo.
  const ours = new Map<string, string | null>()

  return {
    name: 'spec-server',
    configureServer(server) {
      server.watcher.add(dir)
      const onFs = (file: string) => {
        if (!file.startsWith(dir) || !file.endsWith('.json')) return
        const rel = relative(dir, file)
        const now = existsSync(file) ? readFileSync(file, 'utf8') : null
        if (ours.has(rel) && ours.get(rel) === now) return
        ours.delete(rel)
        server.ws.send({ type: 'custom', event: 'spec-changed', data: rel })
      }
      server.watcher.on('change', onFs).on('add', onFs).on('unlink', onFs)

      server.middlewares.use('/api/spec', async (req, res) => {
        const send = (code: number, body: unknown) => {
          res.statusCode = code
          res.setHeader('content-type', 'application/json')
          res.end(JSON.stringify(body))
        }
        try {
          const { load, check } = await getChecker()
          if (req.method === 'GET') {
            const spec = load(dir) as object
            return send(200, { ...spec, errors: check(spec) })
          }
          if (req.method !== 'POST') return send(405, { error: 'method' })
          let body = ''
          for await (const chunk of req) body += chunk
          const writes = JSON.parse(body) as Write[]
          for (const w of writes) if (!SAFE.test(w.path)) return send(400, { error: `refusing to write ${w.path}` })
          for (const w of writes) {
            const file = join(dir, w.path)
            if (w.delete) {
              ours.set(w.path, null)
              if (existsSync(file)) unlinkSync(file)
              continue
            }
            const text = JSON.stringify(w.content, null, 2) + '\n'
            if (existsSync(file) && readFileSync(file, 'utf8') === text) continue
            ours.set(w.path, text)
            writeFileSync(file, text)
          }
          send(200, { errors: check(load(dir)) })
        } catch (e) {
          send(500, { error: String(e) })
        }
      })
    },
  }
}

export default defineConfig({ plugins: [react(), specServer()] })
