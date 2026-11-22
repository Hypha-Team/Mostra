import { expect } from "@playwright/test";

const MAIL_URL = process.env.MAILPIT_URL ?? "http://127.0.0.1:54324";

function decodeHtml(s: string) {
  return s.replace(/&amp;/g, "&").replace(/&#x3D;/g, "=").replace(/&#61;/g, "=").replace(/&quot;/g, '"');
}

async function bodiesFor(email: string): Promise<string[]> {
  // Mailpit
  const search = await fetch(`${MAIL_URL}/api/v1/search?query=${encodeURIComponent(`to:"${email}"`)}`);
  if (search.ok) {
    const { messages = [] } = (await search.json()) as { messages?: { ID: string }[] };
    const out: string[] = [];
    for (const m of messages) {
      const res = await fetch(`${MAIL_URL}/api/v1/message/${m.ID}`);
      const msg = (await res.json()) as { HTML?: string; Text?: string };
      out.push(msg.HTML || msg.Text || "");
    }
    return out;
  }
  // Inbucket (older CLI)
  const mailbox = email.split("@")[0];
  const list = await fetch(`${MAIL_URL}/api/v1/mailbox/${encodeURIComponent(mailbox)}`);
  if (!list.ok) return [];
  const items = (await list.json()) as { id: string }[];
  const out: string[] = [];
  for (const it of items.reverse()) {
    const res = await fetch(`${MAIL_URL}/api/v1/mailbox/${encodeURIComponent(mailbox)}/${it.id}`);
    const msg = (await res.json()) as { body?: { html?: string; text?: string } };
    out.push(msg.body?.html || msg.body?.text || "");
  }
  return out;
}

/** Waits for the newest sign-in email to `email` and returns its link. */
export async function magicLinkFor(email: string): Promise<string> {
  let link: string | undefined;
  await expect
    .poll(
      async () => {
        const [latest] = await bodiesFor(email);
        const match = latest?.match(/href="([^"]*\/auth\/v1\/verify[^"]*)"/);
        link = match ? decodeHtml(match[1]) : undefined;
        return link;
      },
      { timeout: 20_000, message: `no sign-in email for ${email}` },
    )
    .toBeTruthy();
  return link!;
}

export async function mailCount(email: string): Promise<number> {
  return (await bodiesFor(email)).length;
}
