import { query } from '../db/pool.js';

/** Increment active quest progress after a completed trip; pay reward when goal met. */
export async function bumpDriverQuests(driverId) {
  if (!driverId) return;
  const { rows: quests } = await query(
    `SELECT * FROM quests
     WHERE active = TRUE AND ends_at > NOW()`,
  );
  for (const q of quests) {
    await query(
      `INSERT INTO driver_quest_progress (driver_id, quest_id, progress, claimed)
       VALUES ($1, $2, 1, FALSE)
       ON CONFLICT (driver_id, quest_id) DO UPDATE SET
         progress = driver_quest_progress.progress + 1
       WHERE driver_quest_progress.claimed = FALSE`,
      [driverId, q.id],
    );
    const { rows: prog } = await query(
      `SELECT progress, claimed FROM driver_quest_progress
       WHERE driver_id = $1 AND quest_id = $2`,
      [driverId, q.id],
    );
    const row = prog[0];
    if (row && !row.claimed && row.progress >= q.goal) {
      await query(
        `UPDATE driver_quest_progress SET claimed = TRUE
         WHERE driver_id = $1 AND quest_id = $2 AND claimed = FALSE`,
        [driverId, q.id],
      );
      await query(
        `UPDATE drivers SET available_balance = available_balance + $2, updated_at = NOW()
         WHERE id = $1`,
        [driverId, q.reward_birr],
      );
    }
  }
}
