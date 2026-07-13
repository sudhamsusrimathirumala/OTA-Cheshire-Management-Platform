const test = require("node:test");
const assert = require("node:assert/strict");

const functionsEmulatorAvailable = Boolean(
  process.env.FUNCTIONS_EMULATOR_HOST || process.env.FIREBASE_EMULATOR_HUB,
);

test("callable rejects an unauthenticated request", {skip: !functionsEmulatorAvailable}, async () => {
  const response = await fetch(
    `http://${process.env.FUNCTIONS_EMULATOR_HOST || "127.0.0.1:5001"}/demo-ota-onboarding/us-central1/submitOnboardingApplication`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({data: {}}),
    },
  );
  const body = await response.json();
  assert.equal(response.status, 401);
  assert.equal(body.error.status, "UNAUTHENTICATED");
  assert.equal(body.error.details.reason, "unauthenticated");
});
