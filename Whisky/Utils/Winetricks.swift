//
//  Winetricks.swift
//  Whisky
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
import AppKit
import WhiskyKit

enum WinetricksCategories: String {
    case apps
    case benchmarks
    case dlls
    case fonts
    case games
    case settings
}

enum WinetricksError {
    case missingWinetricksScript
    case missingVerbsFile
    case emptyVerbs
    case parseFailed

    var title: String {
        switch self {
        case .missingWinetricksScript:
            return String(localized: "winetricks.error.missingScript.title")
        case .missingVerbsFile:
            return String(localized: "winetricks.error.missingVerbs.title")
        case .emptyVerbs:
            return String(localized: "winetricks.error.emptyVerbs.title")
        case .parseFailed:
            return String(localized: "winetricks.error.parseFailed.title")
        }
    }

    var message: String {
        switch self {
        case .missingWinetricksScript:
            return String(localized: "winetricks.error.missingScript.message")
        case .missingVerbsFile:
            return String(localized: "winetricks.error.missingVerbs.message")
        case .emptyVerbs:
            return String(localized: "winetricks.error.emptyVerbs.message")
        case .parseFailed:
            return String(localized: "winetricks.error.parseFailed.message")
        }
    }

    var filePath: String? {
        switch self {
        case .missingWinetricksScript:
            return Winetricks.winetricksURL.path(percentEncoded: false)
        case .missingVerbsFile:
            return WhiskyWineInstaller.libraryFolder.appending(path: "verbs.txt").path(percentEncoded: false)
        default:
            return nil
        }
    }
}

struct WinetricksVerb: Identifiable {
    var id = UUID()

    var name: String
    var description: String
}

struct WinetricksCategory {
    var category: WinetricksCategories
    var verbs: [WinetricksVerb]
}

class Winetricks {
    static let winetricksURL: URL = WhiskyWineInstaller.libraryFolder
        .appending(path: "winetricks")

    static func runCommand(command: String, bottle: Bottle) async {
        guard let resourcesURL = Bundle.main.url(forResource: "cabextract", withExtension: nil)?
            .deletingLastPathComponent() else { return }
        // swiftlint:disable:next line_length
        let winetricksCmd = #"PATH=\"\#(WhiskyWineInstaller.binFolder.path):\#(resourcesURL.path(percentEncoded: false)):$PATH\" WINE=wine64 WINEPREFIX=\"\#(bottle.url.path)\" \"\#(winetricksURL.path(percentEncoded: false))\" \#(command)"#

        let script = """
        tell application "Terminal"
            activate
            do script "\(winetricksCmd)"
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)

            if let error = error {
                print(error)
                if let description = error["NSAppleScriptErrorMessage"] as? String {
                    await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = String(localized: "alert.message")
                        alert.informativeText = String(localized: "alert.info")
                            + " \(command): "
                            + description
                        alert.alertStyle = .critical
                        alert.addButton(withTitle: String(localized: "button.ok"))
                        alert.runModal()
                    }
                }
            }
        }
    }

    static func parseVerbs() async -> (categories: [WinetricksCategory]?, error: WinetricksError?) {
        let winetricksURL = WhiskyWineInstaller.libraryFolder.appending(path: "winetricks")
        let verbsURL = WhiskyWineInstaller.libraryFolder.appending(path: "verbs.txt")

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: winetricksURL.path(percentEncoded: false)) else {
            return (nil, .missingWinetricksScript)
        }
        guard fileManager.fileExists(atPath: verbsURL.path(percentEncoded: false)) else {
            return (nil, .missingVerbsFile)
        }

        let verbs: String = await { () async -> String in
            do {
                let (data, _) = try await URLSession.shared.data(from: verbsURL)
                return String(data: data, encoding: .utf8) ?? String()
            } catch {
                return String()
            }
        }()

        guard !verbs.isEmpty else {
            return (nil, .emptyVerbs)
        }

        let lines = verbs.components(separatedBy: "\n")
        var categories: [WinetricksCategory] = []
        var currentCategory: WinetricksCategory?

        for line in lines {
            if line.starts(with: "=====") {
                if let currentCategory = currentCategory {
                    categories.append(currentCategory)
                }

                let categoryName = line.replacingOccurrences(of: "=====", with: "").trimmingCharacters(in: .whitespaces)
                if let cateogry = WinetricksCategories(rawValue: categoryName) {
                    currentCategory = WinetricksCategory(category: cateogry,
                                                         verbs: [])
                } else {
                    currentCategory = nil
                }
            } else {
                guard currentCategory != nil else {
                    continue
                }

                let verbName = line.components(separatedBy: " ")[0]
                let verbDescription = line.replacingOccurrences(of: "\(verbName) ", with: "")
                    .trimmingCharacters(in: .whitespaces)
                currentCategory?.verbs.append(WinetricksVerb(name: verbName, description: verbDescription))
            }
        }

        if let currentCategory = currentCategory {
            categories.append(currentCategory)
        }

        if categories.isEmpty {
            return (nil, .parseFailed)
        }

        return (categories, nil)
    }
}
