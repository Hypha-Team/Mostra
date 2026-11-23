"use client";

import { useActionState, useId } from "react";
import { useLocale, useTranslations } from "next-intl";
import { registerOrganisation, type OrganisationState } from "@/lib/auth/actions";
import { ORGANIZATION_KINDS } from "@/lib/auth/types";

export function OrganisationForm() {
  const t = useTranslations("OrganisationForm");
  const locale = useLocale();
  const [state, action, pending] = useActionState<OrganisationState, FormData>(
    registerOrganisation,
    { status: "idle" },
  );
  const ids = { name: useId(), kind: useId(), website: useId(), nif: useId(), error: useId() };
  const error = state.status === "error" ? state.error : null;
  const values = state.status === "error" ? state.values : undefined;
  const field = "min-h-11 rounded-md border border-chip-border bg-white px-3";

  return (
    <form action={action} className="flex max-w-md flex-col gap-5" noValidate>
      <input type="hidden" name="locale" value={locale} />
      <div className="flex flex-col gap-2">
        <label htmlFor={ids.name} className="small-label">
          {t("name")}
        </label>
        <input id={ids.name} name="name" required defaultValue={values?.name} className={field} aria-invalid={error === "name" || undefined} />
      </div>
      <div className="flex flex-col gap-2">
        <label htmlFor={ids.kind} className="small-label">
          {t("kind")}
        </label>
        <select key={values?.kind ?? ""} id={ids.kind} name="kind" required defaultValue={values?.kind ?? ""} className={field} aria-invalid={error === "kind" || undefined}>
          <option value="" disabled />
          {ORGANIZATION_KINDS.map((k) => (
            <option key={k} value={k}>
              {t(`kinds.${k}`)}
            </option>
          ))}
        </select>
      </div>
      <div className="flex flex-col gap-2">
        <label htmlFor={ids.website} className="small-label">
          {t("website")}
        </label>
        <input id={ids.website} name="website" type="url" inputMode="url" placeholder="https://" defaultValue={values?.website} className={field} aria-invalid={error === "website" || undefined} />
      </div>
      <div className="flex flex-col gap-2">
        <label htmlFor={ids.nif} className="small-label">
          {t("nif")}
        </label>
        <input id={ids.nif} name="nif" inputMode="numeric" defaultValue={values?.nif} className={field} />
      </div>
      {error && (
        <p id={ids.error} role="alert" className="text-sm text-pay-fee-fg" data-testid="form-error">
          {t(`errors.${error}`)}
        </p>
      )}
      <button type="submit" className="btn btn-primary self-start" disabled={pending} aria-busy={pending || undefined}>
        {pending ? t("sending") : t("submit")}
      </button>
    </form>
  );
}
