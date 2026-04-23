/**
 * Platform attestation wrapper.
 *
 * Phase 1 of the mobile flow. Wraps iOS App Attest and Android Play Integrity
 * behind one TS surface. The backend issues a challenge nonce, the device
 * produces a platform-signed attestation, and the backend verifies it against
 * Apple / Google public keys before trusting any downstream call.
 *
 * Why it comes before NFC+ZK: deepfake camera injection is the dominant
 * 2025–2026 attack class; platform attestation is the only layer that stops
 * it, and it's cheap to gate every Cloud Function callable on a valid token.
 */

import { NativeModules, Platform } from 'react-native';

interface IosAppAttest {
  isSupported(): Promise<boolean>;
  generateKey(): Promise<string>;
  /** Challenge must be base64-encoded. Returns base64 CBOR attestation. */
  attestKey(keyId: string, challenge: string): Promise<string>;
  /** Payload is base64-encoded; returns base64 CBOR assertion. */
  generateAssertion(keyId: string, payload: string): Promise<string>;
}

interface AndroidPlayIntegrity {
  isSupported(): Promise<boolean>;
  /** Nonce must be URL-safe base64, 16–500 chars per Google's constraints. */
  requestIntegrityToken(nonce: string): Promise<string>;
}

const AppAttestNative = NativeModules.AppAttestModule as
  | IosAppAttest
  | undefined;
const PlayIntegrityNative = NativeModules.PlayIntegrityModule as
  | AndroidPlayIntegrity
  | undefined;

export type Attestation =
  | { platform: 'ios'; keyId: string; attestation: string }
  | { platform: 'android'; token: string };

export async function isAttestationSupported(): Promise<boolean> {
  if (Platform.OS === 'ios') {
    if (!AppAttestNative) return false;
    return AppAttestNative.isSupported();
  }
  if (Platform.OS === 'android') {
    if (!PlayIntegrityNative) return false;
    return PlayIntegrityNative.isSupported();
  }
  return false;
}

export async function attestDevice(
  challenge: string,
): Promise<Attestation> {
  if (Platform.OS === 'ios') {
    if (!AppAttestNative) {
      throw new Error('AppAttestModule not linked');
    }
    const supported = await AppAttestNative.isSupported();
    if (!supported) {
      throw new Error(
        'App Attest unsupported (simulator, unsigned build, or iOS < 14)',
      );
    }
    const keyId = await AppAttestNative.generateKey();
    const attestation = await AppAttestNative.attestKey(keyId, challenge);
    return { platform: 'ios', keyId, attestation };
  }
  if (Platform.OS === 'android') {
    if (!PlayIntegrityNative) {
      throw new Error('PlayIntegrityModule not linked');
    }
    const token = await PlayIntegrityNative.requestIntegrityToken(challenge);
    return { platform: 'android', token };
  }
  throw new Error(`Platform attestation not implemented for ${Platform.OS}`);
}

/**
 * iOS-only: sign a request payload with a previously-attested key.
 * Call once per protected backend request after the initial attestation.
 */
export async function assertIos(
  keyId: string,
  payloadB64: string,
): Promise<string> {
  if (Platform.OS !== 'ios' || !AppAttestNative) {
    throw new Error('generateAssertion only available on iOS');
  }
  return AppAttestNative.generateAssertion(keyId, payloadB64);
}
