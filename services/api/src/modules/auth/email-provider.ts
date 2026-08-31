import nodemailer, { type Transporter } from "nodemailer";

export type AuthenticationCodeEmail = {
  recipient: string;
  code: string;
  expiresInMinutes: number;
};

export interface EmailProvider {
  sendAuthenticationCode(message: AuthenticationCodeEmail): Promise<void>;
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
}
