"use client";

import { useLocale, useTranslations } from "next-intl";
import { Link, usePathname } from "@/i18n/navigation";
import { routing } from "@/i18n/routing";

export function LocaleSwitcher() {
  const t = useTranslations("LocaleSwitcher");
  const current = useLocale();
  const pathname = usePathname();

  return (
    <nav aria-label={t("label")} className="flex items-center gap-3 text-sm">
      {routing.locales.map((locale) => {
        const active = locale === current;
        return (
          <Link
            key={locale}
            href={pathname}
            locale={locale}
            hrefLang={locale}
            lang={locale}
            aria-current={active ? "true" : undefined}
            className={
              active
                ? "font-semibold underline underline-offset-4"
                : "text-label hover:text-ink"
            }
          >
            {t(locale)}
          </Link>
        );
      })}
    </nav>
  );
}
