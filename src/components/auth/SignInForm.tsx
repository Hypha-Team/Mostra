"use client";

import { useActionState, useId } from "react";
import { useLocale, useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import {
  requestPartnerLink,
  requestUniversityLink,
  type LinkState,
} from "@/lib/auth/actions";

export function SignInForm({ kind }: { kind: "university" | "partner" }) {
  const t = useTranslations("SignIn");
  const locale = useLocale();
  const [state, action, pending] = useActionState<LinkState, FormData>(
    kind === "university" ? requestUniversityLink : requestPartnerLink,
    { status: "idle" },
  );
  const emailId = useId();
  const nameId = useId();
  const consentId = useId();
  const errorId = useId();

  if (state.status === "sent") {
    return (
      <div role="status" className="flex flex-col gap-3" data-testid="link-sent">
        <h2 className="section-title">{t("sentTitle")}</h2>
        <p className="text-secondary">{t("sentBody", { email: state.email })}</p>
      </div>
    );
  }

  const error = state.status === "error" ? state.error : null;

  return (
    <form action={action} className="flex max-w-md flex-col gap-5" noValidate>
      <input type="hidden" name="locale" value={locale} />
      {kind === "partner" && (
        <div className="flex flex-col gap-2">
          <label htmlFor={nameId} className="small-label">
            {t("nameLabel")}
          </label>
          <input
            id={nameId}
            name="full_name"
            autoComplete="name"
            defaultValue={state.status === "error" ? state.fullName : undefined}
            className="min-h-11 rounded-md border border-chip-border bg-white px-3"
          />
        </div>
      )}
      <div className="flex flex-col gap-2">
        <label htmlFor={emailId} className="small-label">
          {t("emailLabel")}
        </label>
        <input
          id={emailId}
          name="email"
          type="email"
          autoComplete="email"
          required
          defaultValue={state.status === "error" ? state.email : undefined}
          aria-invalid={error === "invalidEmail" || error === "notUniversity" || undefined}
          aria-describedby={error ? errorId : undefined}
          className="min-h-11 rounded-md border border-chip-border bg-white px-3"
        />
      </div>
      <div className="flex items-start gap-3">
        <input
          id={consentId}
          name="consent"
          type="checkbox"
          required
          defaultChecked={state.status === "error" ? state.consent : undefined}
          aria-invalid={error === "consent" || undefined}
          className="mt-1 size-5 accent-ink"
        />
        <label htmlFor={consentId} className="text-sm text-secondary">
          {t.rich("consent", {
            link: (chunks) => (
              <Link href="/privacy" className="underline underline-offset-2">
                {chunks}
              </Link>
            ),
          })}
        </label>
      </div>
      {error && (
        <p id={errorId} role="alert" className="text-sm text-pay-fee-fg" data-testid="form-error">
          {t(`errors.${error}`)}
        </p>
      )}
      <button type="submit" className="btn btn-primary self-start" disabled={pending}>
        {pending ? t("sending") : t("submit")}
      </button>
    </form>
  );
}
