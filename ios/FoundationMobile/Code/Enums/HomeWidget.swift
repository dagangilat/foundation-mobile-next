import SwiftUI

/// Home-screen widgets.
///
/// Task B5 stripped the upstream-ecosystem widgets (token earning, Freedom
/// Tool voting, Hidden Keys, Digital Likeness) together with the modules behind
/// them. Identity recovery is the one widget whose product is ours to keep.
enum HomeWidget: String, Hashable, CaseIterable {
    case recovery
}

extension HomeWidget {
    var title: String {
        switch self {
        case .recovery: String(localized: "Recovery Method")
        }
    }

    var description: String {
        switch self {
        case .recovery: String(localized: "Set up a new way to recover\nyour account")
        }
    }
}

extension HomeWidget {
    var image: ImageResource {
        switch self {
        case .recovery: .recoveryWidget
        }
    }
}

extension HomeWidget {
    var isVisible: Bool {
        switch self {
        case .recovery: return true
        }
    }

    var isManageable: Bool {
        switch self {
        case .recovery: return true
        }
    }

    var isRemovable: Bool {
        switch self {
        case .recovery: return false
        }
    }
}
