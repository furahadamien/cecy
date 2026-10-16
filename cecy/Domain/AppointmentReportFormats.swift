import Foundation
import UIKit

nonisolated enum AppointmentReportFormat: String, CaseIterable, Sendable {
    case text, csv, pdf
    var title: String { rawValue.uppercased() }
    var fileExtension: String { rawValue }
}

nonisolated enum AppointmentReportCSV {
    static func encode(_ document: AppointmentSummaryDocument) -> Data {
        var rows = [["section", "entry"]]
        rows.append(["REPORT", document.title])
        rows.append(["DATE RANGE", document.dateRange])
        rows.append(["NOTICE", document.notice])
        for section in document.sections {
            rows += section.lines.map { [section.kind.rawValue, $0] }
        }
        let text = rows.map { $0.map(escape).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
        return Data(text.utf8)
    }

    private static func escape(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

@MainActor enum AppointmentReportPDF {
    static func encode(_ document: AppointmentSummaryDocument) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 48
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: format(document))
        return renderer.pdfData { context in
            var y: CGFloat = margin
            func newPage() { context.beginPage(); y = margin }
            func draw(_ text: String, font: UIFont, color: UIColor = .label, spacing: CGFloat = 8) {
                let style = NSMutableParagraphStyle(); style.lineSpacing = 3
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
                let width = page.width - margin * 2
                let height = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil).height.rounded(.up)
                if y + height > page.height - margin { newPage() }
                (text as NSString).draw(with: CGRect(x: margin, y: y, width: width, height: height),
                    options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
                y += height + spacing
            }

            newPage()
            draw(document.title, font: .boldSystemFont(ofSize: 22))
            draw(document.dateRange, font: .boldSystemFont(ofSize: 13), color: .darkGray)
            draw(document.notice, font: .systemFont(ofSize: 11), color: .darkGray, spacing: 18)
            for section in document.sections {
                draw(section.kind.rawValue, font: .boldSystemFont(ofSize: 14), spacing: 10)
                for line in section.lines { draw(line, font: .systemFont(ofSize: 11), spacing: 6) }
                y += 12
            }
        }
    }

    private static func format(_ document: AppointmentSummaryDocument) -> UIGraphicsPDFRendererFormat {
        let value = UIGraphicsPDFRendererFormat()
        value.documentInfo = [kCGPDFContextTitle as String: document.title,
                              kCGPDFContextCreator as String: "Cecy",
                              kCGPDFContextSubject as String: "User-selected appointment report with text alternatives for trends"]
        return value
    }
}
