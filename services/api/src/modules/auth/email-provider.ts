import nodemailer, { type Transporter } from "nodemailer";

export type AuthenticationCodeEmail = {
  recipient: string;
  code: string;
  expiresInMinutes: number;
};

export type PlanInvitationEmail = {
  recipient: string;
  inviterName: string;
  planName: string;
  invitationUrl: string;
  expiresInDays: number;
};

export interface EmailProvider {
  sendAuthenticationCode(message: AuthenticationCodeEmail): Promise<void>;
  sendPlanInvitation(message: PlanInvitationEmail): Promise<void>;
}

export type SmtpEmailProviderConfiguration = {
  host: string;
  port: number;
  secure: boolean;
  username: string;
  password: string;
  from: string;
};

export class SmtpEmailProvider implements EmailProvider {
  private readonly transporter: Transporter;

  constructor(private readonly configuration: SmtpEmailProviderConfiguration) {
    this.transporter = nodemailer.createTransport({
      host: configuration.host,
      port: configuration.port,
      secure: configuration.secure,
      auth: {
        user: configuration.username,
        pass: configuration.password
      },
      connectionTimeout: 8_000,
      greetingTimeout: 8_000,
      socketTimeout: 12_000,
      requireTLS: !configuration.secure,
      tls: { minVersion: "TLSv1.2" }
    });
  }

  async sendAuthenticationCode(message: AuthenticationCodeEmail): Promise<void> {
    await this.transporter.sendMail({
      from: this.configuration.from,
      to: message.recipient,
      subject: `${message.code} is your Paktly code`,
      text: `Your Paktly verification code is ${message.code}. It expires in ${message.expiresInMinutes} minutes. If you did not request this code, you can ignore this email.`
    });
  }

  async sendPlanInvitation(message: PlanInvitationEmail): Promise<void> {
    await this.transporter.sendMail({
      from: this.configuration.from,
      to: message.recipient,
      subject: `${message.inviterName} invited you to ${message.planName} on Paktly`,
      text: [
        `${message.inviterName} invited you to join “${message.planName}” on Paktly.`,
        "",
        "Open this secure invitation to sign in or create your Paktly account:",
        message.invitationUrl,
        "",
        `This invitation expires in ${message.expiresInDays} days. If you were not expecting it, you can ignore this email.`
      ].join("\n")
    });
  }
}
