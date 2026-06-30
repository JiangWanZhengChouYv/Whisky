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
    public enum WineMode: String, Codable, CaseIterable, Sendable {
        case whiskyWine
        case crossover
        case proton11
        case proton10

        public var isDownloadable: Bool {
            switch self {
            case .whiskyWine, .proton11, .proton10:
                return true
            case .crossover:
                return false
            }
        }
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

    /// Base URL for Proton 11 files (based on Gcenx wine-staging 11.10)
    public static let proton11BaseURL =
        "https://github.com/JiangWanZhengChouYv/Whisky/releases/download/proton11/"

    /// Base URL for Proton 10 files (based on Gcenx wine-staging 11.9)
    public static let proton10BaseURL =
        "https://github.com/JiangWanZhengChouYv/Whisky/releases/download/proton10/"

    /// Returns the download URL for the specified Proton mode
    public static func protonDownloadURL(for mode: WineMode) -> URL? {
        let baseURL: String
        let fileName: String
        switch mode {
        case .proton11:
            baseURL = proton11BaseURL
            fileName = "Proton11.tar.gz"
        case .proton10:
            baseURL = proton10BaseURL
            fileName = "Proton10.tar.gz"
        default:
            return nil
        }
        return URL(string: baseURL + fileName)
    }

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
            return crossOverAppURL()?.appendingPathComponent("Contents")
                .appendingPathComponent("SharedSupport")
                .appendingPathComponent("CrossOver")
                ?? URL(fileURLWithPath: "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver")
        case .proton11:
            return applicationFolder.appending(path: "Libraries/Proton11")
        case .proton10:
            return applicationFolder.appending(path: "Libraries/Proton10")
        }
    }

    /// URL to the installed `wine` `bin` directory
    public static var binFolder: URL {
        switch currentMode {
        case .whiskyWine:
            return libraryFolder.appending(path: "Wine").appending(path: "bin")
        case .crossover:
            return libraryFolder.appending(path: "bin")
        case .proton11, .proton10:
            return libraryFolder.appending(path: "files").appending(path: "bin")
        }
    }

    /// URL to the installed `wine` `share` directory
    public static var shareFolder: URL {
        switch currentMode {
        case .whiskyWine:
            return libraryFolder.appending(path: "Wine").appending(path: "share")
        case .crossover:
            return libraryFolder.appending(path: "share")
        case .proton11, .proton10:
            return libraryFolder.appending(path: "files").appending(path: "share")
        }
    }

    /// URL to the installed `wine` `lib` directory
    public static var libFolder: URL {
        switch currentMode {
        case .whiskyWine:
            return libraryFolder.appending(path: "Wine").appending(path: "lib")
        case .crossover:
            return libraryFolder.appending(path: "lib")
        case .proton11, .proton10:
            return libraryFolder.appending(path: "files").appending(path: "lib")
        }
    }

    /// URL to the winetricks script
    public static var winetricksURL: URL {
        let fileManager = FileManager.default
        let crossoverWinetricks = binFolder.appending(path: "winetricks")

        switch currentMode {
        case .whiskyWine, .proton11, .proton10:
            return binFolder.appending(path: "winetricks")
        case .crossover:
            if fileManager.fileExists(atPath: crossoverWinetricks.path(percentEncoded: false)) {
                return crossoverWinetricks
            } else {
                let whiskyWineBin = applicationFolder
                    .appending(path: "Libraries")
                    .appending(path: "Wine")
                    .appending(path: "bin")
                return whiskyWineBin.appending(path: "winetricks")
            }
        }
    }

    /// URL to the verbs.txt file
    public static var verbsURL: URL {
        switch currentMode {
        case .whiskyWine, .proton11, .proton10:
            return shareFolder.appending(path: "verbs.txt")
        case .crossover:
            return applicationFolder.appending(path: "verbs.txt")
        }
    }

    // MARK: - CrossOver Detection

    private static let possibleCrossOverPaths = [
        "/Applications/CrossOver.app",
        "\(NSHomeDirectory())/Applications/CrossOver.app"
    ]

    public static func isCrossOverInstalled() -> Bool {
        let fileManager = FileManager.default
        for appPath in possibleCrossOverPaths {
            let crossoverAppURL = URL(fileURLWithPath: appPath)
            let wineBinURL = URL(fileURLWithPath: appPath)
                .appendingPathComponent("Contents")
                .appendingPathComponent("SharedSupport")
                .appendingPathComponent("CrossOver")
                .appendingPathComponent("bin")
                .appendingPathComponent("wine")
            if fileManager.fileExists(atPath: crossoverAppURL.path) &&
               fileManager.fileExists(atPath: wineBinURL.path) {
                return true
            }
        }
        return false
    }

    public static func crossOverAppURL() -> URL? {
        let fileManager = FileManager.default
        for appPath in possibleCrossOverPaths {
            let crossoverAppURL = URL(fileURLWithPath: appPath)
            if fileManager.fileExists(atPath: crossoverAppURL.path) {
                return crossoverAppURL
            }
        }
        return nil
    }

    // MARK: - WhiskyWine Detection

    private static var whiskyWineLibraryFolder: URL {
        applicationFolder.appending(path: "Libraries")
    }

    private static var whiskyWineBinFolder: URL {
        whiskyWineLibraryFolder.appending(path: "Wine").appending(path: "bin")
    }

    private static var whiskyWineLibFolder: URL {
        whiskyWineLibraryFolder.appending(path: "Wine").appending(path: "lib")
    }

    private static var whiskyWineShareFolder: URL {
        whiskyWineLibraryFolder.appending(path: "Wine").appending(path: "share")
    }

    public static func isWhiskyWineInstalled() -> Bool {
        let fileManager = FileManager.default
        let wineBinPath = whiskyWineBinFolder.appendingPathComponent("wine64")
        let wineBinFallback = whiskyWineBinFolder.appendingPathComponent("wine")
        let wineLibFolder = whiskyWineLibFolder
        let wineUnixLibFolder = wineLibFolder
            .appendingPathComponent("wine")
            .appendingPathComponent("x86_64-unix")
        let wineNlsFolder = whiskyWineShareFolder
            .appendingPathComponent("wine")
            .appendingPathComponent("nls")
        let wineFontsFolder = whiskyWineShareFolder
            .appendingPathComponent("wine")
            .appendingPathComponent("fonts")

        let wineExists = fileManager.fileExists(atPath: wineBinPath.path) ||
                         fileManager.fileExists(atPath: wineBinFallback.path)
        let libExists = fileManager.fileExists(atPath: wineLibFolder.path)
        let unixLibExists = fileManager.fileExists(atPath: wineUnixLibFolder.path)
        let nlsExists = fileManager.fileExists(atPath: wineNlsFolder.path)
        let fontsExists = fileManager.fileExists(atPath: wineFontsFolder.path)

        guard wineExists && libExists && unixLibExists && nlsExists && fontsExists else {
            return false
        }

        let minSize: Int64 = 50 * 1024 * 1024
        guard directorySize(wineLibFolder) >= minSize else {
            return false
        }

        return whiskyWineVersion() != nil
    }

    // MARK: - Proton Detection

    private static func protonLibraryFolder(for mode: WineMode) -> URL {
        switch mode {
        case .proton11:
            return applicationFolder.appending(path: "Libraries/Proton11")
        case .proton10:
            return applicationFolder.appending(path: "Libraries/Proton10")
        default:
            return applicationFolder.appending(path: "Libraries")
        }
    }

    private static func protonBinFolder(for mode: WineMode) -> URL {
        protonLibraryFolder(for: mode).appending(path: "files").appending(path: "bin")
    }

    private static func protonLibFolder(for mode: WineMode) -> URL {
        protonLibraryFolder(for: mode).appending(path: "files").appending(path: "lib")
    }

    private static func protonShareFolder(for mode: WineMode) -> URL {
        protonLibraryFolder(for: mode).appending(path: "files").appending(path: "share")
    }

    public static func isProton11Installed() -> Bool {
        isProtonInstalled(mode: .proton11)
    }

    public static func isProton10Installed() -> Bool {
        isProtonInstalled(mode: .proton10)
    }

    private static func isProtonInstalled(mode: WineMode) -> Bool {
        guard mode == .proton11 || mode == .proton10 else {
            return false
        }

        let fileManager = FileManager.default
        let wineBinPath = protonBinFolder(for: mode).appendingPathComponent("wine64")
        let wineBinFallback = protonBinFolder(for: mode).appendingPathComponent("wine")
        let wineLibFolder = protonLibFolder(for: mode)
        let wineUnixLibFolder = wineLibFolder
            .appendingPathComponent("wine")
            .appendingPathComponent("x86_64-unix")
        let wineNlsFolder = protonShareFolder(for: mode)
            .appendingPathComponent("wine")
            .appendingPathComponent("nls")
        let wineFontsFolder = protonShareFolder(for: mode)
            .appendingPathComponent("wine")
            .appendingPathComponent("fonts")

        let wineExists = fileManager.fileExists(atPath: wineBinPath.path) ||
                         fileManager.fileExists(atPath: wineBinFallback.path)
        let libExists = fileManager.fileExists(atPath: wineLibFolder.path)
        let unixLibExists = fileManager.fileExists(atPath: wineUnixLibFolder.path)
        let nlsExists = fileManager.fileExists(atPath: wineNlsFolder.path)
        let fontsExists = fileManager.fileExists(atPath: wineFontsFolder.path)

        guard wineExists && libExists && unixLibExists && nlsExists && fontsExists else {
            return false
        }

        let minSize: Int64 = 50 * 1024 * 1024
        guard directorySize(wineLibFolder) >= minSize else {
            return false
        }

        return protonVersion(mode: mode) != nil
    }

    public static func isInstalled(mode: WineMode) -> Bool {
        switch mode {
        case .whiskyWine:
            return isWhiskyWineInstalled()
        case .proton11:
            return isProton11Installed()
        case .proton10:
            return isProton10Installed()
        case .crossover:
            return isCrossOverInstalled()
        }
    }

    public static func downloadURL(for mode: WineMode) -> URL? {
        switch mode {
        case .whiskyWine:
            return URL(string: whiskyWineBaseURL + "Libraries.tar.gz")
        case .proton11:
            return protonDownloadURL(for: .proton11)
        case .proton10:
            return protonDownloadURL(for: .proton10)
        case .crossover:
            return nil
        }
    }

    public static func install(from: URL) -> Result<Void, Error> {
        do {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: applicationFolder.path) {
                try fileManager.createDirectory(at: applicationFolder, withIntermediateDirectories: true)
            } else {
                let librariesFolder = applicationFolder.appending(path: "Libraries")
                if fileManager.fileExists(atPath: librariesFolder.path) {
                    try fileManager.removeItem(at: librariesFolder)
                }
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

    public static func installWithRetries(from url: URL, maxRetries: Int = 3) async -> Result<Void, Error> {
        var lastError: Error?
        for attempt in 1...maxRetries {
            print("[WhiskyWine Install] Attempt \(attempt)/\(maxRetries)")
            let result = install(from: url)
            switch result {
            case .success:
                return .success(())
            case .failure(let error):
                lastError = error
                if attempt < maxRetries {
                    print("[WhiskyWine Install] Attempt \(attempt) failed, retrying...")
                    clearDownloadCache()
                }
            }
        }
        print("[WhiskyWine Install] All \(maxRetries) attempts failed")
        guard let finalError = lastError else {
            return .failure(InstallationError.invalidInstallation("Unknown installation error"))
        }
        return .failure(finalError)
    }

    public static func installWithRetries(from url: URL, mode: WineMode, maxRetries: Int = 3) async -> Result<Void, Error> {
        switch mode {
        case .whiskyWine:
            return await installWithRetries(from: url, maxRetries: maxRetries)
        case .proton11, .proton10:
            var lastError: Error?
            for attempt in 1...maxRetries {
                print("[Proton Install] Attempt \(attempt)/\(maxRetries)")
                let result = installProton(from: url, mode: mode)
                switch result {
                case .success:
                    return .success(())
                case .failure(let error):
                    lastError = error
                    if attempt < maxRetries {
                        print("[Proton Install] Attempt \(attempt) failed, retrying...")
                        clearDownloadCache()
                    }
                }
            }
            print("[Proton Install] All \(maxRetries) attempts failed")
            guard let finalError = lastError else {
                return .failure(InstallationError.invalidInstallation("Unknown installation error"))
            }
            return .failure(finalError)
        case .crossover:
            return .failure(InstallationError.invalidInstallation("CrossOver installation is not supported via this method"))
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
            let versionPlist = whiskyWineLibraryFolder
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
