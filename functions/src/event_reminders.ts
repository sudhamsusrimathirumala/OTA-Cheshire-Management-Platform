import {createHash, randomUUID} from "node:crypto";
import {DocumentReference, FieldValue, Firestore, Timestamp} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {ReminderSpec, currentReminder, reminderMessage, reminderSpecs} from "./event_reminder_logic";
import {chunkTargets, eligibleAccountIds} from "./push_logic";
import {deleteInvalidDevices, isPermanentMessagingError, loadAudienceInputs, loadDevices, sendPushBatch} from "./push_delivery";

const leaseMillis = 5 * 60000;
const latenessMillis = 15 * 60000;
const tokenKey = (token: string) => createHash("sha256").update(token).digest("hex");

export class EventReminderBackend {
  constructor(private db: Firestore, private send = sendPushBatch, private now = () => Date.now()) {}

  async sync(eventId: string): Promise<void> {
    const eventRef = this.db.collection("events").doc(eventId);
    const event = await eventRef.get();
    const specs = new Map(reminderSpecs(eventId, event.data()).map((s) => [s.id, s]));
    const existing = await this.db.collection("eventReminders").where("eventId", "==", eventId).get();
    const ids = [...new Set([...specs.keys(), ...existing.docs.map((d) => d.id)])];
    for (const group of chunkTargets(ids, 200)) {
      await this.db.runTransaction(async (tx) => {
        const current = await tx.get(eventRef);
        if (current.exists !== event.exists || (current.exists && !current.updateTime!.isEqual(event.updateTime!))) {
          throw new Error("Event changed while scheduling; retry with latest event");
        }
        const refs = group.map((id) => this.db.collection("eventReminders").doc(id));
        const snapshots = await tx.getAll(...refs);
        for (const snapshot of snapshots) {
          const old = snapshot.data(); const spec = specs.get(snapshot.id);
          if (old?.status === "completed") continue; // Sent history is immutable.
          const same = spec && old?.startMillis === spec.startMillis && old?.dueMillis === spec.dueMillis && old?.locationId === spec.locationId;
          // Never create a historical reminder. Existing due work has a bounded lateness window.
          const future = spec && (spec.dueMillis > this.now() || (same && old?.status !== "canceled"));
          if (!future || !spec) {
            if (old && old.status !== "canceled") tx.update(snapshot.ref, {
              status: "canceled", wakeAt: FieldValue.delete(), owner: FieldValue.delete(),
              canceledAt: FieldValue.serverTimestamp(),
            });
          } else if (!same || old?.status === "canceled") {
            tx.set(snapshot.ref, {...spec, kind: "event-start", status: "pending",
              wakeAt: Timestamp.fromMillis(spec.dueMillis), revision: randomUUID(),
              owner: FieldValue.delete(), leaseUntil: FieldValue.delete(),
              updatedAt: FieldValue.serverTimestamp(), createdAt: old?.createdAt ?? FieldValue.serverTimestamp()}, {merge: true});
          }
        }
      });
    }
  }

  async runDue(): Promise<void> {
    // Pending, retry and expired lease work share a single indexed wakeAt queue.
    const due = await this.db.collection("eventReminders").where("wakeAt", "<=", Timestamp.fromMillis(this.now()))
      .orderBy("wakeAt").limit(100).get();
    for (const snapshot of due.docs) {
      try { await this.dispatch(snapshot.ref); }
      catch (_) { logger.error("event_reminder_worker_failed"); }
    }
  }

