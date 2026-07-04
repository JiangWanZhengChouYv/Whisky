//
//  BottleListEntry.swift
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

import SwiftUI
import WhiskyKit
import UniformTypeIdentifiers

struct BottleListEntry: View {
    let bottle: Bottle
    @Binding var selected: URL?
    @Binding var refresh: Bool

    @State private var showBottleRename: Bool = false
    @State private var name: String = ""

    var body: some View {
        Text(name)
            .opacity(bottle.isAvailable ? 1.0 : 0.5)
            .onChange(of: refresh, initial: true) {
                name = bottle.settings.name
            }
            .sheet(isPresented: $showBottleRename) {
                RenameView("rename.bottle.title", name: name) { newName in
                    name = newName
                    bottle.rename(newName: newName)
                }
            }
            .contextMenu {
                Button("button.rename", systemImage: "pencil.line") {
                    showBottleRename.toggle()
                }
                .disabled(!bottle.isAvailable)
                .labelStyle(.titleAndIcon)
                Button("button.duplicateBottle", systemImage: "doc.on.doc") {
                    Task(priority: .userInitiated) {
                        bottle.duplicate()
                    }
                }
                .disabled(!bottle.isAvailable)
                .labelStyle(.titleAndIcon)
                Button("button.removeAlert", systemImage: "trash") {
                    showRemoveAlert(bottle: bottle)
                }
                .labelStyle(.titleAndIcon)
                Divider()
                Button("button.moveBottle", systemImage: "shippingbox.and.arrow.backward") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.canCreateDirectories = true
                    panel.begin { result in
                        if result == .OK {
                            if let url = panel.urls.first {
                                let newBottePath = url
                                    .appending(path: bottle.url.lastPathComponent)

                                bottle.move(destination: newBottePath)
                                selected = newBottePath
                            }
                        }
                    }
                }
                .disabled(!bottle.isAvailable)
                .labelStyle(.titleAndIcon)
                Button("button.exportBottle", systemImage: "arrowshape.turn.up.right") {
                    let panel = NSSavePanel()
                    panel.canCreateDirectories = true
                    panel.allowedContentTypes = [UTType.gzip]
                    panel.allowsOtherFileTypes = false
                    panel.isExtensionHidden = false
                    panel.nameFieldStringValue = bottle.settings.name + ".tar.gz"
                    panel.begin { result in
                        if result == .OK {
                            if let url = panel.url {
                                Task.detached(priority: .background) {
                                    do {
                                        try bottle.exportAsArchive(destination: url)
                                        await MainActor.run {
                                            showExportSuccessAlert(path: url.path)
                                        }
                                    } catch {
                                        await MainActor.run {
                                            showExportErrorAlert(error: error)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .disabled(!bottle.isAvailable)
                .labelStyle(.titleAndIcon)
                Divider()
                Button("button.showInFinder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([bottle.url])
                }
                .disabled(!bottle.isAvailable)
                .labelStyle(.titleAndIcon)
            }
    }

    func showRemoveAlert(bottle: Bottle) {
        let checkbox = NSButton(checkboxWithTitle: String(localized: "button.removeAlert.checkbox"),
                                target: self, action: nil)
        let alert = NSAlert()
        alert.messageText = String(format: String(localized: "button.removeAlert.msg"),
                                   bottle.settings.name)
        alert.informativeText = String(localized: "button.removeAlert.info")
        alert.alertStyle = .warning
        let delete = alert.addButton(withTitle: String(localized: "button.removeAlert.delete"))
        delete.hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "button.removeAlert.cancel"))
        if bottle.isAvailable {
            alert.accessoryView = checkbox
        }

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            Task(priority: .userInitiated) {
                if selected == bottle.url {
                    selected = nil
                }

                bottle.remove(delete: checkbox.state == .on)
            }
        }
    }

    private func showExportSuccessAlert(path: String) {
        let alert = NSAlert()
        alert.messageText = String(localized: "export.success")
        alert.informativeText = String(format: String(localized: "export.successMessage"), path)
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "button.ok"))
        alert.runModal()
    }

    private func showExportErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = String(localized: "export.failed")
        alert.informativeText = String(format: String(localized: "export.errorMessage"),
                                       error.localizedDescription)
        alert.alertStyle = .critical
        alert.addButton(withTitle: String(localized: "button.ok"))
        alert.runModal()
    }
}

#Preview {
    BottleListEntry(
        bottle: Bottle(bottleUrl: URL(filePath: "")),
        selected: .constant(nil),
        refresh: .constant(false)
    )
}
