// Sync nocturno: plataforma de Seeds → Supabase de la herramienta de proyección.
// Lambda (fuera de la VPC) disparada por EventBridge Scheduler. Los datos los pide a la data-Lambda del
// conector (dentro de la VPC, usuario read-only del reader de Aurora) y escribe con la clave secreta
// de Supabase guardada en SSM.
import { LambdaClient, InvokeCommand } from "@aws-sdk/client-lambda";
import { SSMClient, GetParameterCommand } from "@aws-sdk/client-ssm";
import { SQL, SQL_OWNERS, monthRange, buildPayload, summarize } from "./payload.mjs";

const DATA_FUNCTION = process.env.DATA_FUNCTION || "seeds-docs-mcp-data";
const SUPABASE_URL = process.env.SUPABASE_URL || "https://xrqxikvhhkkxitsbqxkv.supabase.co";
const KEY_PARAM = process.env.KEY_PARAM || "/proyecciones-sync/supabase-key";
// Si la plataforma devuelve muchos menos contratos que los cargados, algo anda mal: no se pisa.
const MIN_RATIO = 0.8;

const lambda = new LambdaClient({});
const ssm = new SSMClient({});

async function queryPlatform(sql, params) {
  const res = await lambda.send(new InvokeCommand({ FunctionName: DATA_FUNCTION, Payload: JSON.stringify({ sql, params }) }));
  const out = JSON.parse(new TextDecoder().decode(res.Payload));
  if (res.FunctionError || out.error || out.errorMessage) throw new Error(`data-Lambda: ${out.error || out.errorMessage}`);
  return out.rows;
}

async function supabaseKey() {
  if (process.env.SUPABASE_KEY) return process.env.SUPABASE_KEY;
  const res = await ssm.send(new GetParameterCommand({ Name: KEY_PARAM, WithDecryption: true }));
  return res.Parameter.Value;
}

async function supabase(key, path, init = {}) {
  // Las claves nuevas (sb_secret_…) van solo en `apikey`; no son un JWT para `Authorization`.
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: { apikey: key, "Content-Type": "application/json", ...(init.headers || {}) },
  });
  if (!res.ok) throw new Error(`Supabase ${res.status}: ${await res.text()}`);
  return res.status === 204 || init.method === "POST" ? null : res.json();
}

// Del año anterior al siguiente (hora de Argentina): histórico para la base y la velocidad de ventas, y el año
// que viene para poder proyectar el Q1 con el Q4 como base.
function projectionRange() {
  const y = +new Intl.DateTimeFormat("en", { timeZone: "America/Argentina/Buenos_Aires", year: "numeric" }).format(new Date());
  return [`${y - 1}-01`, `${y + 1}-12`];
}

export async function runSync({ write = false, from, to, prevContracts, includeRow = false } = {}) {
  [from, to] = from && to ? [from, to] : projectionRange();
  const months = monthRange(from, to);
  const key = write || !prevContracts ? await supabaseKey() : null;

  let prev = null;
  if (!prevContracts) {
    const [current] = await supabase(key, "revenue_snapshots?quarter=eq.dataset&select=quarter,months,contracts,uploaded_by,created_at");
    prev = current || null;
    prevContracts = prev?.contracts || [];
  }

  const [rows, owners] = await Promise.all([queryPlatform(SQL, [from, to]), queryPlatform(SQL_OWNERS, [])]);
  const { row, sinTc } = buildPayload(rows, months, prevContracts, owners);
  const summary = summarize(row, sinTc);

  if (prevContracts.length && row.contracts.length < MIN_RATIO * prevContracts.length)
    throw new Error(`Guarda: ${row.contracts.length} contratos vs ${prevContracts.length} cargados (< ${MIN_RATIO * 100}%). No se escribe.`);

  if (write) {
    const upsert = (body) => supabase(key, "revenue_snapshots?on_conflict=quarter", {
      method: "POST",
      headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify(body),
    });
    // Copia de la carga anterior en `dataset-anterior` (la app solo lee `dataset`): permite volver un paso atrás.
    if (prev) await upsert({ ...prev, quarter: "dataset-anterior" });
    await upsert(row);
  }
  return { escrito: write, ...summary, ...(includeRow ? { row } : {}) };
}

export async function handler() {
  const result = await runSync({ write: true });
  console.log(JSON.stringify(result));
  return result;
}
