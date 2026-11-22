import Image from "next/image";
import { getTranslations } from "next-intl/server";

export async function FacultyLogo({ height = 32 }: { height?: number }) {
  const t = await getTranslations("Brand");
  // Source PNG is 900 × 211
  const width = Math.round((height * 900) / 211);
  return (
    <Image
      src="/brand/fbaul-logo.png"
      alt={t("facultyLogoAlt")}
      width={width}
      height={height}
      style={{ height, width: "auto" }}
      priority
    />
  );
}
