import AppKit
import Foundation
import StornautCore
import SwiftUI
import Testing

@testable import StornautApp

enum SnapshotAppearance: String, CaseIterable, Sendable {
    case light
    case dark

    var nsAppearance: NSAppearance? {
        switch self {
        case .light:
            NSAppearance(named: .aqua)
        case .dark:
            NSAppearance(named: .darkAqua)
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

enum SnapshotLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    /// `StornautLocalization` keeps the selected language in process-global
    /// mutable state, and `StornautByteFormatter` reads it by default. A
    /// snapshot that only injected `\.locale` would render whichever language
    /// an earlier test happened to leave behind.
    var settingsLanguage: SettingsLanguage {
        switch self {
        case .english:
            .english
        case .simplifiedChinese:
            .simplifiedChinese
        }
    }
}

struct SnapshotVariant: Sendable, CustomStringConvertible {
    let appearance: SnapshotAppearance
    let language: SnapshotLanguage

    /// Every appearance against every language. Worth the goldens for shared
    /// components, where a translation length change is the likeliest cause
    /// of a layout break.
    static let fullMatrix: [SnapshotVariant] = SnapshotAppearance.allCases
        .flatMap { appearance in
            SnapshotLanguage.allCases.map {
                SnapshotVariant(appearance: appearance, language: $0)
            }
        }

    /// Both extremes without paying for the cross product on every page
    /// state. Pages are large, and the appearance/language interaction is
    /// already covered in detail by the component suite.
    static let diagonal: [SnapshotVariant] = [
        SnapshotVariant(appearance: .light, language: .english),
        SnapshotVariant(appearance: .dark, language: .simplifiedChinese),
    ]

    var description: String {
        "\(appearance.rawValue)/\(language.rawValue)"
    }
}

enum SnapshotError: Error, CustomStringConvertible {
    case allocationFailed
    case encodingFailed
    case decodingFailed(String)
    case missingGolden(String)
    case sizeMismatch(String, expected: String, actual: String)
    case languageRaced(expected: String)

    var description: String {
        switch self {
        case .allocationFailed:
            "Could not allocate the off-screen bitmap."
        case .encodingFailed:
            "Could not encode the rendered bitmap as PNG."
        case let .decodingFailed(name):
            "Could not decode the stored golden \(name)."
        case let .missingGolden(name):
            """
            Missing golden \(name). Record it with \
            STORNAUT_RECORD_SNAPSHOTS=1.
            """
        case let .sizeMismatch(name, expected, actual):
            "Golden \(name) is \(expected) but the render is \(actual)."
        case let .languageRaced(expected):
            """
            Another suite changed the process-global language while rendering \
            \(expected). Mark the interfering suite `.serialized` or stop it \
            from writing StornautLocalization.
            """
        }
    }
}

/// Off-screen view snapshots.
///
/// Rendering goes through a free-standing `NSHostingView` rather than an
/// `NSWindow`, so results do not depend on a title bar, an active display or
/// the host's backing scale factor. The bitmap is always allocated at 1x.
@MainActor
enum SnapshotHarness {
    /// A pixel counts as different when any channel moves further than this.
    /// Text antialiasing routinely moves a channel by one or two levels.
    nonisolated static let channelTolerance = 2

    /// Share of differing pixels that still passes. Real layout regressions
    /// move far more than this; antialiasing noise stays well below it.
    nonisolated static let differingPixelRatioTolerance = 0.001

    static var isRecording: Bool {
        ProcessInfo.processInfo.environment["STORNAUT_RECORD_SNAPSHOTS"] == "1"
    }

    static var goldenDirectory: URL {
        repositoryRoot.appending(
            path: "Tests/Fixtures/Snapshots",
            directoryHint: .isDirectory
        )
    }

    /// The view is built lazily on purpose. Views such as `OverviewView`
    /// capture a `StornautByteFormatter` in a stored property, which reads the
    /// process-global language at construction time, so the language has to be
    /// pinned before the view exists.
    static func verify(
        _ view: @autoclosure () -> some View,
        named name: String,
        size: CGSize,
        variant: SnapshotVariant,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let appearance = variant.appearance
        let language = variant.language
        let identifier = "\(name).\(appearance.rawValue).\(language.rawValue)"
        let rendered = try render(
            view(),
            size: size,
            appearance: appearance,
            language: language
        )
        let goldenURL = goldenDirectory.appending(path: "\(identifier).png")

        guard FileManager.default.fileExists(atPath: goldenURL.path) else {
            guard isRecording else {
                throw SnapshotError.missingGolden(identifier)
            }
            try write(rendered, to: goldenURL)
            Issue.record(
                "Recorded a new golden for \(identifier).",
                sourceLocation: sourceLocation
            )
            return
        }

        let golden = try Data(contentsOf: goldenURL)
        let comparison = try compare(
            golden: golden,
            rendered: rendered,
            identifier: identifier
        )

        guard comparison.exceedsTolerance else { return }

        if isRecording {
            try write(rendered, to: goldenURL)
            Issue.record(
                "Re-recorded \(identifier).",
                sourceLocation: sourceLocation
            )
            return
        }

        Attachment.record(golden, named: "\(identifier).golden.png")
        Attachment.record(rendered, named: "\(identifier).actual.png")
        if let difference = comparison.differenceImage {
            Attachment.record(
                difference,
                named: "\(identifier).difference.png"
            )
        }

        Issue.record(
            """
            \(identifier) drifted from its golden: \
            \(comparison.differingPixelCount) of \(comparison.pixelCount) \
            pixels differ (\(percentage(comparison.differingPixelRatio))), \
            largest channel delta \(comparison.maximumChannelDelta). \
            Inspect the attached golden, actual and difference images, then \
            re-record with STORNAUT_RECORD_SNAPSHOTS=1 once the change is \
            intended.
            """,
            sourceLocation: sourceLocation
        )
    }

    static func render(
        _ view: @autoclosure () -> some View,
        size: CGSize,
        appearance: SnapshotAppearance,
        language: SnapshotLanguage
    ) throws -> Data {
        // `StornautLocalization` has no reader, so restore the process default
        // rather than the previous value; the snapshot suites are `.serialized`
        // and always pin the language themselves before rendering.
        defer { StornautLocalization.apply(.english) }
        StornautLocalization.apply(language.settingsLanguage)

        let content = view()
            .environment(\.colorScheme, appearance.colorScheme)
            .environment(\.locale, language.locale)
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))

        let hostingView = NSHostingView(rootView: AnyView(content))
        hostingView.appearance = appearance.nsAppearance
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        guard
            let representation = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width),
                pixelsHigh: Int(size.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            throw SnapshotError.allocationFailed
        }

