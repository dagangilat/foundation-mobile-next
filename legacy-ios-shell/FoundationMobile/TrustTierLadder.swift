import Foundation

enum RungStatus { case done, current, locked }

struct LadderRung: Equatable {
    let tier: AppConfig.Profile.TrustTier
    let status: RungStatus
}

// Ladder rows for the verified screen, highest first. Rungs below the achieved
// tier are cleared (.done); the achieved tier is .current; higher tiers are
// .locked (which drives the upgrade hint). Pure logic, unit-tested; VerifiedView
// renders the result.
enum TrustTierLadder {
    static func rungs(achieved: AppConfig.Profile.TrustTier) -> [LadderRung] {
        let order: [AppConfig.Profile.TrustTier] = [.high, .standard, .low]
        return order.map { tier in
            let status: RungStatus = tier == achieved ? .current
                                   : (tier < achieved ? .done : .locked)
            return LadderRung(tier: tier, status: status)
        }
    }
}
