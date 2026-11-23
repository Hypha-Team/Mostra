"use client";

import { useActionState } from "react";
import { useTranslations } from "next-intl";
import { SubmitButton } from "@/components/SubmitButton";
import { reviewOrganisation, type ReviewState } from "@/lib/auth/actions";

export type PendingOrganisationRow = {
  id: string;
  name: string;
  kind: "gallery" | "studio" | "company" | "institution" | "association";
  website: string | null;
  nif: string | null;
  is_demo: boolean;
  requestedOn: string;
};

/** One pending organisation with approve / reject. The page refreshes itself after the decision. */
export function PendingOrganisation({ org }: { org: PendingOrganisationRow }) {
  const t = useTranslations("Admin");
  const [state, action] = useActionState<ReviewState, FormData>(reviewOrganisation, { status: "idle" });

  return (
    <li
      className="flex flex-col gap-3 rounded-md border border-line bg-white px-4 py-4 sm:flex-row sm:items-center sm:justify-between"
      data-testid="pending-organisation"
    >
      <div className="flex flex-col gap-1">
        <span className="font-medium">
          {org.name} {org.is_demo && <span className="chip ml-2 bg-chip">{t("demo")}</span>}
        </span>
        <span className="text-sm text-secondary">
          {t(`kinds.${org.kind}`)}
          {org.website && <> · {org.website}</>}
          {org.nif && (
            <>
              {" "}
              · {t("nif")} {org.nif}
            </>
          )}
        </span>
        <span className="text-xs text-label">{t("requested", { date: org.requestedOn })}</span>
        {state.status === "error" && (
          <span role="alert" className="text-sm text-pay-fee-fg">
            {t("failed")}
          </span>
        )}
      </div>
      <form action={action} className="flex gap-2">
        <input type="hidden" name="id" value={org.id} />
        <SubmitButton name="decision" value="approved" pendingLabel={t("approving")} className="btn btn-secondary">
          {t("approve")}
        </SubmitButton>
        <SubmitButton name="decision" value="rejected" pendingLabel={t("rejecting")} className="btn btn-tertiary">
          {t("reject")}
        </SubmitButton>
      </form>
    </li>
  );
}
