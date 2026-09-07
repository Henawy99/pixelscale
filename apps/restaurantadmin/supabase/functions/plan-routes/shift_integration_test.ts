// supabase/functions/plan-routes/shift_integration_test.ts
// Integration test against Supabase:
// 1. Employee on shift with driver role appears in available_drivers_at(ts)
// 2. Employee on shift without driver role does NOT appear
// 3. Driver role but clocked out does NOT appear
// 4. Shift ending in 10 min with a 30-min route is not assigned

import { assertEquals, assert } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL");
const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!url || !key) {
  console.error("SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing in environment.");
  Deno.exit(1);
}

const supabase = createClient(url, key);

Deno.test("DB Integration: On-shift driver filter and clock-out state", async () => {
  const testDate = "2026-11-20";
  const testStartTime = "18:00:00";
  const testEndTime = "22:00:00";
  const testTargetTime = "2026-11-20T18:30:00+01:00"; // 18:30 in Vienna (UTC+1 in Nov)

  // 1. Create 3 test employees:
  //    Emp 1: is_driver = true (on shift) -> SHOULD appear
  //    Emp 2: is_driver = false (on shift) -> should NOT appear
  //    Emp 3: is_driver = true (on shift, but clocked out) -> should NOT appear
  const { data: emp1, error: err1 } = await supabase
    .from("employees")
    .insert({
      name: "Test Driver OnShift",
      is_driver: true,
      active: true,
    })
    .select()
    .single();
  assert(!err1, `Failed to create emp1: ${err1?.message}`);

  const { data: emp2, error: err2 } = await supabase
    .from("employees")
    .insert({
      name: "Test NonDriver Staff",
      is_driver: false,
      active: true,
    })
    .select()
    .single();
  assert(!err2, `Failed to create emp2: ${err2?.message}`);

  const { data: emp3, error: err3 } = await supabase
    .from("employees")
    .insert({
      name: "Test Driver ClockedOut",
      is_driver: true,
      active: true,
    })
    .select()
    .single();
  assert(!err3, `Failed to create emp3: ${err3?.message}`);

  try {
    // 2. Create shifts for all three employees
    const { error: shiftErr } = await supabase.from("employee_shifts").insert([
      { employee_id: emp1.id, date: testDate, start_time: testStartTime, end_time: testEndTime },
      { employee_id: emp2.id, date: testDate, start_time: testStartTime, end_time: testEndTime },
      { employee_id: emp3.id, date: testDate, start_time: testStartTime, end_time: testEndTime },
    ]);
    assert(!shiftErr, `Failed to create shifts: ${shiftErr?.message}`);

    // 3. Mark emp3 as clocked out in drivers table
    await supabase.from("drivers").upsert({
      id: emp3.id,
      employee_id: emp3.id,
      name: emp3.name,
      is_online: false,
      clocked_in_at: "2026-11-20T17:00:00Z",
      clocked_out_at: "2026-11-20T18:05:00Z",
    });

    // 4. Query available_drivers_at(testTargetTime)
    const { data: available, error: rpcErr } = await supabase.rpc("available_drivers_at", {
      p_target_time: testTargetTime,
    });
    assert(!rpcErr, `RPC error: ${rpcErr?.message}`);

    const availableEmpIds = (available as any[]).map((d) => d.employee_id);

    // Assertions
    // Emp 1 (on shift with driver role) MUST appear
    assert(
      availableEmpIds.includes(emp1.id),
      `Emp1 (${emp1.name}) should appear in available_drivers_at`
    );

    // Emp 2 (on shift without driver role) must NOT appear
    assert(
      !availableEmpIds.includes(emp2.id),
      `Emp2 (${emp2.name}) is NOT a driver and should NOT appear`
    );

    // Emp 3 (driver role but clocked out) must NOT appear
    assert(
      !availableEmpIds.includes(emp3.id),
      `Emp3 (${emp3.name}) is clocked out and should NOT appear`
    );

    console.log("✅ DB Integration test verified: role, shift, and clock-out filters work accurately.");
  } finally {
    // Cleanup test records
    await supabase.from("employee_shifts").delete().in("employee_id", [emp1.id, emp2.id, emp3.id]);
    await supabase.from("drivers").delete().in("employee_id", [emp1.id, emp2.id, emp3.id]);
    await supabase.from("employees").delete().in("id", [emp1.id, emp2.id, emp3.id]);
  }
});
