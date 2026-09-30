# Motor de Proyección de Ventas — Seeds

Herramienta interna de proyección de ventas del equipo comercial de Seeds.
Este repo contiene la **v1 en producción** y la **especificación de la v2** (ver `V2_SPEC.md`).

> **Mantenedores:** Daniel Bordoli y Gastón Salinas se encargan del desarrollo
> de la v2 y de la conexión con las APIs. Cualquier duda de contexto, hablar con Mono.

---

## Qué es

App web de un solo archivo (`app/index.html`) que corre sobre:
- **Supabase** — autenticación (magic-link por email) + base de datos (proyecciones, objetivos, snapshots de revenue).
- **Netlify** — hosting del sitio estático.

Hoy el admin **sube a mano** el CSV de Power BI y la app lo procesa en el navegador.
El objetivo de la v2 es **reemplazar esa carga manual por un sync en vivo** desde los
conectores de Seeds Docs (plataforma) y HubSpot (pipeline). Todo el detalle en `V2_SPEC.md`.

## Estructura

```
app/    → la aplicación
  index.html                      ← ARCHIVO DESPLEGADO (tiene las claves reales de Supabase)
  seeds-proyeccion-produccion.html ← plantilla canónica (claves placeholder) — TODA edición va acá primero
  seeds-proyeccion-LISTO.html      ← copia espejo de index.html
db/     → esquema de Supabase (correr en orden)
  schema.sql            ← base: profiles, projections, revenue_snapshots, RLS, triggers
  schema_objetivos.sql  ← tabla de objetivos
  schema_talent.sql     ← rol 'talent' (solo lectura)
docs/   → guías de la v1
  GUIA_PASO_A_PASO.md
  README_PRODUCCION.md
V2_SPEC.md → especificación y plan de la v2 (leer esto para continuar el desarrollo)
```

## Flujo de desarrollo (v1)

1. Editar **`app/seeds-proyeccion-produccion.html`** (la plantilla con placeholders), nunca el `index.html` directo.
2. Inyectar las claves de Supabase para generar `index.html` y `seeds-proyeccion-LISTO.html`:
   - `SUPABASE_URL` → `https://xrqxikvhhkkxitsbqxkv.supabase.co`
   - `SUPABASE_ANON_KEY` → la clave **anon / publishable** (segura para cliente)
3. Validar los `<script>` inline con `node --check`.
4. Subir `index.html` a Netlify (arrastrar al deploy; misma URL).

## Notas importantes

- La clave del HTML es la **anon / publishable** de Supabase → es segura para exponer en el cliente.
  **Nunca** poner la `service_role` / `sb_secret` en el HTML ni en el front. Esa va solo del lado servidor.
- Los datos (proyecciones, objetivos, revenue) viven en **Supabase**. Re-desplegar el `index.html`
  cambia solo la app, nunca los datos.
- Login = magic-link por email. La fila en `profiles` se crea al primer login; recién ahí se le
  puede asignar rol por SQL.

## Cómo subir esto al repo (para Daniel)

Desde tu máquina, con acceso al repo:

```bash
git clone https://github.com/danielbordoliseeds/proyecciones-mono.git
cd proyecciones-mono
# copiar acá el contenido de esta carpeta
git add .
git commit -m "v1 en producción + spec de la v2"
git push origin main
```

(O, más simple: subir los archivos por la UI web de GitHub → "Add file" → "Upload files".)
