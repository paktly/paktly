import { createApp } from "./app.js";
import { loadEnvironment } from "./config/environment.js";

const environment = loadEnvironment();
const app = await createApp(environment);

const shutdown = async (signal: string) => {
  app.log.info({ signal }, "shutdown requested");
  await app.close();
  process.exit(0);
};

process.on("SIGINT", () => void shutdown("SIGINT"));
process.on("SIGTERM", () => void shutdown("SIGTERM"));

try {
  await app.listen({ host: environment.apiHost, port: environment.apiPort });
} catch (error) {
  app.log.fatal({ err: error }, "API failed to start");
  process.exit(1);
}
