import { z } from "zod";

export const waitlistRequestSchema = z.object({
  company: z.string().max(200).optional().default(""),
  email: z.string().trim().toLowerCase().email().max(320),
  marketingConsent: z.literal(true),
  termsAcknowledged: z.literal(true)
});

export type WaitlistRequest = z.infer<typeof waitlistRequestSchema>;

export function parseWaitlistRequest(input: unknown) {
  return waitlistRequestSchema.safeParse(input);
}
