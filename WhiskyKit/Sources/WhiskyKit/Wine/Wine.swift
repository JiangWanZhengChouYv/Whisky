//
//  Wine.swift
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
import os.log

public class Wine {
    /// URL to the installed `DXVK` folder
    private static var dxvkFolder: URL { WhiskyWineInstaller.dxvkFolder(for: WhiskyWineInstaller.currentMode) }
    /// Whether DXVK files are available for the current mode
    public static var isDXVKAvailable: Bool {
        WhiskyWineInstaller.isDXVKInstalled(mode: WhiskyWineInstaller.currentMode)
    }
    /// Path to the `wine` binary
    public static var wineBinary: URL {
        switch WhiskyWineInstaller.currentMode {
        case .whiskyWine, .proton11, .proton10:
            return WhiskyWineInstaller.binFolder.appending(path: "wine64")
        case .crossover:
            return WhiskyWineInstaller.libFolder
                .appendingPathComponent("wine")
                .appendingPathComponent("x86_64-unix")
                .appending(path: "wine")
        }
    }
    /// Parth to the `wineserver` binary
    private static var wineserverBinary: URL {
        switch WhiskyWineInstaller.currentMode {
        case .whiskyWine, .proton11, .proton10:
            return WhiskyWineInstaller.binFolder.appending(path: "wineserver")
        case .crossover:
            return WhiskyWineInstaller.libraryFolder
                .appendingPathComponent("CrossOver-Hosted Application")
                .appending(path: "wineserver")
        }
    }

    /// Run a process on a executable file given by the `executableURL`
    private static func runProcess(
        name: String? = nil, args: [String], environment: [String: String], executableURL: URL, directory: URL? = nil,
        fileHandle: FileHandle?
    ) throws -> AsyncStream<ProcessOutput> {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = args
        process.currentDirectoryURL = directory ?? executableURL.deletingLastPathComponent()
        process.environment = environment
        process.qualityOfService = .userInitiated

        return try process.runStream(
            name: name ?? args.joined(separator: " "), fileHandle: fileHandle
        )
    }

    /// Run a `wine` process with the given arguments and environment variables returning a stream of output
    private static func runWineProcess(
        name: String? = nil, args: [String], environment: [String: String] = [:],
        fileHandle: FileHandle?
    ) throws -> AsyncStream<ProcessOutput> {
        return try runProcess(
            name: name, args: args, environment: environment, executableURL: wineBinary,
            fileHandle: fileHandle
        )
    }

    /// Run a `wineserver` process with the given arguments and environment variables returning a stream of output
    private static func runWineserverProcess(
        name: String? = nil, args: [String], environment: [String: String] = [:],
        fileHandle: FileHandle?
    ) throws -> AsyncStream<ProcessOutput> {
        return try runProcess(
            name: name, args: args, environment: environment, executableURL: wineserverBinary,
            fileHandle: fileHandle
        )
    }

    /// Run a `wine` process with the given arguments and environment variables returning a stream of output
    public static func runWineProcess(
        name: String? = nil, args: [String], bottle: Bottle, environment: [String: String] = [:]
    ) throws -> AsyncStream<ProcessOutput> {
        let fileHandle = try makeFileHandle()
        fileHandle.writeApplicaitonInfo()
        fileHandle.writeInfo(for: bottle)

        return try runWineProcess(
            name: name, args: args,
            environment: constructWineEnvironment(for: bottle, environment: environment),
            fileHandle: fileHandle
        )
    }

    /// Run a `wineserver` process with the given arguments and environment variables returning a stream of output
    public static func runWineserverProcess(
        name: String? = nil, args: [String], bottle: Bottle, environment: [String: String] = [:]
    ) throws -> AsyncStream<ProcessOutput> {
        let fileHandle = try makeFileHandle()
        fileHandle.writeApplicaitonInfo()
        fileHandle.writeInfo(for: bottle)

        return try runWineserverProcess(
            name: name, args: args,
            environment: constructWineServerEnvironment(for: bottle, environment: environment),
            fileHandle: fileHandle
        )
    }

