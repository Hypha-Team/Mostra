import Image from "next/image";
import { getTranslations } from "next-intl/server";

/** "powered by HYPHA" mark. Ink logo only — never red, never next to the magenta button. */
export async function PoweredBy({ size = "header" }: { size?: "header" | "welcome" }) {
  const t = await getTranslations("Brand");
  const height = size === "welcome" ? 16 : 10;
  // Source PNG is 800 × 199
  const width = Math.round((height * 800) / 199);

  return (
    <span className="inline-flex items-center gap-1.5 text-label" style={{ fontSize: height }}>
      <span>{t("poweredBy")}</span>
      <Image
        src="/brand/hypha-logo-ink.png"
        alt={t("hyphaLogoAlt")}
        width={width}
        height={height}
        style={{ height, width: "auto" }}
      />
    </span>
  );
}
