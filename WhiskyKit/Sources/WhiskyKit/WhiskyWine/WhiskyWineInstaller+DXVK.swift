//
//  WhiskyWineInstaller+DXVK.swift
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
    // MARK: - DXVK

    /// DXVK download URL (Gcenx DXVK-macOS, MIT license)
    public static let dxvkDownloadURL = URL(string:
        "https://github.com/Gcenx/DXVK-macOS/releases/download/v1.10.3-20230507-repack/" +
        "dxvk-macOS-async-v1.10.3-20230507-repack-builtin.tar.gz"
    )!

    /// Returns the DXVK folder URL for the specified wine mode
    public static func dxvkFolder(for mode: WineMode) -> URL {
        switch mode {
        case .whiskyWine:
            return applicationFolder.appending(path: "Libraries/DXVK")
        case .proton11:
            return applicationFolder.appending(path: "Libraries/Proton11/DXVK")
        case .proton10:
            return applicationFolder.appending(path: "Libraries/Proton10/DXVK")
        case .crossover:
            return applicationFolder.appending(path: "Libraries/DXVK")
        }
    }

    /// Check if DXVK is installed for the specified mode
    public static func isDXVKInstalled(mode: WineMode) -> Bool {
        let fileManager = FileManager.default
        let dxvkDir = dxvkFolder(for: mode)
        print("[DXVK] Checking installation for mode \(mode.rawValue) at: \(dxvkDir.path)")
        let x64Dir = dxvkDir.appending(path: "x64")
        let x32Dir = dxvkDir.appending(path: "x32")

        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: x64Dir.path, isDirectory: &isDir), isDir.boolValue else {
            print("[DXVK] x64 directory not found, DXVK not installed")
            return false
        }
        guard fileManager.fileExists(atPath: x32Dir.path, isDirectory: &isDir), isDir.boolValue else {
            print("[DXVK] x32 directory not found, DXVK not installed")
            return false
        }

        guard let x64Contents = try? fileManager.contentsOfDirectory(atPath: x64Dir.path) else {
            print("[DXVK] Failed to read x64 directory contents")
            return false
        }
        let dllFiles = x64Contents.filter { $0.lowercased().hasSuffix(".dll") }
        let installed = !dllFiles.isEmpty
        print("[DXVK] Mode \(mode.rawValue) DXVK installed: \(installed), DLL count: \(dllFiles.count)")
        return installed
    }

    /// Install DXVK from a local tar file to the specified mode
    public static func installDXVK(from tarURL: URL, mode: WineMode) throws {
        guard mode != .crossover else {
            throw NSError(domain: "DXVKInstall", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "DXVK not supported for CrossOver mode"])
        }

        let fileManager = FileManager.default
        let dxvkDir = dxvkFolder(for: mode)
        print("[DXVK Install] Installing DXVK for mode \(mode.rawValue) to: \(dxvkDir.path)")

        if fileManager.fileExists(atPath: dxvkDir.path) {
            print("[DXVK Install] Removing existing DXVK directory")
            try fileManager.removeItem(at: dxvkDir)
        }

        let tempDir = applicationFolder.appending(path: "tmp/dxvk-install-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        try Tar.untar(tarBall: tarURL, toURL: tempDir)

        let extractedContents = try fileManager.contentsOfDirectory(atPath: tempDir.path)

        guard let extractedFolder = extractedContents.first(where: { $0.contains("dxvk") }) else {
            throw NSError(domain: "DXVKInstall", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not find DXVK folder in tar"])
        }

        let extractedPath = tempDir.appending(path: extractedFolder)
        let x64Source = extractedPath.appending(path: "x86_64-windows")
        let x32Source = extractedPath.appending(path: "i386-windows")

        guard fileManager.fileExists(atPath: x64Source.path) else {
            throw NSError(domain: "DXVKInstall", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Could not find x86_64-windows in DXVK tar"])
        }

        try fileManager.createDirectory(at: dxvkDir, withIntermediateDirectories: true)
        let x64Target = dxvkDir.appending(path: "x64")
        let x32Target = dxvkDir.appending(path: "x32")

        try fileManager.moveItem(at: x64Source, to: x64Target)

        if fileManager.fileExists(atPath: x32Source.path) {
            try fileManager.moveItem(at: x32Source, to: x32Target)
        } else {
            try fileManager.createDirectory(at: x32Target, withIntermediateDirectories: true)
        }

        print("[DXVK Install] DXVK installed successfully for mode \(mode.rawValue)")
    }
}
