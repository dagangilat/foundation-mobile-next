import Foundation
import Network
import Combine

/// Lightweight network reachability state, published for SwiftUI gating.
///
/// Wraps Apple's `NWPathMonitor` from the Network framework. Used by
/// HomeView to disable Verify-humanity / Connect-to-Foundation CTAs when
/// the device has no working connection, so the user gets immediate
/// "Waiting for network…" feedback instead of letting Firebase callables
/// time out 60 s into a tap.
///
/// Plan ref: P0-3 (Foundation Mobile + Backend Resilience Plan).
///
/// Why this lives at the app level rather than per-coordinator:
/// reachability is shared state — every coordinator that talks to the
/// network needs the same answer. A central singleton (1) ensures every
/// caller gets the same "is network up" reading at any instant, and
/// (2) keeps a single NWPathMonitor instance running so we're not
/// fighting the OS over cellular data wake-ups.
///
/// Quirks worth knowing:
/// - `path.status == .satisfied` does NOT mean DNS works or the
///   internet is reachable — only that an interface is up and willing
///   to route. We treat `.satisfied` as "show CTAs as enabled" and
///   let actual callables surface real failures. This matches what
///   Apple recommends; trying to ping-test would burn battery.
/// - `isExpensive` flips true on cellular when the user has Low Data
///   Mode on, or when on a personal hotspot. We surface it via a
///   separate published property so future code can opt into "save
///   bandwidth" behavior (e.g. skip MoproSmoke).
/// - `isConstrained` is the iOS Low Data Mode signal proper.
///
/// The monitor runs on its own dispatch queue; state changes are
/// republished on @MainActor so SwiftUI can observe without dispatching.
@MainActor
final class Reachability: ObservableObject {
    static let shared = Reachability()

    /// True when the OS reports a usable network path. Default `true`
    /// so the UI doesn't show a "no network" banner during the brief
    /// monitor-startup window before the first path update arrives —
    /// false-positive offline banners are worse UX than a delayed one.
    @Published private(set) var isReachable: Bool = true

    /// True when the path is metered (cellular, hotspot). Future
    /// behavior can opt into bandwidth-saving here; today this is
    /// just a published signal.
    @Published private(set) var isExpensive: Bool = false

    /// True when iOS Low Data Mode is on for the active interface.
    @Published private(set) var isConstrained: Bool = false

    /// Active interface type — useful for diagnostics in support
    /// tickets ("user reports failures on cellular") but not used
    /// for any control flow today.
    @Published private(set) var interface: NWInterface.InterfaceType? = nil

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.foundation.reachability", qos: .utility)

    private init() {
        self.monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            // Hop to MainActor for the @Published mutations. The
            // pathUpdateHandler fires on `queue`, not the main thread.
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isReachable = (path.status == .satisfied)
                self.isExpensive = path.isExpensive
                self.isConstrained = path.isConstrained
                self.interface = Self.pickInterface(from: path)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    /// Pick the most-specific available interface type. NWPath exposes
    /// `usesInterfaceType(_:)` rather than a single field; we check in
    /// priority order (wired > wifi > cellular > loopback > other).
    private static func pickInterface(from path: NWPath) -> NWInterface.InterfaceType? {
        if path.usesInterfaceType(.wiredEthernet) { return .wiredEthernet }
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.loopback) { return .loopback }
        if path.usesInterfaceType(.other) { return .other }
        return nil
    }
}