    /// Execute a `wine start /unix {url}` command returning the output result
    public static func runProgram(
        at url: URL, args: [String] = [], bottle: Bottle, environment: [String: String] = [:]
    ) async throws {
        if bottle.settings.dxvk {
            if isDXVKAvailable {
                try enableDXVK(bottle: bottle)
            } else {
                Logger.wineKit.warning("DXVK is enabled but DXVK files are not available")
            }
        }

        await MainActor.run {
            bottle.settings.addRecentlyUsedProgram(url)
            Logger.wineKit.info("Added to recently used: \(url.lastPathComponent, privacy: .public)")
        }

        var args = args
        if isSteamProgram(url: url) {
            applySteamCompatibilityArgs(args: &args)
        }

        let fileHandle = try makeFileHandle()
        fileHandle.writeApplicaitonInfo()
        fileHandle.writeInfo(for: bottle)

        var wineEnv = constructWineEnvironment(for: bottle, programURL: url, environment: environment)

        for await _ in try runWineProcess(
            name: url.lastPathComponent,
            args: ["start", "/unix", url.path(percentEncoded: false)] + args,
            environment: wineEnv,
            fileHandle: fileHandle
        ) { }
    }

    private static func isSteamProgram(url: URL) -> Bool {
        switch WhiskyWineInstaller.currentMode {
        case .proton11, .proton10:
            return url.path.lowercased().contains("steam")
        case .whiskyWine, .crossover:
            return false
        }
    }

    private static func applySteamCompatibilityArgs(args: inout [String]) {
        // Steam 自身参数：强制使用旧版非 Chromium 登录界面
        if !args.contains("-noreactlogin") {
            args.append("-noreactlogin")
        }
        // Chromium/CEF 参数：必须使用 -- 双横线格式（单横线 -cef-xxx 不生效）
        let cefArgs = [
            "--disable-gpu",
            "--in-process-gpu",
            "--disable-sandbox",
            "--disable-gpu-compositing",
            "--disable-direct-composition",
            "--no-zygote",
            "--use-gl=swiftshader",
            "--disable-features=VizDisplayCompositor",
            "--enable-low-end-device-mode",
            "--disable-gpu-rasterization",
            "--disable-oop-rasterization"
        ]
        for cefArg in cefArgs {
            if !args.contains(cefArg) {
                args.append(cefArg)
            }
        }
    }

    private static func applySteamCompatibilityEnvironment(environment: inout [String: String]) {
        if environment["STEAMOS"] == nil {
            environment["STEAMOS"] = "1"
        }

        environment.removeValue(forKey: "ROSETTA_ADVERTISE_AVX")

        if environment["WINEMSYNC"] != nil {
            environment.removeValue(forKey: "WINEESYNC")
        }
    }

    public static func generateRunCommand(
        at url: URL, bottle: Bottle, args: String, environment: [String: String]
    ) -> String {
        var wineCmd = "\(wineBinary.esc) start /unix \(url.esc) \(args)"
        let env = constructWineEnvironment(for: bottle, environment: environment)
        for environment in env {
            wineCmd = "\(environment.key)=\"\(environment.value)\" " + wineCmd
        }

        return wineCmd
    }

