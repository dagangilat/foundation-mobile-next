/**
 * Foundation Mobile — root.
 *
 * Routes:
 *  - loading        → spinner
 *  - not signed in  → SignInScreen
 *  - signed in      → HomeScreen (Foundation branded, ring tier, three pillars)
 *
 * Phase 1 adds App Attest + Play Integrity ahead of NFC+ZK (Phase 3 via Self
 * SDK). Nothing identifying ever leaves the device — the only outbound
 * payloads are the enclave-signed attestation blob and the Solana commitment.
 */

import React, { useEffect, useState } from 'react';
import { Linking, StatusBar, StyleSheet, View } from 'react-native';
import {
  SafeAreaProvider,
  useSafeAreaInsets,
} from 'react-native-safe-area-context';
import {
  ActivityIndicator,
  MD3DarkTheme,
  PaperProvider,
  Surface,
  Text,
} from 'react-native-paper';
import {
  completeSignInFromDeepLink,
  onAuthChange,
  type Claims,
} from './src/lib/auth';
import { SignInScreen } from './src/screens/SignInScreen';
import { FOUNDATION_COLORS, HomeScreen } from './src/screens/HomeScreen';

const foundationTheme = {
  ...MD3DarkTheme,
  roundness: 3,
  colors: {
    ...MD3DarkTheme.colors,
    primary: FOUNDATION_COLORS.brandGreen,
    onPrimary: FOUNDATION_COLORS.bg,
    background: FOUNDATION_COLORS.bg,
    surface: FOUNDATION_COLORS.bg,
    surfaceVariant: FOUNDATION_COLORS.surface,
    onSurface: FOUNDATION_COLORS.white,
    onSurfaceVariant: FOUNDATION_COLORS.muted,
    outline: FOUNDATION_COLORS.border,
  },
};

function App() {
  return (
    <PaperProvider theme={foundationTheme}>
      <SafeAreaProvider>
        <StatusBar barStyle="light-content" />
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
        claims ? { status: 'signed-in', claims } : { status: 'signed-out' },
      );
    });
  }, []);

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
          <ActivityIndicator color={FOUNDATION_COLORS.brandGreen} />
          <Text style={styles.sub}>Checking sign-in…</Text>
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
  root: { flex: 1, backgroundColor: FOUNDATION_COLORS.bg },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  sub: { color: FOUNDATION_COLORS.muted, marginTop: 12 },
});

export default App;
