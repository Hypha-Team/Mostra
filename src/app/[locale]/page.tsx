import { getTranslations } from "next-intl/server";
import { FacultyLogo } from "@/components/FacultyLogo";
import { LocaleSwitcher } from "@/components/LocaleSwitcher";
import { PoweredBy } from "@/components/PoweredBy";
import { Link } from "@/i18n/navigation";

/** Screen 1 — Welcome / sign in. */
export default async function Welcome() {
  const t = await getTranslations("Welcome");
  const tHome = await getTranslations("Home");

  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col justify-between px-4 py-8 sm:px-8">
      <header className="flex items-center justify-between">
        <FacultyLogo height={28} />
        <LocaleSwitcher />
      </header>

      <section className="flex flex-col gap-8">
        <div className="flex flex-col gap-4">
          <h1 className="text-[56px] font-semibold leading-none tracking-[-0.03em]">{tHome("name")}</h1>
          <p className="text-lg text-secondary">{t("line")}</p>
        </div>
        <div className="flex flex-col items-stretch gap-3 sm:items-start">
          <Link href="/sign-in" className="btn btn-primary" data-testid="enter-university">
            {t("enterUniversity")}
          </Link>
          <Link href="/sign-in/organisation" className="btn btn-tertiary" data-testid="enter-organisation">
            {t("imOrganisation")}
          </Link>
        </div>
      </section>

      <footer>
        <PoweredBy size="welcome" />
      </footer>
    </main>
  );
}
