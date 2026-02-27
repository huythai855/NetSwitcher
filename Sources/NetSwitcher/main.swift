import AppKit
import Foundation
import SwiftUI

// MARK: - Models

struct Config: Codable {
    var profiles: [NetworkProfile]
}

struct NetworkProfile: Codable {
    var name: String
    var networkService: String?    // default "Wi-Fi"
    var wifiSSID: String?
    var wifiPassword: String?
    var wifiDevice: String? // e.g. "en1"
    var proxy: ProxyConfig
}

struct ProxyConfig: Codable {
    var enabled: Bool
    var host: String?
    var port: Int?
    var applyTo: [ProxyType]?      // [.web, .secureweb]
    var bypassDomains: [String]?
}

enum ProxyType: String, Codable {
    case web
    case secureweb
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var configStore = ConfigStore()
    private var currentConfig: Config = Config(profiles: [])
    private var lastAppliedProfileName: String?
    private var configEditorWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // hide dock icon

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = ""
        statusItem.button?.image = NSImage(systemSymbolName: "network", accessibilityDescription: "NetSwitcher")

        loadConfig()
        rebuildMenu()
    }

    // MARK: Menu

    private func rebuildMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "NetSwitcher", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        if let current = lastAppliedProfileName {
            let currentItem = NSMenuItem(title: "Last applied: \(current)", action: nil, keyEquivalent: "")
            currentItem.isEnabled = false
            menu.addItem(currentItem)
        }

        menu.addItem(.separator())

        if currentConfig.profiles.isEmpty {
            let empty = NSMenuItem(title: "No profiles found", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for (index, profile) in currentConfig.profiles.enumerated() {
                let item = NSMenuItem(
                    title: profile.name,
                    action: #selector(applyProfileMenuAction(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.tag = index
                if profile.name == lastAppliedProfileName {
                    item.state = .on
                }
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let reload = NSMenuItem(title: "Reload Config", action: #selector(reloadConfigAction), keyEquivalent: "r")
        reload.target = self
        menu.addItem(reload)

        let openConfig = NSMenuItem(title: "Open Config", action: #selector(openConfigAction), keyEquivalent: "o")
        openConfig.target = self
        menu.addItem(openConfig)

        let showService = NSMenuItem(title: "Show Network Services", action: #selector(showNetworkServicesAction), keyEquivalent: "s")
        showService.target = self
        menu.addItem(showService)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: Actions

    @objc private func applyProfileMenuAction(_ sender: NSMenuItem) {
        let idx = sender.tag
        guard currentConfig.profiles.indices.contains(idx) else { return }
        let profile = currentConfig.profiles[idx]

        statusItem.button?.title = ""
        statusItem.button?.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Applying")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try NetworkExecutor.apply(profile: profile)
                DispatchQueue.main.async {
                    self.lastAppliedProfileName = profile.name
                    self.statusItem.button?.title = ""
                    self.statusItem.button?.image = NSImage(systemSymbolName: "network", accessibilityDescription: "NetSwitcher")
                    self.rebuildMenu()
                    self.notify(title: "Applied", body: profile.name)
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusItem.button?.title = ""
                    self.statusItem.button?.image = NSImage(systemSymbolName: "network", accessibilityDescription: "NetSwitcher")
                    self.notify(title: "Error", body: error.localizedDescription)
                }
            }
        }
    }

    @objc private func reloadConfigAction() {
        loadConfig()
        rebuildMenu()
        notify(title: "Config", body: "Reloaded")
    }

    @objc private func openConfigAction() {
        if let wc = configEditorWindowController {
            wc.showWindow(nil)
            wc.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let vm = ConfigEditorViewModel(
            configStore: configStore,
            onSaveSuccess: { [weak self] in
                DispatchQueue.main.async {
                    self?.loadConfig()
                    self?.rebuildMenu()
                    self?.notify(title: "Config", body: "Saved")
                }
            }
        )

        let view = ConfigEditorView(viewModel: vm)

        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "NetSwitcher Config"
        window.setContentSize(NSSize(width: 860, height: 560))
        window.styleMask.insert(.resizable)
        window.center()

        let wc = NSWindowController(window: window)
        self.configEditorWindowController = wc

        // clear ref when closed
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.configEditorWindowController = nil
        }

        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showNetworkServicesAction() {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Shell.run("/usr/sbin/networksetup", args: ["-listallnetworkservices"])
            let text = result.stdout.isEmpty ? result.stderr : result.stdout
            DispatchQueue.main.async {
                self.notify(title: "Network Services", body: text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    // MARK: Helpers

    private func loadConfig() {
        do {
            currentConfig = try configStore.loadOrCreateSample()
        } catch {
            currentConfig = Config(profiles: [])
            notify(title: "Config Error", body: error.localizedDescription)
        }
    }

    private func notify(title: String, body: String) {
        let n = NSUserNotification()
        n.title = title
        n.informativeText = body
        NSUserNotificationCenter.default.deliver(n)
        print("[\(title)] \(body)")
    }
}

// MARK: - Config Store

final class ConfigStore {
    let appName = "NetSwitcher"

    var appSupportDir: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(appName, isDirectory: true)
    }

    var configURL: URL {
        appSupportDir.appendingPathComponent("profiles.json")
    }

    func save(_ config: Config) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: appSupportDir.path) {
            try fm.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }
        let data = try JSONEncoder.pretty.encode(config)
        try data.write(to: configURL, options: .atomic)
    }

    func loadOrCreateSample() throws -> Config {
        let fm = FileManager.default
        if !fm.fileExists(atPath: appSupportDir.path) {
            try fm.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }

        if !fm.fileExists(atPath: configURL.path) {
            let sample = sampleConfig()
            let data = try JSONEncoder.pretty.encode(sample)
            try data.write(to: configURL)
            return sample
        }

        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(Config.self, from: data)
    }

    private func sampleConfig() -> Config {
        Config(profiles: [
            NetworkProfile(
                name: "iPhone của Thái",
                networkService: "Wi-Fi",
                wifiSSID: "iPhone của Thái",
                wifiPassword: nil,
                proxy: ProxyConfig(
                    enabled: false,
                    host: nil,
                    port: nil,
                    applyTo: [.web, .secureweb],
                    bypassDomains: ["*.local", "169.254/16", "localhost", "127.0.0.1"]
                )
            ),
            NetworkProfile(
                name: "Work - Office",
                networkService: "Wi-Fi",
                wifiSSID: "Work - Office",
                wifiPassword: nil,
                proxy: ProxyConfig(
                    enabled: true,
                    host: "35.172.68.108",
                    port: 8080,
                    applyTo: [.web, .secureweb],
                    bypassDomains: ["*.viettel.net", "*.local", "169.254/16", "localhost", "127.0.0.1"]
                )
            )
        ])
    }
}

// MARK: - Network Executor

enum NetworkExecutor {
    private static func switchWifi(device: String, ssid: String, password: String?) throws {
        let attempts = 2
        var lastError: Error?

        for i in 1...attempts {
            do {
                if let password, !password.isEmpty {
                    try runNetworksetup(["-setairportnetwork", device, ssid, password], step: "Switch Wi-Fi")
                } else {
                    try runNetworksetup(["-setairportnetwork", device, ssid], step: "Switch Wi-Fi")
                }
                return
            } catch {
                lastError = error
                if i < attempts {
                    Thread.sleep(forTimeInterval: 1.0)
                }
            }
        }

        throw lastError ?? NSError(
            domain: "NetSwitcher",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Switch Wi-Fi failed after retry."]
        )
    }


    static func apply(profile: NetworkProfile) throws {
        let service = profile.networkService ?? "Wi-Fi"

        // 1) Switch Wi-Fi (optional)
        if let rawSSID = profile.wifiSSID {
            let ssid = rawSSID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !ssid.isEmpty {
                let service = profile.networkService ?? "Wi-Fi"
                let device = (profile.wifiDevice?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                    ? profile.wifiDevice!.trimmingCharacters(in: .whitespacesAndNewlines)
                    : (getDevice(forService: service) ?? "en0")

                let rawPwd = profile.wifiPassword ?? ""
                let pwd = rawPwd.trimmingCharacters(in: .whitespacesAndNewlines)

                print("DEBUG Wi-Fi device=\(device), ssid=[\(ssid)] len=\(ssid.count), pwdLen=\(pwd.count)")

                try switchWifi(device: device, ssid: ssid, password: pwd.isEmpty ? nil : pwd)
            }
        }

        // 2) Apply proxy
        if profile.proxy.enabled {
            guard let host = profile.proxy.host, !host.isEmpty,
                  let port = profile.proxy.port else {
                throw NSError(
                    domain: "NetSwitcher",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "Proxy enabled but host/port missing in profile '\(profile.name)'."]
                )
            }

            let applyTo = profile.proxy.applyTo ?? [.web, .secureweb]
            for t in applyTo {
                switch t {
                case .web:
                    try runNetworksetup(["-setwebproxy", service, host, "\(port)"], step: "Set HTTP proxy")
                    try runNetworksetup(["-setwebproxystate", service, "on"], step: "Enable HTTP proxy")
                case .secureweb:
                    try runNetworksetup(["-setsecurewebproxy", service, host, "\(port)"], step: "Set HTTPS proxy")
                    try runNetworksetup(["-setsecurewebproxystate", service, "on"], step: "Enable HTTPS proxy")
                }
            }

            if let bypass = profile.proxy.bypassDomains, !bypass.isEmpty {
                try runNetworksetup(["-setproxybypassdomains", service] + bypass, step: "Set proxy bypass domains")
            }
        } else {
            // Turn off both HTTP/HTTPS proxy on this service
            try runNetworksetup(["-setwebproxystate", service, "off"], step: "Disable HTTP proxy")
            try runNetworksetup(["-setsecurewebproxystate", service, "off"], step: "Disable HTTPS proxy")
            // Optional: keep bypass list untouched
        }
    }

    private static func runNetworksetup(_ args: [String], step: String) throws {
        let result = Shell.run("/usr/sbin/networksetup", args: args)

        let output = result.stdout + result.stderr

        let isError = result.exitCode != 0 
            || output.lowercased().contains("failed") 
            || output.lowercased().contains("error")
            || output.lowercased().contains("could not find")

        if isError {
            let message = """
            \(step) failed.
            Command: networksetup \(args.joined(separator: " "))
            Exit: \(result.exitCode)
            Output: \(output.trimmingCharacters(in: .whitespacesAndNewlines))
            """
            // Use 1 as a fallback error code if exitCode is 0 but stdout contains an error
            let code = result.exitCode == 0 ? 1 : Int(result.exitCode)
            throw NSError(domain: "NetSwitcher", code: code,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private static func getDevice(forService service: String) -> String? {
        let result = Shell.run("/usr/sbin/networksetup", args: ["-listallhardwareports"])
        let lines = result.stdout.components(separatedBy: .newlines)
        var currentPort: String?
        for line in lines {
            if line.hasPrefix("Hardware Port: ") {
                currentPort = String(line.dropFirst("Hardware Port: ".count))
            } else if line.hasPrefix("Device: "), currentPort == service {
                return String(line.dropFirst("Device: ".count))
            }
        }
        return nil
    }
}

// MARK: - Shell

struct ShellResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

enum Shell {
    @discardableResult
    static func run(_ launchPath: String, args: [String]) -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

            return ShellResult(
                exitCode: process.terminationStatus,
                stdout: String(data: outData, encoding: .utf8) ?? "",
                stderr: String(data: errData, encoding: .utf8) ?? ""
            )
        } catch {
            return ShellResult(
                exitCode: -1,
                stdout: "",
                stderr: error.localizedDescription
            )
        }
    }
}

// MARK: - JSON Helpers

extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}

// MARK: - Config Editor UI (SwiftUI)

final class ConfigEditorViewModel: ObservableObject {
    @Published var config: Config = Config(profiles: [])
    @Published var selectedIndex: Int = 0
    @Published var statusMessage: String = ""
    @Published var bypassText: String = "" // UI helper for selected profile

    private let configStore: ConfigStore
    private let onSaveSuccess: (() -> Void)?

    init(configStore: ConfigStore, onSaveSuccess: (() -> Void)? = nil) {
        self.configStore = configStore
        self.onSaveSuccess = onSaveSuccess
        load()
    }

    func load() {
        do {
            let loaded = try configStore.loadOrCreateSample()
            self.config = loaded
            if config.profiles.isEmpty {
                selectedIndex = 0
                bypassText = ""
            } else {
                selectedIndex = min(selectedIndex, config.profiles.count - 1)
                syncBypassTextFromSelected()
            }
            statusMessage = "Loaded"
        } catch {
            statusMessage = "Load failed: \(error.localizedDescription)"
        }
    }

    func save() {
        guard config.profiles.indices.contains(selectedIndex) else {
            do {
                try configStore.save(config)
                statusMessage = "Saved"
                onSaveSuccess?()
            } catch {
                statusMessage = "Save failed: \(error.localizedDescription)"
            }
            return
        }

        // sync bypass text back into model before save
        let lines = bypassText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        config.profiles[selectedIndex].proxy.bypassDomains = lines

        do {
            try configStore.save(config)
            statusMessage = "Saved"
            onSaveSuccess?()
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func addProfile() {
        let newProfile = NetworkProfile(
            name: "New Profile",
            networkService: "Wi-Fi",
            wifiSSID: "",
            wifiPassword: "",
            proxy: ProxyConfig(
                enabled: false,
                host: "",
                port: 8080,
                applyTo: [.web, .secureweb],
                bypassDomains: []
            )
        )
        config.profiles.append(newProfile)
        selectedIndex = max(0, config.profiles.count - 1)
        syncBypassTextFromSelected()
    }

    func removeSelectedProfile() {
        guard config.profiles.indices.contains(selectedIndex) else { return }
        config.profiles.remove(at: selectedIndex)
        if config.profiles.isEmpty {
            selectedIndex = 0
            bypassText = ""
        } else {
            selectedIndex = min(selectedIndex, config.profiles.count - 1)
            syncBypassTextFromSelected()
        }
    }

    func selectionChanged(to idx: Int) {
        guard config.profiles.indices.contains(idx) else { return }
        // persist current bypass text into current selected profile before switching
        if config.profiles.indices.contains(selectedIndex) {
            let lines = bypassText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            config.profiles[selectedIndex].proxy.bypassDomains = lines
        }
        selectedIndex = idx
        syncBypassTextFromSelected()
    }

    private func syncBypassTextFromSelected() {
        guard config.profiles.indices.contains(selectedIndex) else {
            bypassText = ""
            return
        }
        bypassText = (config.profiles[selectedIndex].proxy.bypassDomains ?? []).joined(separator: "\n")
    }
}

struct ConfigEditorView: View {
    @ObservedObject var viewModel: ConfigEditorViewModel

    var body: some View {
        HStack(spacing: 0) {
            leftPane
            Divider()
            rightPane
        }
        .frame(minWidth: 860, minHeight: 560)
    }

    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Profiles")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.addProfile() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 18, height: 18)
                }

                Button(action: { viewModel.removeSelectedProfile() }) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 18, height: 18)
                }
                .disabled(!viewModel.config.profiles.indices.contains(viewModel.selectedIndex))
                .disabled(!viewModel.config.profiles.indices.contains(viewModel.selectedIndex))
            }

            List(selection: Binding(
                get: { viewModel.config.profiles.indices.contains(viewModel.selectedIndex) ? viewModel.selectedIndex : nil },
                set: { newValue in
                    if let idx = newValue {
                        viewModel.selectionChanged(to: idx)
                    }
                })
            ) {
                ForEach(Array(viewModel.config.profiles.enumerated()), id: \.offset) { index, profile in
                    Text(profile.name.isEmpty ? "(No name)" : profile.name)
                        .tag(Optional(index))
                }
            }

            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Button("Reload") { viewModel.load() }
                Spacer()
                Button("Save") { viewModel.save() }
                    .keyboardShortcut("s", modifiers: [.command])
            }
        }
        .padding(12)
        .frame(width: 240)
    }

    private var rightPane: some View {
        Group {
            if viewModel.config.profiles.indices.contains(viewModel.selectedIndex) {
                let idx = viewModel.selectedIndex
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        GroupBox("Profile") {
                            VStack(alignment: .leading, spacing: 10) {
                                LabeledTextField("Name", text: bindingString(\.name, at: idx))
                                LabeledTextField("Network Service", text: bindingOptionalString(\.networkService, at: idx, defaultValue: "Wi-Fi"))
                                LabeledTextField("Wi-Fi SSID", text: bindingOptionalString(\.wifiSSID, at: idx))
                                LabeledSecureField("Wi-Fi Password", text: bindingOptionalString(\.wifiPassword, at: idx))
                            }
                            .padding(.top, 4)
                        }

                        GroupBox("Proxy") {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("Enable Proxy", isOn: bindingProxyEnabled(at: idx))

                                LabeledTextField("Host", text: bindingProxyHost(at: idx))
                                    .disabled(!viewModel.config.profiles[idx].proxy.enabled)

                                HStack {
                                    Text("Port")
                                        .frame(width: 110, alignment: .leading)

                                    TextField(
                                        "8080",
                                        text: bindingProxyPortString(at: idx)
                                    )
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(!viewModel.config.profiles[idx].proxy.enabled)
                                    .frame(maxWidth: 120, alignment: .leading)

                                    Spacer()
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Apply To")
                                        .font(.subheadline)

                                    Toggle("HTTP (web)", isOn: bindingApplyTo(.web, at: idx))
                                        .disabled(!viewModel.config.profiles[idx].proxy.enabled)

                                    Toggle("HTTPS (secureweb)", isOn: bindingApplyTo(.secureweb, at: idx))
                                        .disabled(!viewModel.config.profiles[idx].proxy.enabled)
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Bypass Domains (mỗi dòng 1 giá trị)")
                                        .font(.subheadline)

                                    TextEditor(text: $viewModel.bypassText)
                                        .font(.system(size: 12, design: .monospaced))
                                        .frame(height: 120)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                        )
                                        .disabled(!viewModel.config.profiles[idx].proxy.enabled)
                                }
                            }
                            .padding(.top, 4)
                        }

                        Spacer(minLength: 8)
                    }
                    .padding(16)
                }
            } else {
                VStack {
                    Spacer()
                    Text("Chưa có profile")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: Bindings helpers

    private func bindingString(_ keyPath: WritableKeyPath<NetworkProfile, String>, at idx: Int) -> Binding<String> {
        Binding(
            get: { viewModel.config.profiles[idx][keyPath: keyPath] },
            set: { viewModel.config.profiles[idx][keyPath: keyPath] = $0 }
        )
    }

    private func bindingOptionalString(_ keyPath: WritableKeyPath<NetworkProfile, String?>, at idx: Int, defaultValue: String = "") -> Binding<String> {
        Binding(
            get: { viewModel.config.profiles[idx][keyPath: keyPath] ?? defaultValue },
            set: { newValue in
                let trimmed = newValue
                viewModel.config.profiles[idx][keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    private func bindingProxyEnabled(at idx: Int) -> Binding<Bool> {
        Binding(
            get: { viewModel.config.profiles[idx].proxy.enabled },
            set: { viewModel.config.profiles[idx].proxy.enabled = $0 }
        )
    }

    private func bindingProxyHost(at idx: Int) -> Binding<String> {
        Binding(
            get: { viewModel.config.profiles[idx].proxy.host ?? "" },
            set: { viewModel.config.profiles[idx].proxy.host = $0.isEmpty ? nil : $0 }
        )
    }

    private func bindingProxyPortString(at idx: Int) -> Binding<String> {
        Binding(
            get: {
                if let p = viewModel.config.profiles[idx].proxy.port {
                    return String(p)
                }
                return ""
            },
            set: { newValue in
                let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.isEmpty {
                    viewModel.config.profiles[idx].proxy.port = nil
                } else if let p = Int(cleaned) {
                    viewModel.config.profiles[idx].proxy.port = p
                }
            }
        )
    }

    private func bindingApplyTo(_ type: ProxyType, at idx: Int) -> Binding<Bool> {
        Binding(
            get: {
                let arr = viewModel.config.profiles[idx].proxy.applyTo ?? []
                return arr.contains(type)
            },
            set: { enabled in
                var arr = viewModel.config.profiles[idx].proxy.applyTo ?? []
                if enabled {
                    if !arr.contains(type) { arr.append(type) }
                } else {
                    arr.removeAll { $0 == type }
                }
                viewModel.config.profiles[idx].proxy.applyTo = arr
            }
        )
    }
}

// MARK: - Small UI components

struct LabeledTextField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 110, alignment: .leading)
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct LabeledSecureField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 110, alignment: .leading)
            SecureField("", text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()