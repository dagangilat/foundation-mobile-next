/**
 * Foundation Mobile — Phase 0 placeholder.
 *
 * MD3 theme via react-native-paper. Sign-in and ring-tier display are wired in
 * Phase 0 once Firebase config is in place. Phase 1 adds App Attest + Play
 * Integrity; then NFC+ZK (Phase 3) via the Self SDK.
 */

import React from 'react';
import { StatusBar, StyleSheet, useColorScheme, View } from 'react-native';
import {
  SafeAreaProvider,
  useSafeAreaInsets,
} from 'react-native-safe-area-context';
import {
  MD3DarkTheme,
  MD3LightTheme,
  PaperProvider,
  Text,
  Surface,
} from 'react-native-paper';

function App() {
  const isDarkMode = useColorScheme() === 'dark';
  const theme = isDarkMode ? MD3DarkTheme : MD3LightTheme;

  return (
    <PaperProvider theme={theme}>
      <SafeAreaProvider>
        <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
        <AppContent />
      </SafeAreaProvider>
    </PaperProvider>
  );
}

function AppContent() {
  const insets = useSafeAreaInsets();

  return (
    <Surface style={[styles.container, { paddingTop: insets.top }]}>
      <View style={styles.body}>
        <Text variant="headlineMedium">Foundation</Text>
        <Text variant="bodyMedium" style={styles.subtitle}>
          Phase 0 — sign-in + ring tier (coming next).
        </Text>
      </View>
    </Surface>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  body: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  subtitle: {
    marginTop: 8,
    textAlign: 'center',
    opacity: 0.7,
  },
});

export default App;