  async dispatch(ref: DocumentReference): Promise<void> {
    const owner = randomUUID();
    const spec = await this.db.runTransaction(async (tx) => {
      const snapshot = await tx.get(ref); const data = snapshot.data();
      if (!data || ["completed", "canceled"].includes(data.status) ||
          data.wakeAt?.toMillis() > this.now() ||
          (data.status === "processing" && data.leaseUntil?.toMillis() > this.now())) return undefined;
      const event = await tx.get(this.db.collection("events").doc(data.eventId));
      const current = currentReminder(data as ReminderSpec, event.data());
      if (!current || current.startMillis !== data.startMillis || current.dueMillis !== data.dueMillis ||
          current.locationId !== data.locationId || this.now() >= current.startMillis ||
          this.now() > current.dueMillis + latenessMillis) {
        tx.update(ref, {status: "canceled", wakeAt: FieldValue.delete(), owner: FieldValue.delete(), canceledAt: FieldValue.serverTimestamp()});
        return undefined;
      }
      if (current.dueMillis > this.now()) return undefined;
      tx.update(ref, {status: "processing", owner, attemptCount: Number(data.attemptCount ?? 0) + 1,
        leaseUntil: Timestamp.fromMillis(this.now() + leaseMillis), wakeAt: Timestamp.fromMillis(this.now() + leaseMillis)});
      return current;
    });
    if (!spec) return;
    try {
      const eventRef = this.db.collection("events").doc(spec.eventId);
      const location = await this.db.collection("locations").doc(spec.locationId).get();
      if (!location.exists || location.get("isActive") !== true) { await this.finish(ref, owner, "canceled"); return; }
      const {accounts, profiles} = await loadAudienceInputs(this.db, spec.locationId);
      const devices = await loadDevices(this.db, eligibleAccountIds("event", {locationId: spec.locationId}, accounts, profiles));
      const tokens = [...new Set(devices.map((d) => d.token))];
      const targets = await ref.collection("targets").get();
      const delivered = new Set(targets.docs.filter((d) => ["sent", "invalid"].includes(d.get("status"))).map((d) => d.id));
      const pending = tokens.filter((token) => !delivered.has(tokenKey(token)));
      let failed = false;
      for (const tokenBatch of chunkTargets(pending, 100)) {
        const event = await eventRef.get();
        const current = currentReminder(spec, event.data());
        const record = await ref.get();
        if (record.get("owner") !== owner || record.get("status") !== "processing") return;
        if (!current || current.startMillis !== spec.startMillis || current.dueMillis !== spec.dueMillis ||
            current.locationId !== spec.locationId || this.now() >= spec.startMillis || this.now() > spec.dueMillis + latenessMillis) {
          await this.finish(ref, owner, "canceled"); return;
        }
        // Renew the lease before each send. A stale worker cannot finish a newer lease.
        if (!await this.renew(ref, owner)) return;
        const result = await this.send(tokenBatch, reminderMessage(current, event.data()!, location.data()!), spec.id);
        const invalidRefs: DocumentReference[] = [];
        const batch = this.db.batch();
        result.responses.forEach((response, index) => {
          const token = tokenBatch[index];
          const permanent = response.error && isPermanentMessagingError(response.error.code);
          if (response.success || permanent) {
            batch.set(ref.collection("targets").doc(tokenKey(token)), {
              status: response.success ? "sent" : "invalid", updatedAt: FieldValue.serverTimestamp(),
            });
          } else { failed = true; }
          if (permanent) invalidRefs.push(...devices.filter((d) => d.token === token).map((d) => d.reference));
        });
        await batch.commit(); await deleteInvalidDevices(this.db, invalidRefs);
      }
      await this.finish(ref, owner, failed ? "failed" : "completed");
    } catch (_) {
      await this.finish(ref, owner, "failed");
      logger.error("event_reminder_dispatch_failed");
    }
  }

  private async renew(ref: DocumentReference, owner: string): Promise<boolean> {
    return this.db.runTransaction(async (tx) => {
      const doc = await tx.get(ref);
      if (doc.get("owner") !== owner || doc.get("status") !== "processing") return false;
      tx.update(ref, {leaseUntil: Timestamp.fromMillis(this.now() + leaseMillis), wakeAt: Timestamp.fromMillis(this.now() + leaseMillis)});
      return true;
    });
  }
  private async finish(ref: DocumentReference, owner: string, status: string): Promise<void> {
    await this.db.runTransaction(async (tx) => {
      const doc = await tx.get(ref);
      if (doc.get("owner") !== owner || doc.get("status") !== "processing") return;
      const attempt = Number(doc.get("attemptCount") ?? 1);
      tx.update(ref, {status, owner: FieldValue.delete(), leaseUntil: FieldValue.delete(),
        wakeAt: status === "failed" ? Timestamp.fromMillis(this.now() + Math.min(60000 * 2 ** attempt, 5 * 60000)) : FieldValue.delete(),
        ...(status === "completed" ? {completedAt: FieldValue.serverTimestamp()} : {}),
        updatedAt: FieldValue.serverTimestamp()});
    });
  }
}
