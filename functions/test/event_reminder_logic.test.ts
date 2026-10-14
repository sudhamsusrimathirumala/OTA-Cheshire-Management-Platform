import assert from "node:assert/strict";
import test from "node:test";
import {currentReminder, eventOccurrences, reminderId, reminderMessage, reminderSpecs} from "../src/event_reminder_logic";

const first = Date.UTC(2027, 0, 1, 22);
const schedule = {version: 1, timeZoneId: "America/New_York", firstOccurrenceId: "a",
  occurrences: [{id: "a", startMillis: first, endMillis: first + 3600000, canceled: false},
    {id: "b", startMillis: first + 86400000, endMillis: first + 90000000, canceled: false}]};
const event = {title: "Belt Testing", locationId: "north", isPublished: true, isArchived: false,
  startDateTime: first, endDateTime: first + 3600000,
  reminders: {mode: "first", offsetsMinutes: [1440, 60]}, eventSchedule: schedule};

test("legacy events have one occurrence and opt in explicitly", () => {
  const {eventSchedule, ...once} = event;
  assert.equal(eventOccurrences(once).length, 1);
  assert.equal(reminderSpecs("series", once).length, 2);
  assert.equal(reminderSpecs("series", {...once, reminders: undefined}).length, 0);
});
test("first never means next; cancel/remove/reschedule the anchor safely", () => {
  assert.deepEqual(reminderSpecs("series", event).map((s) => s.occurrenceId), ["a", "a"]);
  assert.equal(reminderSpecs("series", {...event, eventSchedule: {...schedule,
    occurrences: schedule.occurrences.map((o) => ({...o, canceled: o.id === "a"}))}}).length, 0);
  assert.equal(reminderSpecs("series", {...event, eventSchedule: {...schedule, occurrences: [schedule.occurrences[1]]}}).length, 0);
  const before = reminderSpecs("series", event)[0];
  const edited = {...event, eventSchedule: {...schedule, occurrences: schedule.occurrences.map((o) =>
    ({...o, startMillis: o.startMillis + 3600000, endMillis: o.endMillis + 3600000}))}};
  assert.equal(currentReminder(before, edited)?.id, before.id);
  assert.equal(currentReminder(before, edited)?.dueMillis, before.dueMillis + 3600000);
});
test("every, disabled, offsets and independent duplicate identity", () => {
  assert.equal(reminderSpecs("series", {...event, reminders: {mode: "every", offsetsMinutes: [1440, 60, 60]}}).length, 4);
  assert.equal(reminderSpecs("series", {...event, reminders: {mode: "none", offsetsMinutes: [60]}}).length, 0);
  assert.notEqual(reminderId("series", "a", 60), reminderId("duplicate", "a", 60));
  assert.equal(reminderSpecs("series", {...event, reminders: {mode: "every", offsetsMinutes: [-1]}}).length, 0);
});
test("nonpublished, archived, deleted, draft duplicate and malformed schedules fail closed", () => {
  for (const value of [undefined, {...event, isPublished: false}, {...event, isArchived: true},
    {...event, eventSchedule: {version: 3}}, {...event, eventSchedule: {...schedule, occurrences: Array(181).fill(schedule.occurrences[0])}}]) {
    assert.equal(reminderSpecs("series", value).length, 0);
  }
});
test("message uses current details, location timezone and occurrence navigation", () => {
  const payload = reminderMessage(reminderSpecs("series", event)[1], {...event, title: "Updated Seminar"}, {name: "North Academy", timeZoneId: "America/New_York"});
  assert.match(payload.title, /Updated Seminar/);
  assert.match(payload.body, /5:00 PM EST/);
  assert.match(payload.body, /North Academy/);
  assert.equal(payload.data.occurrenceId, "a");
  assert.equal(payload.data.reminderKind, "event-start");
  assert.equal(payload.expiresAtMillis, first);
  assert.ok(payload.body.length <= 180);
});
