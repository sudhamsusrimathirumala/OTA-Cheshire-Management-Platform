import {DocumentReference, Firestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {AccountRecord, ProfileRecord, chunkTargets, isPermanentMessagingError} from "./push_logic";

export async function loadAudienceInputs(db: Firestore, locationId: string): Promise<{
  accounts: AccountRecord[]; profiles: ProfileRecord[];
}> {
  const snapshot = await db.collection("users").where("locationId", "==", locationId)
    .where("isActive", "==", true).where("role", "in", ["parent", "student"]).get();
  const accounts: AccountRecord[] = snapshot.docs.map((d) => ({
    id: d.id, role: String(d.get("role")), isActive: d.get("isActive") === true,
    locationId: String(d.get("locationId")),
    linkedStudentProfileIds: Array.isArray(d.get("linkedStudentProfileIds")) ?
      d.get("linkedStudentProfileIds").filter((id: unknown) => typeof id === "string") : [],
  }));
  const ids = [...new Set(accounts.flatMap((a) => a.linkedStudentProfileIds))];
  const snapshots = [];
  for (const batch of chunkTargets(ids, 100)) {
    snapshots.push(...await db.getAll(...batch.map((id) => db.collection("studentProfiles").doc(id))));
  }
  const profiles: ProfileRecord[] = snapshots.filter((d) => d.exists).map((d) => ({
    id: d.id, isActive: d.get("isActive") === true, locationId: String(d.get("locationId")),
    linkedUserId: typeof d.get("linkedUserId") === "string" ? d.get("linkedUserId") : undefined,
    guardianUserIds: Array.isArray(d.get("guardianUserIds")) ? d.get("guardianUserIds") : [],
    beltRank: typeof d.get("beltRank") === "string" ? d.get("beltRank") : undefined,
    preferredClassGroupIds: Array.isArray(d.get("preferredClassGroupIds")) ? d.get("preferredClassGroupIds") : [],
  }));
  return {accounts, profiles};
}
export interface PushDevice {token: string; reference: DocumentReference}
export async function loadDevices(db: Firestore, ids: string[]): Promise<PushDevice[]> {
  const devices: PushDevice[] = [];
  for (const batch of chunkTargets(ids, 50)) {
    const snapshots = await Promise.all(batch.map((id) => db.collection("users").doc(id)
      .collection("pushDevices").where("enabled", "==", true).get()));
    for (const d of snapshots.flatMap((s) => s.docs)) {
      const token = d.get("fcmToken");
      if (typeof token === "string" && token) devices.push({token, reference: d.ref});
    }
  }
  return devices;
}
export async function deleteInvalidDevices(db: Firestore, references: DocumentReference[]): Promise<void> {
  for (const refs of chunkTargets(references.map((r) => r.path), 450)) {
    const batch = db.batch(); refs.forEach((path) => batch.delete(db.doc(path))); await batch.commit();
  }
}
export interface PushPayload {title: string; body: string; data: Record<string, string>; important: boolean; expiresAtMillis?: number}
export async function sendPushBatch(tokens: string[], payload: PushPayload, key: string) {
  return getMessaging().sendEachForMulticast({tokens, notification: {title: payload.title, body: payload.body}, data: payload.data,
    android: {priority: payload.important ? "high" : "normal", collapseKey: key.slice(0, 64),
      ...(payload.expiresAtMillis === undefined ? {} : {ttl: Math.max(0, Math.min(28 * 86400000, payload.expiresAtMillis - Date.now()))}),
      notification: {channelId: "ota_updates", sound: "default"}},
    apns: {headers: {"apns-collapse-id": key.slice(0, 64),
      ...(payload.expiresAtMillis === undefined ? {} : {"apns-expiration": String(Math.floor(payload.expiresAtMillis / 1000))})},
      payload: {aps: {sound: "default", threadId: key.slice(0, 64)}}},
  });
}
export {isPermanentMessagingError};
