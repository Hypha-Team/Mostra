import "server-only";
import nodemailer from "nodemailer";

/**
 * Transactional email over SMTP (app notifications — Supabase's built-in SMTP only sends auth email).
 * Production/preview: Resend SMTP (smtp.resend.com:465, user "resend", password = API key).
 * CI/local: the local Supabase Mailpit (127.0.0.1:54325, no auth).
 * Not configured → the email is skipped and logged; the action that triggered it still succeeds.
 */
type Mail = { to: string; subject: string; text: string; html: string };

function transport() {
  const host = process.env.SMTP_HOST;
  const from = process.env.EMAIL_FROM;
  if (!host || !from) return null;
  const port = Number(process.env.SMTP_PORT ?? 465);
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASSWORD;
  return {
    from,
    mailer: nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: user && pass ? { user, pass } : undefined,
    }),
  };
}

export async function sendEmail(mail: Mail): Promise<"sent" | "skipped" | "failed"> {
  const t = transport();
  if (!t) {
    console.warn("email skipped: SMTP_HOST / EMAIL_FROM not configured", { subject: mail.subject });
    return "skipped";
  }
  try {
    await t.mailer.sendMail({ from: t.from, ...mail });
    return "sent";
  } catch (error) {
    console.error("email failed", { subject: mail.subject, error: (error as Error).message });
    return "failed";
  }
}

export function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}
