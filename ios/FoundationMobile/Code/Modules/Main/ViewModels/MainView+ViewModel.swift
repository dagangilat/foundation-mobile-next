import SwiftUI

enum MainTabs: Int, CaseIterable {
    case home, identity, scanQr, profile

    var iconName: ImageResource {
        switch self {
        case .home: .homeLine
        case .identity: .passportLine
        case .scanQr: .qrScan2Line
        case .profile: .userLine
        }
    }

    var activeIconName: ImageResource {
        switch self {
        case .home: .homeFill
        case .identity: .passportFill
        case .scanQr: .qrScan2Line
        case .profile: .userFill
        }
    }
}

extension MainView {
    class ViewModel: ObservableObject {
        @Published var selectedTab: MainTabs = .home
        @Published var isQrCodeScanSheetShown = false

        func selectTab(_ tab: MainTabs) {
            selectedTab = tab
        }
    }
}
