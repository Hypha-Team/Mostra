"use client";

import { useFormStatus } from "react-dom";

/**
 * Submit button with a loading state (CLAUDE.md › UX rules): disabled while its form is
 * submitting, with a "…ing" label. With several buttons in one form (name/value), only the
 * one that was pressed shows the pending label.
 */
export function SubmitButton({
  children,
  pendingLabel,
  className = "btn btn-secondary",
  name,
  value,
  testId,
}: {
  children: React.ReactNode;
  pendingLabel: React.ReactNode;
  className?: string;
  name?: string;
  value?: string;
  testId?: string;
}) {
  const { pending, data } = useFormStatus();
  const mine = pending && (!name || data?.get(name) === value);
  return (
    <button
      type="submit"
      name={name}
      value={value}
      disabled={pending}
      aria-busy={mine || undefined}
      data-testid={testId}
      className={className}
    >
      {mine ? pendingLabel : children}
    </button>
  );
}
