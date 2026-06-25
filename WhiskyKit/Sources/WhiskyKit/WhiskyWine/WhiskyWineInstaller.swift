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

    public static func install(from: URL) -> Result<Void, Error> {
        do {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: applicationFolder.path) {
                try fileManager.createDirectory(at: applicationFolder, withIntermediateDirectories: true)
            } else {
                // Recreate it
                try fileManager.removeItem(at: applicationFolder)
                try fileManager.createDirectory(at: applicationFolder, withIntermediateDirectories: true)
            }

            print("[WhiskyWine Install] Extracting tar to \(applicationFolder.path)")
            try Tar.untar(tarBall: from, toURL: applicationFolder)
            // Do NOT delete the tar file — it may be the cached download.
            // The download manager caches to ~/Library/Application Support/Whisky/Downloads/.
            // Deleting it would force a re-download on the next launch.

            print("[WhiskyWine Install] Normalizing extracted contents...")
            try normalizeExtractedContents()

            print("[WhiskyWine Install] Setting executable permissions...")
            try makeBinariesExecutable()

            print("[WhiskyWine Install] Ensuring version plist exists...")
            try ensureVersionPlist()

            // Final validation
            print("[WhiskyWine Install] Validating installation...")
            let wineBinPath = WhiskyWineInstaller.binFolder.appendingPathComponent("wine64")
            print("  - libraryFolder path: \(libraryFolder.path)")
            print("  - wineBinary path: \(wineBinPath.path)")
            print("  - wineBinary exists: \(fileManager.fileExists(atPath: wineBinPath.path))")

            let versionPlistURL = libraryFolder
                .appendingPathComponent("WhiskyWineVersion")
                .appendingPathExtension("plist")
            print("  - versionPlist path: \(versionPlistURL.path)")
            print("  - versionPlist exists: \(fileManager.fileExists(atPath: versionPlistURL.path))")
            print("  - whiskyWineVersion result: \(String(describing: whiskyWineVersion()))")

            if !fileManager.fileExists(atPath: wineBinPath.path) {
                let error = InstallationError.invalidInstallation(
                    "wineBinary not found at \(wineBinPath.path)"
                )
                print("[WhiskyWine Install] VALIDATION FAILED: \(error.errorDescription ?? "unknown")")
                return .failure(error)
            }

            if whiskyWineVersion() == nil {
                let error = InstallationError.invalidInstallation(
                    "WhiskyWineVersion.plist not found or invalid"
                )
                print("[WhiskyWine Install] VALIDATION FAILED: \(error.errorDescription ?? "unknown")")
                return .failure(error)
            }

            print("[WhiskyWine Install] Installation successful!")
            return .success(())
        } catch {
            print("[WhiskyWine Install] Installation failed: \(error)")
            return .failure(error)
        }
    }

    private static func normalizeExtractedContents() throws {
        let fileManager = FileManager.default
        let expectedWineBin = libraryFolder
            .appendingPathComponent("Wine")
            .appendingPathComponent("bin")
            .appendingPathComponent("wine64")

        if fileManager.fileExists(atPath: expectedWineBin.path) {
            print("[WhiskyWine Install] wine64 found at expected path")
            return
        }

        print("[WhiskyWine Install] wine64 NOT at expected path, searching...")

        guard let wine64URL = findWine64(in: applicationFolder) else {
            print("[WhiskyWine Install] ERROR: wine64 not found in extracted contents")
            printDirectoryTree(at: applicationFolder, indent: 0)

            let tree = directoryTreeDescription(at: applicationFolder)
            throw InstallationError.invalidInstallation(
                "wine64 binary not found in extracted archive. " +
                "The downloaded file may be corrupted. " +
                "Directory structure:\n\(tree)"
            )
        }

        print("[WhiskyWine Install] Found wine64 at: \(wine64URL.path)")
        try moveWineToLibrary(from: wine64URL.deletingLastPathComponent().deletingLastPathComponent())
        try moveVersionPlist(from: applicationFolder)
        print("[WhiskyWine Install] Contents normalized successfully")
    }

    private static func findWine64(in root: URL) -> URL? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "wine64" {
            return fileURL
        }
        return nil
    }

    private static func moveWineToLibrary(from wineDir: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: libraryFolder, withIntermediateDirectories: true)
        let targetWineDir = libraryFolder.appendingPathComponent("Wine")

        if wineDir.resolvingSymlinksInPath().path == targetWineDir.resolvingSymlinksInPath().path {
            print("[WhiskyWine Install] Wine already at target location")
            return
        }

        if fileManager.fileExists(atPath: targetWineDir.path) {
            try fileManager.removeItem(at: targetWineDir)
        }

        print("[WhiskyWine Install] Moving Wine from \(wineDir.path) to \(targetWineDir.path)")
        try fileManager.moveItem(at: wineDir, to: targetWineDir)
    }

    private static func moveVersionPlist(from root: URL) throws {
        let fileManager = FileManager.default
        let versionPlistName = "WhiskyWineVersion.plist"

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let targetPlist = libraryFolder.appendingPathComponent(versionPlistName)
        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == versionPlistName {
            guard fileURL.resolvingSymlinksInPath().path != targetPlist.resolvingSymlinksInPath().path else {
                return
            }
            if fileManager.fileExists(atPath: targetPlist.path) {
                try fileManager.removeItem(at: targetPlist)
            }
            print("[WhiskyWine Install] Moving \(versionPlistName) to \(targetPlist.path)")
            try fileManager.moveItem(at: fileURL, to: targetPlist)
            return
        }
    }

    private static func printDirectoryTree(at url: URL, indent: Int) {
        let fileManager = FileManager.default
        let prefix = String(repeating: "  ", count: indent)
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: url.path)
            print("\(prefix)\(url.lastPathComponent)/")
            for item in contents.sorted() {
                let itemURL = url.appendingPathComponent(item)
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        printDirectoryTree(at: itemURL, indent: indent + 1)
                    } else {
                        print("\(prefix)  \(item)")
                    }
                }
            }
        } catch {
            print("\(prefix)\(url.lastPathComponent)/ (error: \(error.localizedDescription))")
        }
    }

    private static func directoryTreeDescription(at url: URL) -> String {
        let fileManager = FileManager.default
        var result = ""

        func buildTree(_ url: URL, indent: Int) {
            let prefix = String(repeating: "  ", count: indent)
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: url.path)
                result += "\(prefix)\(url.lastPathComponent)/\n"
                for item in contents.sorted() {
                    let itemURL = url.appendingPathComponent(item)
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir) {
                        if isDir.boolValue {
                            buildTree(itemURL, indent: indent + 1)
                        } else {
                            result += "\(prefix)  \(item)\n"
                        }
                    }
                }
            } catch {
                result += "\(prefix)\(url.lastPathComponent)/ (error: \(error.localizedDescription))\n"
            }
        }

        buildTree(url, indent: 0)
        return result
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

public enum InstallationError: Error, LocalizedError, CustomStringConvertible, CustomNSError {
    case invalidInstallation(String)
    case extractionFailed(String)

    public var errorDescription: String? {
        // Always return a non-nil, human-readable string so that
        // Foundation's `error.localizedDescription` never falls back to
        // the "Swift.String 错误 1" placeholder.
        switch self {
        case .invalidInstallation(let reason):
            return "Invalid installation: \(reason)"
        case .extractionFailed(let reason):
            return "Extraction failed: \(reason)"
        }
    }

    public var description: String {
        return errorDescription ?? "InstallationError"
    }

    public var localizedDescription: String {
        return errorDescription ?? "InstallationError"
    }

    public static var errorDomain: String { "com.Whisky.InstallationError" }

    public var errorCode: Int {
        switch self {
        case .invalidInstallation:
            return 1
        case .extractionFailed:
            return 2
        }
    }

    public var errorUserInfo: [String: Any] {
        return [NSLocalizedDescriptionKey: errorDescription ?? "InstallationError"]
    }
}
