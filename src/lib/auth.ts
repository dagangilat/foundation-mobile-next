/**
 * Auth module — mirrors evoting-frontend/src/lib/auth.ts, but on top of
 * @react-native-firebase/auth. Identity is Firebase Auth only (Phase 4
 * cutover); sign-in is the email-link flow gated by an admin-approved
 * invite. Ring tier comes from Firebase custom claims.
 */

import auth, {
  FirebaseAuthTypes,
} from '@react-native-firebase/auth';
import AsyncStorage from '@react-native-async-storage/async-storage';

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

function fromIdToken(
  t: FirebaseAuthTypes.IdTokenResult,
  user: FirebaseAuthTypes.User,
): Claims {
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

export function onAuthChange(
  cb: (claims: Claims | null) => void,
): () => void {
  return auth().onAuthStateChanged(async (user) => {
    if (!user) {
      cb(null);
      return;
    }
    const result = await user.getIdTokenResult();
    cb(fromIdToken(result, user));
  });
}

export async function signOut(): Promise<void> {
  await auth().signOut();
}

// ─── Email-link sign-in ──────────────────────────────────────────────

// NOTE: bundle IDs are the RN-CLI defaults. Standardize to
// `com.foundationglobal.mobile` at Firebase-app registration time (requires
// moving android/.../java/com/foundationmobile/** and editing the iOS pbxproj).
const ACTION_CODE_SETTINGS: FirebaseAuthTypes.ActionCodeSettings = {
  // Universal Link / App Link that reopens the app with the sign-in link.
  // Configured per-environment in Phase 0 step 4.
  url: 'https://foundation-global.com/mobile-signin',
  handleCodeInApp: true,
  iOS: { bundleId: 'org.reactjs.native.example.FoundationMobile' },
  android: {
    packageName: 'com.foundationmobile',
    installApp: true,
    minimumVersion: '1',
  },
};

export async function sendSignInLink(email: string): Promise<void> {
  await auth().sendSignInLinkToEmail(email, ACTION_CODE_SETTINGS);
  // Persist so we can complete sign-in when the deep link reopens the app.
  await AsyncStorage.setItem(PENDING_EMAIL_KEY, email);
}

export async function isSignInLink(link: string): Promise<boolean> {
  return auth().isSignInWithEmailLink(link);
}

export async function completeSignInFromDeepLink(
  link: string,
): Promise<'signed-in' | 'no-pending-email' | 'not-a-sign-in-link'> {
  const isLink = await auth().isSignInWithEmailLink(link);
  if (!isLink) return 'not-a-sign-in-link';
  const email = await AsyncStorage.getItem(PENDING_EMAIL_KEY);
  if (!email) return 'no-pending-email';
  await auth().signInWithEmailLink(email, link);
  await AsyncStorage.removeItem(PENDING_EMAIL_KEY);
  return 'signed-in';
}
