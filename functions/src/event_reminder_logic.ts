import {createHash} from "node:crypto";

export interface ReminderSpec {
  id: string; eventId: string; occurrenceId: string; offsetMinutes: number;
  dueMillis: number; startMillis: number; locationId: string;
}
export interface StoredOccurrence {id: string; startMillis: number; endMillis: number; canceled: boolean}
export const reminderOffsets = [10080, 4320, 1440, 120, 60];
export function millis(value: unknown): number {
  if (typeof value === "number") return value;
  if (value && typeof value === "object" && "toMillis" in value) {
    return (value as {toMillis(): number}).toMillis();
  }
  return NaN;
}
export function reminderId(eventId: string, occurrenceId: string, offset: number): string {
  return createHash("sha256").update(JSON.stringify(["event-start-v1", eventId, occurrenceId, offset])).digest("hex");
}
export function eventOccurrences(event: Record<string, unknown>): StoredOccurrence[] {
  const schedule = event.eventSchedule as Record<string, unknown> | undefined;
  if (schedule !== undefined) {
    if (schedule?.version !== 1 || !Array.isArray(schedule.occurrences) ||
        schedule.occurrences.length === 0 || schedule.occurrences.length > 180 ||
        typeof schedule.firstOccurrenceId !== "string") return [];
    const items = schedule.occurrences as StoredOccurrence[];
    if (items.some((o) => typeof o?.id !== "string" || !/^[a-zA-Z0-9_-]{1,64}$/.test(o.id) ||
        !Number.isSafeInteger(o.startMillis) || !Number.isSafeInteger(o.endMillis) ||
        o.endMillis <= o.startMillis || typeof o.canceled !== "boolean") ||
        new Set(items.map((o) => o.id)).size !== items.length) return [];
    return items;
  }
  const startMillis = millis(event.startDateTime); const endMillis = millis(event.endDateTime);
  return Number.isFinite(startMillis) && endMillis > startMillis ?
    [{id: "once", startMillis, endMillis, canceled: false}] : [];
}
export function reminderSpecs(eventId: string, event: Record<string, unknown> | undefined): ReminderSpec[] {
  if (!event || event.isPublished !== true || event.isArchived === true || event.isCanceled === true ||
      event.eventType === "closure" || typeof event.locationId !== "string" || !event.locationId ||
      typeof event.title !== "string" || !event.title.trim()) return [];
  const config = event.reminders as {mode?: string; offsetsMinutes?: number[]} | undefined;
  if (!config || !["first", "every"].includes(config.mode ?? "") || !Array.isArray(config.offsetsMinutes) ||
      config.offsetsMinutes.length > 5 || config.offsetsMinutes.some((n) => !reminderOffsets.includes(n))) return [];
  const schedule = event.eventSchedule as {firstOccurrenceId?: string} | undefined;
  const first = schedule?.firstOccurrenceId ?? "once";
  return eventOccurrences(event).filter((o) => !o.canceled && (config.mode === "every" || o.id === first))
    .flatMap((o) => [...new Set(config.offsetsMinutes)].map((offsetMinutes) => ({
      id: reminderId(eventId, o.id, offsetMinutes), eventId, occurrenceId: o.id, offsetMinutes,
      startMillis: o.startMillis, dueMillis: o.startMillis - offsetMinutes * 60000,
      locationId: event.locationId as string,
    })));
}
export function currentReminder(spec: ReminderSpec, event: Record<string, unknown> | undefined): ReminderSpec | undefined {
  return reminderSpecs(spec.eventId, event).find((s) => s.id === spec.id);
}
export function reminderMessage(spec: ReminderSpec, event: Record<string, unknown>, location: Record<string, unknown>) {
  const zone = String(location.timeZoneId ?? "UTC");
  const when = new Intl.DateTimeFormat("en-US", {timeZone: zone, month: "short", day: "numeric",
    hour: "numeric", minute: "2-digit", timeZoneName: "short"}).format(new Date(spec.startMillis));
  const title = String(event.title).trim().replace(/\s+/g, " ").slice(0, 65);
  const academy = String(location.name ?? "Academy").trim().replace(/\s+/g, " ").slice(0, 40);
  return {title: `Reminder: ${title}`, body: `${title} • ${when} • ${academy}. Open OTA for details.`.slice(0, 180),
    important: false, expiresAtMillis: spec.startMillis,
    data: {contentType: "event", contentId: spec.eventId, locationId: spec.locationId,
      occurrenceId: spec.occurrenceId, reminderId: spec.id, reminderKind: "event-start", offsetMinutes: String(spec.offsetMinutes)}};
}
