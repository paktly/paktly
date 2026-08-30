import { readFile } from "node:fs/promises";
import postgres from "postgres";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL is required to migrate waitlist storage");

const migration = await readFile(new URL("../db/migrations/001_waitlist.sql", import.meta.url), "utf8");
const sql = postgres(databaseUrl, { max: 1 });
try {
  await sql.unsafe(migration);
  process.stdout.write("Waitlist migration applied.\n");
} finally {
  await sql.end();
}
