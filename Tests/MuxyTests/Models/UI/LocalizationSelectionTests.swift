import Foundation
import Testing

@testable import Muxy

@Suite("LocalizationSelection")
struct LocalizationSelectionTests {
    @Test("options list built-in languages first")
    func optionsIncludeBuiltins() {
        let options = LocalizationSelection.options(
            from: [],
            selectedValue: LocalizationSelection.builtinValue
        )

        #expect(options == [
            .init(
                id: LocalizationSelection.builtinValue,
                title: "English",
                isAvailable: true
            ),
            .init(
                id: LocalizationSelection.builtinPrefix + "zh-Hans",
                title: "简体中文",
                isAvailable: true
            ),
        ])
    }

    @Test("built-in languages resolve by option id")
    func builtinsResolveByOptionID() {
        let english = LocalizationSelection.builtin(forOptionID: LocalizationSelection.builtinValue)
        #expect(english?.language == "en")

        let chinese = LocalizationSelection.builtin(
            forOptionID: LocalizationSelection.builtinPrefix + "zh-Hans"
        )
        #expect(chinese?.language == "zh-Hans")

        #expect(LocalizationSelection.builtin(forOptionID: "community-de:de") == nil)
        #expect(LocalizationSelection.builtin(forOptionID: "builtin:missing") == nil)
    }

    @Test("options distinguish providers from multiple extensions")
    func optionsIncludeProviderNames() {
        let options = LocalizationSelection.options(
            from: [
                binding(extensionID: "community-de", localizationID: "de", title: "Deutsch"),
                binding(extensionID: "formal-de", localizationID: "de-formal", title: "Deutsch"),
            ],
            selectedValue: LocalizationSelection.builtinValue
        )

        #expect(options.map(\.title) == [
            "English",
            "简体中文",
            "Deutsch — community-de",
            "Deutsch — formal-de",
        ])
    }

    @Test("options preserve an unavailable provider selection")
    func optionsPreserveUnavailableProvider() {
        let selected = LocalizationSelection.value(
            extensionID: "community-de",
            localizationID: "de"
        )

        let options = LocalizationSelection.options(from: [], selectedValue: selected)

        #expect(options.last == .init(
            id: selected,
            title: "community-de (de, unavailable)",
            isAvailable: false
        ))
    }

    private func binding(
        extensionID: String,
        localizationID: String,
        title: String
    ) -> ExtensionStore.LocalizationBinding {
        let localization = ExtensionLocalization(
            id: localizationID,
            language: "de",
            title: title,
            bundle: "German.bundle"
        )
        let manifest = ExtensionManifest(
            name: extensionID,
            version: "1.0.0",
            localizations: [localization]
        )
        return ExtensionStore.LocalizationBinding(
            muxyExtension: MuxyExtension(
                id: extensionID,
                directory: URL(fileURLWithPath: "/tmp/\(extensionID)"),
                manifest: manifest
            ),
            localization: localization
        )
    }
}

