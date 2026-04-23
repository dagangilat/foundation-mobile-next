/**
 * Auth module — mirrors evoting-frontend/src/lib/auth.ts, using the Firebase
 * JS SDK (firebase@10) on top of React Native. Identity is Firebase Auth only
 * (Phase 4 cutover); sign-in is the email-link flow gated by an admin-approved
 * invite. Ring tier comes from Firebase custom claims.
 */

import {
  onAuthStateChanged,
  signOut as firebaseSignOut,
  sendSignInLinkToEmail,
  signInWithEmailLink,
  isSignInWithEmailLink,
  type IdTokenResult,
  type User,
  type ActionCodeSettings,
} from 'firebase/auth';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { auth } from './firebase';

const PENDING_EMAIL_KEY = '@foundation/auth/pendingEmail';

export interface Claims {
  sub: string;
  email?: string;
  /** Ring tier set by the @plantagoai/auth blocking trigger on first sign-in. */
  ring?: number;
  role?: string;
  exp: number;
  iat: number;
}

function fromIdToken(t: IdTokenResult, user: User): Claims {
  const c = t.claims as Record<string, unknown>;
  return {
    sub: user.uid,
    email: user.email ?? (c.email as string | undefined),
    ring: typeof c.ring === 'number' ? c.ring : undefined,
    role: typeof c.role === 'string' ? c.role : undefined,
    exp: Math.floor(new Date(t.expirationTime).getTime() / 1000),
    iat: Math.floor(new Date(t.issuedAtTime).getTime() / 1000),
  };
}

export function onAuthChange(cb: (claims: Claims | null) => void): () => void {
  return onAuthStateChanged(auth, async (user) => {
    if (!user) {
      cb(null);
      return;
    }
    const result = await user.getIdTokenResult();
    cb(fromIdToken(result, user));
  });
}

export async function signOut(): Promise<void> {
  await firebaseSignOut(auth);
}

// ─── Email-link sign-in ──────────────────────────────────────────────

// Android package still matches the RN-CLI default; rename pending
// (move android/.../java/com/foundationmobile/** to .../com/foundationglobal/mobile/**).
const ACTION_CODE_SETTINGS: ActionCodeSettings = {
  // Universal Link / App Link that reopens the app with the sign-in link.
  // Configure Associated Domains on iOS + an /.well-known/assetlinks.json on
  // Android before this actually round-trips the app.
  url: 'https://foundation-global.com/mobile-signin',
  handleCodeInApp: true,
  iOS: { bundleId: 'com.foundationglobal.mobile' },
  android: {
    packageName: 'com.foundationmobile',
    installApp: true,
    minimumVersion: '1',
  },
};

export async function sendSignInLink(email: string): Promise<void> {
  await sendSignInLinkToEmail(auth, email, ACTION_CODE_SETTINGS);
  await AsyncStorage.setItem(PENDING_EMAIL_KEY, email);
}

export async function completeSignInFromDeepLink(
  link: string,
): Promise<'signed-in' | 'no-pending-email' | 'not-a-sign-in-link'> {
  if (!isSignInWithEmailLink(auth, link)) return 'not-a-sign-in-link';
  const email = await AsyncStorage.getItem(PENDING_EMAIL_KEY);
  if (!email) return 'no-pending-email';
  await signInWithEmailLink(auth, email, link);
  await AsyncStorage.removeItem(PENDING_EMAIL_KEY);
  return 'signed-in';
}
