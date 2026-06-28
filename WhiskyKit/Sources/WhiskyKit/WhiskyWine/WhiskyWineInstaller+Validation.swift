//
//  WhiskyWineInstaller+Validation.swift
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

extension WhiskyWineInstaller {
    static func validateInstallation() throws {
        let fileManager = FileManager.default
        let wineBinPath = binFolder.appendingPathComponent("wine64")
        let wineLibFolder = libraryFolder
            .appendingPathComponent("Wine")
            .appendingPathComponent("lib")
        let wineUnixLibFolder = wineLibFolder
            .appendingPathComponent("wine")
            .appendingPathComponent("x86_64-unix")
        let wineNlsFolder = shareFolder
            .appendingPathComponent("wine")
            .appendingPathComponent("nls")
        let wineFontsFolder = shareFolder
            .appendingPathComponent("wine")
            .appendingPathComponent("fonts")
        let winetricksPath = binFolder.appendingPathComponent("winetricks")

        printValidationDiagnostics(
            wineBinPath: wineBinPath,
            wineLibFolder: wineLibFolder,
            wineUnixLibFolder: wineUnixLibFolder,
            wineNlsFolder: wineNlsFolder,
            wineFontsFolder: wineFontsFolder,
            winetricksPath: winetricksPath
        )

        try validateRequiredFilesExist(
            wineBinPath: wineBinPath,
            wineLibFolder: wineLibFolder,
            wineUnixLibFolder: wineUnixLibFolder,
            wineNlsFolder: wineNlsFolder,
            wineFontsFolder: wineFontsFolder,
            winetricksPath: winetricksPath
        )

        verifyWineFunctionality()
    }

    private static func printValidationDiagnostics(
        wineBinPath: URL,
        wineLibFolder: URL,
        wineUnixLibFolder: URL,
        wineNlsFolder: URL,
        wineFontsFolder: URL,
        winetricksPath: URL
    ) {
        let fileManager = FileManager.default
        print("  - libraryFolder path: \(libraryFolder.path)")
        print("  - wineBinary path: \(wineBinPath.path)")
        print("  - wineBinary exists: \(fileManager.fileExists(atPath: wineBinPath.path))")
        print("  - wineLib path: \(wineLibFolder.path)")
        print("  - wineLib exists: \(fileManager.fileExists(atPath: wineLibFolder.path))")
        print("  - wineLib size: \(directorySize(wineLibFolder)) bytes")
        print("  - wineUnixLib path: \(wineUnixLibFolder.path)")
        print("  - wineUnixLib exists: \(fileManager.fileExists(atPath: wineUnixLibFolder.path))")
        print("  - wineNls path: \(wineNlsFolder.path)")
        print("  - wineNls exists: \(fileManager.fileExists(atPath: wineNlsFolder.path))")
        print("  - wineFonts path: \(wineFontsFolder.path)")
        print("  - wineFonts exists: \(fileManager.fileExists(atPath: wineFontsFolder.path))")
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
        wineUnixLibFolder: URL,
        wineNlsFolder: URL,
        wineFontsFolder: URL,
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

        let minSize: Int64 = 50 * 1024 * 1024
        let libSize = directorySize(wineLibFolder)
        if libSize < minSize {
            let error = InstallationError.invalidInstallation(
                "Wine lib directory too small: \(libSize) bytes (expected >= \(minSize) bytes)"
            )
            print("[WhiskyWine Install] VALIDATION FAILED: \(error.errorDescription ?? "unknown")")
            throw error
        }

        if !fileManager.fileExists(atPath: wineUnixLibFolder.path) {
            let error = InstallationError.invalidInstallation(
                "Wine x86_64-unix lib directory not found at \(wineUnixLibFolder.path)"
            )
            print("[WhiskyWine Install] VALIDATION FAILED: \(error.errorDescription ?? "unknown")")
            throw error
        }

        if !fileManager.fileExists(atPath: wineNlsFolder.path) {
            let error = InstallationError.invalidInstallation(
                "Wine NLS directory not found at \(wineNlsFolder.path)"
            )
            print("[WhiskyWine Install] VALIDATION FAILED: \(error.errorDescription ?? "unknown")")
            throw error
        }

        if !fileManager.fileExists(atPath: wineFontsFolder.path) {
            let error = InstallationError.invalidInstallation(
                "Wine fonts directory not found at \(wineFontsFolder.path)"
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

    static func directorySize(_ url: URL) -> Int64 {
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
}
