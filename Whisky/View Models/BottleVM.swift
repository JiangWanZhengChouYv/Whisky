//
//  BottleVM.swift
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
import SemanticVersion
import WhiskyKit

// swiftlint:disable:next todo
// TODO: Don't use unchecked!
final class BottleVM: ObservableObject, @unchecked Sendable {
    @MainActor static let shared = BottleVM()

    var bottlesList = BottleData()
    @Published var bottles: [Bottle] = []

    @MainActor
    func loadBottles() {
        bottles = bottlesList.loadBottles()
    }

    func countActive() -> Int {
        return bottles.filter { $0.isAvailable == true }.count
    }

    func createNewBottle(bottleName: String, winVersion: WinVersion, bottleURL: URL) -> URL {
        let newBottleDir = bottleURL.appending(path: UUID().uuidString)

        Task.detached {
            await self.createBottleAsync(bottleName: bottleName,
                                         winVersion: winVersion,
                                         newBottleDir: newBottleDir)
        }
        return newBottleDir
    }

    private func createBottleAsync(bottleName: String,
                                   winVersion: WinVersion,
                                   newBottleDir: URL) async {
        var bottleId: Bottle?
        do {
            try FileManager.default.createDirectory(atPath: newBottleDir.path(percentEncoded: false),
                                                    withIntermediateDirectories: true)
            let bottle = Bottle(bottleUrl: newBottleDir, inFlight: true)
            bottleId = bottle

            await MainActor.run {
                self.bottles.append(bottle)
            }

            bottle.settings.windowsVersion = winVersion
            bottle.settings.name = bottleName
            try await Wine.wineboot(bottle: bottle)
            try await Wine.changeWinVersion(bottle: bottle, win: winVersion)
            let wineVer = try await Wine.wineVersion()
            bottle.settings.wineVersion = SemanticVersion(wineVer) ?? SemanticVersion(0, 0, 0)
            await MainActor.run {
                bottle.inFlight = false
                self.bottlesList.paths.append(newBottleDir)
                self.loadBottles()
            }
        } catch {
            await handleBottleCreationError(error: error,
                                            bottleId: bottleId,
                                            newBottleDir: newBottleDir)
        }
    }

    @MainActor
    private func handleBottleCreationError(error: Error,
                                           bottleId: Bottle?,
                                           newBottleDir: URL) async {
        let nsError = error as NSError
        print("Failed to create new bottle: \(error)")
        print("Detailed error: domain=\(nsError.domain), code=\(nsError.code), userInfo=\(nsError.userInfo)")

        var detailedMessage = error.localizedDescription

        if let wineError = error as? WineInterfaceError {
            detailedMessage = wineError.errorDescription ?? error.localizedDescription
        }

        let alert = NSAlert()
        alert.messageText = "Failed to create bottle"
        alert.informativeText = detailedMessage
        alert.alertStyle = .critical
        alert.addButton(withTitle: String(localized: "button.ok"))
        alert.runModal()

        if let bottle = bottleId {
            bottle.inFlight = false
            self.bottlesList.paths.append(newBottleDir)
            self.loadBottles()
        }
    }
}
