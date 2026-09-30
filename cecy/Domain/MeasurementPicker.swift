import Foundation

nonisolated enum MeasurementPickerKind {
    case height, weight

    var title: String { self == .height ? "Height" : "Weight" }
    var identifier: String { self == .height ? "profileHeight" : "profileWeight" }
    var suggestedCanonicalValue: Double { self == .height ? 170 : 65 }
    var validCanonicalRange: ClosedRange<Double> { self == .height ? 1...300 : 1...1000 }

    func unit(_ system: MeasurementSystem) -> String {
        self == .height ? (system == .metric ? "cm" : "in") : (system == .metric ? "kg" : "lb")
    }
    func step(_ system: MeasurementSystem) -> Double {
        self == .height ? (system == .metric ? 1 : 0.5) : (system == .metric ? 0.5 : 1)
    }
    func display(_ value: Double, system: MeasurementSystem) -> Double {
        self == .height ? system.heightForDisplay(value) : system.weightForDisplay(value)
    }
    func canonical(_ value: Double, system: MeasurementSystem) -> Double {
        self == .height ? system.heightInCentimeters(value) : system.weightInKilograms(value)
    }
    /// Integer tags avoid floating-point selection mismatches in wheel pickers.
    func indices(system: MeasurementSystem) -> ClosedRange<Int> {
        let lower = Int(ceil(display(validCanonicalRange.lowerBound, system: system) / step(system)))
        let upper = Int(floor(display(validCanonicalRange.upperBound, system: system) / step(system)))
        return lower...upper
    }
    func index(for value: Double, system: MeasurementSystem) -> Int {
        let range = indices(system: system)
        let safeValue = value.isFinite ? value : suggestedCanonicalValue
        let bounded = min(validCanonicalRange.upperBound, max(validCanonicalRange.lowerBound, safeValue))
        return min(range.upperBound, max(range.lowerBound, Int((display(bounded, system: system) / step(system)).rounded())))
    }
    func value(at index: Int, system: MeasurementSystem) -> Double {
        canonical(Double(index) * step(system), system: system)
    }
    func formatted(_ canonicalValue: Double, system: MeasurementSystem) -> String {
        let value = display(canonicalValue, system: system)
        if self == .height && system == .imperial {
            // Round before splitting so 11.99 inches carries into the next foot.
            let totalInches = (value * 2).rounded() / 2
            let feet = Int(totalInches / 12)
            let inches = totalInches - Double(feet * 12)
            return "\(feet) ft \(inches.formatted(.number.precision(.fractionLength(0...1)))) in"
        }
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit(system))"
    }
}
