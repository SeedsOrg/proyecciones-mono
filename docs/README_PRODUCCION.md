# Seeds · Motor de Proyección — Puesta en producción (Fase 1)

Esta es la guía para llevar el prototipo a una app multi-usuario con login y guardado,
usando **Supabase** (que Seeds ya tiene conectado). Pensada para que la ejecute un dev
o un contractor de Seeds. Tiempo estimado: media jornada.

## Qué incluye esta fase
- Login por **Google** (o link por email) restringido al equipo.
- Cada comercial ve y edita **solo su cartera**; el Head of Sales ve el **consolidado**.
- Las proyecciones se **guardan en la base** y se recuperan al volver a entrar.
- Toda la data protegida por **Row Level Security** a nivel de base de datos.

> El revenue (export de Power BI) y el pipeline (deals de HubSpot) se siguen cargando
> por CSV como en el prototipo. Automatizar esas fuentes es Fase 2/3.

---

## Paso 1 — Base de datos
1. Entrá a **Supabase Studio** del proyecto de Seeds → **SQL Editor** → **New query**.
2. Pegá el contenido de `schema.sql` y **Run**. Crea las tablas, las funciones y las
   políticas de seguridad (RLS).

## Paso 2 — Autenticación con Google
1. Studio → **Authentication → Providers → Google** → activar.
2. Seguir el asistente para crear las credenciales OAuth en Google Cloud y pegar
   *Client ID* y *Client Secret*.
3. En **Authentication → URL Configuration**, agregar la URL donde se va a hostear la app
   (ver Paso 4) como *Site URL* y *Redirect URL*.
4. (Recomendado) Restringir el acceso al dominio de Seeds: en **Authentication → Policies**
   o vía un trigger, permitir solo emails `@weareseeders.com`.

## Paso 3 — Configurar la app
1. Abrí `seeds-proyeccion-produccion.html`.
2. Arriba de todo, completá las dos variables con los datos de
   **Studio → Project Settings → API**:
   ```js
   const SUPABASE_URL = "https://xxxxx.supabase.co";
   const SUPABASE_ANON_KEY = "eyJ...";   // anon/public key — NUNCA la service_role
   ```
   > La *anon key* es pública por diseño; la seguridad real la dan las políticas RLS.
   > **Nunca** pongas la *service_role* key en este archivo.

## Paso 4 — Hosting
La app es un único archivo estático. Opciones simples:
- Subirlo a **Vercel**, **Netlify** o **Cloudflare Pages** (drag & drop de la carpeta).
- O servirlo desde **Supabase Storage** con dominio propio.

Copiá la URL final y agregala en el Paso 2.3.

## Paso 5 — Usuarios y carteras
1. Que cada comercial entre una vez con su Google de Seeds (se crea su perfil solo).
2. En **SQL Editor**, asigná rol y cartera (al final de `schema.sql` están los ejemplos):
   ```sql
   update public.profiles set role='admin', comercial_name='Jose María Imaz (Mono)'
     where email='jose.imaz@weareseeders.com';
   update public.profiles set comercial_name='Tomi Barale' where email='tomi@weareseeders.com';
   -- ...resto del equipo
   ```
   El `comercial_name` **debe coincidir exactamente** con las claves del objeto `OWNERS`
   dentro de la app (ej. `Tomi Barale`, `Camila Jordan`, `Pedro Uriarte`, etc.).

## Paso 6 — Probar el piloto
- Un comercial: entra, sube su CSV de revenue, proyecta, toca **Guardar**, cierra sesión
  y vuelve a entrar → su proyección está guardada. No ve carteras de otros.
- El admin: ve el **Consolidado** con lo que cada uno guardó.

---

## Seguridad — no negociable
- La data de revenue por cliente es de lo más confidencial de Seeds. La app **no** debe
  quedar en una URL pública sin login.
- La seguridad se apoya en **RLS**: aunque alguien tenga la anon key, solo puede leer/escribir
  lo que las políticas permiten para su usuario.
- Nunca exponer la *service_role* key en el frontend ni en el repo.
- Activar en Supabase: confirmación por email/dominio y, si se puede, MFA para el admin.

## Roadmap (después del piloto)
- **Fase 2:** owners y pipeline traídos en vivo de HubSpot por API (se acaba el mapeo a mano
  y la carga de CSV de deals). Historial de proyecciones Q a Q.
- **Fase 3:** refresh automático del revenue desde la API de Power BI; normalización del
  campo *Amount* en HubSpot; seguimiento de proyectado vs real al cierre del trimestre.

## Archivos
- `seeds-proyeccion-produccion.html` — la app con login y guardado.
- `schema.sql` — esquema + seguridad para correr en Supabase.
- `seeds-proyeccion.html` — el prototipo original (sin login), útil para pruebas offline.
