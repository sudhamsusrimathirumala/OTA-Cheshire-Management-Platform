#!/bin/sh
set -eu

if [ -z "${APP_ENVIRONMENT:-}" ]; then
  echo "error: APP_ENVIRONMENT is not configured for this Xcode build."
  exit 1
fi

SOURCE_PLIST="${PROJECT_DIR}/Firebase/${APP_ENVIRONMENT}/GoogleService-Info.plist"
DESTINATION_PLIST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"

if [ ! -f "${SOURCE_PLIST}" ]; then
  echo "error: Missing Firebase configuration: ${SOURCE_PLIST}"
  echo "error: Supply the matching ${APP_ENVIRONMENT} plist; no environment fallback is allowed."
  exit 1
fi

cp "${SOURCE_PLIST}" "${DESTINATION_PLIST}"
