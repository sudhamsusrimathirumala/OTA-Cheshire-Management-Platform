import {getApps, initializeApp} from "firebase-admin/app";
import {
  DocumentReference,
  FieldValue,
  Firestore,
  Timestamp,
  WriteBatch,
  getFirestore,
} from "firebase-admin/firestore";
import {loadAudienceInputs, loadDevices, deleteInvalidDevices, sendPushBatch} from "./push_delivery";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineBoolean} from "firebase-functions/params";
import {EventReminderBackend} from "./event_reminders";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions";
import {
  ContentType,
  announcementDeliveryData,
  canClaimDispatch,
  chunkTargets,
  eligibleAccountIds,
  isFirstPublication,
  isTargetedPublishedAnnouncement,
  isPermanentMessagingError,
  notificationPayload,
  targetedDeliveryPlan,
} from "./push_logic";

if (getApps().length === 0) initializeApp();
const db = getFirestore();
export const pushFunctionRegion = "us-east1";
const triggerOptions = {region: pushFunctionRegion, maxInstances: 2, retry: true};
const eventRemindersEnabled = defineBoolean("EVENT_REMINDERS_ENABLED", {default: false});

export const pushPublishedAnnouncement = onDocumentWritten(
  {...triggerOptions, document: "announcements/{contentId}"},
  async (event) => {
    const contentId = event.params.contentId;
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    await syncTargetedAnnouncementDeliveries(contentId, after);
    await dispatchPublication("announcement", contentId, before, after);
  },
);

export const pushPublishedEvent = onDocumentWritten(
  {...triggerOptions, document: "events/{contentId}"},
  async (event) => {
    await new EventReminderBackend(db).sync(event.params.contentId);
    await dispatchPublication("event", event.params.contentId,
      event.data?.before.data(), event.data?.after.data());
  },
);

export const pushPublishedResource = onDocumentWritten(
  {...triggerOptions, document: "resources/{contentId}"},
  (event) => dispatchPublication("resource", event.params.contentId,
    event.data?.before.data(), event.data?.after.data()),
);

async function dispatchPublication(
  type: ContentType,
  contentId: string,
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined,
): Promise<void> {
  if (!isFirstPublication(type, before, after) || !after) return;
  const dispatchId = `${type}_${contentId}`;
  if (!await claimDispatch(db, dispatchId, type, contentId, String(after.locationId))) return;
  let successCount = 0;
  let failureCount = 0;
  let targetCount = 0;
  try {
    const {accounts, profiles} = await loadAudienceInputs(db, String(after.locationId));
    const accountIds = eligibleAccountIds(type, after, accounts, profiles);
    const devices = await loadDevices(db, accountIds);
    const payload = notificationPayload(type, contentId, after);
    targetCount = new Set(devices.map((device) => device.token)).size;
    let temporaryFailureCount = 0;
    const invalidRefs: DocumentReference[] = [];
    for (const tokenBatch of chunkTargets(devices.map((device) => device.token))) {
      const result = await sendPushBatch(tokenBatch, payload, dispatchId);
      successCount += result.successCount;
      failureCount += result.failureCount;
      result.responses.forEach((response, index) => {
        const code = response.error?.code;
        if (code && isPermanentMessagingError(code)) {
          const token = tokenBatch[index];
          invalidRefs.push(...devices.filter((device) => device.token === token)
            .map((device) => device.reference));
        } else if (!response.success) {
          temporaryFailureCount++;
        }
      });
    }
    await deleteInvalidDevices(db, invalidRefs);
    if (temporaryFailureCount > 0) {
      throw Object.assign(new Error("Temporary FCM delivery failure"), {
        code: "messaging/temporary-delivery-failure",
      });
    }
    await db.collection("pushDispatches").doc(dispatchId).update({
      status: "completed",
      completedAt: FieldValue.serverTimestamp(),
      successCount,
      failureCount,
      targetCount,
      leaseUntil: FieldValue.delete(),
    });
    logger.info("push_dispatch_completed", {dispatchId, successCount, failureCount, targetCount});
  } catch (error) {
    await db.collection("pushDispatches").doc(dispatchId).set({
      status: "failed",
      lastErrorCode: safeErrorCode(error),
      successCount,
      failureCount,
      targetCount,
      leaseUntil: FieldValue.delete(),
    }, {merge: true});
    logger.error("push_dispatch_failed", {dispatchId, code: safeErrorCode(error)});
    throw error;
  }
}

async function syncTargetedAnnouncementDeliveries(
  contentId: string,
  after: Record<string, unknown> | undefined,
): Promise<void> {
  const existingSnapshot = await db.collectionGroup("announcementDeliveries")
    .where("announcementId", "==", contentId).get();
  const existingByUid = new Map(existingSnapshot.docs.map((document) => [
    document.ref.parent.parent?.id ?? "",
    document.ref,
  ]));
  let recipientIds: string[] = [];
  if (isTargetedPublishedAnnouncement(after)) {
    const {accounts, profiles} = await loadAudienceInputs(db, String(after?.locationId));
    recipientIds = eligibleAccountIds("announcement", after!, accounts, profiles);
  }
  const plan = targetedDeliveryPlan([...existingByUid.keys()], recipientIds);
  const writes: Array<(batch: WriteBatch) => void> = [];
  for (const uid of plan.deleteUids) {
    const reference = existingByUid.get(uid);
    if (reference) writes.push((batch) => batch.delete(reference));
  }
  if (after && isTargetedPublishedAnnouncement(after)) {
    const delivery = announcementDeliveryData(contentId, after);
    for (const uid of plan.upsertUids) {
      const reference = db.collection("users").doc(uid)
        .collection("announcementDeliveries").doc(contentId);
      writes.push((batch) => batch.set(reference, delivery));
    }
  }
  for (let index = 0; index < writes.length; index += 450) {
    const batch = db.batch();
    writes.slice(index, index + 450).forEach((write) => write(batch));
    await batch.commit();
  }
}

async function claimDispatch(
  firestore: Firestore,
  dispatchId: string,
  type: ContentType,
  contentId: string,
  locationId: string,
): Promise<boolean> {
  const reference = firestore.collection("pushDispatches").doc(dispatchId);
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const existing = snapshot.data();
    const lease = existing?.leaseUntil instanceof Timestamp ? existing.leaseUntil.toMillis() : undefined;
    if (!canClaimDispatch(existing ? {status: existing.status, leaseUntilMillis: lease} : undefined, Date.now())) {
      return false;
    }
    transaction.set(reference, {
      contentType: type,
      contentId,
      locationId,
      status: "processing",
      attemptCount: Number(existing?.attemptCount ?? 0) + 1,
      leaseUntil: Timestamp.fromMillis(Date.now() + 5 * 60 * 1000),
      startedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
}

function safeErrorCode(error: unknown): string {
  if (typeof error === "object" && error !== null && "code" in error) {
    return String((error as {code: unknown}).code).slice(0, 100);
  }
  return "unknown";
}

// UTC polling operates on stored instants, independently of open apps.
export const dispatchEventReminders = onSchedule({region: pushFunctionRegion,
  schedule: "every 1 minutes", timeZone: "UTC", maxInstances: 2, timeoutSeconds: 540,
  retryCount: 3}, async () => {
    if (eventRemindersEnabled.value()) await new EventReminderBackend(db).runDue();
  });
