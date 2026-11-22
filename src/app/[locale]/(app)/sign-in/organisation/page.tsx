import { Suspense } from "react";
import { getTranslations } from "next-intl/server";
import { LinkError } from "@/components/auth/LinkError";
import { SignInForm } from "@/components/auth/SignInForm";
import { Link } from "@/i18n/navigation";

export default async function OrganisationSignInPage({
  searchParams,
}: PageProps<"/[locale]/sign-in/organisation">) {
  const t = await getTranslations("SignIn");
  return (
    <div className="flex flex-col gap-8">
      <header className="flex max-w-xl flex-col gap-3">
        <h1 className="section-title">{t("orgTitle")}</h1>
        <p className="text-secondary">{t("orgIntro")}</p>
      </header>
      <Suspense fallback={null}>
        <LinkError searchParams={searchParams} />
      </Suspense>
      <SignInForm kind="partner" />
      <Link href="/sign-in" className="text-sm underline underline-offset-4">
        {t("toUniversity")}
      </Link>
    </div>
  );
}
