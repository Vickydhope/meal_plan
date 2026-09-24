import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { buildContextBlock, type ContextInput, daysBefore } from "./context.ts";

const base: ContextInput = {
  profile: {
    daily_calorie_target: 2600,
    goal: "lose",
    activity_level: "active",
    weight_kg: 79.4,
  },
  todayLogs: [],
  yearOfLogs: [],
  activity: [],
  localDate: "2026-09-25",
  calorieBudget: null,
};

Deno.test("includes weight and says activity is unknown when none synced", () => {
  const block = buildContextBlock(base);
  assertStringIncludes(block, "Weight: 79.4 kg");
  assertStringIncludes(block, "No activity data synced");
  assertStringIncludes(block, "Daily calorie target: 2600 kcal");
});

Deno.test("reports today's and the weekly activity", () => {
  const block = buildContextBlock({
    ...base,
    activity: [
      { day: "2026-09-25", steps: 9000, active_energy_kcal: 400 },
      { day: "2026-09-24", steps: 5000, active_energy_kcal: 200 },
    ],
  });
  assertStringIncludes(block, "Activity today");
  assertStringIncludes(block, "9000 steps, 400 kcal");
  assertStringIncludes(block, "avg 7000 steps/day, 300 kcal");
  assert(!block.includes("No activity data synced"));
});

Deno.test("no 'today' line when only earlier days are synced", () => {
  const block = buildContextBlock({
    ...base,
    activity: [{ day: "2026-09-24", steps: 5000, active_energy_kcal: 200 }],
  });
  assert(!block.includes("Activity today"));
});

Deno.test("dynamic mode: explains the mode and quotes the app's budget", () => {
  const block = buildContextBlock({
    ...base,
    profile: { ...base.profile, calorie_mode: "dynamic" },
    calorieBudget: 2536,
  });
  assertStringIncludes(block, "Calorie goal setting: activity-based");
  assertStringIncludes(block, "Today's calorie goal (as shown in the app): 2536 kcal");
  assertStringIncludes(block, "On the 'Fixed' setting their goal would be 2600 kcal");
  assert(!block.includes("Daily calorie target:"));
});

Deno.test("fixed mode: no mode line, just the target", () => {
  const block = buildContextBlock({
    ...base,
    profile: { ...base.profile, calorie_mode: "fixed" },
    calorieBudget: 2600,
  });
  assert(!block.includes("Calorie goal setting"));
  assertStringIncludes(block, "Daily calorie target: 2600 kcal");
});

Deno.test("daysBefore crosses month boundaries", () => {
  assertEquals(daysBefore("2026-10-03", 6), "2026-09-27");
});