        representation.size = size
        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)

        guard
            let data = representation.representation(
                using: .png,
                properties: [:]
            )
        else {
            throw SnapshotError.encodingFailed
        }

        // `StornautAppModel` also writes the process-global language, so a
        // suite running alongside this one could retarget the render midway.
        // Fail loudly instead of recording a golden in the wrong language.
        guard StornautLocalization.locale == language.locale else {
            throw SnapshotError.languageRaced(expected: language.rawValue)
        }
        return data
    }

    struct Comparison {
        let pixelCount: Int
        let differingPixelCount: Int
        let maximumChannelDelta: Int
        let differenceImage: Data?

        var differingPixelRatio: Double {
            pixelCount == 0
                ? 0
                : Double(differingPixelCount) / Double(pixelCount)
        }

        var exceedsTolerance: Bool {
            differingPixelRatio > differingPixelRatioTolerance
        }
    }

    static func compare(
        golden: Data,
        rendered: Data,
        identifier: String
    ) throws -> Comparison {
        guard
            let goldenImage = NSBitmapImageRep(data: golden),
            let renderedImage = NSBitmapImageRep(data: rendered)
        else {
            throw SnapshotError.decodingFailed(identifier)
        }

        let width = goldenImage.pixelsWide
        let height = goldenImage.pixelsHigh

        guard
            width == renderedImage.pixelsWide,
            height == renderedImage.pixelsHigh
        else {
            throw SnapshotError.sizeMismatch(
                identifier,
                expected: "\(width)x\(height)",
                actual: """
                    \(renderedImage.pixelsWide)x\(renderedImage.pixelsHigh)
                    """
            )
        }

        guard
            let goldenPixels = goldenImage.bitmapData,
            let renderedPixels = renderedImage.bitmapData
        else {
            throw SnapshotError.decodingFailed(identifier)
        }

        let goldenStride = goldenImage.bytesPerRow
        let renderedStride = renderedImage.bytesPerRow
        let goldenSamples = goldenImage.samplesPerPixel
        let renderedSamples = renderedImage.samplesPerPixel
        let comparedChannels = min(goldenSamples, renderedSamples, 4)

        var differingPixelCount = 0
        var maximumChannelDelta = 0
        var difference = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let goldenOffset = y * goldenStride + x * goldenSamples
                let renderedOffset = y * renderedStride + x * renderedSamples
                var pixelDelta = 0

                for channel in 0..<comparedChannels {
                    let delta = abs(
                        Int(goldenPixels[goldenOffset + channel])
                            - Int(renderedPixels[renderedOffset + channel])
                    )
                    pixelDelta = max(pixelDelta, delta)
                }

                maximumChannelDelta = max(maximumChannelDelta, pixelDelta)
                let differenceOffset = (y * width + x) * 4

                if pixelDelta > channelTolerance {
                    differingPixelCount += 1
                    difference[differenceOffset] = 255
                    difference[differenceOffset + 1] = 0
                    difference[differenceOffset + 2] = 0
                    difference[differenceOffset + 3] = 255
                } else {
                    // Keep unchanged areas visible but muted so the red
                    // regressions read at a glance.
                    let luminance =
                        UInt8(
                            Int(goldenPixels[goldenOffset]) / 3 + 160
                        )
                    difference[differenceOffset] = luminance
                    difference[differenceOffset + 1] = luminance
                    difference[differenceOffset + 2] = luminance
                    difference[differenceOffset + 3] = 255
                }
            }
        }

        return Comparison(
            pixelCount: width * height,
            differingPixelCount: differingPixelCount,
            maximumChannelDelta: maximumChannelDelta,
            differenceImage: differingPixelCount == 0
                ? nil
                : pngData(from: difference, width: width, height: height)
        )
    }

    private static func pngData(
        from pixels: [UInt8],
        width: Int,
        height: Int
    ) -> Data? {
        var mutablePixels = pixels
        return mutablePixels.withUnsafeMutableBufferPointer { buffer in
            var planes: [UnsafeMutablePointer<UInt8>?] = [buffer.baseAddress]
            guard
                let representation = NSBitmapImageRep(
                    bitmapDataPlanes: &planes,
                    pixelsWide: width,
                    pixelsHigh: height,
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .deviceRGB,
                    bytesPerRow: width * 4,
                    bitsPerPixel: 32
                )
            else {
                return nil
            }
            return representation.representation(using: .png, properties: [:])
        }
    }

    private static func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    private static func percentage(_ ratio: Double) -> String {
        String(format: "%.4f%%", ratio * 100)
    }

    private static var repositoryRoot: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
