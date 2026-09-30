# Motor de Proyección v2 — Especificación y plan

Documento de handoff para continuar el desarrollo. Resume las decisiones tomadas
con Mono y los hallazgos de la exploración de los conectores.

---

## 1. Objetivo de la v2

Reemplazar la **carga manual del CSV de Power BI** por un **sync en vivo** desde
los datos de la plataforma, y sumar un conjunto de modificaciones (abajo).
La experiencia de proyección debe considerar la **sanidad de las cuentas y el largo
plazo**, no solo el próximo trimestre.

## 2. Regla de oro — fuentes de la verdad

Cada dato viene de una sola fuente, para no cruzar montos ni duplicar:

| Dato | Fuente | Por qué |
|---|---|---|
| Contratos ya vendidos / net revenue actual | **Seeds Docs (plataforma)** | Montos más veraces (bimoneda con TC del contrato) |
| Vencimientos / base para extensiones | **Seeds Docs (plataforma)** | Es la realidad contratada |
| Histórico mensual por cuenta (~3 años) | **Seeds Docs (plataforma)** | Para estacionalidad y proyectado vs real |
| Pipeline de **nuevas ventas** (aún no firmado) | **HubSpot** | Es lo único que la plataforma no tiene todavía |

> **Extensiones NO se toman de HubSpot** (Pipeline de Extensiones) porque se duplicarían
> con los vencimientos de Seeds Docs: es el mismo contrato visto desde el CRM.
> HubSpot queda acotado **exclusivamente al pipeline de nuevas ventas**.

## 3. Modificaciones pedidas

1. **Extensiones + necesidades de HMs → a cargo de Customer Success.** El CS proyecta
   las renovaciones (sobre los vencimientos de Seeds Docs) y las necesidades de hiring
   managers existentes.
2. **Dos responsables por cuenta.** Cada cliente tiene un **comercial/AE** (proyecta nuevas
   ventas) y un **CS** (proyecta extensiones/HMs). Ya viene resuelto por el conector
   (`clientes_equipo` devuelve ambos). Esto **reemplaza el mapeo `OWNERS` hardcodeado** de la v1.
3. **Recomendaciones por estacionalidad.** Basadas en el histórico plurianual de cada cuenta.
   Ej.: en Q4 varias cuentas firman contratos más cortos (hasta diciembre) porque aún no
   tienen visibilidad de presupuesto 2027. Requiere el histórico → depende del bug (sección 6).
4. **Proyectado vs real en vivo + cierre de Q3.** Comparar lo que cada uno proyectó (guardado
   en Supabase) contra lo efectivamente cumplido (Seeds Docs).

## 4. Pipeline de HubSpot — cómo entra

- Solo **Pipeline de Ventas** (`pipeline = default`), etapa **"Potential Business"** en adelante.
- **Monto completo, sin ponderar** por probabilidad de etapa.
- **Ordenados por avance**: los más avanzados arriba (Contrato pendiente → Staffing →
  Potential Business), el resto abajo.
- Usar **`amount_in_home_currency`** (USD normalizado); hay deals en USD, ARS y CLP.
- Se muestran en la pestaña de **nuevas ventas** del comercial, que decide cuáles incluir.
- Al ganarse un deal y volverse contrato, deja de contar como pipeline y pasa a ser base
  real de Seeds Docs (no se cuenta dos veces).

### Datos del pipeline (HubSpot)
- `dealstage` "Potential Business" = valor `29347448`.
- Etapas siguientes (avance): Staffing `29347450`, A validar Ops `contractsent`,
  Contrato Cliente Pendiente `69722470`, Oportunidad ganada `29347455`.
- Propiedades útiles: `dealname` (trae la cuenta), `amount` + `deal_currency_code`,
  `amount_in_home_currency`, `closedate`, `hubspot_owner_id`, `pipeline`, `dealstage`.

## 5. Arquitectura del sync

La página estática de Netlify **no puede** llamar a los conectores MCP directamente.
El dato tiene que llegar a Supabase por un proceso aparte.

- **Camino A — sync asistido (para llegar a fin de mes):** se corre a demanda, trae el dato
  de los conectores y lo escribe en Supabase (tabla `revenue_snapshots` y las que hagan falta).
  La app lo lee igual que hoy, sin CSV manual.
- **Camino B — sync automático (objetivo):** una **Supabase Edge Function con cron** que
  llama a la **API propia de la plataforma de Seeds** (no al MCP) y a la **API REST de HubSpot**
  (private app token, solo lectura de deals), y actualiza Supabase cada noche.

### Accesos pendientes para el Camino B (pedidos a Daniel/Gastón por mail)
- API de la plataforma de Seeds: contratos con net revenue mensual **con histórico ~3 años**,
  clientes con su AE + CS, y vencimientos.
- HubSpot: private app token con scope de lectura de deals.

## 6. Conectores — estado (exploración hecha)

### Seeds Docs (funciona)
- `clientes_equipo` — por cliente: **KAM/AE + CS** + talentos activos. (Base de la modif. #2.)
- `contratos_net_revenue` — por cliente: nº contratos, net sales total, net revenue mensual.
- `contratos_por_vencer` — contratos que vencen + revenue en riesgo. (Base de extensiones.)
  Nota: devuelve varias filas por contrato (legs bimoneda) y tiene algún outlier de calidad
  de dato → hay que deduplicar/limpiar.

### Seeds Docs — BUG a resolver (bloqueante para histórico/estacionalidad)
- **`contratos_detalle` falla:** `column o.enableBillingCurrency does not exist`.
- Reproducir: llamar con cualquier filtro (ej. `cliente='Mercadolibre', solo_ongoing=true`).
- Es la única vista con el **detalle por contrato** y el **histórico mensual** (parámetro `mes`),
  necesario para la modif. #3 y parte de la #4.
- Reportado a Daniel/Gastón. Alternativa de respaldo para histórico: `facturas_procesadas`.

### HubSpot (funciona)
- `search_crm_objects` (objectType DEAL) con filtro por `dealstage`.
- `get_properties` para enums de `dealstage` / `pipeline`.

## 7. Histórico

- Alcance: **~3 años** hacia atrás (no hay más data en la plataforma).
- **Backfill** inicial (una vez, mes a mes hacia atrás) + **snapshot mensual** de ahí en adelante,
  guardados en Supabase, para que la serie se acumule sola.

## 8. Plan de ataque (Camino A)

1. **Sync base (Seeds Docs → Supabase):** net revenue por cuenta + mapa comercial/CS.
   Elimina el CSV manual y el `OWNERS` hardcodeado.
2. **Modelo de dos responsables** (comercial + CS) heredado del conector.
3. **Pipeline de HubSpot** (solo nuevas ventas) en la pestaña del comercial.
4. **Proyectado vs real en vivo + cierre de Q3.**
5. En paralelo (depende del bug): histórico plurianual + recomendaciones de estacionalidad.

## 9. Decisiones pendientes

- ¿La v2 se construye evolucionando el `index.html` de la v1, o arquitectura nueva?
  (Recomendación: evolucionar la v1 para llegar a fin de mes.)
- El primer sync: ¿traer **todas** las cuentas de la plataforma o solo las carteras activas del equipo?
