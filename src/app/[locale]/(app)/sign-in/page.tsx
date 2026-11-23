import { Suspense } from "react";
import { getTranslations } from "next-intl/server";
import { LinkError } from "@/components/auth/LinkError";
import { SignInForm } from "@/components/auth/SignInForm";
import { Link } from "@/i18n/navigation";

export default async function SignInPage({ searchParams }: PageProps<"/[locale]/sign-in">) {
  const t = await getTranslations("SignIn");
  return (
    <div className="flex flex-col gap-8">
      <header className="flex max-w-xl flex-col gap-3">
        <h1 className="section-title">{t("title")}</h1>
        <p className="text-secondary">{t("intro")}</p>
      </header>
      <Suspense fallback={null}>
        <LinkError searchParams={searchParams} />
      </Suspense>
      <SignInForm kind="university" />
      <Link href="/sign-in/organisation" className="text-sm underline underline-offset-4">
        {t("toOrganisation")}
      </Link>
    </div>
  );
}
