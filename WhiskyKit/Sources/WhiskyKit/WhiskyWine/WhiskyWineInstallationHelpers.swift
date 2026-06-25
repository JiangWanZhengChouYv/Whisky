//
//  WhiskyWineInstallationHelpers.swift
//  WhiskyKit
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import Foundation

enum WhiskyWineInstallationHelpers {
    static let applicationFolder = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appending(path: Bundle.whiskyBundleIdentifier)

    static let libraryFolder = applicationFolder.appending(path: "Libraries")

    static let binFolder: URL = libraryFolder.appending(path: "Wine").appending(path: "bin")

    static func makeBinariesExecutable() throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: binFolder.path) {
            let binContents = try fileManager.contentsOfDirectory(atPath: binFolder.path)
            for binFile in binContents {
                let binPath = binFolder.appendingPathComponent(binFile).path
                try fileManager.setAttributes(
                    [.posixPermissions: NSNumber(value: 0o755)],
                    ofItemAtPath: binPath
                )
            }
        }
    }

    static func runWineCommand(arguments: [String]) throws -> String {
        let wine64URL = binFolder.appendingPathComponent("wine64")
        let process = Process()
        process.executableURL = wine64URL
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func ensureVersionPlist() throws {
        let fileManager = FileManager.default
        let versionPlistURL = libraryFolder
            .appendingPathComponent("WhiskyWineVersion")
            .appendingPathExtension("plist")

        let shouldCreateNew: Bool
        if fileManager.fileExists(atPath: versionPlistURL.path) {
            do {
                let data = try Data(contentsOf: versionPlistURL)
                _ = try PropertyListDecoder().decode(WhiskyWineVersion.self, from: data)
                shouldCreateNew = false
            } catch {
                print("[WhiskyWine Install] Existing version plist invalid, recreating: \(error)")
                shouldCreateNew = true
            }
        } else {
            shouldCreateNew = true
        }

        if shouldCreateNew {
            try fileManager.createDirectory(at: libraryFolder, withIntermediateDirectories: true)
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml
            let versionInfo = WhiskyWineVersion()
            let versionData = try encoder.encode(versionInfo)
            try versionData.write(to: versionPlistURL)
            print("[WhiskyWine Install] Created WhiskyWineVersion.plist")
        }
    }
}
