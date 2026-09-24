type LoggedMeal = Record<string, unknown>;
type ActivityRow = { day: string; steps: number; active_energy_kcal: number };

export type ContextInput = {
  profile: Record<string, unknown> | null;
  todayLogs: LoggedMeal[];
  yearOfLogs: LoggedMeal[];
  /** `daily_activity` rows for the 7 days ending on [localDate]. */
  activity: ActivityRow[];
  /** The client's local calendar date, `YYYY-MM-DD`. */
  localDate: string | null;
  /** Today's budget exactly as the app shows it, if the client sent one. */
  calorieBudget: number | null;
  now?: number;
};

type Totals = { calories: number; protein: number; carbs: number; fats: number };

function sumMeals(logs: LoggedMeal[]): Totals {
  return logs.reduce<Totals>(
    (acc, log) => ({
      calories: acc.calories + (Number(log.total_calories) || 0),
      protein: acc.protein + (Number(log.total_protein) || 0),
      carbs: acc.carbs + (Number(log.total_carbs) || 0),
      fats: acc.fats + (Number(log.total_fats) || 0),
    }),
    { calories: 0, protein: 0, carbs: 0, fats: 0 },
  );
}

/** Sums calories/macros for the logs whose `created_at` falls in the last [days]. */
function summarizeRange(logs: LoggedMeal[], days: number, now: number): {
  calories: number;
  protein: number;
  carbs: number;
  fats: number;
  mealCount: number;
  avgCaloriesPerDay: number;
} {
  const cutoff = now - days * 24 * 60 * 60 * 1000;
  const inRange = logs.filter(
    (log) => new Date(log.created_at as string).getTime() >= cutoff,
  );
  const totals = sumMeals(inRange);
  return {
    ...totals,
    mealCount: inRange.length,
    avgCaloriesPerDay: Math.round(totals.calories / days),
  };
}

/** Builds the nutrition/activity summary injected into the system prompt. */
export function buildContextBlock(input: ContextInput): string {
  const { profile, todayLogs, yearOfLogs, activity, localDate } = input;
  const now = input.now ?? Date.now();
  const lines: string[] = [];

  const planTarget = Number(profile?.daily_calorie_target) || null;
  const budget = input.calorieBudget;
  if (profile?.calorie_mode === "dynamic") {
    lines.push(
      "Calorie goal setting: activity-based (the app calls it " +
        "'Activity-based' — use that name, not 'dynamic'). Today's goal " +
        "starts at their plan for an inactive day and goes up by the " +
        "calories their health app has recorded them burning today.",
    );
  }
  if (budget !== null && planTarget !== null && budget !== planTarget) {
    lines.push(
      `Today's calorie goal (as shown in the app): ${budget} kcal — ` +
        `always quote this as today's goal. (On the 'Fixed' setting their ` +
        `goal would be ${planTarget} kcal every day.)`,
    );
  } else if (budget !== null || planTarget !== null) {
    lines.push(`Daily calorie target: ${budget ?? planTarget} kcal`);
  }
  if (profile?.goal) lines.push(`Goal: ${profile.goal}`);
  if (profile?.activity_level) {
    lines.push(`Activity level (self-reported): ${profile.activity_level}`);
  }
  if (profile?.weight_kg) lines.push(`Weight: ${profile.weight_kg} kg`);

  const today = activity.find((row) => row.day === localDate);
  if (today) {
    lines.push(
      `Activity today (synced from the user's phone health app): ` +
        `${today.steps} steps, ${today.active_energy_kcal} kcal active ` +
        `energy burned.`,
    );
  }
  if (activity.length === 0) {
    lines.push(
      "No activity data synced (steps/exercise unknown) — don't guess them.",
    );
  } else {
    const avg = (pick: (row: ActivityRow) => number) =>
      Math.round(activity.reduce((sum, row) => sum + pick(row), 0) / activity.length);
    lines.push(
      `Activity over the last 7 days (${activity.length} day(s) synced): ` +
        `avg ${avg((r) => r.steps)} steps/day, ` +
        `${avg((r) => r.active_energy_kcal)} kcal active energy/day.`,
    );
  }

  if (todayLogs.length === 0) {
    lines.push("No meals logged yet today.");
  } else {
    const totals = sumMeals(todayLogs);
    lines.push(
      `Eaten today: ${totals.calories} kcal (protein ${totals.protein}g, ` +
        `carbs ${totals.carbs}g, fats ${totals.fats}g) across ${todayLogs.length} ` +
        `logged meal(s): ${
          todayLogs.map((log) => log.meal_name).join(", ")
        }.`,
    );
  }

  for (const [label, days] of [
    ["Last 7 days", 7],
    ["Last 30 days", 30],
    ["Last 365 days", 365],
  ] as const) {
    const s = summarizeRange(yearOfLogs, days, now);
    lines.push(
      s.mealCount === 0
        ? `${label}: no meals logged.`
        : `${label}: ${s.calories} kcal total (avg ${s.avgCaloriesPerDay} ` +
          `kcal/day, protein ${s.protein}g, carbs ${s.carbs}g, fats ` +
          `${s.fats}g) across ${s.mealCount} logged meal(s).`,
    );
  }

  return lines.join("\n");
}

/** `YYYY-MM-DD` [days] before [date] (also `YYYY-MM-DD`). */
export function daysBefore(date: string, days: number): string {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() - days);
  return d.toISOString().slice(0, 10);
}
