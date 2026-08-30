import { readdir, readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import postgres from "postgres";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL is required");

const sql = postgres(databaseUrl, { max: 1 });
const migrationsDirectory = join(dirname(fileURLToPath(import.meta.url)), "..", "migrations");

try {
  await sql`CREATE TABLE IF NOT EXISTS schema_migrations (
    name TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`;
  const files = (await readdir(migrationsDirectory)).filter((file) => file.endsWith(".sql")).sort();
  for (const file of files) {
    const [existing] = await sql`SELECT name FROM schema_migrations WHERE name = ${file}`;
    if (existing) continue;
    const contents = await readFile(join(migrationsDirectory, file), "utf8");
    await sql.begin(async (transaction) => {
      await transaction.unsafe(contents);
      await transaction`INSERT INTO schema_migrations (name) VALUES (${file})`;
    });
    process.stdout.write(`Applied ${file}\n`);
  }
} finally {
  await sql.end();
}
