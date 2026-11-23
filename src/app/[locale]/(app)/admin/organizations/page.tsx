import { Suspense } from "react";
import { notFound } from "next/navigation";
import { getFormatter, getLocale, getTranslations } from "next-intl/server";
import { redirect } from "@/i18n/navigation";
import { PendingOrganisation } from "@/components/admin/PendingOrganisation";
import { getCurrentUser, isAdmin } from "@/lib/auth/current-user";
import { createClient } from "@/lib/supabase/server";

type Row = {
  id: string;
  name: string;
  kind: "gallery" | "studio" | "company" | "institution" | "association";
  website: string | null;
  nif: string | null;
  status: "pending" | "approved" | "rejected";
  created_at: string;
  approved_at: string | null;
  is_demo: boolean;
};

export default async function AdminOrganisationsPage() {
  const t = await getTranslations("Admin");
  return (
    <div className="flex flex-col gap-8">
      <h1 className="section-title">{t("title")}</h1>
      <Suspense fallback={null}>
        <AdminList />
      </Suspense>
    </div>
  );
}

async function AdminList() {
  const t = await getTranslations("Admin");
  const format = await getFormatter();
  const locale = await getLocale();
  const user = await getCurrentUser();
  if (!user) redirect({ href: "/sign-in", locale });
  if (!isAdmin(user)) notFound();

  const supabase = await createClient();
  const { data } = await supabase
    .from("organizations")
    .select("id, name, kind, website, nif, status, created_at, approved_at, is_demo")
    .order("created_at", { ascending: true })
    .returns<Row[]>();
  const rows = data ?? [];
  const pending = rows.filter((r) => r.status === "pending");
  const decided = rows
    .filter((r) => r.status !== "pending")
    .sort((a, b) => (b.approved_at ?? "").localeCompare(a.approved_at ?? ""))
    .slice(0, 20);

  return (
    <div className="flex flex-col gap-10">
      <section aria-labelledby="pending-heading" className="flex flex-col gap-4">
        <h2 id="pending-heading" className="small-label">
          {t("pending")}
        </h2>
        {pending.length === 0 && <p className="text-label">{t("empty")}</p>}
        <ul className="flex flex-col gap-3">
          {pending.map((o) => (
            <PendingOrganisation
              key={o.id}
              org={{
                id: o.id,
                name: o.name,
                kind: o.kind,
                website: o.website,
                nif: o.nif,
                is_demo: o.is_demo,
                requestedOn: format.dateTime(new Date(o.created_at), { dateStyle: "medium" }),
              }}
            />
          ))}
        </ul>
      </section>

      {decided.length > 0 && (
        <section aria-labelledby="decided-heading" className="flex flex-col gap-4">
          <h2 id="decided-heading" className="small-label">
            {t("decided")}
          </h2>
          <ul className="flex flex-col divide-y divide-line">
            {decided.map((o) => (
              <li key={o.id} className="flex items-center justify-between py-3 text-sm" data-testid="decided-organisation">
                <span>{o.name}</span>
                <span className={o.status === "approved" ? "text-pay-paid-fg" : "text-label"}>
                  {t(`status.${o.status}`)}
                </span>
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}
