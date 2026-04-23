/**
 * Firebase App Check — coarse gating for our Cloud Functions + Firestore.
 *
 * Uses DeviceCheck/App Attest on iOS and Play Integrity on Android. Firebase
 * servers verify the attestation against Apple / Google public keys and issue
 * a short-lived App Check token that @react-native-firebase auto-attaches to
 * every callable + Firestore request. Backend rejects unattested requests
 * when ENFORCE_APP_CHECK=true is set (see functions/lib/app-check.js).
 *
 * Note: this is SEPARATE from src/lib/attestation.ts. App Check provides
 * request-level gating; our custom AppAttestModule / PlayIntegrityModule
 * produce the raw attestation blob that gets signed into the Secure Enclave
 * payload in Phase 7 (enclave seal) — App Check's opaque token isn't suitable
 * for that.
 */

import appCheck from '@react-native-firebase/app-check';

let initPromise: Promise<void> | null = null;

export function initializeAppCheck(): Promise<void> {
  if (initPromise) return initPromise;
  initPromise = (async () => {
    const provider = appCheck().newReactNativeFirebaseAppCheckProvider();
    provider.configure({
      android: {
        // 'debug' for emulators / unsigned builds; production uses 'playIntegrity'.
        provider: __DEV__ ? 'debug' : 'playIntegrity',
      },
      apple: {
        // 'deviceCheck' covers iOS 11+; 'appAttest' requires iOS 14+ and is stricter.
        provider: __DEV__ ? 'debug' : 'appAttest',
      },
    });
    await appCheck().initializeAppCheck({
      provider,
      isTokenAutoRefreshEnabled: true,
    });
  })();
  return initPromise;
}
