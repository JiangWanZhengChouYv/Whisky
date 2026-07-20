//
//  RunningProcessView.swift
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
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.whisky.Whisky", category: "RunningProcessesView")

enum ProcessLoadState {
    case loading, success, error, empty
}

struct BottleProcess: Identifiable {
    var id = UUID()
    var pid: String
    var procName: String
}

struct RunningProcessesView: View {
    @ObservedObject var bottle: Bottle

    @State private var processes = [BottleProcess]()
    @State private var processSortOrder = [KeyPathComparator(\BottleProcess.pid)]
    @State private var selectedProcess: BottleProcess.ID?
    @State private var loadState: ProcessLoadState = .loading

    var body: some View {
        ZStack {
            switch loadState {
            case .loading:
                HStack(alignment: .center) {
                    Spacer()
                    VStack(alignment: .center) {
                        ProgressView()
                            .padding()
                        Text("process.table.loading")
                    }
                    Spacer()
                }
            case .success:
                VStack {
                    Table(processes, selection: $selectedProcess, sortOrder: $processSortOrder) {
                        TableColumn("process.table.pid", value: \.pid)
                        TableColumn("process.table.executable", value: \.procName)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    HStack {
                        Spacer()
                        Button("process.table.refresh") {
                            Task.detached(priority: .userInitiated) {
                                await fetchProcesses()
                            }
                        }
                        Button("process.table.kill") {
                            Task.detached(priority: .userInitiated) {
                                await killProcess()
                            }
                        }
                    }
                    .padding()
                }
            case .empty:
                HStack(alignment: .center) {
                    Spacer()
                    VStack(alignment: .center) {
                        Text("process.table.empty")
                            .padding()
                    }
                    Spacer()
                }
            case .error:
                HStack(alignment: .center) {
                    Spacer()
                    VStack(alignment: .center) {
                        Text("process.table.error")
                            .padding()
                        Button("process.table.retry") {
                            Task.detached(priority: .userInitiated) {
                                await fetchProcesses()
                            }
                        }
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            Task.detached(priority: .userInitiated) {
                await fetchProcesses()
            }
        }
    }

    func fetchProcesses() async {
        loadState = .loading
        var newProcessList = [BottleProcess]()
        let output: String?

        do {
            output = try await Wine.runWine(["tasklist.exe", "/FO", "CSV"], bottle: bottle)
        } catch {
            logger.error("Error running tasklist.exe: \(error.localizedDescription, privacy: .public)")
            loadState = .error
            return
        }

        let lines = output?.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
        var isFirstLine = true
        for line in lines ?? [] {
            // Skip CSV header line
            if isFirstLine {
                isFirstLine = false
                continue
            }
            let lineParts = line.split(separator: ",", omittingEmptySubsequences: true)
            if lineParts.count > 1 {
                // Remove surrounding quotes from CSV fields
                let procName = String(lineParts[0]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                let pid = String(lineParts[1]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if !procName.isEmpty && !pid.isEmpty {
                    newProcessList.append(BottleProcess(pid: pid, procName: procName))
                }
            }
        }
        processes = newProcessList
        if newProcessList.isEmpty {
            loadState = .empty
        } else {
            loadState = .success
        }
    }

    func killProcess() async {
        if let thisProcess = processes.first(where: { $0.id == selectedProcess }) {
            do {
                try await Wine.runWine(["taskkill.exe", "/PID", thisProcess.pid, "/F"], bottle: bottle)
                try await Task.sleep(nanoseconds: 2000)
            } catch {
                logger.error("Error running taskkill.exe: \(error.localizedDescription, privacy: .public)")
            }
            await fetchProcesses()
        }
    }
}
