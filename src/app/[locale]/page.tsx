import { getTranslations } from "next-intl/server";
import { FacultyLogo } from "@/components/FacultyLogo";
import { LocaleSwitcher } from "@/components/LocaleSwitcher";
import { PoweredBy } from "@/components/PoweredBy";

export default async function Home() {
  const t = await getTranslations("Home");

  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col justify-between px-4 py-8 sm:px-8">
      <header className="flex items-center justify-between">
        <FacultyLogo height={28} />
        <LocaleSwitcher />
      </header>

      <section className="flex flex-col gap-4">
        <h1 className="text-[56px] font-semibold leading-none tracking-[-0.03em]">{t("name")}</h1>
        <p className="text-lg text-secondary">{t("tagline")}</p>
        <p className="small-label" data-testid="build-status">
          {t("status")}
        </p>
      </section>

      <footer>
        <PoweredBy size="welcome" />
      </footer>
    </main>
  );
}
