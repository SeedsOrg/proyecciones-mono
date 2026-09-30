// Arma la fila `dataset` de revenue_snapshots desde la plataforma, con las reglas acordadas con Mono
// (sep-2026, ver V2_SPEC.md):
//  - Net revenue = grower − seeder de offers firmadas, pagos no borrados ni cancelados (misma base que
//    el header de En Curso en PlantedSeeders). El mes es el invoiceDate.
//  - Meses pasados con el TC de ese mes; meses futuros con el último TC. ARS → ARS-CCL.
//  - Moneda sin TC (ej. PYG): ese mes del contrato no se cuenta.
//  - Quilmes se agrupa en AB InBev; Magnum queda separado. Nombres de cliente sin espacios sobrantes.
//  - Una fila por cliente + talento + tipo, como el export de Power BI.

export const CLIENT_GROUP = { "Cervecería y Maltería Quilmes": "AB InBev", "Cervecería Quilmes": "AB InBev" };

const toUsd = (a) => `case ${a}.currency when 'USD' then ${a}.rate
  else ${a}.rate / nullif((select mer.value from monthly_exchange_rates mer
    where mer.currency = case ${a}.currency when 'ARS' then 'ARS-CCL' else ${a}.currency end
    order by (to_char(mer."createdAt", 'YYYY-MM') <= to_char(${a}."invoiceDate", 'YYYY-MM')) desc, mer."createdAt" desc
    limit 1), 0) end`;

const legs = (table, a, sign) => `
  select o."plantedSeederId" as ps_id, to_char(${a}."invoiceDate", 'YYYY-MM') as m, ${sign} * ${toUsd(a)} as usd
  from offers o join ${table} ${a} on ${a}."offerId" = o.id
  where o."deletedAt" is null and o.status = 'A'
    and ${a}."deletedAt" is null and ${a}.status <> 'C'
    and to_char(${a}."invoiceDate", 'YYYY-MM') between $1 and $2`;

// Parámetros: $1 = primer mes, $2 = último mes (AAAA-MM).
export const SQL = `
  with nr as (
    select ps_id, m, case when bool_or(usd is null) then null else sum(usd) end as usd
    from (${legs("grower_payments", "gp", 1)} union all ${legs("payments", "p", -1)}) x group by ps_id, m
  )
  select trim(ps."clientName") as client, ps.type as ctype,
    trim(regexp_replace(ps."seederLastName" || ' ' || ps."seederFirstName", '\\s+', ' ', 'g')) as person,
    json_object_agg(nr.m, round(nr.usd::numeric, 2)) as by_month
  from nr join planted_seeders ps on ps.id = nr.ps_id and ps."deletedAt" is null
  group by ps.id`;

export function monthRange(from, to) {
  const months = [];
  for (let d = new Date(from + "-01T00:00:00Z"); d.toISOString().slice(0, 7) <= to; d.setUTCMonth(d.getUTCMonth() + 1))
    months.push(d.toISOString().slice(0, 7));
  return months;
}

// Las proyecciones guardadas referencian contratos por `cliente|talento|tipo`. Para no romperlas, a los
// talentos que ya están cargados se les deja el nombre exacto que tienen (el de Power BI, mayúsculas
// incluidas); los nuevos van como "Apellido Nombre".
const norm = (s) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
const personKey = (client, person) =>
  `${norm(client).replace(/[^a-z0-9]/g, "")}|${norm(person).split(/[^a-z0-9]+/).filter(Boolean).sort().join(" ")}`;

export function buildPayload(rows, months, prevContracts = []) {
  const prevName = new Map(prevContracts.map((c) => [personKey(c.client, c.person), c.person]));
  const byKey = new Map();
  const sinTc = [];
  for (const r of rows) {
    const client = CLIENT_GROUP[r.client] || r.client;
    const person = prevName.get(personKey(client, r.person)) || r.person;
    if (Object.values(r.by_month).some((v) => v == null)) sinTc.push(`${client} / ${person}`);
    const k = `${client}|${person}|${r.ctype}`;
    const c = byKey.get(k) || { client, ctype: r.ctype, person, series: months.map(() => 0) };
    months.forEach((m, i) => (c.series[i] = Math.round((c.series[i] + Number(r.by_month[m] ?? 0)) * 100) / 100));
    byKey.set(k, c);
  }
  const contracts = [...byKey.values()]
    .filter((c) => c.series.some((v) => v !== 0))
    .sort((a, b) => a.client.localeCompare(b.client) || a.person.localeCompare(b.person));
  return { row: { quarter: "dataset", months, contracts, uploaded_by: null, created_at: new Date().toISOString() }, sinTc };
}

export function summarize(row, sinTc) {
  return {
    meses: `${row.months[0]}..${row.months.at(-1)}`,
    contratos: row.contracts.length,
    clientes: new Set(row.contracts.map((c) => c.client)).size,
    total_por_mes: Object.fromEntries(row.months.map((m, i) => [m, Math.round(row.contracts.reduce((s, c) => s + c.series[i], 0))])),
    sin_tc_excluidos: sinTc,
  };
}
