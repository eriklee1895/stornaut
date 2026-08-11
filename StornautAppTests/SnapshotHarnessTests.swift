import AppKit
import Foundation
import SwiftUI
import Testing

@testable import StornautApp

@MainActor
@Suite("Snapshot harness", .serialized)
struct SnapshotHarnessTests {
    @Test
    func renderRestoresThePreviousProcessLanguage() throws {
        defer { StornautLocalization.apply(.english) }
        StornautLocalization.apply(.simplifiedChinese)

        _ = try SnapshotHarness.render(
            Text(verbatim: "snapshot"),
            size: CGSize(width: 80, height: 30),
            appearance: .light,
            language: .english
        )

        #expect(StornautLocalization.locale.identifier == "zh-Hans")
    }

    @Test
    func missingGoldenExplainsTheXcodeTestRunnerEnvironmentVariable() {
        let message = SnapshotError.missingGolden("fixture").description

        #expect(
            message.contains(
                "TEST_RUNNER_STORNAUT_RECORD_SNAPSHOTS=1"
            )
        )
    }

    @Test
    func identicalImagesHaveNoDifferenceArtifact() throws {
        let image = try png(width: 2, height: 1)

        let comparison = try SnapshotHarness.compare(
            golden: image,
            rendered: image,
            identifier: "identical"
        )

        #expect(comparison.pixelCount == 2)
        #expect(comparison.differingPixelCount == 0)
        #expect(comparison.maximumChannelDelta == 0)
        #expect(comparison.differenceImage == nil)
        #expect(!comparison.exceedsTolerance)
    }

    @Test
    func channelToleranceIsInclusive() throws {
        let golden = try png(width: 1, height: 1)
        let rendered = try png(width: 1, height: 1, redValues: [0: 2])

        let comparison = try SnapshotHarness.compare(
            golden: golden,
            rendered: rendered,
            identifier: "channel-tolerance"
        )

        #expect(comparison.maximumChannelDelta == 2)
        #expect(comparison.differingPixelCount == 0)
        #expect(!comparison.exceedsTolerance)
    }

    @Test
    func aChannelDeltaAboveToleranceProducesADifference() throws {
        let golden = try png(width: 1, height: 1)
        let rendered = try png(width: 1, height: 1, redValues: [0: 3])

        let comparison = try SnapshotHarness.compare(
            golden: golden,
            rendered: rendered,
            identifier: "channel-difference"
        )

        #expect(comparison.maximumChannelDelta == 3)
        #expect(comparison.differingPixelCount == 1)
        #expect(comparison.differenceImage != nil)
        #expect(comparison.exceedsTolerance)
    }

    @Test
    func differingPixelRatioToleranceIsInclusive() throws {
        let golden = try png(width: 1_000, height: 1)
        let atTolerance = try png(
            width: 1_000,
            height: 1,
            redValues: [0: 3]
        )
        let aboveTolerance = try png(
            width: 1_000,
            height: 1,
            redValues: [0: 3, 1: 3]
        )

        let passing = try SnapshotHarness.compare(
            golden: golden,
            rendered: atTolerance,
            identifier: "ratio-at-tolerance"
        )
        let failing = try SnapshotHarness.compare(
            golden: golden,
            rendered: aboveTolerance,
            identifier: "ratio-above-tolerance"
        )

        #expect(passing.differingPixelRatio == 0.001)
        #expect(!passing.exceedsTolerance)
        #expect(failing.differingPixelRatio == 0.002)
        #expect(failing.exceedsTolerance)
    }

    @Test
    func invalidPNGThrowsAComparisonError() throws {
        let image = try png(width: 1, height: 1)

        #expect(throws: SnapshotError.self) {
            _ = try SnapshotHarness.compare(
                golden: Data("not a png".utf8),
                rendered: image,
                identifier: "invalid"
            )
        }
    }

    @Test
    func differentImageDimensionsThrowAComparisonError() throws {
        let golden = try png(width: 1, height: 1)
        let rendered = try png(width: 2, height: 1)

        #expect(throws: SnapshotError.self) {
            _ = try SnapshotHarness.compare(
                golden: golden,
                rendered: rendered,
                identifier: "size-mismatch"
            )
        }
    }

    private func png(
        width: Int,
        height: Int,
        redValues: [Int: UInt8] = [:]
    ) throws -> Data {
        var pixels = [UInt8](
            repeating: 0,
            count: width * height * 4
        )
        for pixel in 0..<(width * height) {
            pixels[pixel * 4 + 3] = 255
        }
        for (pixel, red) in redValues {
            pixels[pixel * 4] = red
        }

        return try pixels.withUnsafeMutableBufferPointer { buffer in
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
                ),
                let data = representation.representation(
                    using: .png,
                    properties: [:]
                )
            else {
                throw SnapshotHarnessTestError.pngEncodingFailed
            }
            return data
        }
    }
}

private enum SnapshotHarnessTestError: Error {
    case pngEncodingFailed
}
