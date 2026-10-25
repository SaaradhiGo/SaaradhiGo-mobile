#!/usr/bin/env bash
#
# Repeatable Android release builds for the SaaradhiGo RIDER app.
#
# WHY A SCRIPT AND NOT A RUNBOOK LINE
# -----------------------------------
# A release build of this app needs four things right at once: the signing
# material, the right --dart-define pair for the target environment, the
# non-production opt-in for a QA build (and NOT for a store build), and the
# right artifact type (Play takes an .aab; a sideloaded pilot takes an .apk).
# Any one of them wrong produces a build that looks fine and is wrong:
#
#   * no dart-defines        -> the app refuses to start (by design)
#   * QA urls, no opt-in     -> the app refuses to start (by design)
#   * QA urls, store build   -> riders book rides that do not exist
#   * .apk for Play          -> rejected at upload, after the signing ceremony
#
# Typing that by hand once a week is how one of them eventually goes wrong.
#
# THE BACKUP GATE
# ---------------
# This script refuses to produce a SIGNED artifact unless
# SAARADHIGO_KEYSTORE_BACKUP_VERIFIED=yes is set in the environment. The
# keystores currently exist in exactly one directory on one machine, and an
# upload key that is lost after the first Play upload cannot be replaced
# without Google's intervention. Set it only once both .jks files AND
# credentials.txt are in a password manager or encrypted vault that somebody
# other than the builder can reach.
#
# Use `smoke-apk` to exercise the build pipeline without the keys.
#
# USAGE
#   tool/build_release.sh play-aab      # production App Bundle for Play
#   tool/build_release.sh qa-apk        # QA release APK, split per ABI
#   tool/build_release.sh smoke-apk     # debug-signed, NOT distributable
#
# Signing material comes from android/key.properties or the ANDROID_* env
# vars. This script never prints a password, a key path or a keystore.

set -euo pipefail

PROD_API="https://api.saaradhigo.com/api/v1"
PROD_WS="wss://api.saaradhigo.com/ws"
# QA SERVER ADDRESS
#
# These pointed at dev.api.saaradhigo.in, which RESOLVES (16.112.4.47) and
# then times out on connect -- nothing serves it. Every QA artifact built
# here was therefore an app that could not reach a backend at all, and the
# failure looks exactly like a backend outage from the phone.
#
# The QA backend is served at the Railway-generated hostname below, which
# was verified reachable (HTTP 200 on /healthz) when this was changed.
#
# Overridable, so pointing a build at a different QA server does not mean
# editing this file: SAARADHIGO_QA_API=... ./tool/build_release.sh qa-apk
# When api.saaradhigo.com is finally pointed at the production service, set it
# back here and delete this note.
QA_API="${SAARADHIGO_QA_API:-https://backend-qa-811d.up.railway.app/api/v1}"
QA_WS="${SAARADHIGO_QA_WS:-wss://backend-qa-811d.up.railway.app/ws}"

# Optional, never printed. Passed through only when set in the environment.
#
#   MAPS_API_KEY         -> -Pmaps.apiKey, filling the manifest placeholder.
#                           Nothing in this app reads it today (maps render
#                           with flutter_map over OSM and the Google key lives
#                           on the server), so an empty placeholder is
#                           harmless. It stays wired so that adopting the Maps
#                           SDK later does not mean rediscovering this.
#   CASHFREE_APP_ID      -> --dart-define, payment SDK identity
#   CASHFREE_ENVIRONMENT -> --dart-define, SANDBOX or PRODUCTION
#
# No payment configuration is baked in here. A build with neither Cashfree
# variable set has an empty payment config, which is the correct and
# deliberate state while live payments are disabled -- and the script prints
# that on every run rather than leaving it implicit.
EXTRA_ARGS=()
if [ -n "${MAPS_API_KEY:-}" ]; then
  EXTRA_ARGS+=("-Pmaps.apiKey=${MAPS_API_KEY}")
  MAPS_NOTE="supplied from MAPS_API_KEY"
else
  MAPS_NOTE="not supplied (placeholder resolves empty; nothing reads it today)"
fi
if [ -n "${CASHFREE_APP_ID:-}" ]; then
  EXTRA_ARGS+=("--dart-define=CASHFREE_APP_ID=${CASHFREE_APP_ID}")
fi
if [ -n "${CASHFREE_ENVIRONMENT:-}" ]; then
  EXTRA_ARGS+=("--dart-define=CASHFREE_ENVIRONMENT=${CASHFREE_ENVIRONMENT}")
  PAY_NOTE="CASHFREE_ENVIRONMENT=${CASHFREE_ENVIRONMENT}"
else
  PAY_NOTE="no payment configuration (live payments disabled)"
fi

TARGET="${1:-}"

die() { printf '\n%s\n\n' "ERROR: $*" >&2; exit 1; }

usage() {
  sed -n '/^# USAGE/,/^# Signing/p' "$0" | sed 's/^# \{0,1\}//'
  exit 64
}

