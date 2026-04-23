/**
 * Foundation home — dark navy, shield logo + wordmark, stacked three-pillar
 * hero, Solana pill, and a footer copy line. Adapted to mobile portrait.
 *
 * Colors are drawn from foundation-global.com's brand palette. See
 * FOUNDATION_COLORS below; keep this in sync if the web palette shifts.
 */

import React from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';
import {
  Icon,
  IconButton,
  Surface,
  Text,
} from 'react-native-paper';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import type { Claims } from '../lib/auth';
import { signOut } from '../lib/auth';

export const FOUNDATION_COLORS = {
  bg: '#0a0e27',           // dark navy background
  surface: '#0f1636',       // slightly lighter card surface
  border: '#1e2a5a',
  white: '#ffffff',
  muted: '#9aa3c7',
  brandGreen: '#34d399',    // Foundation wordmark accent + shield gradient start
  brandCyan: '#22d3ee',     // shield gradient end
  pillBg: 'rgba(52, 211, 153, 0.12)',
  voice: '#818cf8',         // indigo-400
  share: '#2dd4bf',         // teal-400
  market: '#22d3ee',        // cyan-400
};

interface Props {
  claims: Claims | null;
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
  const insets = useSafeAreaInsets();
  const ringText =
    claims && typeof claims.ring === 'number'
      ? RING_LABEL[claims.ring] ?? `Ring ${claims.ring}`
      : null;

  return (
    <Surface style={[styles.root, { paddingTop: insets.top }]}>
      <ScrollView
        contentContainerStyle={[
          styles.scroll,
          { paddingBottom: insets.bottom + 24 },
        ]}
        showsVerticalScrollIndicator={false}
      >
        {/* ── Header ───────────────────────────────────── */}
        <View style={styles.header}>
          <View style={styles.brandRow}>
            <Icon
              source="shield-check"
              size={28}
              color={FOUNDATION_COLORS.brandGreen}
            />
            <Text style={styles.brand}>
              <Text style={styles.brandBase}>Found</Text>
              <Text style={styles.brandAccent}>ation</Text>
            </Text>
          </View>
          {claims ? (
            <IconButton
              icon="logout"
              iconColor={FOUNDATION_COLORS.muted}
              size={20}
              onPress={signOut}
            />
          ) : null}
        </View>

        {/* ── Solana pill ─────────────────────────────── */}
        <View style={styles.pill}>
          <View style={styles.pillDot} />
          <Text style={styles.pillText}>Powered by Solana Blockchain</Text>
        </View>

        {/* ── Hero ────────────────────────────────────── */}
        <View style={styles.hero}>
          <Text style={styles.yourText}>Your</Text>
          <Pillar
            icon="monitor-dashboard"
            label="Voice."
            color={FOUNDATION_COLORS.voice}
          />
          <Pillar
            icon="wallet-outline"
            label="Share."
            color={FOUNDATION_COLORS.share}
          />
          <Pillar
            icon="cart-outline"
            label="Market."
            color={FOUNDATION_COLORS.market}
          />
        </View>

        {/* ── Body copy ───────────────────────────────── */}
        <Text style={styles.body}>
          Three pillars for human thriving in the age of AI — Your Voice for
          governance, Your Share for community funds, and Your Market for
          collective purchasing — all on one verified identity layer.
        </Text>

        {/* ── Ring tier or sign-in CTA ────────────────── */}
        <View style={styles.card}>
          {claims ? (
            <>
              <Text style={styles.cardLabel}>Signed in</Text>
              <Text style={styles.cardValue}>
                {claims.email ?? claims.sub}
              </Text>
              <View style={styles.cardSpacer} />
              <Text style={styles.cardLabel}>Ring tier</Text>
              <Text style={styles.cardValue}>
                {ringText ?? 'No ring tier yet (invite pending)'}
              </Text>
            </>
          ) : (
            <>
              <Text style={styles.cardLabel}>Phase 0</Text>
              <Text style={styles.cardValue}>
                Sign in to see your ring tier and get started.
              </Text>
            </>
          )}
        </View>
      </ScrollView>
    </Surface>
  );
}

function Pillar({
  icon,
  label,
  color,
}: {
  icon: string;
  label: string;
  color: string;
}) {
  return (
    <View style={styles.pillarRow}>
      <Icon source={icon} size={44} color={color} />
      <Text style={[styles.pillarText, { color }]}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: FOUNDATION_COLORS.bg,
  },
  scroll: {
    paddingHorizontal: 20,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 12,
  },
  brandRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  brand: {
    fontSize: 22,
    fontWeight: '700',
    letterSpacing: 0.2,
  },
  brandBase: {
    color: FOUNDATION_COLORS.white,
  },
  brandAccent: {
    color: FOUNDATION_COLORS.brandGreen,
  },
  pill: {
    alignSelf: 'flex-start',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: FOUNDATION_COLORS.pillBg,
    borderColor: 'rgba(52, 211, 153, 0.35)',
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: 999,
    paddingVertical: 6,
    paddingHorizontal: 12,
    marginTop: 24,
  },
  pillDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: FOUNDATION_COLORS.brandGreen,
  },
  pillText: {
    color: FOUNDATION_COLORS.brandGreen,
    fontSize: 13,
    fontWeight: '500',
  },
  hero: {
    marginTop: 28,
  },
  yourText: {
    color: FOUNDATION_COLORS.white,
    fontSize: 64,
    fontWeight: '800',
    letterSpacing: -1,
    lineHeight: 68,
  },
  pillarRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    marginTop: 6,
  },
  pillarText: {
    fontSize: 56,
    fontWeight: '800',
    letterSpacing: -1,
    lineHeight: 62,
  },
  body: {
    color: FOUNDATION_COLORS.muted,
    fontSize: 15,
    lineHeight: 22,
    marginTop: 32,
  },
  card: {
    marginTop: 28,
    padding: 16,
    borderRadius: 14,
    backgroundColor: FOUNDATION_COLORS.surface,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: FOUNDATION_COLORS.border,
  },
  cardLabel: {
    color: FOUNDATION_COLORS.muted,
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'uppercase',
    letterSpacing: 0.6,
  },
  cardValue: {
    color: FOUNDATION_COLORS.white,
    fontSize: 16,
    marginTop: 4,
  },
  cardSpacer: {
    height: 14,
  },
});
