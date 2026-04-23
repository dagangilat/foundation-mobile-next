import React from 'react';
import { StyleSheet, View } from 'react-native';
import { Button, Surface, Text } from 'react-native-paper';
import type { Claims } from '../lib/auth';
import { signOut } from '../lib/auth';

interface Props {
  claims: Claims;
}

const RING_LABEL: Record<number, string> = {
  0: 'Ring 0 — Operator',
  1: 'Ring 1 — Admin',
  2: 'Ring 2 — Steward',
  3: 'Ring 3 — Contributor',
  4: 'Ring 4 — Member',
  5: 'Ring 5 — Guest',
};

export function HomeScreen({ claims }: Props) {
  const ringText =
    typeof claims.ring === 'number'
      ? RING_LABEL[claims.ring] ?? `Ring ${claims.ring}`
      : 'No ring tier yet (invite pending or claim not propagated)';

  return (
    <Surface style={styles.root}>
      <View style={styles.body}>
        <Text variant="headlineMedium">Foundation</Text>
        <Text variant="bodyMedium" style={styles.sub}>
          Phase 0 demo gate.
        </Text>

        <View style={styles.card}>
          <Text variant="labelLarge">Signed in as</Text>
          <Text variant="titleMedium">{claims.email ?? claims.sub}</Text>
          <View style={styles.spacer} />
          <Text variant="labelLarge">Ring tier</Text>
          <Text variant="titleMedium">{ringText}</Text>
        </View>

        <Button mode="outlined" onPress={signOut} style={styles.cta}>
          Sign out
        </Button>
      </View>
    </Surface>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  body: {
    flex: 1,
    padding: 24,
    justifyContent: 'center',
  },
  sub: { marginTop: 8, opacity: 0.7 },
  card: {
    marginTop: 24,
    padding: 16,
    borderRadius: 12,
    backgroundColor: 'rgba(127,127,127,0.08)',
  },
  spacer: { height: 16 },
  cta: { marginTop: 24, alignSelf: 'flex-start' },
});
