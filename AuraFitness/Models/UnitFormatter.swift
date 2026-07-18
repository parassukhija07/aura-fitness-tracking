import Foundation

/// Central, stateless conversion + formatting utility for weight/length unit preferences.
/// Canonical storage: weight in kg, length in cm. No new settings, no state — the caller
/// passes in the current unit preference string (`appState.weightUnit` / `appState.lengthUnit`).
enum UnitFormatter {

    static let kgPerLb: Double = 0.45359237
    static let cmPerInch: Double = 2.54

    // MARK: - WEIGHT (canonical = kg)

    /// Convert canonical kg to the display unit's numeric value.
    static func weightValue(_ kg: Double, unit: String) -> Double {
        unit == "lb" ? kg / kgPerLb : kg
    }

    /// Formatted number only (no unit suffix). Precision: 1 decimal, trimmed if whole.
    static func weightNumber(_ kg: Double, unit: String) -> String {
        formatTrimmed(weightValue(kg, unit: unit))
    }

    /// Formatted "<number> <unit>" e.g. "220 lb" / "100 kg".
    static func weight(_ kg: Double, unit: String) -> String {
        "\(weightNumber(kg, unit: unit)) \(unit)"
    }

    /// Parse a user-typed string in `unit` back to canonical kg. Returns nil on empty/invalid.
    static func parseWeightToKg(_ text: String, unit: String) -> Double? {
        guard let value = Double(text) else { return nil }
        return unit == "lb" ? value * kgPerLb : value
    }

    // MARK: - LENGTH (canonical = cm)

    static func lengthValue(_ cm: Double, unit: String) -> Double {
        unit == "in" ? cm / cmPerInch : cm
    }

    static func lengthNumber(_ cm: Double, unit: String) -> String {
        formatTrimmed(lengthValue(cm, unit: unit))
    }

    static func length(_ cm: Double, unit: String) -> String {
        "\(lengthNumber(cm, unit: unit)) \(unit)"
    }

    static func parseLengthToCm(_ text: String, unit: String) -> Double? {
        guard let value = Double(text) else { return nil }
        return unit == "in" ? value * cmPerInch : value
    }

    // MARK: - Bare suffix

    /// Bare display suffix, echoing the pref (used where only the label is needed).
    static func weightSuffix(_ unit: String) -> String { unit }
    static func lengthSuffix(_ unit: String) -> String { unit }

    // MARK: - Private helpers

    private static func formatTrimmed(_ value: Double) -> String {
        let formatted = String(format: "%.1f", value)
        return formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
    }
}
