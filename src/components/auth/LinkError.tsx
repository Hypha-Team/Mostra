import { getTranslations } from "next-intl/server";

export async function LinkError({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { error } = await searchParams;
  if (error !== "link") return null;
  const t = await getTranslations("SignIn");
  return (
    <p role="alert" data-testid="link-error" className="max-w-md rounded-md bg-pay-fee-bg px-4 py-3 text-sm text-pay-fee-fg">
      {t("errors.link")}
    </p>
  );
}
