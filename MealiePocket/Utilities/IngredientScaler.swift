import Foundation

/// Reusable utility for scaling recipe ingredients and formatting quantities.
/// Display formatting lives here; actual shopping-list scaling is handled server-side
/// via the Mealie API `scale` parameter.
enum IngredientScaler {
    
    // MARK: - Scaling
    
    /// Calculates the scale factor from original to target servings.
    static func scaleFactor(originalServings: Double?, targetServings: Double?) -> Double {
        guard let original = originalServings, original > 0,
              let target = targetServings, target > 0 else {
            return 1.0
        }
        return target / original
    }
    
    // MARK: - Display Formatting
    
    /// Formats a numeric quantity for display. Whole numbers are shown as integers,
    /// common fractions are rendered as unicode fraction characters,
    /// and other values use up to 2 decimal places.
    private static let quantityFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    static func formatQuantity(_ value: Double) -> String {
        if value == floor(value) && value < 100000 {
            return String(Int(value))
        }
        
        let whole = Int(value)
        let fractional = value - Double(whole)
        
        if let vulgar = vulgarFraction(for: fractional) {
            return whole > 0 ? "\(whole) \(vulgar)" : vulgar
        }
        
        return quantityFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2g", value)
    }
    
    /// Maps a fractional value (0..1) to a Unicode fraction character if it is
    /// within the given tolerance of a known fraction.
    static func vulgarFraction(for fractional: Double, tolerance: Double = 0.05) -> String? {
        let fractions: [(threshold: Double, symbol: String)] = [
            (1.0 / 8.0, "\u{215B}"),
            (1.0 / 6.0, "\u{2159}"),
            (1.0 / 5.0, "\u{2155}"),
            (1.0 / 4.0, "\u{00BC}"),
            (1.0 / 3.0, "\u{2153}"),
            (3.0 / 8.0, "\u{215C}"),
            (2.0 / 5.0, "\u{2156}"),
            (1.0 / 2.0, "\u{00BD}"),
            (3.0 / 5.0, "\u{2157}"),
            (5.0 / 8.0, "\u{215D}"),
            (2.0 / 3.0, "\u{2154}"),
            (3.0 / 4.0, "\u{00BE}"),
            (4.0 / 5.0, "\u{2158}"),
            (5.0 / 6.0, "\u{215A}"),
            (7.0 / 8.0, "\u{215E}"),
        ]
        
        for fraction in fractions {
            if abs(fractional - fraction.threshold) < tolerance {
                return fraction.symbol
            }
        }
        return nil
    }
}
