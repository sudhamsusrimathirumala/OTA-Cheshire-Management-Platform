import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {PublicationDispatcher} from "./publication_dispatch";
import {syncTargetedAnnouncementDeliveries} from "./announcement_delivery";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineBoolean} from "firebase-functions/params";
import {EventReminderBackend} from "./event_reminders";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
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
    await syncTargetedAnnouncementDeliveries(db, contentId);
    await new PublicationDispatcher(db).dispatch("announcement", contentId, before, after);
  },
);

export const pushPublishedEvent = onDocumentWritten(
  {...triggerOptions, document: "events/{contentId}"},
  async (event) => {
    await new EventReminderBackend(db).sync(event.params.contentId);
    await new PublicationDispatcher(db).dispatch("event", event.params.contentId,
      event.data?.before.data(), event.data?.after.data());
  },
);

export const pushPublishedResource = onDocumentWritten(
  {...triggerOptions, document: "resources/{contentId}"},
  (event) => new PublicationDispatcher(db).dispatch("resource", event.params.contentId,
    event.data?.before.data(), event.data?.after.data()),
);

// UTC polling operates on stored instants, independently of open apps.
export const dispatchEventReminders = onSchedule({region: pushFunctionRegion,
  schedule: "every 1 minutes", timeZone: "UTC", maxInstances: 2, timeoutSeconds: 540,
  retryCount: 3}, async () => {
    if (eventRemindersEnabled.value()) await new EventReminderBackend(db).runDue();
  });
