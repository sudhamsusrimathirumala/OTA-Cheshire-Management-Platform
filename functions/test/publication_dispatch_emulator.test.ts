import assert from "node:assert/strict";
import {before, beforeEach, after, test} from "node:test";
import {initializeApp, deleteApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {BatchResponse} from "firebase-admin/messaging";
import {PublicationDispatcher} from "../src/publication_dispatch";
import {syncTargetedAnnouncementDeliveries} from "../src/announcement_delivery";
import {PushPayload} from "../src/push_delivery";

const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
const app = enabled ? initializeApp({projectId: "demo-ota-publications"}, "publication-tests") : undefined;
const db = app ? getFirestore(app) : undefined;
let now = Date.UTC(2027, 0, 1, 12);
let calls: Array<{tokens: string[]; payload: PushPayload}> = [];
let failures = new Set<string>();
let duringSend: (() => Promise<void>) | undefined;
const send = async (tokens: string[], payload: PushPayload): Promise<BatchResponse> => {
  calls.push({tokens, payload});
  if (duringSend) { const action = duringSend; duringSend = undefined; await action(); }
  const responses = tokens.map((token) => failures.has(token) ? {success: false, error: {
    code: token === "invalid" ? "messaging/registration-token-not-registered" : "messaging/internal-error",
  } as never} : {success: true});
  return {responses, successCount: responses.filter((r) => r.success).length,
    failureCount: responses.filter((r) => !r.success).length};
};
const content = (extra = {}) => ({title: "Announcement", summary: "Details", body: "Message",
  locationId: "north", status: "published", audienceType: "everyone",
  publishedAt: Timestamp.fromMillis(now), ...extra});
const backend = () => new PublicationDispatcher(db!, send, () => now);
const dispatch = () => backend().dispatch("announcement", "notice", undefined, content());
const emulatorTest = (name: string, action: () => Promise<void>) => test(name, {skip: !enabled}, action);

before(() => {
  if (enabled && !/^(127\.0\.0\.1|localhost):/.test(process.env.FIRESTORE_EMULATOR_HOST!)) {
    throw new Error("Tests require a local emulator");
  }
});
beforeEach(async () => {
  if (!db) return;
  for (const collection of ["pushDispatches", "announcements", "users", "studentProfiles"]) {
    await db.recursiveDelete(db.collection(collection));
  }
  now = Date.UTC(2027, 0, 1, 12); calls = []; failures = new Set(); duringSend = undefined;
  for (const [id, role, locationId] of [["parent", "parent", "north"], ["wrong", "parent", "other"], ["guest", "guest", "north"]]) {
    await db.doc(`users/${id}`).set({role, locationId, isActive: true, linkedStudentProfileIds: [id]});
    await db.doc(`studentProfiles/${id}`).set({locationId, isActive: true, guardianUserIds: [id], beltRank: "White"});
    await db.doc(`users/${id}/pushDevices/phone`).set({fcmToken: id === "parent" ? "good" : id, enabled: true});
  }
  await db.doc("announcements/notice").set(content());
});
after(async () => { if (app) await deleteApp(app); });

emulatorTest("publication retries send only failed tokens and delete invalid registrations", async () => {
  for (const token of ["retry", "invalid"]) {
    await db!.doc(`users/parent/pushDevices/${token}`).set({fcmToken: token, enabled: true});
  }
  failures = new Set(["retry", "invalid"]);
  await assert.rejects(dispatch(), {code: "messaging/temporary-delivery-failure"});
  assert.deepEqual(calls[0].tokens.sort(), ["good", "invalid", "retry"]);
  assert.equal((await db!.doc("users/parent/pushDevices/invalid").get()).exists, false);
  failures.clear(); await dispatch(); await dispatch();
  assert.equal(calls.length, 2); assert.deepEqual(calls[1].tokens, ["retry"]);
  assert.equal((await db!.doc("pushDispatches/announcement_notice").get()).get("status"), "completed");
});

emulatorTest("active leases reject retries; expired abandoned leases can recover", async () => {
  const ref = db!.doc("pushDispatches/announcement_notice");
  await ref.set({status: "processing", owner: "abandoned", leaseUntil: Timestamp.fromMillis(now + 300000)});
  await assert.rejects(dispatch(), {code: "dispatch-busy"});
  assert.equal(calls.length, 0);
  now += 300001; await dispatch();
  assert.deepEqual(calls[0].tokens, ["good"]);
  assert.equal((await ref.get()).get("attemptCount"), 1);
});

emulatorTest("outdated trigger payloads use current content and respect unpublication", async () => {
  await db!.doc("announcements/notice").update({status: "draft"});
  await dispatch(); assert.equal(calls.length, 0);
  await db!.doc("announcements/notice").update({status: "published", title: "Current title"});
  await dispatch(); assert.equal(calls[0].payload.title, "Current title");
});

emulatorTest("transport errors release the lease so the platform retry can recover", async () => {
  duringSend = async () => { throw new Error("Mock transport failure"); };
  await assert.rejects(dispatch(), /Mock transport failure/);
  assert.equal((await db!.doc("pushDispatches/announcement_notice").get()).get("status"), "failed");
  await dispatch(); assert.equal(calls.length, 2);
});

emulatorTest("unpublishing during a multi-batch send stops unsent batches", async () => {
  const batch = db!.batch();
  for (let i = 0; i < 101; i++) {
    batch.set(db!.doc(`users/parent/pushDevices/extra-${i}`), {fcmToken: `extra-${i}`, enabled: true});
  }
  await batch.commit();
  duringSend = async () => { await db!.doc("announcements/notice").update({status: "draft"}); };
  await dispatch(); assert.equal(calls.length, 1);
  assert.equal((await db!.doc("pushDispatches/announcement_notice").get()).get("status"), "canceled");
});

emulatorTest("targeted delivery reconciliation cannot resurrect stale text or recipients", async () => {
  const ref = db!.doc("announcements/notice");
  await ref.update({audienceType: "specificUsers", targetUserIds: ["parent"]});
  await syncTargetedAnnouncementDeliveries(db!, "notice");
  const delivery = db!.doc("users/parent/announcementDeliveries/notice");
  assert.equal((await delivery.get()).get("title"), "Announcement");
  await ref.update({title: "Latest title"});
  await syncTargetedAnnouncementDeliveries(db!, "notice");
  assert.equal((await delivery.get()).get("title"), "Latest title");
  await ref.update({targetUserIds: ["wrong"]});
  await syncTargetedAnnouncementDeliveries(db!, "notice");
  assert.equal((await delivery.get()).exists, false);
  assert.equal((await db!.doc("users/wrong/announcementDeliveries/notice").get()).exists, false);
  await ref.update({targetUserIds: ["parent"]});
  await syncTargetedAnnouncementDeliveries(db!, "notice");
  await ref.delete();
  await syncTargetedAnnouncementDeliveries(db!, "notice");
  assert.equal((await delivery.get()).exists, false);
});
