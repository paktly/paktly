import type { Metadata } from "next";
import { LegalPage } from "../../components/legal-page";

export const metadata: Metadata = {
  title: "Account Deletion | Paktly",
  description: "How to request deletion of your Paktly account and personal data.",
  alternates: { canonical: "/account-deletion" }
};

const sections = [
  {
    title: "Request account deletion",
    content: <><p>You can request deletion of your Paktly account and associated personal data by emailing <a href="mailto:privacy@paktly.io?subject=Paktly%20account%20deletion">privacy@paktly.io</a> from the email address associated with your account. Use the subject “Paktly account deletion.”</p><p>This is a deletion request, not an unsubscribe or a request to sign out. We may need to verify account ownership before processing it. Never include a password, verification code, passkey, private key, or payment details.</p></>
  },
  {
    title: "If you cannot access your account email",
    content: <p>Contact <a href="mailto:privacy@paktly.io?subject=Paktly%20account%20access%20and%20deletion">privacy@paktly.io</a> and explain that you cannot access the email used for your account. If you used Sign in with Apple and Hide My Email, mention this so we can help identify the account and verify your request.</p>
  },
  {
    title: "What the request covers",
    content: <p>Account deletion covers your account and profile information and associated personal data, including saved friends, device registrations, notification settings, and product interest preferences. Shared plan records, expense history, and any records that must be retained require review so we can explain the treatment of those records and any applicable retention obligations.</p>
  },
  {
    title: "Shared expenses and smart accounts",
    content: <><p>Deleting your account does not constitute payment of an outstanding shared expense. Include any questions about unresolved balances in your request. Do not send funds to anyone claiming payment is needed to process a privacy request.</p><p>Deleting Paktly data does not erase public blockchain records or automatically close an independently controlled smart account. If you previously activated an experimental smart wallet, tell us so its relationship to your Paktly account can be reviewed without requesting your private credentials.</p></>
  },
  {
    title: "Processing and confirmation",
    content: <p>We will explain any verification needed, the expected processing time, and any data that must be retained when responding to your request. We will confirm when processing is complete. Deleting the app from your phone does not delete your Paktly account.</p>
  },
  {
    title: "Privacy questions",
    content: <p>Read the <a href="/privacy">Privacy Policy</a> for more information about personal data, or visit <a href="/support">Support</a> for other account questions.</p>
  }
] as const;

export default function AccountDeletionPage() {
  return <LegalPage eyebrow="YOUR ACCOUNT" title="Delete your Paktly account" summary="Request deletion of your account and personal data, including if you no longer have the app installed." effectiveDate="September 7, 2026" sections={sections} />;
}
