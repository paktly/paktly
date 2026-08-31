import { beforeEach, describe, expect, it, vi } from "vitest";

const smtp = vi.hoisted(() => ({
  createTransport: vi.fn(),
  sendMail: vi.fn()
}));

vi.mock("nodemailer", () => ({
  default: {
    createTransport: smtp.createTransport
  }
}));

import { SmtpEmailProvider } from "../src/modules/auth/email-provider.js";

describe("SmtpEmailProvider", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    smtp.createTransport.mockReturnValue({ sendMail: smtp.sendMail });
    smtp.sendMail.mockResolvedValue({ messageId: "message-1" });
  });

  it("uses authenticated TLS SMTP and sends the authentication code", async () => {
    const provider = new SmtpEmailProvider({
      host: "smtppro.zoho.com",
      port: 465,
      secure: true,
      username: "hello@paktly.io",
      password: "app-password",
      from: "Paktly <hello@paktly.io>"
    });

    await provider.sendAuthenticationCode({
      recipient: "alex@example.com",
      code: "481205",
      expiresInMinutes: 10
    });

    expect(smtp.createTransport).toHaveBeenCalledWith(expect.objectContaining({
      host: "smtppro.zoho.com",
      port: 465,
      secure: true,
      auth: { user: "hello@paktly.io", pass: "app-password" },
      tls: { minVersion: "TLSv1.2" }
    }));
    expect(smtp.sendMail).toHaveBeenCalledWith({
      from: "Paktly <hello@paktly.io>",
      to: "alex@example.com",
      subject: "481205 is your Paktly code",
      text: expect.stringContaining("expires in 10 minutes")
    });
  });

  it("requires STARTTLS when implicit TLS is disabled", () => {
    new SmtpEmailProvider({
      host: "smtp.zeptomail.com",
      port: 587,
      secure: false,
      username: "emailapikey",
      password: "smtp-password",
      from: "Paktly <hello@paktly.io>"
    });

    expect(smtp.createTransport).toHaveBeenCalledWith(expect.objectContaining({
      secure: false,
      requireTLS: true
    }));
  });

  it("sends a secure plan invitation with the account creation link", async () => {
    const provider = new SmtpEmailProvider({
      host: "smtppro.zoho.com",
      port: 465,
      secure: true,
      username: "hello@paktly.io",
      password: "app-password",
      from: "Paktly <hello@paktly.io>"
    });

    await provider.sendPlanInvitation({
      recipient: "new-member@example.com",
      inviterName: "Alex",
      planName: "Lisbon summer",
      invitationUrl: "https://paktly.io/invite?token=secure-token",
      expiresInDays: 7
    });

    expect(smtp.sendMail).toHaveBeenCalledWith(expect.objectContaining({
      to: "new-member@example.com",
      subject: "Alex invited you to Lisbon summer on Paktly",
      text: expect.stringContaining("https://paktly.io/invite?token=secure-token")
    }));
  });
});
