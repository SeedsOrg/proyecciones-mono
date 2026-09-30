# Guía paso a paso — Poner online el Motor de Proyección
### Para hacerlo vos mismo, sin saber de programación

Son 6 partes. Es todo clickear, copiar y pegar. Tiempo: una tarde tranquila.
No hay que instalar nada ni escribir código.

Vas a usar dos páginas web gratis:
- **Supabase** → la "base de datos" segura donde se guardan las proyecciones y el login.
- **Netlify** → donde se publica la app para que tenga una dirección web.

Tené a mano estos dos archivos (los que te pasé):
- `seeds-proyeccion-produccion.html` → la app.
- `schema.sql` → un texto que vas a copiar y pegar una vez.

> 💡 Consejo: hacé esto en una compu (no en el celular). Vas a tener varias pestañas abiertas.

---

## PARTE 1 — Crear la base de datos (Supabase) · 10 min

1. Entrá a **https://supabase.com** y tocá **Start your project**.
2. Registrate (podés usar tu cuenta de Google de Seeds). Es gratis.
3. Tocá **New project**.
   - **Name:** `seeds-proyeccion`
   - **Database Password:** poné una contraseña fuerte y **guardala** en algún lado (no la vas a usar seguido, pero no la pierdas).
   - **Region:** elegí la más cercana (por ej. *South America (São Paulo)*).
4. Tocá **Create new project** y esperá 1–2 minutos a que diga que está listo.

---

## PARTE 2 — Cargar la estructura (copiar y pegar) · 5 min

1. En el menú de la izquierda, tocá **SQL Editor** (ícono de base de datos).
2. Tocá **+ New query**.
3. Abrí el archivo `schema.sql`, **seleccioná todo** (Ctrl+A / Cmd+A) y **copialo** (Ctrl+C / Cmd+C).
4. Pegalo en el cuadro grande de Supabase (Ctrl+V / Cmd+V).
5. Tocá el botón verde **Run** (abajo a la derecha).
6. Tiene que decir **Success**. Listo, ya está la estructura y la seguridad. ✅

---

## PARTE 3 — Copiar las dos "llaves" · 3 min

1. En el menú de la izquierda, abajo, tocá **Project Settings** (el engranaje) → **API**.
2. Vas a ver dos datos que necesitás copiar:
   - **Project URL** → algo como `https://abcd1234.supabase.co`
   - **Project API keys → `anon` `public`** → un texto largo que empieza con `eyJ...`
3. Copiá los dos a un bloc de notas por ahora. (La clave `anon` es pública por diseño, no es un secreto.)

> ⚠️ **Nunca** copies la clave que dice `service_role`. Esa sí es secreta y no va en la app.

---

## PARTE 4 — Pegar las llaves en la app · 5 min

1. Buscá el archivo `seeds-proyeccion-produccion.html` en tu compu.
2. Abrilo con un editor de texto simple:
   - **Windows:** clic derecho → *Abrir con* → **Bloc de notas**.
   - **Mac:** clic derecho → *Abrir con* → **TextEdit**. (Si te muestra texto con formato raro, andá a *Formato → Convertir a texto sin formato*.)
3. Arriba de todo vas a ver estas dos líneas:
   ```
   const SUPABASE_URL = "https://TU-PROYECTO.supabase.co";
   const SUPABASE_ANON_KEY = "TU_ANON_KEY";
   ```
4. Reemplazá `https://TU-PROYECTO.supabase.co` por tu **Project URL**, y `TU_ANON_KEY` por tu clave **anon**.
   Dejá las comillas. Tiene que quedar tipo:
   ```
   const SUPABASE_URL = "https://abcd1234.supabase.co";
   const SUPABASE_ANON_KEY = "eyJhbGciOi...";
   ```
5. **Guardá** el archivo (Ctrl+S / Cmd+S). No cambies el nombre ni la extensión `.html`.

---

## PARTE 5 — Publicar la app (arrastrar y soltar) · 5 min

