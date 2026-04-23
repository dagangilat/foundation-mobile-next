import React, { useState } from 'react';
import { StyleSheet, View } from 'react-native';
import {
  Button,
  HelperText,
  Icon,
  Surface,
  Text,
  TextInput,
} from 'react-native-paper';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { sendSignInLink } from '../lib/auth';
import { FOUNDATION_COLORS } from './HomeScreen';

export function SignInScreen() {
  const insets = useSafeAreaInsets();
  const [email, setEmail] = useState('');
  const [status, setStatus] = useState<
    'idle' | 'sending' | 'sent' | 'error'
  >('idle');
  const [errorText, setErrorText] = useState('');

  async function submit() {
    setStatus('sending');
    setErrorText('');
    try {
      await sendSignInLink(email.trim());
      setStatus('sent');
    } catch (err) {
      setStatus('error');
      setErrorText(err instanceof Error ? err.message : String(err));
    }
  }

  return (
    <Surface style={[styles.root, { paddingTop: insets.top }]}>
      <View style={styles.header}>
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

      <View style={styles.body}>
        <Text style={styles.title}>Sign in</Text>
        <Text style={styles.subtitle}>
          Enter your invited email. We'll send a one-tap sign-in link.
        </Text>

        <TextInput
          mode="outlined"
          label="Email"
          autoCapitalize="none"
          keyboardType="email-address"
          textContentType="emailAddress"
          value={email}
          onChangeText={setEmail}
          disabled={status === 'sending' || status === 'sent'}
          style={styles.input}
          theme={{
            colors: {
              onSurfaceVariant: FOUNDATION_COLORS.muted,
              outline: FOUNDATION_COLORS.border,
              primary: FOUNDATION_COLORS.brandGreen,
              onSurface: FOUNDATION_COLORS.white,
              background: FOUNDATION_COLORS.surface,
            },
          }}
          outlineColor={FOUNDATION_COLORS.border}
          activeOutlineColor={FOUNDATION_COLORS.brandGreen}
          textColor={FOUNDATION_COLORS.white}
        />

        {status === 'error' ? (
          <HelperText type="error" visible>
            {errorText}
          </HelperText>
        ) : null}

        {status === 'sent' ? (
          <HelperText type="info" visible style={{ color: FOUNDATION_COLORS.brandGreen }}>
            Link sent. Open it on this device to finish signing in.
          </HelperText>
        ) : null}

        <Button
          mode="contained"
          onPress={submit}
          loading={status === 'sending'}
          disabled={!email || status === 'sending' || status === 'sent'}
          style={styles.cta}
          buttonColor={FOUNDATION_COLORS.brandGreen}
          textColor={FOUNDATION_COLORS.bg}
        >
          Send sign-in link
        </Button>
      </View>
    </Surface>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: FOUNDATION_COLORS.bg,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 20,
    paddingVertical: 12,
  },
  brand: {
    fontSize: 22,
    fontWeight: '700',
  },
  brandBase: { color: FOUNDATION_COLORS.white },
  brandAccent: { color: FOUNDATION_COLORS.brandGreen },
  body: {
    flex: 1,
    paddingHorizontal: 20,
    justifyContent: 'center',
  },
  title: {
    color: FOUNDATION_COLORS.white,
    fontSize: 36,
    fontWeight: '800',
    letterSpacing: -0.5,
  },
  subtitle: {
    color: FOUNDATION_COLORS.muted,
    fontSize: 15,
    marginTop: 8,
    marginBottom: 24,
    lineHeight: 22,
  },
  input: {
    backgroundColor: FOUNDATION_COLORS.surface,
    marginBottom: 4,
  },
  cta: {
    marginTop: 20,
    borderRadius: 12,
  },
});
