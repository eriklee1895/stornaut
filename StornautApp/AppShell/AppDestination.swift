import SwiftUI

enum AppDestination: String, CaseIterable, Identifiable, Sendable {
    case overview
    case scan
    case investigations
    case history

    var id: Self { self }

    var localizationKey: String {
        switch self {
        case .overview:
            "destination.overview"
        case .scan:
            "destination.scan"
        case .investigations:
            "destination.investigations"
        case .history:
            "destination.history"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .overview:
            "destination.overview"
        case .scan:
            "destination.scan"
        case .investigations:
            "destination.investigations"
        case .history:
            "destination.history"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            "chart.pie"
        case .scan:
            StornautSystemImage.quickScan
        case .investigations:
            "scope"
        case .history:
            "clock.arrow.trianglehead.counterclockwise.rotate.90"
        }
    }
}
