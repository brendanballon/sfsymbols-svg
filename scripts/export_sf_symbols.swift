#!/usr/bin/env swift

import Foundation
import CoreText
import CoreGraphics

struct Config {
    enum Size: String {
        case small
        case medium
        case large
    }

    var appPath: String
    var outputPath: String
    var size: Size
    var clean: Bool

    static func parse() throws -> Config {
        var appPath = "/Applications/San Fransymbols.app"
        var outputPath = "symbols"
        var size = Size.large
        var clean = true

        var index = 1
        let args = CommandLine.arguments

        while index < args.count {
            let arg = args[index]
            switch arg {
            case "--app-path":
                index += 1
                guard index < args.count else { throw ExportError.invalidArguments("Missing value for --app-path") }
                appPath = args[index]
            case "--output":
                index += 1
                guard index < args.count else { throw ExportError.invalidArguments("Missing value for --output") }
                outputPath = args[index]
            case "--size":
                index += 1
                guard index < args.count else { throw ExportError.invalidArguments("Missing value for --size") }
                guard let parsed = Size(rawValue: args[index]) else {
                    throw ExportError.invalidArguments("Invalid --size value: \(args[index]). Use small, medium, or large")
                }
                size = parsed
            case "--no-clean":
                clean = false
            case "--help", "-h":
                printHelpAndExit()
            default:
                throw ExportError.invalidArguments("Unknown argument: \(arg)")
            }
            index += 1
        }

        return Config(appPath: appPath, outputPath: outputPath, size: size, clean: clean)
    }

    static func printHelpAndExit() -> Never {
        let help = """
        Usage: swift scripts/export_sf_symbols.swift [options]

        Options:
          --app-path <path>  Path to the SF Symbols app bundle.
                             Default: /Applications/San Fransymbols.app
          --output <path>    Destination folder for SVG files.
                             Default: symbols
          --size <size>      Glyph variant: small, medium, or large.
                             Default: large
          --no-clean         Keep existing files in output directory.
          -h, --help         Show this help.
        """
        print(help)
        Foundation.exit(0)
    }
}

enum ExportError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case missingFile(String)
    case invalidData(String)

    var description: String {
        switch self {
        case .invalidArguments(let message): return message
        case .missingFile(let message): return message
        case .invalidData(let message): return message
        }
    }
}

