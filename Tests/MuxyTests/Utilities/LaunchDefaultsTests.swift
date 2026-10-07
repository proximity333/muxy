import Foundation
import Testing

@testable import Muxy

@Suite("LaunchDefaults", .serialized)
struct LaunchDefaultsTests {
    private static let suiteName = "LaunchDefaultsTests"

    private func makeDefaults() -> (defaults: UserDefaults, restore: () -> Void) {
        let defaults = UserDefaults(suiteName: Self.suiteName)!
        let originalArguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        return (
            defaults,
            {
                defaults.removePersistentDomain(forName: Self.suiteName)
                defaults.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain)
                UserDefaults.standard.removeSuite(named: Self.suiteName)
            }
        )
    }

    @Test("outranks the application domain and keeps existing launch arguments")
    func outranksApplicationDomainAndKeepsArguments() {
        let (defaults, restore) = makeDefaults()
        defer { restore() }

        defaults.set("Always", forKey: "AppleShowScrollBars")
        defaults.setVolatileDomain(["MuxyTestArgument": "kept"], forName: UserDefaults.argumentDomain)

        LaunchDefaults.useOverlayScrollers(defaults: defaults)

        #expect(defaults.string(forKey: "AppleShowScrollBars") == "WhenScrolling")
        #expect(defaults.string(forKey: "MuxyTestArgument") == "kept")
    }

    @Test("leaves the persisted application domain untouched")
    func doesNotPersistToApplicationDomain() {
        let (defaults, restore) = makeDefaults()
        defer { restore() }

        LaunchDefaults.useOverlayScrollers(defaults: defaults)

        let persisted = defaults.persistentDomain(forName: Self.suiteName)?["AppleShowScrollBars"] as? String
        #expect(persisted == nil)
    }
}
