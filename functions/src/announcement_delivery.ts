import {Firestore, Transaction} from "firebase-admin/firestore";
import {loadAudienceInputs} from "./push_delivery";
import {announcementDeliveryData, eligibleAccountIds, isTargetedPublishedAnnouncement, targetedDeliveryPlan} from "./push_logic";

export async function syncTargetedAnnouncementDeliveries(db: Firestore, contentId: string): Promise<void> {
  const contentRef = db.collection("announcements").doc(contentId);
  // Firestore triggers can arrive out of order. Always reconcile current data.
  const content = await contentRef.get();
  const after = content.data();
  const existing = await db.collectionGroup("announcementDeliveries").where("announcementId", "==", contentId).get();
  const existingByUid = new Map(existing.docs.map((doc) => [doc.ref.parent.parent!.id, doc.ref]));
  let recipients: string[] = [];
  if (isTargetedPublishedAnnouncement(after)) {
    const {accounts, profiles} = await loadAudienceInputs(db, String(after!.locationId));
    recipients = eligibleAccountIds("announcement", after!, accounts, profiles);
  }
  const plan = targetedDeliveryPlan([...existingByUid.keys()], recipients);
  const writes: Array<(batch: Transaction) => void> = [];
  for (const uid of plan.deleteUids) writes.push((batch) => { batch.delete(existingByUid.get(uid)!); });
  if (isTargetedPublishedAnnouncement(after)) {
    const data = announcementDeliveryData(contentId, after!);
    for (const uid of plan.upsertUids) writes.push((batch) => {
      batch.set(db.collection("users").doc(uid).collection("announcementDeliveries").doc(contentId), data);
    });
  }
  for (let start = 0; start < writes.length; start += 450) {
    await db.runTransaction(async (tx) => {
      const current = await tx.get(contentRef);
      if (current.exists !== content.exists ||
          (current.exists && !current.updateTime!.isEqual(content.updateTime!))) {
        throw new Error("Announcement changed while syncing deliveries; retry latest content");
      }
      writes.slice(start, start + 450).forEach((write) => write(tx));
    });
  }
}
