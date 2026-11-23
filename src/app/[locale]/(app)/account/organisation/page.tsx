import { Suspense } from "react";
import { getLocale, getTranslations } from "next-intl/server";
import { OrganisationForm } from "@/components/auth/OrganisationForm";
import { redirect } from "@/i18n/navigation";
import { getCurrentUser } from "@/lib/auth/current-user";

export default async function RegisterOrganisationPage() {
  const t = await getTranslations("OrganisationForm");
  return (
    <div className="flex flex-col gap-8">
      <header className="flex max-w-xl flex-col gap-3">
        <h1 className="section-title">{t("title")}</h1>
        <p className="text-secondary">{t("intro")}</p>
      </header>
      <Suspense fallback={null}>
        <Guard />
      </Suspense>
    </div>
  );
}

async function Guard() {
  const locale = await getLocale();
  const user = await getCurrentUser();
  if (!user) redirect({ href: "/sign-in/organisation", locale });
  if (user!.organizations.length > 0) redirect({ href: "/account", locale });
  return <OrganisationForm />;
}
