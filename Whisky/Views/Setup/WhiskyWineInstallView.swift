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
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        HStack(spacing: 12) {
                            Button("查看日志") {
                                WhiskyApp.showErrorLog(
                                    title: "安装错误",
                                    message: errorMessage
                                )
                            }
                            Button("setup.retry") {
                                WhiskyWineInstaller.clearDownloadCache()
                                if path.last == .whiskyWineInstall {
                                    path.removeLast()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
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
        .frame(width: 400, height: 260)
        .onAppear {
            Task {
                let result = await WhiskyWineInstaller.installWithRetries(from: tarLocation, mode: WhiskyWineInstaller.currentMode)
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

}
