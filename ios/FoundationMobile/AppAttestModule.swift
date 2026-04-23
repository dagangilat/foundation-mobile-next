import Foundation
import DeviceCheck
import CryptoKit
import React

/// App Attest native module.
///
/// Phase 1 of the mobile flow. iOS provides DCAppAttestService for platform
/// attestation — proves the request comes from a genuine, unmodified build of
/// our app on a real device. Blocks the deepfake camera-injection attack class
/// that OSS liveness pipelines can't defeat on their own.
///
/// Flow:
///   1. Backend issues a random challenge nonce.
///   2. generateKey() produces a Secure-Enclave-backed key and returns its id.
///   3. attestKey(keyId, challenge) returns the CBOR attestation object,
///      which the backend verifies against Apple's App Attest public keys.
///   4. Subsequent calls use assertKey(keyId, payload) to sign server requests.
@objc(AppAttestModule)
class AppAttestModule: NSObject {

  @objc static func requiresMainQueueSetup() -> Bool { false }

  @objc(isSupported:rejecter:)
  func isSupported(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    resolve(DCAppAttestService.shared.isSupported)
  }

  @objc(generateKey:rejecter:)
  func generateKey(
    _ resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    let service = DCAppAttestService.shared
    guard service.isSupported else {
      reject("E_UNSUPPORTED", "App Attest is not supported on this device", nil)
      return
    }
    service.generateKey { keyId, error in
      if let error = error {
        reject("E_GENERATE_KEY", error.localizedDescription, error)
        return
      }
      guard let keyId = keyId else {
        reject("E_GENERATE_KEY", "No key id returned", nil)
        return
      }
      resolve(keyId)
    }
  }

  @objc(attestKey:challenge:resolver:rejecter:)
  func attestKey(
    _ keyId: String,
    challenge: String,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    guard let challengeData = Data(base64Encoded: challenge) else {
      reject("E_INVALID_CHALLENGE", "Challenge must be base64-encoded", nil)
      return
    }
    let clientDataHash = Data(SHA256.hash(data: challengeData))
    DCAppAttestService.shared.attestKey(keyId, clientDataHash: clientDataHash) {
      attestationObject, error in
      if let error = error {
        reject("E_ATTEST", error.localizedDescription, error)
        return
      }
      guard let attestationObject = attestationObject else {
        reject("E_ATTEST", "No attestation returned", nil)
        return
      }
      resolve(attestationObject.base64EncodedString())
    }
  }

  @objc(generateAssertion:payload:resolver:rejecter:)
  func generateAssertion(
    _ keyId: String,
    payload: String,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    guard let payloadData = Data(base64Encoded: payload) else {
      reject("E_INVALID_PAYLOAD", "Payload must be base64-encoded", nil)
      return
    }
    let clientDataHash = Data(SHA256.hash(data: payloadData))
    DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: clientDataHash) {
      assertion, error in
      if let error = error {
        reject("E_ASSERT", error.localizedDescription, error)
        return
      }
      guard let assertion = assertion else {
        reject("E_ASSERT", "No assertion returned", nil)
        return
      }
      resolve(assertion.base64EncodedString())
    }
  }
}
