import AppKit
import Foundation

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
        let url = configStore.configURL
        NSWorkspace.shared.open(url)
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

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()