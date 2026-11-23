import { getTranslations } from "next-intl/server";

export default async function PrivacyPage() {
  const t = await getTranslations("Privacy");
  return (
    <article className="flex max-w-2xl flex-col gap-5">
      <h1 className="section-title">{t("title")}</h1>
      <p className="small-label">{t("draft")}</p>
      <p className="text-secondary">{t("p1")}</p>
      <p className="text-secondary">{t("p2")}</p>
      <p className="text-secondary">{t("p3")}</p>
    </article>
  );
}
