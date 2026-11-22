import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";

export default function NotFound() {
  const t = useTranslations("NotFound");
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col justify-center gap-6 px-4">
      <h1 className="section-title">{t("title")}</h1>
      <Link href="/" className="btn btn-tertiary self-start">
        {t("back")}
      </Link>
    </main>
  );
}