func readNonEmptyLines(at url: URL) throws -> [String] {
    let text = try String(contentsOf: url, encoding: .utf8)
    return text
        .split(whereSeparator: \ .isNewline)
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

func glyphName(for symbolCharacter: String, size: Config.Size) throws -> String {
    guard let scalar = symbolCharacter.unicodeScalars.first else {
        throw ExportError.invalidData("Encountered empty symbol character entry")
    }
    return "uni\(String(format: "%X", scalar.value)).\(size.rawValue)"
}

func format(_ value: CGFloat) -> String {
    String(format: "%.12g", Double(value))
}

func format(_ point: CGPoint) -> String {
    "\(format(point.x)),\(format(point.y))"
}

func pathData(for path: CGPath) -> String {
    var commands: [String] = []

    path.applyWithBlock { element in
        let type = element.pointee.type
        let points = element.pointee.points

        switch type {
        case .moveToPoint:
            commands.append("M \(format(points[0]))")
        case .addLineToPoint:
            commands.append("L \(format(points[0]))")
        case .addQuadCurveToPoint:
            commands.append("Q \(format(points[0])) \(format(points[1]))")
        case .addCurveToPoint:
            commands.append("C \(format(points[0])) \(format(points[1])) \(format(points[2]))")
        case .closeSubpath:
            commands.append("Z")
        @unknown default:
            break
        }
    }

    return commands.joined(separator: "\n    ")
}

func loadFont(from url: URL) throws -> CTFont {
    guard let provider = CGDataProvider(url: url as CFURL) else {
        throw ExportError.invalidData("Failed to open font provider for \(url.path)")
    }
    guard let cgFont = CGFont(provider) else {
        throw ExportError.invalidData("Failed to parse font at \(url.path)")
    }
    return CTFontCreateWithGraphicsFont(cgFont, 44, nil, nil)
}

func exportSymbols(config: Config) throws {
    let appURL = URL(fileURLWithPath: config.appPath)
    let resourcesURL = appURL.appendingPathComponent("Contents/Resources", isDirectory: true)

    let namesURL = resourcesURL.appendingPathComponent("symbol_names.txt")
    let charsURL = resourcesURL.appendingPathComponent("symbol_chars.txt")

    guard FileManager.default.fileExists(atPath: namesURL.path) else {
        throw ExportError.missingFile("Missing symbol names file at \(namesURL.path)")
    }
    guard FileManager.default.fileExists(atPath: charsURL.path) else {
        throw ExportError.missingFile("Missing symbol chars file at \(charsURL.path)")
    }

    let preferredFontURL = resourcesURL.appendingPathComponent("SF-Pro.ttf")
    let fallbackFontURL = resourcesURL.appendingPathComponent("SFSymbolsFallback.ttf")
    let fontURL: URL
    if FileManager.default.fileExists(atPath: preferredFontURL.path) {
        fontURL = preferredFontURL
    } else if FileManager.default.fileExists(atPath: fallbackFontURL.path) {
        fontURL = fallbackFontURL
    } else {
        throw ExportError.missingFile("Unable to find SF font in \(resourcesURL.path)")
    }

    let names = try readNonEmptyLines(at: namesURL)
    let chars = try readNonEmptyLines(at: charsURL)

    guard names.count == chars.count else {
        throw ExportError.invalidData("Mismatched metadata counts: names=\(names.count), chars=\(chars.count)")
    }

    let outputURL = URL(fileURLWithPath: config.outputPath, isDirectory: true)
    if config.clean, FileManager.default.fileExists(atPath: outputURL.path) {
        try FileManager.default.removeItem(at: outputURL)
    }
    try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

    let font = try loadFont(from: fontURL)

    var missingCount = 0

    for (index, name) in names.enumerated() {
        let symbolChar = chars[index]
        let generatedGlyphName = try glyphName(for: symbolChar, size: config.size)
        var glyph = CTFontGetGlyphWithName(font, generatedGlyphName as CFString)

        if glyph == 0 {
            missingCount += 1
            continue
        }

        var box = CGRect.zero
        CTFontGetBoundingRectsForGlyphs(font, .default, &glyph, &box, 1)

        let paddedBoxMultiplier: CGFloat = box.origin.y > 0 ? 2 : -2
        let paddedHeight = box.height + (paddedBoxMultiplier * box.origin.y)
        let paddedWidth = box.width + (2 * box.origin.x)
        let canvas = CGRect(
            x: 0,
            y: 0,
            width: max(1, paddedWidth),
            height: max(1, paddedHeight)
        )

        guard let rawPath = CTFontCreatePathForGlyph(font, glyph, nil) else {
            missingCount += 1
            continue
        }

        let exportPath: CGPath
        if box.origin.y > 0 {
            exportPath = rawPath
        } else {
            var transform = CGAffineTransform(translationX: 0, y: -2 * box.origin.y)
            exportPath = rawPath.copy(using: &transform) ?? rawPath
        }

        let path = pathData(for: exportPath)
        if path.isEmpty {
            missingCount += 1
            continue
        }

        let svg = """
        <svg width='\(format(canvas.width))px' height='\(format(canvas.height))px' xmlns='http://www.w3.org/2000/svg' version='1.1'>
        <g fill-rule='nonzero' transform='scale(1,-1) translate(0,-\(format(canvas.height)))'>
        <path fill='black' stroke='black' fill-opacity='1.0' stroke-width='1.0' d='
            \(path)
        ' />
        </g>
        </svg>
        """

        let outputFile = outputURL.appendingPathComponent("\(name).svg")
        try Data(svg.utf8).write(to: outputFile)
    }

    print("Exported \(names.count - missingCount) of \(names.count) symbols to \(outputURL.path) using \(fontURL.lastPathComponent) (size: \(config.size.rawValue)).")
    if missingCount > 0 {
        print("Skipped \(missingCount) symbols due to missing glyphs/paths.")
    }
}

do {
    let config = try Config.parse()
    try exportSymbols(config: config)
} catch let error as ExportError {
    fputs("Error: \(error.description)\n", stderr)
    Foundation.exit(1)
} catch {
    fputs("Unexpected error: \(error)\n", stderr)
    Foundation.exit(1)
}
