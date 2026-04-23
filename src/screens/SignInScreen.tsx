import React, { useState } from 'react';
import { StyleSheet, View } from 'react-native';
import {
  Button,
  Text,
  TextInput,
  HelperText,
  Surface,
} from 'react-native-paper';
import { sendSignInLink } from '../lib/auth';

export function SignInScreen() {
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
    <Surface style={styles.root}>
      <View style={styles.card}>
        <Text variant="headlineMedium">Sign in</Text>
        <Text variant="bodyMedium" style={styles.sub}>
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
          style={styles.input}
          disabled={status === 'sending' || status === 'sent'}
        />

        {status === 'error' ? (
          <HelperText type="error" visible>
            {errorText}
          </HelperText>
        ) : null}

        {status === 'sent' ? (
          <HelperText type="info" visible>
            Link sent. Open it on this device to finish signing in.
          </HelperText>
        ) : null}

        <Button
          mode="contained"
          onPress={submit}
          loading={status === 'sending'}
          disabled={!email || status === 'sending' || status === 'sent'}
          style={styles.cta}
        >
          Send sign-in link
        </Button>
      </View>
    </Surface>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  card: {
    flex: 1,
    padding: 24,
    justifyContent: 'center',
  },
  sub: { marginTop: 8, marginBottom: 24, opacity: 0.7 },
  input: { marginBottom: 8 },
  cta: { marginTop: 16 },
});
