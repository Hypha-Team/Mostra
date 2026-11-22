import { defineRouting } from "next-intl/routing";

export const routing = defineRouting({
  locales: ["pt", "en"],
  defaultLocale: "pt",
  // pt lives at "/", en at "/en"
  localePrefix: "as-needed",
  // "/" is always Portuguese, whatever the browser language; switching is explicit.
  localeDetection: false,
});

export type AppLocale = (typeof routing.locales)[number];
