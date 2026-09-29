import Foundation
import SwiftUI

@MainActor
@Observable
final class LocalizationService {
    static let shared = LocalizationService()

    private(set) var activeSelection = LocalizationSelection.builtinValue
    private(set) var locale = Locale(identifier: "en")
    private(set) var bundleURL: URL?

    private let defaults: UserDefaults
    private var searchStringCache: [String: String] = [:]
    private var stringTable: [String: String] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func select(_ value: String, store: ExtensionStore = .shared) {
        defaults.set(value, forKey: LocalizationSelection.storageKey)
        refresh(store: store)
    }

    func refresh(store: ExtensionStore = .shared) {
        let storedValue = defaults.string(forKey: LocalizationSelection.storageKey)
            ?? LocalizationSelection.builtinValue
        refresh(storedValue: storedValue, bindings: store.localizations())
    }

    func refresh(
        storedValue: String,
        bindings: [ExtensionStore.LocalizationBinding]
    ) {
        searchStringCache.removeAll(keepingCapacity: true)
        let previousSelection = activeSelection
        let previousLocale = locale
        let previousBundleURL = bundleURL
        if let builtin = LocalizationSelection.builtin(forOptionID: storedValue) {
            activeSelection = builtin.optionID
            locale = Locale(identifier: builtin.language)
            bundleURL = builtin.language == "en" ? nil : Bundle.appResources.bundleURL
        } else if let identifier = LocalizationSelection.parse(storedValue),
                  let binding = bindings.first(where: {
                      $0.muxyExtension.id == identifier.extensionID
                          && $0.localization.id == identifier.localizationID
                  }),
                  let resolvedBundleURL = binding.bundleURL
        {
            activeSelection = binding.id
            locale = Locale(identifier: binding.localization.language)
            bundleURL = resolvedBundleURL
        } else {
            activeSelection = LocalizationSelection.builtinValue
            locale = Locale(identifier: "en")
            bundleURL = nil
        }
        loadStringTable()
        postChangeIfNeeded(
            previousSelection: previousSelection,
            previousLocale: previousLocale,
            previousBundleURL: previousBundleURL
        )
    }

    private func loadStringTable() {
        stringTable.removeAll(keepingCapacity: true)
        guard let bundleURL, let bundle = Bundle(url: bundleURL) else { return }
        stringTable = Self.loadTable(from: bundle, language: locale.identifier)
    }

    private static func loadTable(from bundle: Bundle, language: String) -> [String: String] {
        guard let catalog = bundle.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: nil,
            forLocalization: language
        ),
            let table = NSDictionary(contentsOfFile: catalog) as? [String: String]
        else { return [:] }
        return table
    }

    func resource(_ resource: LocalizedStringResource) -> LocalizedStringResource {
        var translated = LocalizedStringResource(stringLiteral: resolve(resource))
        translated.locale = locale
        return translated
    }

    func string(_ resource: LocalizedStringResource) -> String {
        resolve(resource)
    }

    private func resolve(_ resource: LocalizedStringResource) -> String {
        if let translation = pretranslated(for: resource) {
            return translation
        }
        guard let bundleURL else {
            var fallback = resource
            fallback.locale = locale
            return String(localized: fallback)
        }
        let translated = LocalizedStringResource(
            resource.defaultValue,
            table: resource.table,
            locale: locale,
            bundle: .atURL(bundleURL)
        )
        return String(localized: translated)
    }

    private func pretranslated(for resource: LocalizedStringResource) -> String? {
        guard resource.table == nil else { return nil }
        guard resource.defaultValue == String.LocalizationValue(resource.key) else { return nil }
        return stringTable[resource.key]
    }

    func searchString(key: String) -> String {
        if let cached = searchStringCache[key] {
            return cached
        }
        let value = string(LocalizedStringResource(String.LocalizationValue(key)))
        searchStringCache[key] = value
        return value
    }

    private func postChangeIfNeeded(
        previousSelection: String,
        previousLocale: Locale,
        previousBundleURL: URL?
    ) {
        guard previousSelection != activeSelection
            || previousLocale.identifier != locale.identifier
            || previousBundleURL != bundleURL
        else { return }
        NotificationCenter.default.post(name: .localizationDidChange, object: self)
    }
}

@MainActor
enum LocalizedSearch {
    static func matches(
        query: String,
        localizedKeys: [String] = [],
        verbatimValues: [String] = [],
        localization: LocalizationService = .shared
    ) -> Bool {
        let normalizedQuery = normalize(query, locale: localization.locale)
        guard !normalizedQuery.isEmpty else { return true }
        let localizedValues = localizedKeys.flatMap { key in
            [key, localization.searchString(key: key)]
        }
        let searchableText = (localizedValues + verbatimValues)
            .map { normalize($0, locale: localization.locale) }
            .joined(separator: " ")
        return searchableText.contains(normalizedQuery)
    }

    private static func normalize(_ value: String, locale: Locale) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: locale
            )
    }
}

@MainActor
enum L10n {
    static func resource(_ resource: LocalizedStringResource) -> LocalizedStringResource {
        LocalizationService.shared.resource(resource)
    }

    static func resource(key: String) -> LocalizedStringResource {
        resource(LocalizedStringResource(String.LocalizationValue(key)))
    }

    static func string(_ resource: LocalizedStringResource) -> String {
        LocalizationService.shared.string(resource)
    }

    static func string(key: String) -> String {
        string(LocalizedStringResource(String.LocalizationValue(key)))
    }
}

struct LocalizationEnvironment<Content: View>: View {
    @State private var localizationService = LocalizationService.shared
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .environment(localizationService)
            .environment(\.locale, localizationService.locale)
    }
}