    public static func generateTerminalEnvironmentCommand(bottle: Bottle) -> String {
        let wineBinaryName = wineBinary.lastPathComponent
        let wineDir = wineBinary.deletingLastPathComponent().path
        var cmd = """
        export PATH=\"\(wineDir):\(WhiskyWineInstaller.binFolder.path):$PATH\"
        export WINE=\"\(wineBinaryName)\"
        alias wine=\"\(wineBinaryName)\"
        alias winecfg=\"\(wineBinaryName) winecfg\"
        alias msiexec=\"\(wineBinaryName) msiexec\"
        alias regedit=\"\(wineBinaryName) regedit\"
        alias regsvr32=\"\(wineBinaryName) regsvr32\"
        alias wineboot=\"\(wineBinaryName) wineboot\"
        alias wineconsole=\"\(wineBinaryName) wineconsole\"
        alias winedbg=\"\(wineBinaryName) winedbg\"
        alias winefile=\"\(wineBinaryName) winefile\"
        alias winepath=\"\(wineBinaryName) winepath\"
        """

        let env = constructWineEnvironment(for: bottle, environment: constructWineEnvironment(for: bottle))
        for environment in env {
            cmd += "\nexport \(environment.key)=\"\(environment.value)\""
        }

        return cmd
    }

    /// Run a `wineserver` command with the given arguments and return the output result
    private static func runWineserver(_ args: [String], bottle: Bottle) async throws -> String {
        var result: [ProcessOutput] = []

        for await output in try Self.runWineserverProcess(args: args, bottle: bottle, environment: [:]) {
            result.append(output)
        }

        return result.compactMap { output -> String? in
            switch output {
            case .started, .terminated:
                return nil
            case .message(let message), .error(let message):
                return message
            }
        }.joined()
    }

    @discardableResult
    /// Run a `wine` command with the given arguments and return the output result
    public static func runWine(
        _ args: [String], bottle: Bottle?, environment: [String: String] = [:]
    ) async throws -> String {
        var result: [String] = []
        var errorOutput: [String] = []
        var terminationStatus: Int32 = 0
        let fileHandle = try makeFileHandle()
        fileHandle.writeApplicaitonInfo()
        var environment = environment

        if let bottle = bottle {
            fileHandle.writeInfo(for: bottle)
            environment = constructWineEnvironment(for: bottle, environment: environment)
        } else {
            environment = constructBaseWineEnvironment(environment: environment)
        }

        for await output in try runWineProcess(args: args, environment: environment, fileHandle: fileHandle) {
            switch output {
            case .started:
                break
            case .terminated(let process):
                terminationStatus = process.terminationStatus
            case .message(let message):
                result.append(message)
            case .error(let message):
                errorOutput.append(message)
            }
        }

        let allOutput = (result + errorOutput).joined()
        if terminationStatus != 0 {
            throw WineInterfaceError.wineProcessFailed(
                command: args.joined(separator: " "),
                status: terminationStatus,
                output: allOutput
            )
        }

        return allOutput
    }

