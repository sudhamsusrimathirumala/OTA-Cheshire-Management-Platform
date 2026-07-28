import {getApps, initializeApp} from "firebase-admin/app";
import {
  DocumentReference,
  FieldValue,
  Firestore,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions";
import {
  AccountRecord,
  ContentType,
  ProfileRecord,
  canClaimDispatch,
  chunkTargets,
  eligibleAccountIds,
  isFirstPublication,
  isPermanentMessagingError,
  notificationPayload,
} from "./push_logic";

if (getApps().length === 0) initializeApp();
const db = getFirestore();
export const pushFunctionRegion = "us-east1";
const triggerOptions = {region: pushFunctionRegion, maxInstances: 2, retry: true};

export const pushPublishedAnnouncement = onDocumentWritten(
  {...triggerOptions, document: "announcements/{contentId}"},
  (event) => dispatchPublication("announcement", event.params.contentId,
    event.data?.before.data(), event.data?.after.data()),
);

export const pushPublishedEvent = onDocumentWritten(
  {...triggerOptions, document: "events/{contentId}"},
  (event) => dispatchPublication("event", event.params.contentId,
    event.data?.before.data(), event.data?.after.data()),
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
    const {accounts, profiles} = await loadAudienceInputs(String(after.locationId));
    const accountIds = eligibleAccountIds(type, after, accounts, profiles);
    const devices = await loadDevices(accountIds);
    const payload = notificationPayload(type, contentId, after);
    targetCount = devices.length;
    let temporaryFailureCount = 0;
    const invalidRefs: DocumentReference[] = [];
    for (const tokenBatch of chunkTargets(devices.map((device) => device.token))) {
      const result = await getMessaging().sendEachForMulticast({
        tokens: tokenBatch,
        notification: {title: payload.title, body: payload.body},
        data: payload.data,
        android: {
          priority: payload.important ? "high" : "normal",
          collapseKey: `${type}_${contentId}`,
          notification: {channelId: "ota_updates", sound: "default"},
        },
        apns: {
          headers: {"apns-collapse-id": `${type}_${contentId}`},
          payload: {aps: {sound: "default", threadId: `${type}_${contentId}`}},
        },
      });
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
    await deleteInvalidDevices(invalidRefs);
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
      targetCount: devices.length,
      leaseUntil: FieldValue.delete(),
    });
    logger.info("push_dispatch_completed", {dispatchId, successCount, failureCount, targetCount: devices.length});
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

async function loadAudienceInputs(locationId: string): Promise<{
  accounts: AccountRecord[]; profiles: ProfileRecord[];
}> {
  const snapshot = await db.collection("users")
    .where("locationId", "==", locationId)
    .where("isActive", "==", true)
    .where("role", "in", ["parent", "student"]).get();
  const accounts: AccountRecord[] = snapshot.docs.map((document) => ({
    id: document.id,
    role: String(document.get("role")),
    isActive: document.get("isActive") === true,
    locationId: String(document.get("locationId")),
    linkedStudentProfileIds: Array.isArray(document.get("linkedStudentProfileIds")) ?
      document.get("linkedStudentProfileIds").filter((id: unknown) => typeof id === "string") : [],
  }));
  const profileIds = [...new Set(accounts.flatMap((account) => account.linkedStudentProfileIds))];
  const profileSnapshots = profileIds.length === 0 ? [] :
    await db.getAll(...profileIds.map((id) => db.collection("studentProfiles").doc(id)));
  const profiles: ProfileRecord[] = profileSnapshots.filter((item) => item.exists).map((item) => ({
    id: item.id,
    isActive: item.get("isActive") === true,
    locationId: String(item.get("locationId")),
    beltRank: typeof item.get("beltRank") === "string" ? item.get("beltRank") : undefined,
    preferredClassGroupIds: Array.isArray(item.get("preferredClassGroupIds")) ?
      item.get("preferredClassGroupIds").filter((id: unknown) => typeof id === "string") : [],
  }));
  return {accounts, profiles};
}

async function loadDevices(accountIds: string[]): Promise<Array<{
  token: string; reference: DocumentReference;
}>> {
  const snapshots = await Promise.all(accountIds.map((id) =>
    db.collection("users").doc(id).collection("pushDevices")
      .where("enabled", "==", true).get()));
  const byToken = new Map<string, DocumentReference>();
  for (const document of snapshots.flatMap((snapshot) => snapshot.docs)) {
    const token = document.get("fcmToken");
    if (typeof token === "string" && token) byToken.set(token, document.ref);
  }
  return [...byToken].map(([token, reference]) => ({token, reference}));
}

async function deleteInvalidDevices(references: DocumentReference[]): Promise<void> {
  const unique = [...new Map(references.map((reference) => [reference.path, reference])).values()];
  for (const refs of chunkTargets(unique.map((reference) => reference.path), 450)) {
    const batch = db.batch();
    refs.forEach((path) => batch.delete(db.doc(path)));
    await batch.commit();
  }
}

function safeErrorCode(error: unknown): string {
  if (typeof error === "object" && error !== null && "code" in error) {
    return String((error as {code: unknown}).code).slice(0, 100);
  }
  return "unknown";
}
