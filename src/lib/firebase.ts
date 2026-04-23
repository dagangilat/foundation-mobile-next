/**
 * Firebase JS SDK initialization.
 *
 * We use the modular JS SDK (firebase@10) rather than @react-native-firebase
 * because the latter's CocoaPods integration didn't cleanly coexist with
 * Firebase 11+ Swift pods + use_frameworks!. The JS SDK works identically on
 * iOS and Android, auto-attaches tokens via the `fetch` transport, and has
 * no native-bridge maintenance.
 *
 * Config values below mirror `ios/FoundationMobile/GoogleService-Info.plist`
 * — if you rotate the Firebase project or regenerate config, update both.
 */

import { initializeApp, getApps, getApp, type FirebaseApp } from 'firebase/app';
import { initializeAuth, type Auth } from 'firebase/auth';
// getReactNativePersistence is exported from firebase/auth's RN-specific
// bundle (dist/index.rn.js, which Metro resolves via the `react-native`
// package field) but the shipped typings entry (auth-public.d.ts) omits it.
// @ts-expect-error — runtime export, resolved by Metro's RN resolver
import { getReactNativePersistence } from 'firebase/auth';
import { getFunctions, type Functions } from 'firebase/functions';
import AsyncStorage from '@react-native-async-storage/async-storage';

const firebaseConfig = {
  apiKey: 'AIzaSyBb5Cvhm2ndMdz8A90KnpP5w1-7XOGV2yk',
  authDomain: 'solanavote-devnet.firebaseapp.com',
  projectId: 'solanavote-devnet',
  storageBucket: 'solanavote-devnet.firebasestorage.app',
  messagingSenderId: '213114263206',
  appId: '1:213114263206:ios:bf5b23192ece0dfc448667',
};

export const app: FirebaseApp =
  getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);

// initializeAuth is the RN-specific entry point — it lets us pass
// AsyncStorage persistence so the user stays signed in across restarts.
// Must only run once; on Fast Refresh we fall back to getAuth.
export const auth: Auth = (() => {
  try {
    return initializeAuth(app, {
      persistence: getReactNativePersistence(AsyncStorage),
    });
  } catch {
    // Already initialized (happens during Fast Refresh).
    const { getAuth } = require('firebase/auth');
    return getAuth(app);
  }
})();

export const functions: Functions = getFunctions(app);
