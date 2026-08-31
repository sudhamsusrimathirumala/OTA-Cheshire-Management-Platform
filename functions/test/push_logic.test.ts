import assert from "node:assert/strict";
import test from "node:test";
import {
  canClaimDispatch,
  chunkTargets,
  announcementDeliveryData,
  eligibleAccountIds,
  isFirstPublication,
  isTargetedPublishedAnnouncement,
  isPermanentMessagingError,
  notificationPayload,
  targetedDeliveryPlan,
  compatibleClassGroups,
} from "../src/push_logic";

test("only first valid publication triggers", () => {
  const published = {title: "News", summary: "Summary", status: "published", locationId: "cheshire"};
  assert.equal(isFirstPublication("announcement", {status: "draft"}, published), true);
  assert.equal(isFirstPublication("announcement", published, {...published, title: "Edited"}), false);
  assert.equal(isFirstPublication("event", {}, {title: "Event", locationId: "cheshire", isPublished: true, isArchived: false}), true);
  assert.equal(isFirstPublication("resource", {}, {title: "Form", locationId: "cheshire", isPublished: true, isArchived: false, resourceSection: "curriculum"}), false);
});

test("canonical and legacy class audiences match equivalently", () => {
  const account = [{id: "parent", role: "parent", isActive: true, locationId: "cheshire", linkedStudentProfileIds: ["adult"]}];
  const profiles = [{id: "adult", isActive: true, locationId: "cheshire", guardianUserIds: ["parent"], preferredClassGroupIds: ["adult-standard"]}];
  for (const target of ["adult-standard", "teen-adult"]) {
    assert.deepEqual(eligibleAccountIds("announcement", {locationId: "cheshire", audienceType: "classType", targetClassTypeIds: [target]}, account, profiles), ["parent"]);
  }
  assert.deepEqual(compatibleClassGroups("teen-adult"), ["black-belt-standard", "teen-black-belt-standard", "adult-standard"]);
  assert.deepEqual(eligibleAccountIds("announcement", {locationId: "cheshire", audienceType: "classType", targetClassTypeIds: ["level-1-standard"]}, account, profiles), []);
});

test("audiences deduplicate parents and broadcast events by location", () => {
  const accounts = [{id: "parent", role: "parent", isActive: true, locationId: "cheshire", linkedStudentProfileIds: ["a", "b"]}];
  const profiles = [
    {id: "a", isActive: true, locationId: "cheshire", guardianUserIds: ["parent"], beltRank: "White", preferredClassGroupIds: ["level-1-standard"]},
    {id: "b", isActive: true, locationId: "cheshire", guardianUserIds: ["parent"], beltRank: "Blue", preferredClassGroupIds: ["teen-adult"]},
  ];
  assert.deepEqual(eligibleAccountIds("announcement", {locationId: "cheshire", audienceType: "belt", targetBelts: ["Blue"]}, accounts, profiles), ["parent"]);
  assert.deepEqual(eligibleAccountIds("announcement", {locationId: "cheshire", audienceType: "students", targetStudentProfileIds: ["b"]}, accounts, profiles), ["parent"]);
  assert.deepEqual(eligibleAccountIds("event", {locationId: "cheshire"}, accounts, profiles), ["parent"]);
  assert.deepEqual(eligibleAccountIds("resource", {locationId: "other"}, accounts, profiles), []);
});

test("disabled, admin, unlinked, and wrong-location accounts are excluded", () => {
  const accounts = [
    {id: "disabled", role: "parent", isActive: false, locationId: "cheshire", linkedStudentProfileIds: ["profile"]},
    {id: "admin", role: "admin", isActive: true, locationId: "cheshire", linkedStudentProfileIds: ["profile"]},
    {id: "unlinked", role: "parent", isActive: true, locationId: "cheshire", linkedStudentProfileIds: []},
    {id: "elsewhere", role: "parent", isActive: true, locationId: "other", linkedStudentProfileIds: ["profile"]},
  ];
  const profiles = [{id: "profile", isActive: true, locationId: "cheshire", guardianUserIds: ["disabled"]}];
  assert.deepEqual(eligibleAccountIds("event", {locationId: "cheshire"}, accounts, profiles), []);
});

test("forged linked profile IDs never participate in announcement targeting", () => {
  const accounts = [
    {id: "owner", role: "parent", isActive: true, locationId: "cheshire", linkedStudentProfileIds: ["owner-profile"]},
    {id: "attacker", role: "parent", isActive: true, locationId: "cheshire", linkedStudentProfileIds: ["owner-profile"]},
  ];
  const profiles = [{
    id: "owner-profile", isActive: true, locationId: "cheshire",
    guardianUserIds: ["owner"], beltRank: "Blue",
  }];
  assert.deepEqual(eligibleAccountIds(
    "announcement",
    {locationId: "cheshire", audienceType: "belt", targetBelts: ["Blue"]},
    accounts,
    profiles,
  ), ["owner"]);
});

test("targeted delivery copies are deterministic and archive-safe", () => {
  const content = {
    title: "Private", summary: "Summary", body: "Body",
    status: "published", audienceType: "students", locationId: "cheshire",
    targetStudentProfileIds: ["child"], updatedAt: "revision-1",
  };
  assert.equal(isTargetedPublishedAnnouncement(content), true);
  assert.equal(isTargetedPublishedAnnouncement({...content, audienceType: "everyone"}), false);
  assert.equal(isTargetedPublishedAnnouncement({...content, status: "archived"}), false);
  assert.equal(isTargetedPublishedAnnouncement(undefined), false);
  assert.deepEqual(
    announcementDeliveryData("notice", content),
    {
      announcementId: "notice", title: "Private", summary: "Summary",
      body: "Body", status: "published", audienceType: "students",
      locationId: "cheshire", updatedAt: "revision-1",
    },
  );
  assert.deepEqual(
    announcementDeliveryData("notice", content),
    announcementDeliveryData("notice", content),
  );
  assert.deepEqual(
    targetedDeliveryPlan(["old", "kept"], ["kept", "new"]),
    {deleteUids: ["old"], upsertUids: ["kept", "new"]},
  );
  assert.deepEqual(
    targetedDeliveryPlan(["old", "kept"], []),
    {deleteUids: ["kept", "old"], upsertUids: []},
  );
});

test("multicast batching caps at 500 and deduplicates", () => {
  const targets = Array.from({length: 1001}, (_, index) => `token-${index}`);
  targets.push("token-0");
  assert.deepEqual(chunkTargets(targets).map((chunk) => chunk.length), [500, 500, 1]);
});

test("dispatch claims are idempotent and expired leases retry", () => {
  assert.equal(canClaimDispatch(undefined, 100), true);
  assert.equal(canClaimDispatch({status: "completed"}, 100), false);
  assert.equal(canClaimDispatch({status: "processing", leaseUntilMillis: 200}, 100), false);
  assert.equal(canClaimDispatch({status: "processing", leaseUntilMillis: 50}, 100), true);
  assert.equal(canClaimDispatch({status: "failed"}, 100), true);
});

test("invalid-device errors and platform-safe payloads are classified", () => {
  assert.equal(isPermanentMessagingError("messaging/registration-token-not-registered"), true);
  assert.equal(isPermanentMessagingError("messaging/internal-error"), false);
  const payload = notificationPayload("resource", "r1", {title: "Guide", locationId: "cheshire"});
  assert.equal(payload.body, "New academy resource available");
  assert.deepEqual(payload.data, {contentType: "resource", contentId: "r1", locationId: "cheshire"});
});
