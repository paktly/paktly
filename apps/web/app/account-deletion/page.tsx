import type { Metadata } from "next";
import { LegalPage } from "../../components/legal-page";

export const metadata: Metadata = {
  title: "Account Deletion | Paktly",
  description: "How to request deletion of your Paktly account and personal data.",
  alternates: { canonical: "/account-deletion" }
};

const sections = [
  {
    title: "Delete in the app",
    content: <><p>Open Paktly → You → Delete account. Read the explanation, confirm that you understand deletion cannot be undone, then select “Permanently delete account.” If your account is connected to Apple, confirm with that same Apple account to disconnect Sign in with Apple and complete deletion.</p><p>The app confirms successful deletion and signs you out. Cancelling before confirmation leaves your account unchanged. If deletion fails, follow the error instructions; do not assume that uninstalling the app deletes your account.</p></>
  },
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
    content: <><p>Deletion removes your sign-in connections and sessions, saved friends, device registrations, notifications, product interest preferences, and stored AI confirmation drafts. Your profile name, username, avatar reference, and email are removed or replaced with a deleted-member record. Pending offline expenses on the device completing deletion are discarded.</p><p>Shared financial amounts and internal references remain associated with “Deleted member” to preserve other members’ accounting. Descriptions you authored in those records are redacted. Other people’s independently saved contact information and copies they control are not erased by deleting your account.</p></>
  },
  {
    title: "Shared expenses and smart accounts",
    content: <><p>You can delete your account with outstanding balances. Deletion does not pay or forgive a shared expense. Another active member becomes the owner of plans you owned, where one is available. Do not send funds to anyone claiming payment is needed to process a privacy request.</p><p>Deleting Paktly data does not erase public blockchain records or close an independently controlled smart account. Preserve your wallet passkey and recovery access before deleting Paktly. Never share private credentials with support.</p></>
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
