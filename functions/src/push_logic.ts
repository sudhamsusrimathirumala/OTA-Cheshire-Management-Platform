export type ContentType = "announcement" | "event" | "resource";

export interface AccountRecord {
  id: string;
  role: string;
  isActive: boolean;
  locationId: string;
  linkedStudentProfileIds: string[];
}

export interface ProfileRecord {
  id: string;
  isActive: boolean;
  locationId: string;
  beltRank?: string;
  preferredClassGroupIds?: string[];
}

export interface DispatchState {
  status?: string;
  leaseUntilMillis?: number;
}

export function isFirstPublication(
  type: ContentType,
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined,
): boolean {
  if (!after || typeof after.locationId !== "string" || !after.locationId) {
    return false;
  }
  if (type === "announcement") {
    return after.status === "published" && before?.status !== "published" &&
      nonempty(after.title) && nonempty(after.summary);
  }
  if (type === "event") {
    return after.isPublished === true && after.isArchived !== true &&
      before?.isPublished !== true && nonempty(after.title);
  }
  return after.isPublished === true && after.isArchived !== true &&
    before?.isPublished !== true && after.resourceSection === "general" &&
    nonempty(after.title);
}

export function eligibleAccountIds(
  type: ContentType,
  content: Record<string, unknown>,
  accounts: AccountRecord[],
  profiles: ProfileRecord[],
): string[] {
  const locationId = String(content.locationId ?? "");
  const profilesById = new Map(profiles.map((profile) => [profile.id, profile]));
  const result = new Set<string>();
  for (const account of accounts) {
    if (!account.isActive || !["parent", "student"].includes(account.role) ||
        account.locationId !== locationId) continue;
    const linked = account.linkedStudentProfileIds
      .map((id) => profilesById.get(id))
      .filter((profile): profile is ProfileRecord =>
        profile !== undefined && profile.isActive && profile.locationId === locationId);
    if (linked.length === 0) continue;
    if (type !== "announcement" || announcementMatches(content, account, linked)) {
      result.add(account.id);
    }
  }
  return [...result].sort();
}

function announcementMatches(
  content: Record<string, unknown>,
  account: AccountRecord,
  profiles: ProfileRecord[],
): boolean {
  const direct = strings(content.targetUserIds).includes(account.id);
  if (direct) return true;
  const audience = content.audienceType;
  if (audience === "everyone") return true;
  if (audience === "belt") {
    const belts = new Set(strings(content.targetBelts));
    return profiles.some((profile) => profile.beltRank && belts.has(profile.beltRank));
  }
  if (audience === "classType") {
    const groups = new Set(strings(content.targetClassTypeIds).flatMap(compatibleClassGroups));
    return profiles.some((profile) =>
      (profile.preferredClassGroupIds ?? []).flatMap(compatibleClassGroups)
        .some((group) => groups.has(group)));
  }
  if (audience === "students") {
    const selected = new Set(strings(content.targetStudentProfileIds));
    return profiles.some((profile) => selected.has(profile.id));
  }
  if (audience === "parents") return account.role === "parent";
  if (audience === "specificUsers") return direct;
  if (audience === "mixed") {
    return announcementMatches({...content, audienceType: "belt"}, account, profiles) ||
      announcementMatches({...content, audienceType: "classType"}, account, profiles) ||
      announcementMatches({...content, audienceType: "students"}, account, profiles);
  }
  return false;
}

export function compatibleClassGroups(value: string): string[] {
  switch (value) {
    case "little-tigers": return ["little-tiger-standard"];
    case "level-1": return ["level-1-standard"];
    case "level-2": return ["level-2-standard"];
    case "level-3": return ["level-3-standard"];
    case "level-4": return ["level-4-standard"];
    case "teen-adult-sparring": return ["teen-adult-sparring-standard"];
    case "sparring-class":
    case "level-1-2-sparring": return ["level-1-2-sparring-standard"];
    case "teen-adult": return [
      "black-belt-standard", "teen-black-belt-standard", "adult-standard",
    ];
    default: return [value];
  }
}

export function chunkTargets(targets: string[], size = 500): string[][] {
  const unique = [...new Set(targets)];
  const chunks: string[][] = [];
  for (let index = 0; index < unique.length; index += size) {
    chunks.push(unique.slice(index, index + size));
  }
  return chunks;
}

export function canClaimDispatch(
  existing: DispatchState | undefined,
  nowMillis: number,
): boolean {
  if (!existing) return true;
  if (existing.status === "completed") return false;
  return existing.status !== "processing" ||
    (existing.leaseUntilMillis ?? 0) <= nowMillis;
}

export function isPermanentMessagingError(code: string): boolean {
  return [
    "messaging/invalid-registration-token",
    "messaging/registration-token-not-registered",
    "messaging/invalid-argument",
  ].includes(code);
}

export function notificationPayload(
  type: ContentType,
  id: string,
  content: Record<string, unknown>,
): {title: string; body: string; data: Record<string, string>; important: boolean} {
  const title = trim(String(content.title ?? "Academy update"), 90);
  const fallback = type === "event" ? "New academy event posted" :
    type === "resource" ? "New academy resource available" : "New academy announcement";
  const bodySource = type === "announcement" ? content.summary : content.description;
  return {
    title,
    body: trim(nonempty(bodySource) ? String(bodySource) : fallback, 180),
    data: {
      contentType: type,
      contentId: id,
      locationId: String(content.locationId),
    },
    important: type === "announcement" &&
      ["important", "critical"].includes(String(content.priority)),
  };
}

function strings(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

function nonempty(value: unknown): boolean {
  return typeof value === "string" && value.trim().length > 0;
}

function trim(value: string, max: number): string {
  const normalized = value.trim().replace(/\s+/g, " ");
  return normalized.length <= max ? normalized : `${normalized.slice(0, max - 1)}…`;
}
