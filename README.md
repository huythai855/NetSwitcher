# NetSwitcher

**Version 3.0**

NetSwitcher is a lightweight Menu Bar application for macOS to quickly switch between network configurations (WiFi SSID, Password, Proxies) with just one click.

## Features
- **Profile Management**: Support for multiple network profiles.
- **Auto Wi-Fi Switching**: Connects to Wi-Fi access points based on saved SSIDs and passwords.
- **Proxy Management**: Automatically enables/disables Web Proxy (HTTP) and Secure Web Proxy (HTTPS), configures ports, and sets Bypass Domains when switching networks.
- **Native UI Editor**: Easily create, edit, and organize network profiles using a clean SwiftUI interface right from the Menu Bar.

## System Requirements
- macOS 13.0 or later.
- Swift toolchain (if building from source).

## Installation & Usage

### 1. Download & Install (Recommended)
You do not need to build the app yourself. Simply grab the latest version from the Releases page!
1. Download **`NetSwitcher.dmg`** or **`NetSwitcher.app.zip`** from the **[Releases](../../releases)** page.
2. If using the DMG, double-click to mount it.
3. Drag and drop **NetSwitcher** into your **`/Applications`** folder.
4. Launch NetSwitcher from your Launchpad!

### 2. Build from Source (Developers)
If you want to compile and package the application yourself, you can use the provided build scripts:
```bash
# Compile the Swift project (optimized release)
swift build -c release

# Generate macOS AppIcon (requires assets/icon.png)
./make_icns.sh

# Bundle the executable into an .app
./bundle_app.sh

# Wrap the .app into a .dmg installer
./make_dmg.sh
```
Once completed, the `NetSwitcher.app` and `NetSwitcher.dmg` will be available in the `dist/` directory.

## Configuration (profiles.json)
Network configurations are stored at:
`~/Library/Application Support/NetSwitcher/profiles.json`

You can use the built-in native **Config Editor** from the Menu Bar to manage them, or edit the file manually.

**Example Profile Structure:**
```json
{
  "name": "Work - Office",
  "networkService": "Wi-Fi",
  "wifiDevice": "en1",
  "wifiSSID": "Work - Office",
  "wifiPassword": "your-password",
  "proxy": {
    "enabled": true,
    "host": "35.101.11.05",
    "port": 8080,
    "applyTo": ["web", "secureweb"],
    "bypassDomains": [
      "localhost",
      "127.0.0.1"
    ]
  }
}
```
- `wifiDevice`: The Wi-Fi device interface (e.g., `en0`, `en1`). If omitted, the app will automatically scan using `networksetup`.
- `wifiPassword`: Can be omitted if the network does not require a password.
- `proxy.enabled`: Set to `false` to automatically disable proxies when using this network.

## Permissions & Privileges
The application flow executes the macOS command-line tool `/usr/sbin/networksetup` under the hood. It may require Administrator privileges.

## Planned Features
- [x] **UI Menu Editor**: Create a native window editor instead of manually changing `profiles.json`.
- [ ] **Keyboard Shortcuts**: Assign global hotkeys for switching to specific profiles instantly.
- [ ] **Export & Import**: Share network configurations across different Apple devices easily.