    public static func wineVersion() async throws -> String {
        var output = try await runWine(["--version"], bottle: nil)
        output.replace("wine-", with: "")

        // Deal with WineCX version names
        if let index = output.firstIndex(where: { $0.isWhitespace }) {
            return String(output.prefix(upTo: index))
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    public static func runBatchFile(url: URL, bottle: Bottle) async throws -> String {
        return try await runWine(["cmd", "/c", url.path(percentEncoded: false)], bottle: bottle)
    }

    public static func killBottle(bottle: Bottle) throws {
        Task.detached(priority: .userInitiated) {
            try await runWineserver(["-k"], bottle: bottle)
        }
    }

    public static func enableDXVK(bottle: Bottle) throws {
        guard isDXVKAvailable else {
            throw WineError.dxvkNotAvailable
        }
        try FileManager.default.replaceDLLs(
            in: bottle.url.appending(path: "drive_c").appending(path: "windows").appending(path: "system32"),
            withContentsIn: Wine.dxvkFolder.appending(path: "x64")
        )
        try FileManager.default.replaceDLLs(
            in: bottle.url.appending(path: "drive_c").appending(path: "windows").appending(path: "syswow64"),
            withContentsIn: Wine.dxvkFolder.appending(path: "x32")
        )
    }

    /// Construct an environment merging the bottle values with the given values
    private static func constructWineEnvironment(
        for bottle: Bottle, programURL: URL? = nil, environment: [String: String] = [:]
    ) -> [String: String] {
        let wineDataDir = WhiskyWineInstaller.shareFolder.appendingPathComponent("wine")
        let wineBinPath = WhiskyWineInstaller.binFolder.path
        let currentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        var result: [String: String] = [
            "WINEPREFIX": bottle.url.path,
            "WINEDEBUG": "fixme-all",
            "GST_DEBUG": "1",
            "WINEDLLPATH": defaultWineDLLPath(),
            "WINEDATADIR": wineDataDir.path,
            "PATH": "\(wineBinPath):\(currentPath)",
            "ROSETTA_ADVERTISE_AVX": "1",
            "DOTNET_EnableWriteXorExecute": "0"
        ]

        if WhiskyWineInstaller.currentMode == .crossover {
            applyCrossOverEnvironment(to: &result)
        }

        bottle.settings.environmentVariables(wineEnv: &result)
        guard !environment.isEmpty else {
            if let programURL = programURL, isSteamProgram(url: programURL) {
                applySteamCompatibilityEnvironment(environment: &result)
            }
            return result
        }
        result.merge(environment, uniquingKeysWith: { $1 })
        if let programURL = programURL, isSteamProgram(url: programURL) {
            applySteamCompatibilityEnvironment(environment: &result)
        }
        return result
    }

    /// Construct base wine environment without a bottle (for --version etc.)
    private static func constructBaseWineEnvironment(
        environment: [String: String] = [:]
    ) -> [String: String] {
        let wineDataDir = WhiskyWineInstaller.shareFolder.appendingPathComponent("wine")
        let wineBinPath = WhiskyWineInstaller.binFolder.path
        let currentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        var result: [String: String] = [
            "WINEDEBUG": "fixme-all",
            "GST_DEBUG": "1",
            "WINEDLLPATH": defaultWineDLLPath(),
            "WINEDATADIR": wineDataDir.path,
            "PATH": "\(wineBinPath):\(currentPath)",
            "ROSETTA_ADVERTISE_AVX": "1",
            "DOTNET_EnableWriteXorExecute": "0"
        ]

        if WhiskyWineInstaller.currentMode == .crossover {
            applyCrossOverEnvironment(to: &result)
        }

        guard !environment.isEmpty else { return result }
        result.merge(environment, uniquingKeysWith: { $1 })
        return result
    }

    /// Construct an environment merging the bottle values with the given values
    private static func constructWineServerEnvironment(
        for bottle: Bottle, environment: [String: String] = [:]
    ) -> [String: String] {
        let wineDataDir = WhiskyWineInstaller.shareFolder.appendingPathComponent("wine")
        let wineBinPath = WhiskyWineInstaller.binFolder.path
        let currentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        var result: [String: String] = [
            "WINEPREFIX": bottle.url.path,
            "WINEDEBUG": "fixme-all",
            "GST_DEBUG": "1",
            "WINEDLLPATH": defaultWineDLLPath(),
            "WINEDATADIR": wineDataDir.path,
            "PATH": "\(wineBinPath):\(currentPath)",
            "ROSETTA_ADVERTISE_AVX": "1",
            "DOTNET_EnableWriteXorExecute": "0"
        ]

        if WhiskyWineInstaller.currentMode == .crossover {
            applyCrossOverEnvironment(to: &result)
        }

        guard !environment.isEmpty else { return result }
        result.merge(environment, uniquingKeysWith: { $1 })
        return result
    }

    private static func defaultWineDLLPath() -> String {
        let wineLibFolder = WhiskyWineInstaller.libFolder
        let fileManager = FileManager.default
        var paths: [String] = []

        let x64DllPath = wineLibFolder
            .appendingPathComponent("wine")
            .appendingPathComponent("x86_64-windows")
        if fileManager.fileExists(atPath: x64DllPath.path) {
            paths.append(x64DllPath.path)
        }

        let x32DllPath = wineLibFolder
            .appendingPathComponent("wine")
            .appendingPathComponent("i386-windows")
        if fileManager.fileExists(atPath: x32DllPath.path) {
            paths.append(x32DllPath.path)
        }

        let fallbackDllPath = wineLibFolder.appendingPathComponent("wine")
        paths.append(fallbackDllPath.path)

        return paths.joined(separator: ":")
    }

    private static func crossOverWineDLLPath() -> String {
        let libraryFolder = WhiskyWineInstaller.libraryFolder
        let fileManager = FileManager.default
        var paths: [String] = []

        let appleGptkDllPath = libraryFolder
            .appendingPathComponent("lib64")
            .appendingPathComponent("apple_gptk")
            .appendingPathComponent("wine")
            .appendingPathComponent("x86_64-windows")
        if fileManager.fileExists(atPath: appleGptkDllPath.path) {
            paths.append(appleGptkDllPath.path)
        }

        let lib64DllPath = libraryFolder
            .appendingPathComponent("lib64")
            .appendingPathComponent("wine")
            .appendingPathComponent("x86_64-windows")
        paths.append(lib64DllPath.path)

        let lib32DllPath = libraryFolder
            .appendingPathComponent("lib")
            .appendingPathComponent("wine")
            .appendingPathComponent("i386-windows")
        paths.append(lib32DllPath.path)

        let fallbackDllPath = WhiskyWineInstaller.libFolder.appendingPathComponent("wine")
        paths.append(fallbackDllPath.path)

        return paths.joined(separator: ":")
    }

    private static func applyCrossOverEnvironment(to env: inout [String: String]) {
        let libraryFolder = WhiskyWineInstaller.libraryFolder
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first

        env["WINEDLLPATH"] = crossOverWineDLLPath()
        env["CX_ROOT"] = libraryFolder.path
        env["WINELOADER"] = libraryFolder
            .appendingPathComponent("CrossOver-Hosted Application")
            .appending(path: "wineloader").path
        env["WINESERVER"] = wineserverBinary.path
        env["GST_PLUGIN_SYSTEM_PATH"] = libraryFolder
            .appending(path: "lib64")
            .appending(path: "gstreamer-1.0").path
        if let appSupport = appSupport {
            env["GST_REGISTRY"] = appSupport
                .appending(path: "gstreamer-1.0-registry.x86_64.bin").path
        }

        let d3dSharedPath = libraryFolder
            .appendingPathComponent("lib64")
            .appendingPathComponent("apple_gptk")
            .appendingPathComponent("external")
            .appendingPathComponent("libd3dshared.dylib")
        if FileManager.default.fileExists(atPath: d3dSharedPath.path) {
            env["CX_APPLEGPTK_LIBD3DSHARED_PATH"] = d3dSharedPath.path
        }
    }
}

public enum WineError: Error, LocalizedError {
    case dxvkNotAvailable

    public var errorDescription: String? {
        switch self {
        case .dxvkNotAvailable:
            return "DXVK files are not available. Please install DXVK first."
        }
    }
}

public enum WineInterfaceError: Error, LocalizedError {
    case invalidResponce
    case wineProcessFailed(command: String, status: Int32, output: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponce:
            return "Invalid response from Wine"
        case .wineProcessFailed(let command, let status, let output):
            return "Command '\(command)' failed with status \(status): \(output)"
        }
    }
}

extension Wine {
    public static let logsFolder = FileManager.default.urls(
        for: .libraryDirectory, in: .userDomainMask
    )[0].appending(path: "Logs").appending(path: Bundle.whiskyBundleIdentifier)

    public static func makeFileHandle() throws -> FileHandle {
        if !FileManager.default.fileExists(atPath: Self.logsFolder.path) {
            try FileManager.default.createDirectory(at: Self.logsFolder, withIntermediateDirectories: true)
        }

        let dateString = Date.now.ISO8601Format()
        let fileURL = Self.logsFolder.appending(path: dateString).appendingPathExtension("log")
        try "".write(to: fileURL, atomically: true, encoding: .utf8)
        return try FileHandle(forWritingTo: fileURL)
    }
}