[ -n "$TARGET" ] || usage

command -v flutter >/dev/null || die "flutter is not on PATH."

require_backup_confirmation() {
  if [ "${SAARADHIGO_KEYSTORE_BACKUP_VERIFIED:-}" != "yes" ]; then
    die "$(cat <<'EOT'
Refusing to produce a signed artifact: the keystore backup has not been
confirmed.

Both upload keystores and credentials.txt currently exist in exactly one
directory on one machine. An upload key lost after the first Play upload
cannot be replaced without Google's intervention, and an app signing key
lost without Play App Signing cannot be replaced at all.

Once both .jks files AND credentials.txt are in a password manager or
encrypted vault that a second person can reach:

    export SAARADHIGO_KEYSTORE_BACKUP_VERIFIED=yes

To exercise the build pipeline now, without the keys:

    tool/build_release.sh smoke-apk
EOT
)"
  fi
}

require_signing_material() {
  # Presence only. Values are never read, printed or logged here -- Gradle
  # reads them itself, and its own guard refuses the build if they are absent.
  if [ -f android/key.properties ]; then
    for field in storeFile storePassword keyPassword keyAlias; do
      grep -q "^${field}=" android/key.properties \
        || die "android/key.properties is missing ${field}."
    done
    echo "  signing: android/key.properties (4 fields present)"
  elif [ -n "${ANDROID_KEYSTORE_PATH:-}" ]; then
    for var in ANDROID_KEYSTORE_PATH ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD ANDROID_STORE_PASSWORD; do
      [ -n "${!var:-}" ] || die "${var} is not set."
    done
    echo "  signing: ANDROID_* environment variables (4 present)"
  else
    die "No signing material. Create android/key.properties (gitignored) or set the four ANDROID_* variables."
  fi
}

case "$TARGET" in
  play-aab)
    echo "Target: production App Bundle for Google Play"
    require_backup_confirmation
    require_signing_material
    echo "  server: production"
    echo "  maps:   $MAPS_NOTE"
    echo "  pay:    $PAY_NOTE"
    set -x
    flutter build appbundle --release \
      --dart-define=BASE_URL="$PROD_API" \
      --dart-define=WS_BASE_URL="$PROD_WS" "${EXTRA_ARGS[@]}"
    set +x
    ARTIFACT="build/app/outputs/bundle/release/app-release.aab"
    ;;

  qa-apk)
    echo "Target: QA release APK (split per ABI), for sideloading to QA phones"
    require_backup_confirmation
    require_signing_material
    echo "  server: QA, with the non-production opt-in and a QA banner"
    echo "  maps:   $MAPS_NOTE"
    echo "  pay:    $PAY_NOTE"
    set -x
    flutter build apk --release --split-per-abi \
      --dart-define=ALLOW_NON_PRODUCTION_HOST=true \
      --dart-define=BASE_URL="$QA_API" \
      --dart-define=WS_BASE_URL="$QA_WS" "${EXTRA_ARGS[@]}"
    set +x
    ARTIFACT="build/app/outputs/flutter-apk/"
    ;;

  smoke-apk)
    echo "Target: smoke APK -- DEBUG-SIGNED, must never be distributed"
    echo "  server: QA, with the non-production opt-in"
    set -x
    flutter build apk --release --split-per-abi -PallowDebugSigning=true \
      --dart-define=ALLOW_NON_PRODUCTION_HOST=true \
      --dart-define=BASE_URL="$QA_API" \
      --dart-define=WS_BASE_URL="$QA_WS" "${EXTRA_ARGS[@]}"
    set +x
    ARTIFACT="build/app/outputs/flutter-apk/"
    ;;

  *)
    die "Unknown target '$TARGET'. Expected play-aab, qa-apk or smoke-apk."
    ;;
esac

echo
echo "Built: $ARTIFACT"
ls -lh "$ARTIFACT" 2>/dev/null || true

# Say what the artifact is actually signed with, rather than trusting the
# intent of the command. apksigner ships with the Android SDK build-tools.
# Only the launcher counts: a bare apksigner* glob also matches
# lib/apksigner.jar, which is not executable ("Exec format error").
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/AppData/Local/Android/Sdk}}"
SIGNER="$(find "$SDK" \( -name apksigner -o -name apksigner.bat \) -type f 2>/dev/null | sort | tail -1 || true)"
if [ -n "$SIGNER" ]; then
  for apk in build/app/outputs/flutter-apk/*.apk; do
    [ -f "$apk" ] || continue
    echo
    echo "Signer for $(basename "$apk"):"
    "$SIGNER" verify --print-certs "$apk" 2>/dev/null \
      | grep -i 'certificate DN' | sed 's/^/  /' || echo "  (could not read)"
  done
fi

if [ "$TARGET" = "smoke-apk" ]; then
  echo
  echo "REMINDER: this artifact is signed with the Android debug key."
  echo "Delete it when finished. It must not reach a rider."
fi
