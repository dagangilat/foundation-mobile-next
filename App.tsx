/**
 * Foundation Mobile — Phase 0 demo gate.
 *
 * Routes:
 *  - not signed in → SignInScreen (sends an email-link)
 *  - signed in     → HomeScreen (shows ring tier from Firebase custom claims)
 *
 * Phase 1 adds App Attest + Play Integrity ahead of NFC+ZK (Phase 3 via
 * the Self SDK). Nothing identifying ever leaves the device — the only
 * outbound payloads are the enclave-signed attestation blob and the
 * Solana commitment hash.
 */

import React, { useEffect, useState } from 'react';
import {
  Linking,
  StatusBar,
  StyleSheet,
  useColorScheme,
  View,
} from 'react-native';
import {
  SafeAreaProvider,
  useSafeAreaInsets,
} from 'react-native-safe-area-context';
import {
  ActivityIndicator,
  MD3DarkTheme,
  MD3LightTheme,
  PaperProvider,
  Surface,
  Text,
} from 'react-native-paper';
import {
  completeSignInFromDeepLink,
  onAuthChange,
  type Claims,
} from './src/lib/auth';
import { initializeAppCheck } from './src/lib/appCheck';
import { SignInScreen } from './src/screens/SignInScreen';
import { HomeScreen } from './src/screens/HomeScreen';

// Fire-and-forget: initialize App Check before any Firestore/CF call goes out.
// Any error is non-fatal for the UI; backend gating (ENFORCE_APP_CHECK) will
// reject subsequent calls if attestation fails, which surfaces per-callable.
initializeAppCheck().catch((err) => {
  console.warn('[appCheck] initialization failed', err);
});

function App() {
  const isDark = useColorScheme() === 'dark';
  const theme = isDark ? MD3DarkTheme : MD3LightTheme;
  return (
    <PaperProvider theme={theme}>
      <SafeAreaProvider>
        <StatusBar barStyle={isDark ? 'light-content' : 'dark-content'} />
        <AppContent />
      </SafeAreaProvider>
    </PaperProvider>
  );
}

type AuthState =
  | { status: 'loading' }
  | { status: 'signed-out' }
  | { status: 'signed-in'; claims: Claims };

function AppContent() {
  const insets = useSafeAreaInsets();
  const [state, setState] = useState<AuthState>({ status: 'loading' });

  useEffect(() => {
    return onAuthChange((claims) => {
      setState(
        claims
          ? { status: 'signed-in', claims }
          : { status: 'signed-out' },
      );
    });
  }, []);

  // Email-link completion: when the app opens via its universal/app link,
  // look up the pending email (persisted at send time) and complete sign-in.
  useEffect(() => {
    async function tryComplete(url: string | null) {
      if (!url) return;
      const result = await completeSignInFromDeepLink(url);
      if (result === 'no-pending-email') {
        console.warn(
          '[auth] Sign-in deep-link received but no pending email stored.',
        );
      }
    }
    Linking.getInitialURL().then(tryComplete);
    const sub = Linking.addEventListener('url', ({ url }) => tryComplete(url));
    return () => sub.remove();
  }, []);

  if (state.status === 'loading') {
    return (
      <Surface style={[styles.root, { paddingTop: insets.top }]}>
        <View style={styles.center}>
          <ActivityIndicator />
          <Text variant="bodyMedium" style={styles.sub}>
            Checking sign-in…
          </Text>
        </View>
      </Surface>
    );
  }

  if (state.status === 'signed-out') {
    return <SignInScreen />;
  }

  return <HomeScreen claims={state.claims} />;
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  sub: { marginTop: 12, opacity: 0.7 },
});

export default App;
