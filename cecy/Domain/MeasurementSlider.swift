import Foundation

nonisolated enum MeasurementSliderKind {
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
    func range(system: MeasurementSystem, current: Double?, expanded: Bool) -> ClosedRange<Double> {
        let base: ClosedRange<Double>
        if expanded {
            base = display(validCanonicalRange.lowerBound, system: system)...display(validCanonicalRange.upperBound, system: system)
        } else if system == .imperial {
            base = self == .height ? 40...88 : 65...400
        } else {
            base = self == .height ? 100...220 : 30...180
        }
        let current = current.flatMap { $0.isFinite ? display($0, system: system) : nil }
        let lower = min(base.lowerBound, current ?? base.lowerBound)
        let upper = max(base.upperBound, current ?? base.upperBound)
        return lower...upper
    }
    func adjusted(_ current: Double?, system: MeasurementSystem, direction: Double) -> Double {
        let displayValue = display(current ?? suggestedCanonicalValue, system: system) + direction * step(system)
        return min(validCanonicalRange.upperBound, max(validCanonicalRange.lowerBound, canonical(displayValue, system: system)))
    }
}
