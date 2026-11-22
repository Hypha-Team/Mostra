import { Suspense } from "react";
import { getLocale, getTranslations } from "next-intl/server";
import { Link, redirect } from "@/i18n/navigation";
import { signOut } from "@/lib/auth/actions";
import { getCurrentUser, isAdmin } from "@/lib/auth/current-user";

export default async function AccountPage() {
  const t = await getTranslations("Account");
  return (
    <div className="flex flex-col gap-8">
      <h1 className="section-title">{t("title")}</h1>
      <Suspense fallback={<p className="text-label">{t("loading")}</p>}>
        <AccountDetails />
      </Suspense>
    </div>
  );
}

async function AccountDetails() {
  const t = await getTranslations("Account");
  const locale = await getLocale();
  const user = await getCurrentUser();
  if (!user) redirect({ href: "/sign-in", locale });
  const u = user!;
  const roles = u.profile?.roles ?? [];
  const isPartner = roles.includes("partner");

  return (
    <div className="flex flex-col gap-10" data-testid="account">
      <dl className="grid max-w-xl grid-cols-[auto_1fr] gap-x-6 gap-y-3">
        <dt className="small-label self-center">{t("email")}</dt>
        <dd data-testid="account-email">{u.email}</dd>

        <dt className="small-label self-center">{t("roles")}</dt>
        <dd className="flex flex-wrap items-center gap-2" data-testid="account-roles">
          {roles.length === 0 && <span className="text-label">{t("noRoles")}</span>}
          {roles.map((r) => (
            <span key={r} className="chip bg-chip" data-role={r}>
              {t(`roleNames.${r}`)}
            </span>
          ))}
          {u.profile?.verified ? (
            <span className="chip border border-chip-border text-verified" data-testid="verified">
              {t("verified")}
            </span>
          ) : (
            <span className="chip border border-chip-border text-label">{t("notVerified")}</span>
          )}
          {u.profile?.is_demo && <span className="chip bg-chip">{t("demo")}</span>}
        </dd>

        {u.universityName && (
          <>
            <dt className="small-label self-center">{t("university")}</dt>
            <dd>{u.universityName}</dd>
          </>
        )}
      </dl>

      {(isPartner || u.organizations.length > 0) && (
        <section aria-labelledby="org-heading" className="flex max-w-xl flex-col gap-3">
          <h2 id="org-heading" className="small-label">
            {t("organisation")}
          </h2>
          {u.organizations.length === 0 ? (
            <div className="flex flex-col items-start gap-3">
              <p className="text-secondary">{t("noOrganisation")}</p>
              <Link href="/account/organisation" className="btn btn-secondary">
                {t("registerOrganisation")}
              </Link>
            </div>
          ) : (
            <ul className="flex flex-col gap-3">
              {u.organizations.map((o) => (
                <li key={o.id} className="flex flex-col gap-1 rounded-md bg-panel px-4 py-3" data-testid="organisation">
                  <span className="font-medium">{o.name}</span>
                  <span className="text-sm" data-testid="organisation-status" data-status={o.status}>
                    {t(`status.${o.status}`)}
                  </span>
                  {o.status === "pending" && <span className="text-sm text-label">{t("pendingHelp")}</span>}
                </li>
              ))}
            </ul>
          )}
        </section>
      )}

      <div className="flex flex-wrap items-center gap-4">
        {isAdmin(u) && (
          <Link href="/admin/organizations" className="btn btn-secondary">
            {t("adminLink")}
          </Link>
        )}
        <form action={signOut}>
          <input type="hidden" name="locale" value={locale} />
          <button type="submit" className="btn btn-tertiary">
            {t("signOut")}
          </button>
        </form>
      </div>
    </div>
  );
}
