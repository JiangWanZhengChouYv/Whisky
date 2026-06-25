//
//  WhiskyWineInstallView.swift
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

struct WhiskyWineInstallView: View {
    @State var installing: Bool = true
    @State private var installError: String?
    @Binding var tarLocation: URL
    @Binding var path: [SetupStage]
    @Binding var showSetup: Bool

    var body: some View {
        VStack {
            VStack {
                Text("setup.whiskywine.install")
                    .font(.title)
                    .fontWeight(.bold)
                Text("setup.whiskywine.install.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if installing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 80)
                } else if let errorMessage = installError {
                    VStack(spacing: 12) {
                        Image(systemName: "xmark.circle")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("重试") {
                            installError = nil
                            installing = true
                            clearCachedDownload()
                            if path.last == .whiskyWineInstall {
                                path.removeLast()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if installError == nil {
                    Image(systemName: "checkmark.circle")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.green)
                }
                Spacer()
            }
            Spacer()
        }
        .frame(width: 400, height: 200)
        .onAppear {
            Task {
                let result = await WhiskyWineInstaller.install(from: tarLocation)
                await handleInstallResult(result)
            }
        }
    }

    @MainActor
    func proceed() {
        showSetup = false
    }

    @MainActor
    private func handleInstallResult(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            installing = false
            sleep(2)
            proceed()
        case .failure(let error):
            installing = false
            installError = error.safeLocalizedDescription
        }
    }

    private func clearCachedDownload() {
        let fileManager = FileManager.default
        if let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let downloadsDir = supportDir
                .appendingPathComponent("Whisky", isDirectory: true)
                .appendingPathComponent("Downloads", isDirectory: true)
            let cachedTarURL = downloadsDir.appendingPathComponent("Libraries.tar.gz")
            let completeMarkerURL = cachedTarURL.appendingPathExtension("complete")

            if fileManager.fileExists(atPath: cachedTarURL.path) {
                try? fileManager.removeItem(at: cachedTarURL)
                print("[WhiskyWineInstall] Cleared cached tar file")
            }
            if fileManager.fileExists(atPath: completeMarkerURL.path) {
                try? fileManager.removeItem(at: completeMarkerURL)
                print("[WhiskyWineInstall] Cleared complete marker file")
            }
        }
    }
}
