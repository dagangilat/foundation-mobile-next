import Foundation

// Stub for Task 1 — will be fleshed out in Task 3 (ProximityReader integration).
// Provides `isSupported` without importing ProximityReader so DocumentProfile.swift
// stays framework-free and compiles on iOS 16 simulators.
enum WalletDocumentReader {
    /// True when the device and OS support Apple's MobileDocumentReader API.
    /// On iOS <17 this always returns false (the API doesn't exist).
    static var isSupported: Bool {
        if #available(iOS 17, *) {
            // Real check delegated to Task 3 when ProximityReader is linked.
            // For now return false so wallet entries are hidden until Task 3 lands.
            return false
        } else {
            return false
        }
    }
}
