import {createHash, randomUUID} from "node:crypto";
import {DocumentReference, FieldValue, Firestore, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {ContentType, chunkTargets, eligibleAccountIds, isFirstPublication, isPermanentMessagingError, notificationPayload} from "./push_logic";
import {deleteInvalidDevices, loadAudienceInputs, loadDevices, sendPushBatch} from "./push_delivery";

const leaseMillis = 5 * 60000;
const tokenKey = (token: string) => createHash("sha256").update(token).digest("hex");
const collectionFor = (type: ContentType) => ({announcement: "announcements", event: "events", resource: "resources"}[type]);

export class PublicationDispatcher {
  constructor(private db: Firestore, private send = sendPushBatch, private now = () => Date.now()) {}

  async dispatch(type: ContentType, contentId: string,
    before: Record<string, unknown> | undefined, after: Record<string, unknown> | undefined): Promise<void> {
    if (!isFirstPublication(type, before, after)) return;
    const dispatchId = `${type}_${contentId}`;
    const ref = this.db.collection("pushDispatches").doc(dispatchId);
    const contentRef = this.db.collection(collectionFor(type)).doc(contentId);
    const owner = randomUUID();
    const snapshot = await this.db.runTransaction(async (tx) => {
      const [dispatch, content] = await tx.getAll(ref, contentRef);
      const state = dispatch.data();
      if (state?.status === "completed" || !isFirstPublication(type, undefined, content.data())) return undefined;
      if (state?.status === "processing" && state.leaseUntil instanceof Timestamp && state.leaseUntil.toMillis() > this.now()) {
        // Throw so a retry cannot acknowledge work abandoned by another invocation.
        throw Object.assign(new Error("Publication dispatch is leased"), {code: "dispatch-busy"});
      }
      tx.set(ref, {contentType: type, contentId, locationId: content.get("locationId"),
        status: "processing", owner, attemptCount: Number(state?.attemptCount ?? 0) + 1,
        leaseUntil: Timestamp.fromMillis(this.now() + leaseMillis), startedAt: FieldValue.serverTimestamp()}, {merge: true});
      return content;
    });
    if (!snapshot) return;
    let successCount = 0; let failureCount = 0; let targetCount = 0;
    const finish = async (status: string, error?: unknown) => this.db.runTransaction(async (tx) => {
      const state = await tx.get(ref);
      if (state.get("owner") !== owner) return;
      tx.update(ref, {status, successCount, failureCount, targetCount,
        owner: FieldValue.delete(), leaseUntil: FieldValue.delete(),
        ...(status === "completed" ? {completedAt: FieldValue.serverTimestamp()} : {}),
        ...(error ? {lastErrorCode: safeErrorCode(error)} : {})});
    });
    try {
      const content = snapshot.data()!;
      const {accounts, profiles} = await loadAudienceInputs(this.db, String(content.locationId));
      const devices = await loadDevices(this.db, eligibleAccountIds(type, content, accounts, profiles));
      const tokens = [...new Set(devices.map((device) => device.token))];
      targetCount = tokens.length;
      const receipts = await ref.collection("targets").get();
      const completed = new Set(receipts.docs.filter((d) => ["sent", "invalid"].includes(d.get("status"))).map((d) => d.id));
      successCount = receipts.docs.filter((d) => d.get("status") === "sent").length;
      let temporaryFailures = 0;
      for (const tokenBatch of chunkTargets(tokens.filter((token) => !completed.has(tokenKey(token))), 100)) {
        const latest = await contentRef.get();
        if (!isFirstPublication(type, undefined, latest.data())) { await finish("canceled"); return; }
        if (!latest.updateTime!.isEqual(snapshot.updateTime!)) {
          throw Object.assign(new Error("Publication changed while sending"), {code: "content-changed"});
        }
        const renewed = await this.db.runTransaction(async (tx) => {
          const state = await tx.get(ref);
          if (state.get("owner") !== owner || state.get("status") !== "processing") return false;
          tx.update(ref, {leaseUntil: Timestamp.fromMillis(this.now() + leaseMillis)});
          return true;
        });
        if (!renewed) return;
        const result = await this.send(tokenBatch, notificationPayload(type, contentId, content), dispatchId);
        successCount += result.successCount; failureCount += result.failureCount;
        const writes = this.db.batch();
        const invalid: DocumentReference[] = [];
        result.responses.forEach((response, index) => {
          const token = tokenBatch[index];
          const permanent = response.error && isPermanentMessagingError(response.error.code);
          if (response.success || permanent) {
            writes.set(ref.collection("targets").doc(tokenKey(token)), {
              status: response.success ? "sent" : "invalid", updatedAt: FieldValue.serverTimestamp(),
            });
          } else { temporaryFailures++; }
          if (permanent) invalid.push(...devices.filter((device) => device.token === token).map((device) => device.reference));
        });
        await writes.commit();
        await deleteInvalidDevices(this.db, invalid);
      }
      if (temporaryFailures) throw Object.assign(new Error("Temporary push delivery failure"), {code: "messaging/temporary-delivery-failure"});
      await finish("completed");
      logger.info("push_dispatch_completed", {dispatchId, successCount, failureCount, targetCount});
    } catch (error) {
      await finish("failed", error);
      logger.error("push_dispatch_failed", {dispatchId, code: safeErrorCode(error)});
      throw error;
    }
  }
}

function safeErrorCode(error: unknown): string {
  return typeof error === "object" && error !== null && "code" in error ?
    String((error as {code: unknown}).code).replace(/[^a-zA-Z0-9_/-]/g, "-").slice(0, 100) : "unknown";
}
