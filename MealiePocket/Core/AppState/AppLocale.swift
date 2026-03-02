import Foundation

enum AppLocale {
    private(set) static var bundle: Bundle = {
        let code = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "system"
        return resolvedBundle(for: code)
    }()

    static func update(languageCode: String) {
        bundle = resolvedBundle(for: languageCode)
    }

    private static func resolvedBundle(for languageCode: String) -> Bundle {
        guard languageCode != "system",
              let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let b = Bundle(path: path) else {
            return .main
        }
        return b
    }
}
