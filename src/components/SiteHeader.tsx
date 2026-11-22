import { Suspense } from "react";
import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { getCurrentUser, isAdmin } from "@/lib/auth/current-user";
import { FacultyLogo } from "./FacultyLogo";
import { LocaleSwitcher } from "./LocaleSwitcher";
import { PoweredBy } from "./PoweredBy";

export async function SiteHeader() {
  const t = await getTranslations("Header");
  const tHome = await getTranslations("Home");
  return (
    <header className="border-b border-line">
      <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-x-6 gap-y-3 px-4 py-4 sm:px-8">
        <Link href="/" className="flex items-center gap-3" aria-label={t("home")}>
          <FacultyLogo height={24} />
          <span aria-hidden className="h-6 w-px bg-line" />
          <span className="flex flex-col leading-none">
            <span className="text-lg font-semibold tracking-[-0.02em]">{tHome("name")}</span>
            <PoweredBy />
          </span>
        </Link>
        <div className="flex items-center gap-5">
          <Suspense fallback={null}>
            <AuthNav />
          </Suspense>
          <LocaleSwitcher />
        </div>
      </div>
    </header>
  );
}

async function AuthNav() {
  const t = await getTranslations("Header");
  const user = await getCurrentUser();
  return (
    <nav className="flex items-center gap-4 text-sm lowercase">
      {isAdmin(user) && (
        <Link href="/admin/organizations" className="hover:underline underline-offset-4">
          {t("admin")}
        </Link>
      )}
      {user ? (
        <Link href="/account" className="hover:underline underline-offset-4">
          {t("account")}
        </Link>
      ) : (
        <Link href="/sign-in" className="hover:underline underline-offset-4">
          {t("signIn")}
        </Link>
      )}
    </nav>
  );
}
