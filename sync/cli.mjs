// Corre el sync a mano, con tu sesión de AWS (perfil `seeds`).
//   node sync/cli.mjs                       → prueba: muestra qué cargaría, no escribe
//   node sync/cli.mjs --write               → escribe en Supabase
//   node sync/cli.mjs --desde 2026-01 --hasta 2026-12 [--write]
//   node sync/cli.mjs --prev backup.json    → prueba sin leer Supabase (toma los nombres de un backup)
// La clave de Supabase se lee de SSM, o de la variable SUPABASE_KEY si está definida.
import { readFileSync } from "node:fs";

process.env.AWS_PROFILE ||= "seeds";
process.env.AWS_REGION ||= "us-east-1";
const { runSync } = await import("./src/handler.mjs");

const arg = (name) => { const i = process.argv.indexOf(name); return i > 0 ? process.argv[i + 1] : undefined; };
const prevFile = arg("--prev");
const prevContracts = prevFile ? (JSON.parse(readFileSync(prevFile, "utf8")).revenue_snapshots?.[0] ?? JSON.parse(readFileSync(prevFile, "utf8"))).contracts : undefined;

const result = await runSync({ write: process.argv.includes("--write"), from: arg("--desde"), to: arg("--hasta"), prevContracts });
console.log(JSON.stringify(result, null, 2));
