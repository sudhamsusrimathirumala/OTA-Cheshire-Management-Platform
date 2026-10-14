import assert from "node:assert/strict";
import {before, beforeEach, after, test} from "node:test";
import {initializeApp, deleteApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {BatchResponse} from "firebase-admin/messaging";
import {EventReminderBackend} from "../src/event_reminders";
import {reminderSpecs} from "../src/event_reminder_logic";
import {PushPayload} from "../src/push_delivery";

const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
const app = enabled ? initializeApp({projectId: "demo-ota-reminders"}, "event-reminders-tests") : undefined;
const db = app ? getFirestore(app) : undefined;
let now = Date.UTC(2027, 0, 1, 12);
let calls: Array<{tokens: string[]; payload: PushPayload}> = [];
let failures = new Set<string>();
let duringSend: (() => Promise<void>) | undefined;
const send = async (tokens: string[], payload: PushPayload): Promise<BatchResponse> => {
  calls.push({tokens, payload});
  if (duringSend) { const action = duringSend; duringSend = undefined; await action(); }
  const responses = tokens.map((t) => failures.has(t) ? {success: false, error: {code: t === "invalid" ? "messaging/registration-token-not-registered" : "messaging/internal-error"} as never} : {success: true});
  return {responses, successCount: responses.filter((r) => r.success).length, failureCount: responses.filter((r) => !r.success).length};
};
const eventData = (extra = {}) => ({title: "Testing", description: "Details", locationId: "north",
  isPublished: true, isArchived: false, startDateTime: Timestamp.fromMillis(now + 3600000),
  endDateTime: Timestamp.fromMillis(now + 7200000), reminders: {mode: "first", offsetsMinutes: [60]}, ...extra});
const backend = () => new EventReminderBackend(db!, send, () => now);
async function seed(extra = {}) {
  await db!.collection("events").doc("series").set(eventData(extra));
  await backend().sync("series"); now += 1000;
}
before(() => { if (enabled && !process.env.FIRESTORE_EMULATOR_HOST?.startsWith("127.0.0.1") && !process.env.FIRESTORE_EMULATOR_HOST?.startsWith("localhost")) throw new Error("Tests require a local emulator"); });
beforeEach(async () => {
  if (!db) return;
  for (const collection of ["eventReminders", "events", "users", "studentProfiles", "locations"]) await db.recursiveDelete(db.collection(collection));
  now = Date.UTC(2027, 0, 1, 12); calls = []; failures = new Set(); duringSend = undefined;
  await db.collection("locations").doc("north").set({isActive: true, name: "North", timeZoneId: "America/New_York"});
  for (const [id, role, locationId] of [["parent", "parent", "north"], ["guest", "guest", "north"], ["wrong", "parent", "other"], ["inactive", "parent", "north"]]) {
    await db.collection("users").doc(id).set({role, locationId, isActive: id !== "inactive", linkedStudentProfileIds: ["one", "two"]});
    await db.collection("users").doc(id).collection("pushDevices").doc("phone").set({fcmToken: id === "parent" ? "good" : id, enabled: true});
  }
  for (const id of ["one", "two"]) await db.collection("studentProfiles").doc(id).set({isActive: true, locationId: "north", guardianUserIds: ["parent"]});
});
after(async () => { if (app) await deleteApp(app); });
const emulatorTest = (name: string, action: () => Promise<void>) => test(name, {skip: !enabled}, action);

emulatorTest("repeated/concurrent scanners deduplicate parent, devices and leases", async () => {
  await db!.collection("users/parent/pushDevices").doc("duplicate").set({fcmToken: "good", enabled: true});
  // Seed before the due time. Sync must never schedule a newly historical offset.
  await seed({startDateTime: Timestamp.fromMillis(now + 3600000 + 2000)}); now += 3000;
  await Promise.all([backend().runDue(), backend().runDue(), backend().sync("series")]);
  await backend().runDue();
  assert.equal(calls.length, 1); assert.deepEqual(calls[0].tokens, ["good"]);
  assert.equal((await db!.collection("eventReminders").get()).docs[0].get("status"), "completed");
});
emulatorTest("partial transient failures retry only failed tokens; invalid devices cleaned", async () => {
  for (const token of ["retry", "invalid"]) await db!.collection("users/parent/pushDevices").doc(token).set({fcmToken: token, enabled: true});
  await db!.collection("users/parent/pushDevices").doc("invalid-copy").set({fcmToken: "invalid", enabled: true});
  failures = new Set(["retry", "invalid"]);
  await seed({startDateTime: Timestamp.fromMillis(now + 3600000 + 2000)}); now += 3000;
  await backend().runDue(); assert.equal(calls.length, 1);
  assert.equal((await db!.doc("users/parent/pushDevices/invalid-copy").get()).exists, false);
  now += 121000; failures.clear(); await backend().runDue();
  assert.deepEqual(calls[1].tokens, ["retry"]);
  await backend().runDue(); assert.equal(calls.length, 2);
});
emulatorTest("unpublish/archive/delete/disable cancel work and cannot be revived by old scans", async () => {
  for (const edit of [{isPublished: false}, {isArchived: true}, {reminders: {mode: "none", offsetsMinutes: []}}, null]) {
    await db!.recursiveDelete(db!.collection("eventReminders"));
    await seed({startDateTime: Timestamp.fromMillis(now + 3600000 + 2000)});
    if (edit === null) await db!.doc("events/series").delete(); else await db!.doc("events/series").update(edit);
    now += 4000; await backend().runDue(); await backend().sync("series"); await backend().runDue();
    assert.equal(calls.length, 0);
    assert.equal((await db!.collection("eventReminders").get()).docs[0].get("status"), "canceled");
  }
});
emulatorTest("reschedule uses latest text and stable id, preserving already sent history", async () => {
  await seed({startDateTime: Timestamp.fromMillis(now + 3600000 + 2000)});
  const id = (await db!.collection("eventReminders").get()).docs[0].id;
  await db!.doc("events/series").update({title: "Updated", startDateTime: Timestamp.fromMillis(now + 7200000), endDateTime: Timestamp.fromMillis(now + 10800000)});
  await backend().sync("series"); now += 3600000; await backend().runDue();
  assert.match(calls[0].payload.title, /Updated/);
  assert.equal((await db!.collection("eventReminders").get()).docs[0].id, id);
  await db!.doc("events/series").update({startDateTime: Timestamp.fromMillis(now + 10800000), endDateTime: Timestamp.fromMillis(now + 14400000)});
  await backend().sync("series"); now += 7200000; await backend().runDue();
  assert.equal(calls.length, 1);
});
emulatorTest("first passed/canceled/removed never transfers to second; every opts in", async () => {
  const occurrences = [{id: "first", startMillis: now - 86400000, endMillis: now - 82800000, canceled: false},
    {id: "second", startMillis: now + 3602000, endMillis: now + 7202000, canceled: false}];
  await seed({eventSchedule: {version: 1, firstOccurrenceId: "first", occurrences}}); now += 3000;
  await backend().runDue(); assert.equal(calls.length, 0);
  await db!.doc("events/series").update({reminders: {mode: "every", offsetsMinutes: [60]}});
  // Already-past offsets are not backfilled when every is selected.
  await backend().sync("series"); await backend().runDue(); assert.equal(calls.length, 0);
  await db!.doc("events/series").update({eventSchedule: {version: 1, firstOccurrenceId: "first", occurrences: [{...occurrences[1], startMillis: now + 3660000, endMillis: now + 7260000}]}});
  await backend().sync("series"); now += 60001; await backend().runDue();
  assert.equal(calls.length, 1); assert.equal(calls[0].payload.data.occurrenceId, "second");
});
emulatorTest("past suppression, no devices, draft duplicates and expired processing lease", async () => {
  await seed(); await backend().runDue(); assert.equal(calls.length, 0);
  await seed({startDateTime: Timestamp.fromMillis(now + 3602000), isPublished: false}); now += 3000;
  await backend().runDue(); assert.equal(calls.length, 0);
  await db!.recursiveDelete(db!.collection("users"));
  await seed({startDateTime: Timestamp.fromMillis(now + 3602000)}); now += 3000;
  const reminder = (await db!.collection("eventReminders").get()).docs[0];
  await reminder.ref.update({status: "processing", owner: "old", leaseUntil: Timestamp.fromMillis(now - 1), wakeAt: Timestamp.fromMillis(now - 1)});
  await backend().runDue(); assert.equal(calls.length, 0);
  assert.equal((await reminder.ref.get()).get("status"), "completed");
});
emulatorTest("claimed cancellation cannot finish or revive a canceled reminder", async () => {
  await seed({startDateTime: Timestamp.fromMillis(now + 3602000)}); now += 3000;
  duringSend = async () => { await db!.doc("events/series").update({isPublished: false}); await backend().sync("series"); };
  await backend().runDue(); await backend().runDue();
  // A send already in flight cannot be recalled; state stays canceled.
  assert.equal(calls.length, 1);
  assert.equal((await db!.collection("eventReminders").get()).docs[0].get("status"), "canceled");
  assert.equal(reminderSpecs("series", (await db!.doc("events/series").get()).data()).length, 0);
});

emulatorTest("multiple offsets are independent; transport exceptions retry durably", async () => {
  const start = now + 7 * 86400000 + 60000;
  await seed({startDateTime: Timestamp.fromMillis(start), endDateTime: Timestamp.fromMillis(start + 3600000),
    reminders: {mode: "first", offsetsMinutes: [10080, 4320, 1440, 120, 60]}});
  assert.equal((await db!.collection("eventReminders").get()).size, 5);
  now = start - 7 * 86400000;
  duringSend = async () => { throw new Error("Mock transport failed before acceptance"); };
  await backend().runDue();
  assert.equal((await db!.collection("eventReminders").where("status", "==", "failed").get()).size, 1);
  now += 121000; await backend().runDue(); assert.equal(calls.length, 2);
  for (const offset of [4320, 1440, 120, 60]) { now = start - offset * 60000; await backend().runDue(); await backend().runDue(); }
  assert.equal(calls.length, 6);
  assert.equal((await db!.collection("eventReminders").where("status", "==", "completed").get()).size, 5);
});

emulatorTest("removing/adding occurrences cancels old work; canceled first never promotes second", async () => {
  const a = {id: "a", startMillis: now + 3660000, endMillis: now + 7260000, canceled: false};
  const b = {id: "b", startMillis: now + 3720000, endMillis: now + 7320000, canceled: false};
  const schedule = {version: 1, firstOccurrenceId: "a", occurrences: [a, b]};
  await seed({eventSchedule: schedule});
  await db!.doc("events/series").update({eventSchedule: {...schedule, occurrences: [{...a, canceled: true}, b]}});
  await backend().sync("series"); now += 120000; await backend().runDue();
  assert.equal(calls.length, 0);
  assert.equal((await db!.collection("eventReminders").get()).docs[0].get("status"), "canceled");
  const c = {id: "c", startMillis: now + 3660000, endMillis: now + 7260000, canceled: false};
  await db!.doc("events/series").update({eventSchedule: {...schedule, occurrences: [b, c]}, reminders: {mode: "every", offsetsMinutes: [60]}});
  await backend().sync("series"); now += 60001; await backend().runDue();
  assert.equal(calls.length, 1); assert.equal(calls[0].payload.data.occurrenceId, "c");
});
