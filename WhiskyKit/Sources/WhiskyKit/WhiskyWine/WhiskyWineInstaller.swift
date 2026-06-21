//
//  WhiskyWineInstaller.swift
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
import SemanticVersion

public class WhiskyWineInstaller {
    /// Base URL for WhiskyWine files (hosted on GitHub Release assets)
    /// Replaces the original upstream server which is no longer active
    public static let whiskyWineBaseURL =
        "https://github.com/JiangWanZhengChouYv/Whisky/releases/download/whiskywine-v1/"

    /// The Whisky application folder
    public static let applicationFolder = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appending(path: Bundle.whiskyBundleIdentifier)

    /// The folder of all the libfrary files
    public static let libraryFolder = applicationFolder.appending(path: "Libraries")

    /// URL to the installed `wine` `bin` directory
    public static let binFolder: URL = libraryFolder.appending(path: "Wine").appending(path: "bin")

    public static func isWhiskyWineInstalled() -> Bool {
        return whiskyWineVersion() != nil
    }

    public static func install(from: URL) {
        do {
            if !FileManager.default.fileExists(atPath: applicationFolder.path) {
                try FileManager.default.createDirectory(at: applicationFolder, withIntermediateDirectories: true)
            } else {
                // Recreate it
                try FileManager.default.removeItem(at: applicationFolder)
                try FileManager.default.createDirectory(at: applicationFolder, withIntermediateDirectories: true)
            }

            try Tar.untar(tarBall: from, toURL: applicationFolder)
            try FileManager.default.removeItem(at: from)

            try normalizeExtractedContents()
            try makeBinariesExecutable()
            try ensureVersionPlist()
        } catch {
            print("Failed to install WhiskyWine: \(error)")
        }
    }

    private static func normalizeExtractedContents() throws {
        let fileManager = FileManager.default
        let expectedWineBin = libraryFolder
            .appendingPathComponent("Wine")
            .appendingPathComponent("bin")
            .appendingPathComponent("wine64")
        if !fileManager.fileExists(atPath: expectedWineBin.path) {
            let flatWineDir = applicationFolder.appendingPathComponent("Wine")
            if fileManager.fileExists(atPath: flatWineDir.path) {
                try fileManager.createDirectory(at: libraryFolder, withIntermediateDirectories: true)
                let contents = try fileManager.contentsOfDirectory(atPath: applicationFolder.path)
                for item in contents {
                    if item == "Libraries" { continue }
                    let srcURL = applicationFolder.appendingPathComponent(item)
                    let dstURL = libraryFolder.appendingPathComponent(item)
                    try fileManager.moveItem(at: srcURL, to: dstURL)
                }
            }
        }
    }

    private static func makeBinariesExecutable() throws {
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

    private static func ensureVersionPlist() throws {
        let fileManager = FileManager.default
        let versionPlistURL = libraryFolder
            .appendingPathComponent("WhiskyWineVersion")
            .appendingPathExtension("plist")
        if !fileManager.fileExists(atPath: versionPlistURL.path) {
            try fileManager.createDirectory(at: libraryFolder, withIntermediateDirectories: true)
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml
            let versionInfo = WhiskyWineVersion()
            let versionData = try encoder.encode(versionInfo)
            try versionData.write(to: versionPlistURL)
        }
    }

    public static func uninstall() {
        do {
            try FileManager.default.removeItem(at: libraryFolder)
        } catch {
            print("Failed to uninstall WhiskyWine: \(error)")
        }
    }

    public static func shouldUpdateWhiskyWine() async -> (Bool, SemanticVersion) {
        let versionPlistURL = whiskyWineBaseURL + "WhiskyWineVersion.plist"
        let localVersion = whiskyWineVersion()

        var remoteVersion: SemanticVersion?

        if let remoteUrl = URL(string: versionPlistURL) {
            remoteVersion = await withCheckedContinuation { continuation in
                URLSession(configuration: .ephemeral).dataTask(with: URLRequest(url: remoteUrl)) { data, _, error in
                    do {
                        if error == nil, let data = data {
                            let decoder = PropertyListDecoder()
                            let remoteInfo = try decoder.decode(WhiskyWineVersion.self, from: data)
                            let remoteVersion = remoteInfo.version

                            continuation.resume(returning: remoteVersion)
                            return
                        }
                        if let error = error {
                            print(error)
                        }
                    } catch {
                        print(error)
                    }

                    continuation.resume(returning: nil)
                }.resume()
            }
        }

        if let localVersion = localVersion, let remoteVersion = remoteVersion {
            if localVersion < remoteVersion {
                return (true, remoteVersion)
            }
        }

        return (false, SemanticVersion(0, 0, 0))
    }

    public static func whiskyWineVersion() -> SemanticVersion? {
        do {
            let versionPlist = libraryFolder
                .appending(path: "WhiskyWineVersion")
                .appendingPathExtension("plist")

            let decoder = PropertyListDecoder()
            let data = try Data(contentsOf: versionPlist)
            let info = try decoder.decode(WhiskyWineVersion.self, from: data)
            return info.version
        } catch {
            print(error)
            return nil
        }
    }
}

struct WhiskyWineVersion: Codable {
    var version: SemanticVersion = SemanticVersion(1, 0, 0)
}
