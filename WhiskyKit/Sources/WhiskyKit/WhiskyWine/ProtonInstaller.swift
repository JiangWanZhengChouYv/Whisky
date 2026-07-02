//
//  ProtonInstaller.swift
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

extension WhiskyWineInstaller {
    // MARK: - Proton Installation

    public static func installProton(from url: URL, mode: WineMode) -> Result<Void, Error> {
        guard mode == .proton11 || mode == .proton10 else {
            return .failure(InstallationError.invalidInstallation("Invalid Proton mode: \(mode.rawValue)"))
        }

        do {
            let fileManager = FileManager.default
            let protonFolder = applicationFolder.appending(path: "Libraries/\(mode.rawValue.capitalized)")

            if !fileManager.fileExists(atPath: applicationFolder.path) {
                try fileManager.createDirectory(at: applicationFolder, withIntermediateDirectories: true)
            }

            let librariesFolder = applicationFolder.appending(path: "Libraries")
            if !fileManager.fileExists(atPath: librariesFolder.path) {
                try fileManager.createDirectory(at: librariesFolder, withIntermediateDirectories: true)
            }

            if fileManager.fileExists(atPath: protonFolder.path) {
                try fileManager.removeItem(at: protonFolder)
            }

            print("[Proton Install] Extracting tar to \(applicationFolder.path)")
            try Tar.untar(tarBall: url, toURL: applicationFolder)

            // Handle tar with root directory like Proton11/ or Proton10/
            let tarRootFolder = applicationFolder.appending(path: mode.rawValue.capitalized)
            if fileManager.fileExists(atPath: tarRootFolder.path) {
                print("[Proton Install] Found tar root directory \(tarRootFolder.lastPathComponent), moving to Libraries/")
                if fileManager.fileExists(atPath: protonFolder.path) {
                    try fileManager.removeItem(at: protonFolder)
                }
                try fileManager.moveItem(at: tarRootFolder, to: protonFolder)
            } else {
                // Handle flat tar with files/ directory directly
                let extractedFilesFolder = applicationFolder.appending(path: "files")
                if fileManager.fileExists(atPath: extractedFilesFolder.path) {
                    try fileManager.createDirectory(at: protonFolder, withIntermediateDirectories: true)
                    let targetFilesFolder = protonFolder.appending(path: "files")
                    if fileManager.fileExists(atPath: targetFilesFolder.path) {
                        try fileManager.removeItem(at: targetFilesFolder)
                    }
                    try fileManager.moveItem(at: extractedFilesFolder, to: targetFilesFolder)
                }
            }

            let binFolder = protonFolder.appending(path: "files").appending(path: "bin")

            print("[Proton Install] Setting executable permissions...")
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

            print("[Proton Install] Creating wine64 symlink if needed...")
            let wine64URL = binFolder.appendingPathComponent("wine64")
            let wineURL = binFolder.appendingPathComponent("wine")
            if !fileManager.fileExists(atPath: wine64URL.path),
               fileManager.fileExists(atPath: wineURL.path) {
                try fileManager.createSymbolicLink(at: wine64URL, withDestinationURL: wineURL)
            }

            print("[Proton Install] Ensuring version plist exists...")
            let versionPlistURL = protonFolder
                .appendingPathComponent("ProtonVersion")
                .appendingPathExtension("plist")
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml
            let versionInfo = WhiskyWineVersion()
            let versionData = try encoder.encode(versionInfo)
            try versionData.write(to: versionPlistURL)

            print("[Proton Install] Validating installation...")
            try validateProtonInstallation(mode: mode, protonFolder: protonFolder)

            print("[Proton Install] Installation successful!")
            return .success(())
        } catch {
            print("[Proton Install] Installation failed: \(error)")
            return .failure(error)
        }
    }

    public static func uninstallProton(mode: WineMode) {
        guard mode == .proton11 || mode == .proton10 else {
            return
        }
        do {
            let protonFolder = applicationFolder.appending(path: "Libraries/\(mode.rawValue.capitalized)")
            try FileManager.default.removeItem(at: protonFolder)
        } catch {
            print("Failed to uninstall \(mode.rawValue): \(error)")
        }
    }

    private static func validateProtonInstallation(mode: WineMode, protonFolder: URL) throws {
        let fileManager = FileManager.default
        let binFolder = protonFolder.appending(path: "files").appending(path: "bin")
        let libFolder = protonFolder.appending(path: "files").appending(path: "lib")
        let shareFolder = protonFolder.appending(path: "files").appending(path: "share")

        let wineBinPath = binFolder.appendingPathComponent("wine64")
        let wineBinFallback = binFolder.appendingPathComponent("wine")
        let wineUnixLibFolder = libFolder
            .appendingPathComponent("wine")
            .appendingPathComponent("x86_64-unix")
        let wineNlsFolder = shareFolder
            .appendingPathComponent("wine")
            .appendingPathComponent("nls")
        let wineFontsFolder = shareFolder
            .appendingPathComponent("wine")
            .appendingPathComponent("fonts")

        let wineExists = fileManager.fileExists(atPath: wineBinPath.path) ||
                         fileManager.fileExists(atPath: wineBinFallback.path)
        let libExists = fileManager.fileExists(atPath: libFolder.path)
        let unixLibExists = fileManager.fileExists(atPath: wineUnixLibFolder.path)
        let nlsExists = fileManager.fileExists(atPath: wineNlsFolder.path)
        let fontsExists = fileManager.fileExists(atPath: wineFontsFolder.path)

        guard wineExists && libExists && unixLibExists && nlsExists && fontsExists else {
            throw InstallationError.invalidInstallation("Proton installation validation failed")
        }

        let minSize: Int64 = 50 * 1024 * 1024
        guard directorySize(libFolder) >= minSize else {
            throw InstallationError.invalidInstallation("Proton lib directory too small")
        }

        guard protonVersion(mode: mode) != nil else {
            throw InstallationError.invalidInstallation("ProtonVersion.plist not found or invalid")
        }
    }
}
