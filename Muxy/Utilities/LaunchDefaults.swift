import Foundation

enum LaunchDefaults {
    private static let showScrollBarsKey = "AppleShowScrollBars"
    private static let overlayScrollerValue = "WhenScrolling"

    static func useOverlayScrollers(defaults: UserDefaults = .standard) {
        var arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        arguments[showScrollBarsKey] = overlayScrollerValue
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
    }
}
