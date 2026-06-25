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
                // 先初始化 Wine prefix，再设置 Windows 版本
                try await Wine.wineboot(bottle: bottle)
                try await Wine.changeWinVersion(bottle: bottle, win: winVersion)
                let wineVer = try await Wine.wineVersion()
                bottle.settings.wineVersion = SemanticVersion(wineVer) ?? SemanticVersion(0, 0, 0)
                // 成功后持久化记录
                await MainActor.run {
                    bottle.inFlight = false
                    self.bottlesList.paths.append(newBottleDir)
                    self.loadBottles()
                }
            } catch {
                let nsError = error as NSError
                print("Failed to create new bottle: \(error)")
                print("Detailed error: domain=\(nsError.domain), code=\(nsError.code), userInfo=\(nsError.userInfo)")
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "Failed to create bottle"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: String(localized: "button.ok"))
                    alert.runModal()
                }
                if let bottle = bottleId {
                    await MainActor.run {
                        bottle.inFlight = false
                        self.bottlesList.paths.append(newBottleDir)
                        self.loadBottles()
                    }
                }
            }
        }
        return newBottleDir
    }
}
