//
//  WhiskyWineFileUtils.swift
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

enum WhiskyWineFileUtils {
    static let applicationFolder = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appending(path: Bundle.whiskyBundleIdentifier)

    static let libraryFolder = applicationFolder.appending(path: "Libraries")

    static let binFolder: URL = libraryFolder.appending(path: "Wine").appending(path: "bin")

    static func directoryTreeDescription(at url: URL, indent: Int = 0) -> String {
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

        buildTree(url, indent: indent)
        return result
    }

    static func printDirectoryTree(at url: URL, indent: Int) {
        print(directoryTreeDescription(at: url, indent: indent))
    }

    static func findWine64(in root: URL) -> URL? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let fileURL as URL in enumerator
        where fileURL.lastPathComponent == "wine64" || fileURL.lastPathComponent == "wine" {
            return fileURL
        }
        return nil
    }

    static func findLibDirectory(in root: URL) -> URL? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let fileURL as URL in enumerator
        where fileURL.lastPathComponent == "lib" {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDir), isDir.boolValue {
                let parentDir = fileURL.deletingLastPathComponent().lastPathComponent
                if parentDir.lowercased() != "wine" {
                    return fileURL
                }
            }
        }
        return nil
    }

    static func moveWineToLibrary(from wineDir: URL) throws {
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

    static func moveVersionPlist(from root: URL) throws {
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

    static func clearDownloadCache() {
        let fileManager = FileManager.default
        let downloadsDir = applicationFolder
            .appendingPathComponent("Downloads", isDirectory: true)
        let cachedTarURL = downloadsDir.appendingPathComponent("Libraries.tar.gz")
        let completeMarkerURL = cachedTarURL.appendingPathExtension("complete")

        if fileManager.fileExists(atPath: cachedTarURL.path) {
            try? fileManager.removeItem(at: cachedTarURL)
            print("[WhiskyWine] Cleared cached tar file")
        }
        if fileManager.fileExists(atPath: completeMarkerURL.path) {
            try? fileManager.removeItem(at: completeMarkerURL)
            print("[WhiskyWine] Cleared complete marker file")
        }
    }

    static func moveLibDirectoryIfNeeded() throws {
        let fileManager = FileManager.default
        let wineLibFolder = libraryFolder
            .appendingPathComponent("Wine")
            .appendingPathComponent("lib")

        if fileManager.fileExists(atPath: wineLibFolder.path) {
            print("[WhiskyWine Install] lib directory already at expected path: \(wineLibFolder.path)")
            return
        }

        print("[WhiskyWine Install] lib directory not at expected path, searching...")

        let possibleLibLocations = [
            applicationFolder.appendingPathComponent("lib"),
            libraryFolder.appendingPathComponent("lib")
        ]

        var foundLibURL: URL?
        for libURL in possibleLibLocations {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: libURL.path, isDirectory: &isDir), isDir.boolValue {
                foundLibURL = libURL
                break
            }
        }

        if foundLibURL == nil {
            foundLibURL = findLibDirectory(in: applicationFolder)
        }

        guard let libURL = foundLibURL else {
            print("[WhiskyWine Install] WARNING: lib directory not found in extracted contents")
            return
        }

        print("[WhiskyWine Install] Found lib directory at: \(libURL.path)")

        let wineFolder = libraryFolder.appendingPathComponent("Wine")
        try fileManager.createDirectory(at: wineFolder, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: wineLibFolder.path) {
            try fileManager.removeItem(at: wineLibFolder)
        }

        print("[WhiskyWine Install] Moving lib from \(libURL.path) to \(wineLibFolder.path)")
        try fileManager.moveItem(at: libURL, to: wineLibFolder)
        print("[WhiskyWine Install] lib directory moved successfully")
    }
}
