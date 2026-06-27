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
    public enum WineMode: String, Codable, CaseIterable {
        case whiskyWine
        case crossover
    }

    private static let wineModeKey = "WineMode"

    public static var currentMode: WineMode {
        get {
            guard let data = UserDefaults.standard.data(forKey: wineModeKey),
                  let mode = try? JSONDecoder().decode(WineMode.self, from: data) else {
                return .whiskyWine
            }
            return mode
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: wineModeKey)
            }
        }
    }

    /// Base URL for WhiskyWine files (hosted on GitHub Release assets)
    /// Replaces the original upstream server which is no longer active
    public static let whiskyWineBaseURL =
        "https://github.com/JiangWanZhengChouYv/Whisky/releases/download/whiskywine-v1/"

    /// The Whisky application folder
    public static let applicationFolder = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appending(path: Bundle.whiskyBundleIdentifier)

    /// The folder of all the library files
    public static var libraryFolder: URL {
        switch currentMode {
        case .whiskyWine:
            return applicationFolder.appending(path: "Libraries")
        case .crossover:
            return URL(fileURLWithPath: "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver")
        }
    }

    /// URL to the installed `wine` `bin` directory
    public static var binFolder: URL {
        switch currentMode {
        case .whiskyWine:
            return libraryFolder.appending(path: "Wine").appending(path: "bin")
        case .crossover:
            return URL(fileURLWithPath: "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin")
        }
    }

    public static func isCrossOverInstalled() -> Bool {
        let fileManager = FileManager.default
        let crossoverAppURL = URL(fileURLWithPath: "/Applications/CrossOver.app")
        let wineBinURL = URL(fileURLWithPath: "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine")
        return fileManager.fileExists(atPath: crossoverAppURL.path) &&
               fileManager.fileExists(atPath: wineBinURL.path)
    }

    public static func isWhiskyWineInstalled() -> Bool {
        let fileManager = FileManager.default
        let wineBinPath = binFolder.appendingPathComponent("wine64")
        let wineBinFallback = binFolder.appendingPathComponent("wine")
        let wineLibFolder = libraryFolder
            .appendingPathComponent("Wine")
            .appendingPathComponent("lib")

        let wineExists = fileManager.fileExists(atPath: wineBinPath.path) ||
                         fileManager.fileExists(atPath: wineBinFallback.path)
        let libExists = fileManager.fileExists(atPath: wineLibFolder.path)

        guard wineExists && libExists else {
            return false
        }

        let minSize: Int64 = 10 * 1024 * 1024
        return directorySize(wineLibFolder) >= minSize
    }

    private static func directorySize(_ url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let resources = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resources.fileSize ?? 0)
            } catch {
                continue
            }
        }
        return totalSize
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

            print("[WhiskyWine Install] Normalizing extracted contents...")
            try normalizeExtractedContents()

            print("[WhiskyWine Install] Setting executable permissions...")
            try WhiskyWineInstallationHelpers.makeBinariesExecutable()

            print("[WhiskyWine Install] Ensuring version plist exists...")
            try WhiskyWineInstallationHelpers.ensureVersionPlist()

            print("[WhiskyWine Install] Creating wine64 symlink if needed...")
            try createWine64SymlinkIfNeeded()

            print("[WhiskyWine Install] Validating installation...")
            try validateInstallation()

            print("[WhiskyWine Install] Installation successful!")
            return .success(())
        } catch {
            print("[WhiskyWine Install] Installation failed: \(error)")
            return .failure(error)
        }
    }

    public static func uninstall() {
        do {
            try FileManager.default.removeItem(at: libraryFolder)
        } catch {
            print("Failed to uninstall WhiskyWine: \(error)")
        }
    }

    public static func clearDownloadCache() {
        WhiskyWineFileUtils.clearDownloadCache()
    }

    public static func shouldUpdateWhiskyWine() async -> (Bool, SemanticVersion) {
        let versionPlistURL = whiskyWineBaseURL + "WhiskyWineVersion.plist"
        let localVersion = whiskyWineVersion()
        var remoteVersion: SemanticVersion?

        if let remoteUrl = URL(string: versionPlistURL) {
            remoteVersion = await withCheckedContinuation { continuation in
                URLSession(configuration: .ephemeral)
                    .dataTask(with: URLRequest(url: remoteUrl)) { data, _, error in
                    do {
                        if error == nil, let data = data {
                            let decoder = PropertyListDecoder()
                            let remoteInfo = try decoder.decode(WhiskyWineVersion.self, from: data)
                            continuation.resume(returning: remoteInfo.version)
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

// MARK: - Private Helpers

private extension WhiskyWineInstaller {
    static func validateInstallation() throws {
        let fileManager = FileManager.default
        let wineBinPath = binFolder.appendingPathComponent("wine64")
        let wineLibFolder = libraryFolder
            .appendingPathComponent("Wine")
            .appendingPathComponent("lib")
        let winetricksPath = binFolder.appendingPathComponent("winetricks")

        printValidationDiagnostics(
            wineBinPath: wineBinPath,
            wineLibFolder: wineLibFolder,
            winetricksPath: winetricksPath
        )

        try validateRequiredFilesExist(
            wineBinPath: wineBinPath,
            wineLibFolder: wineLibFolder,
            winetricksPath: winetricksPath
        )

        verifyWineFunctionality()
    }

    private static func printValidationDiagnostics(
        wineBinPath: URL,
        wineLibFolder: URL,
        winetricksPath: URL
    ) {
        let fileManager = FileManager.default
        print("  - libraryFolder path: \(libraryFolder.path)")
        print("  - wineBinary path: \(wineBinPath.path)")
        print("  - wineBinary exists: \(fileManager.fileExists(atPath: wineBinPath.path))")
        print("  - wineLib path: \(wineLibFolder.path)")
        print("  - wineLib exists: \(fileManager.fileExists(atPath: wineLibFolder.path))")
        print("  - winetricks path: \(winetricksPath.path)")
        print("  - winetricks exists: \(fileManager.fileExists(atPath: winetricksPath.path))")

        let versionPlistURL = libraryFolder
            .appendingPathComponent("WhiskyWineVersion")
            .appendingPathExtension("plist")
        print("  - versionPlist path: \(versionPlistURL.path)")
        print("  - versionPlist exists: \(fileManager.fileExists(atPath: versionPlistURL.path))")
        print("  - whiskyWineVersion result: \(String(describing: whiskyWineVersion()))")
    }

    private static func validateRequiredFilesExist(
        wineBinPath: URL,
        wineLibFolder: URL,
        winetricksPath: URL
    ) throws {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: wineBinPath.path) {
            let error = InstallationError.invalidInstallation(
                "wineBinary not found at \(wineBinPath.path)"
            )
            print("[WhiskyWine Install] VALIDATION FAILED: \(error.errorDescription ?? "unknown")")
            throw error
        }

        var isDir: ObjCBool = false
        if !fileManager.fileExists(atPath: wineLibFolder.path, isDirectory: &isDir) || !isDir.boolValue {
            let error = InstallationError.invalidInstallation(
                "Wine lib directory not found at \(wineLibFolder.path)"
            )
            print("[WhiskyWine Install] VALIDATION FAILED: \(error.errorDescription ?? "unknown")")
            throw error
        }

        if !fileManager.fileExists(atPath: winetricksPath.path) {
            print("[WhiskyWine Install] WARNING: winetricks script not found at \(winetricksPath.path)")
        }

        if whiskyWineVersion() == nil {
            let error = InstallationError.invalidInstallation(
                "WhiskyWineVersion.plist not found or invalid"
            )
            print("[WhiskyWine Install] VALIDATION FAILED: \(error.errorDescription ?? "unknown")")
            throw error
        }
    }

    private static func verifyWineFunctionality() {
        print("[WhiskyWine Install] Running wine64 --version to verify functionality...")
        do {
            let versionOutput = try WhiskyWineInstallationHelpers.runWineCommand(arguments: ["--version"])
            print("[WhiskyWine Install] wine64 --version output: \(versionOutput)")
            if versionOutput.isEmpty {
                print("[WhiskyWine Install] WARNING: wine64 --version returned empty output")
            }
        } catch {
            print("[WhiskyWine Install] WARNING: Failed to run wine64 --version: \(error)")
        }
    }

    static func normalizeExtractedContents() throws {
        let fileManager = FileManager.default
        let expectedWineBin = libraryFolder
            .appendingPathComponent("Wine")
            .appendingPathComponent("bin")
            .appendingPathComponent("wine64")

        let wineAlreadyInPlace = fileManager.fileExists(atPath: expectedWineBin.path)

        if !wineAlreadyInPlace {
            print("[WhiskyWine Install] wine64 NOT at expected path, searching...")

            guard let wine64URL = WhiskyWineFileUtils.findWine64(in: applicationFolder) else {
                print("[WhiskyWine Install] ERROR: wine64 not found in extracted contents")
                WhiskyWineFileUtils.printDirectoryTree(at: applicationFolder, indent: 0)
                throw InstallationError.invalidInstallation(
                    "wine64 binary not found in extracted archive. " +
                    "The downloaded file may be corrupted. " +
                    "Directory structure:\n\(WhiskyWineFileUtils.directoryTreeDescription(at: applicationFolder))"
                )
            }

            print("[WhiskyWine Install] Found wine64 at: \(wine64URL.path)")
            let wineDir = wine64URL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            try WhiskyWineFileUtils.moveWineToLibrary(from: wineDir)
            try WhiskyWineFileUtils.moveVersionPlist(from: applicationFolder)
        } else {
            print("[WhiskyWine Install] wine64 found at expected path")
        }

        try WhiskyWineFileUtils.moveLibDirectoryIfNeeded()
        print("[WhiskyWine Install] Contents normalized successfully")
    }

    static func createWine64SymlinkIfNeeded() throws {
        let fileManager = FileManager.default
        let wine64URL = binFolder.appendingPathComponent("wine64")
        let wineURL = binFolder.appendingPathComponent("wine")

        if fileManager.fileExists(atPath: wine64URL.path) {
            print("[WhiskyWine Install] wine64 already exists, skipping symlink creation")
            return
        }

        guard fileManager.fileExists(atPath: wineURL.path) else {
            print("[WhiskyWine Install] wine binary not found, cannot create symlink")
            return
        }

        print("[WhiskyWine Install] Creating wine64 symlink -> wine")
        try fileManager.createSymbolicLink(at: wine64URL, withDestinationURL: wineURL)
        print("[WhiskyWine Install] Symlink created successfully")
    }
}
