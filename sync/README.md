# Sync nocturno: plataforma → Supabase

Reemplaza la carga manual del CSV de Power BI. Todas las noches, a las 03:00 hora Argentina, la Lambda
`proyecciones-sync` arma la fila `dataset` de `revenue_snapshots` con el revenue de la plataforma y
la escribe en Supabase. La app la lee igual que antes.

- **Datos:** los pide a la data-Lambda del conector (`seeds-docs-mcp-data`, read-only sobre el reader de
  Aurora). Las reglas de cálculo están en `src/payload.mjs`.
- **Período:** el año en curso, de enero a diciembre.
- **Nombres:** respeta los nombres de talento ya cargados, porque las proyecciones guardadas los referencian.
- **Protecciones:** si la plataforma devuelve menos del 80% de los contratos cargados, no escribe. Antes
  de escribir, copia la carga anterior en la fila `dataset-anterior`.
- **Clave de Supabase:** en SSM (`/proyecciones-sync/supabase-key`), nunca en el código.

> Si alguien sube un CSV a mano desde la app, esa misma noche lo pisa el sync.

## Uso

```bash
aws sso login --profile seeds
cd sync && npm install                 # solo para correrlo local
node cli.mjs                           # prueba: muestra qué cargaría
node cli.mjs --write                   # escribe
MSYS_NO_PATHCONV=1 AWS_PROFILE=seeds bash deploy.sh   # crea/actualiza la infra en AWS
aws lambda invoke --function-name proyecciones-sync out.json && cat out.json   # correr la Lambda ya
```

## Volver a la carga anterior

En el SQL Editor de Supabase:

```sql
update revenue_snapshots set months = p.months, contracts = p.contracts, created_at = now()
from revenue_snapshots p where revenue_snapshots.quarter = 'dataset' and p.quarter = 'dataset-anterior';
```
