//
//  WhiskyWineInstaller+GPTK.swift
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
    // MARK: - GPTK

    /// GPTK download URL (Apple Game Porting Toolkit 3.0-3)
    public static let gptkDownloadURL = URL(string:
        "https://github.com/JiangWanZhengChouYv/Whisky/releases/download/gptk/gptk-3.0-3.tar.gz"
    )!

    /// Returns the GPTK folder URL for the specified wine mode
    public static func gptkFolder(for mode: WineMode) -> URL {
        switch mode {
        case .whiskyWine:
            return applicationFolder.appending(path: "Libraries/GPTK")
        case .proton11:
            return applicationFolder.appending(path: "Libraries/Proton11/GPTK")
        case .proton10:
            return applicationFolder.appending(path: "Libraries/Proton10/GPTK")
        case .crossover:
            return applicationFolder.appending(path: "Libraries/GPTK")
        }
    }

    /// Check if GPTK is installed for the specified mode
    public static func isGPTKInstalled(mode: WineMode) -> Bool {
        let fileManager = FileManager.default
        let gptkDir = gptkFolder(for: mode)
        
        let externalDir = gptkDir.appending(path: "external")
        let wineDir = gptkDir.appending(path: "wine")
        let libd3dsharedPath = externalDir.appending(path: "libd3dshared.dylib")
        let d3d11Path = wineDir.appending(path: "x86_64-windows").appending(path: "d3d11.dll")

        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: externalDir.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        guard fileManager.fileExists(atPath: wineDir.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        guard fileManager.fileExists(atPath: libd3dsharedPath.path) else {
            return false
        }
        guard fileManager.fileExists(atPath: d3d11Path.path) else {
            return false
        }

        return true
    }

    /// Install GPTK from a local tar file to the specified mode
    public static func installGPTK(from tarURL: URL, mode: WineMode) throws {
        guard mode != .crossover else {
            throw NSError(domain: "GPTKInstall", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "GPTK not supported for CrossOver mode"])
        }

        let fileManager = FileManager.default
        let gptkDir = gptkFolder(for: mode)

        if fileManager.fileExists(atPath: gptkDir.path) {
            try fileManager.removeItem(at: gptkDir)
        }

        let tempDir = applicationFolder.appending(path: "tmp/gptk-install-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        try Tar.untar(tarBall: tarURL, toURL: tempDir)

        let extractedContents = try fileManager.contentsOfDirectory(atPath: tempDir.path)

        var extractedPath: URL
        if let gptkFolder = extractedContents.first(where: { $0.hasPrefix("gptk") }) {
            extractedPath = tempDir.appending(path: gptkFolder)
        } else if extractedContents.contains("external") && extractedContents.contains("wine") {
            extractedPath = tempDir
        } else {
            throw NSError(domain: "GPTKInstall", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not find GPTK folder in tar"])
        }

        let externalSource = extractedPath.appending(path: "external")
        let wineSource = extractedPath.appending(path: "wine")

        guard fileManager.fileExists(atPath: externalSource.path) else {
            throw NSError(domain: "GPTKInstall", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Could not find external folder in GPTK tar"])
        }
        guard fileManager.fileExists(atPath: wineSource.path) else {
            throw NSError(domain: "GPTKInstall", code: -4,
                          userInfo: [NSLocalizedDescriptionKey: "Could not find wine folder in GPTK tar"])
        }

        try fileManager.createDirectory(at: gptkDir, withIntermediateDirectories: true)
        let externalTarget = gptkDir.appending(path: "external")
        let wineTarget = gptkDir.appending(path: "wine")

        try fileManager.moveItem(at: externalSource, to: externalTarget)
        try fileManager.moveItem(at: wineSource, to: wineTarget)
    }

    /// Uninstall GPTK for the specified mode
    public static func uninstallGPTK(mode: WineMode) throws {
        guard mode != .crossover else {
            throw NSError(domain: "GPTKUninstall", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "GPTK not supported for CrossOver mode"])
        }

        let fileManager = FileManager.default
        let gptkDir = gptkFolder(for: mode)

        if fileManager.fileExists(atPath: gptkDir.path) {
            try fileManager.removeItem(at: gptkDir)
        } else {
            throw NSError(domain: "GPTKUninstall", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "GPTK not installed"])
        }
    }
}