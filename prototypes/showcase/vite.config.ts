import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'
import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { resolve, join, relative, dirname } from 'node:path'
import { pathToFileURL } from 'node:url'

const dir = resolve(process.env.PRIMITIVES_DIR ?? resolve(import.meta.dirname, '../catalog/primitives'))
// Only <name>.json directly in dir may be written: the name comes from the browser.
const SAFE = /^[a-z0-9][a-z0-9-]*$/

type Validator = { load: (d: string) => { texts: Record<string, string>; prims: Record<string, unknown> }; validate: (p: Record<string, unknown>) => string[] }

function primitivesServer(): Plugin {
  let v: Validator | undefined
  const validator = async () => (v ??= await import(pathToFileURL(resolve(import.meta.dirname, '../catalog/validate.mjs')).href))
  // What the showcase itself last wrote, so the watcher ignores its echo.
  const ours = new Map<string, string | null>()
  const all = (val: Validator) => (existsSync(dir) ? val.load(dir) : { texts: {}, prims: {} })

  return {
    name: 'primitives-server',
    configureServer(server) {
      server.watcher.add(dir)
      const onFs = (file: string) => {
        if (dirname(file) !== dir || !file.endsWith('.json')) return
        const name = relative(dir, file).slice(0, -5)
        const now = existsSync(file) ? readFileSync(file, 'utf8') : null
        if (ours.has(name) && ours.get(name) === now) return
        ours.delete(name)
        server.ws.send({ type: 'custom', event: 'primitives-changed', data: name })
      }
      server.watcher.on('change', onFs).on('add', onFs).on('unlink', onFs)

      server.middlewares.use('/api/', async (req, res) => {
        const send = (code: number, body: unknown) => {
          res.statusCode = code
          res.setHeader('content-type', 'application/json')
          res.end(JSON.stringify(body))
        }
        try {
          const val = await validator()
          const url = req.url ?? ''
          if (req.method === 'GET' && url === '/primitives') {
            const { texts, prims } = all(val)
            return send(200, { primitives: Object.entries(texts).map(([name, text]) => ({ name, text })), errors: val.validate(prims) })
          }
          const m = /^\/primitive\/([^/?]+)$/.exec(url)
          if (req.method !== 'PUT' || !m) return send(404, { error: 'not found' })
          const name = decodeURIComponent(m[1])
          if (!SAFE.test(name)) return send(400, { error: `refusing to write ${name}` })
          let body = ''
          for await (const chunk of req) body += chunk
          let content: unknown
          try { content = JSON.parse(body) } catch (e) { return send(400, { error: `invalid JSON: ${e}` }) }
          // An invalid primitive is never written: the file stays as it was.
          const rejected = val.validate({ [name]: content })
          if (rejected.length) return send(200, { rejected })
          const text = JSON.stringify(content, null, 2) + '\n'
          const file = join(dir, `${name}.json`)
          if (!existsSync(file) || readFileSync(file, 'utf8') !== text) {
            ours.set(name, text)
            writeFileSync(file, text)
          }
          send(200, { text, errors: val.validate(all(val).prims) })
        } catch (e) {
          send(500, { error: String(e) })
        }
      })
    },
  }
}

export default defineConfig({ plugins: [react(), primitivesServer()] })
