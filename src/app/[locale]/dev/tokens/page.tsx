import { notFound } from "next/navigation";
import { getTranslations } from "next-intl/server";
import { LocaleSwitcher } from "@/components/LocaleSwitcher";
import { PoweredBy } from "@/components/PoweredBy";

// Token names and hex values are identifiers, not UI copy.
const COLORS = [
  ["ground", "#FAFAF8", "bg-ground"],
  ["ink", "#111111", "bg-ink"],
  ["label", "#5F5F5F", "bg-label"],
  ["secondary", "#3A3A3A", "bg-secondary"],
  ["line", "#E6E5E0", "bg-line"],
  ["chip-border", "#DAD9D4", "bg-chip-border"],
  ["panel", "#F1F0EB", "bg-panel"],
  ["chip", "#ECEBE6", "bg-chip"],
  ["magenta", "#D42B87", "bg-magenta"],
  ["verified", "#1F5FA8", "bg-verified"],
] as const;

const WEIGHTS = [
  ["font-normal", "Aa 400"],
  ["font-medium", "Aa 500"],
  ["font-semibold", "Aa 600"],
] as const;

/** Internal page to eyeball the design tokens on previews. Not available in production. */
export default async function TokensPage() {
  if (process.env.VERCEL_ENV === "production") notFound();
  const t = await getTranslations("Tokens");

  return (
    <main className="mx-auto flex max-w-5xl flex-col gap-12 px-4 py-10 sm:px-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <h1 className="section-title">{t("title")}</h1>
        <LocaleSwitcher />
      </header>

      <section aria-labelledby="colors" className="flex flex-col gap-4">
        <h2 id="colors" className="small-label">
          {t("colors")}
        </h2>
        <ul className="grid grid-cols-2 gap-4 sm:grid-cols-5">
          {COLORS.map(([name, hex, cls]) => (
            <li key={name} className="flex flex-col gap-2" data-token={name}>
              <span className={`${cls} block h-16 rounded-card border border-line`} />
              <span className="text-sm font-medium">{name}</span>
              <span className="font-mono text-xs text-label">{hex}</span>
            </li>
          ))}
        </ul>
      </section>

      <section aria-labelledby="type" className="flex flex-col gap-4">
        <h2 id="type" className="small-label">
          {t("type")}
        </h2>
        <p className="section-title" data-testid="section-title-sample">
          {t("sectionTitle")}
        </p>
        <p className="small-label">{t("smallLabel")}</p>
        <p className="work-title text-3xl">{t("workTitle")}</p>
        <p className="mono-label">{t("monoLabel")}</p>
        {WEIGHTS.map(([cls, sample]) => (
          <p key={sample} className={`text-base ${cls}`}>
            {sample}
          </p>
        ))}
      </section>

      <section aria-labelledby="buttons" className="flex flex-col gap-4">
        <h2 id="buttons" className="small-label">
          {t("buttons")}
        </h2>
        <div className="flex flex-wrap gap-3">
          <button type="button" className="btn btn-primary" data-testid="btn-primary">
            {t("primary")}
          </button>
          <button type="button" className="btn btn-secondary">
            {t("secondary")}
          </button>
          <button type="button" className="btn btn-tertiary">
            {t("tertiary")}
          </button>
        </div>
      </section>

      <section aria-labelledby="tags" className="flex flex-col gap-4">
        <h2 id="tags" className="small-label">
          {t("tags")}
        </h2>
        <div className="flex flex-wrap gap-2">
          <span className="chip bg-pay-paid-bg text-pay-paid-fg">{t("paid")}</span>
          <span className="chip bg-pay-fee-bg text-pay-fee-fg">{t("entryFee")}</span>
          <span className="chip bg-pay-free-bg text-pay-free-fg">{t("unpaid")}</span>
          <span className="chip bg-pay-free-bg text-pay-free-fg">{t("free")}</span>
          <span className="chip bg-wanted-bg text-wanted-fg">{t("wanted")}</span>
          <span className="chip border border-chip-border bg-chip text-verified">
            {t("verified")}
          </span>
        </div>
      </section>

      <footer>
        <PoweredBy />
      </footer>
    </main>
  );
}