1. Entrá a **https://app.netlify.com/drop**
2. **Arrastrá** el archivo `seeds-proyeccion-produccion.html` al recuadro que dice *Drag and drop your site folder here*.
3. En unos segundos te da una **dirección web** (algo como `https://random-name-123.netlify.app`). **Copiala.**
4. (Recomendado) Creá una cuenta gratis en Netlify cuando te lo ofrezca, así la dirección **no cambia** y podés volver a subir el archivo si lo actualizás. Sin cuenta, la dirección es temporal.

> Esa dirección es la que vas a compartir con el equipo.

---

## PARTE 6 — Avisarle a Supabase cuál es la dirección · 4 min

Esto hace que el link de acceso por email funcione.

1. Volvé a Supabase → menú izquierdo → **Authentication** → **URL Configuration**.
2. En **Site URL**, pegá la dirección de Netlify (la del paso 5.3).
3. En **Redirect URLs**, tocá **Add URL** y pegá la misma dirección.
4. Tocá **Save**.

✅ **¡Listo! La app ya está online y con login.**

---

## ÚLTIMO — Darle acceso al equipo · 5 min

1. Pedile a cada comercial (y a vos) que entre una vez a la dirección, escriba su email de Seeds y toque **Enviar link de acceso**. Les llega un mail con un botón para entrar. *(Si no aparece, que miren en Spam.)*
2. Cuando todos entraron una vez, andá a Supabase → **SQL Editor** → **+ New query**, y pegá esto, cambiando los emails por los reales:
   ```sql
   -- Vos como Head of Sales (ve todo):
   update public.profiles set role='admin', comercial_name='Jose María Imaz (Mono)'
     where email='jose.imaz@weareseeders.com';

   -- Cada comercial con su cartera (el nombre debe ser EXACTO):
   update public.profiles set comercial_name='Tomi Barale'      where email='EMAIL_DE_TOMI';
   update public.profiles set comercial_name='Camila Jordan'    where email='EMAIL_DE_CAMILA';
   update public.profiles set comercial_name='Benjamin Miguens' where email='EMAIL_DE_BENJAMIN';
   update public.profiles set comercial_name='Pedro Uriarte'    where email='EMAIL_DE_PEDRO';
   update public.profiles set comercial_name='Teresa Cirio'     where email='EMAIL_DE_TERESA';
   ```
3. Tocá **Run**. Cada uno, al volver a entrar, ve **solo su cartera**; vos ves el **Consolidado**.

> Los nombres de cartera tienen que coincidir letra por letra con los de la app:
> `Tomi Barale`, `Camila Jordan`, `Benjamin Miguens`, `Pedro Uriarte`, `Jose María Imaz (Mono)`, `Teresa Cirio`, `Natalia Russo`, `Nacho Basso`.

---

## Cómo se usa, día a día
- Cada comercial entra, **sube su CSV de revenue** (igual que en el prototipo), proyecta, y toca **💾 Guardar proyección**.
- Si cierra y vuelve a entrar, su proyección está guardada (vuelve a subir el CSV y se reconecta sola).
- Vos entrás, vas a **Consolidado** y ves lo de todos. Para el consolidado completo, subí el archivo de revenue entero.

## Seguridad — importante
- La dirección tiene **login**: nadie entra sin recibir el link en su email.
- Aunque alguien externo lograra entrar, **solo ve datos si vos le asignaste una cartera**. La base bloquea todo lo demás automáticamente.
- No publiques la dirección en lugares abiertos. Compartila solo con el equipo.

## Si algo no funciona
- **No llega el email de acceso:** revisá Spam. En el plan gratis de Supabase los mails a veces tardan unos minutos.
- **Entro pero veo "sin cartera asignada":** falta correr el paso del SQL con tu email (Último, punto 2).
- **Cambié el archivo y quiero re-subirlo:** volvé a Netlify, arrastralo de nuevo. Si creaste cuenta, mantené el mismo sitio (botón *Deploys → Drag and drop*) para que no cambie la dirección.
- **Cualquier cosa rara:** escribime y lo vemos.
