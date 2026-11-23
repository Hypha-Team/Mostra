export type UserRole = "student" | "alumni" | "professor" | "partner" | "admin";
export type OrganizationStatus = "pending" | "approved" | "rejected";
export type OrganizationKind = "gallery" | "studio" | "company" | "institution" | "association";

export const ORGANIZATION_KINDS: OrganizationKind[] = [
  "gallery",
  "studio",
  "company",
  "institution",
  "association",
];

export type Profile = {
  id: string;
  full_name: string | null;
  roles: UserRole[];
  verified: boolean;
  university_id: string | null;
  is_demo: boolean;
};

export type Organization = {
  id: string;
  name: string;
  kind: OrganizationKind;
  website: string | null;
  nif: string | null;
  status: OrganizationStatus;
  created_at: string;
  approved_at: string | null;
};

export type CurrentUser = {
  id: string;
  email: string | null;
  profile: Profile | null;
  organizations: Organization[];
  universityName: string | null;
};
