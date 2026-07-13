const {initializeApp} = require("firebase-admin/app");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {logger} = require("firebase-functions");

const {
  submitOnboardingApplicationCore,
  trustedIdentityFromAuth,
} = require("./onboarding");

initializeApp();

exports.submitOnboardingApplication = onCall(async (request) => {
  try {
    const identity = trustedIdentityFromAuth(request.auth);
    return await submitOnboardingApplicationCore({
      identity,
      data: request.data,
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("submitOnboardingApplication failed", error);
    throw new HttpsError("internal", "The onboarding application could not be submitted.", {
      reason: "backend-failure",
    });
  }
});
