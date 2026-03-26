import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export type MaterialMatch = {
  material_id: string | null;
  material_name: string | null;
  base_unit: string | null;
  conversion_ratio: number | null;
};

export async function resolveMaterialsForPurchase(supabase: any, lines: any[]): Promise<MaterialMatch[]> {
  const out: MaterialMatch[] = [];
  // Load all materials (could be optimized by querying only when needed)
  const { data: materials } = await supabase
    .from('material')
    .select('id, name, unit_of_measure');

  // Load receipt mappings
  const { data: maps } = await supabase
    .from('receiptmaterialitem')
    .select('raw_name, material_id, receipt_unit, base_unit, conversion_ratio, material_id(name, unit_of_measure)');

  function findMapping(rawName: string): any | null {
    const target = String(rawName).trim().toLowerCase();
    const byExact = (maps || []).find((m: any) => String(m.raw_name || '').trim().toLowerCase() === target);
    if (byExact) return byExact;
    // simple contains-based fallback
    const contains = (maps || []).find((m: any) => target.includes(String(m.raw_name || '').trim().toLowerCase()));
    return contains || null;
  }

  function bestFuzzy(name: string): any | null {
    const t = name.toLowerCase();
    let best: { m: any; score: number } | null = null;
    for (const m of materials || []) {
      const cand = String(m.name || '').toLowerCase();
      if (!cand) continue;
      let score = 0;
      if (cand === t) score = 1;
      else if (cand.includes(t) || t.includes(cand)) score = 0.7;
      else {
        const tt = t.split(/[^a-z0-9]+/).filter(Boolean);
        const cc = cand.split(/[^a-z0-9]+/).filter(Boolean);
        const common = tt.filter(x => cc.some(y => y === x || y.includes(x) || x.includes(y)));
        score = common.length / Math.max(1, Math.max(tt.length, cc.length));
      }
      if (!best || score > best.score) best = { m, score };
    }
    return best && best.score >= 0.55 ? best.m : null;
  }

  for (const line of lines) {
    const mapping = line.raw_name ? findMapping(line.raw_name) : null;
    if (mapping?.material_id) {
      const mat = mapping.material_id as any;
      out.push({
        material_id: mat?.id ?? mapping.material_id,
        material_name: mat?.name ?? null,
        base_unit: (mat?.unit_of_measure ?? mapping.base_unit) || null,
        conversion_ratio: mapping.conversion_ratio ?? null,
      });
      continue;
    }
    if (materials && line.raw_name) {
      const m = bestFuzzy(String(line.raw_name));
      if (m) {
        out.push({ material_id: m.id, material_name: m.name, base_unit: m.unit_of_measure, conversion_ratio: null });
        continue;
      }
    }
    out.push({ material_id: null, material_name: null, base_unit: null, conversion_ratio: null });
  }
  return out;
}

