# NetSwitcher

**Version 1.0**

NetSwitcher is a lightweight Menu Bar application for macOS to quickly switch between network configurations (WiFi SSID, Password, Proxies) with just one click.

## Features
- **Profile Management**: Support for multiple network profiles.
- **Auto Wi-Fi Switching**: Connects to Wi-Fi access points based on saved SSIDs and passwords.
- **Proxy Management**: Automatically enables/disables Web Proxy (HTTP) and Secure Web Proxy (HTTPS), configures ports, and sets Bypass Domains when switching networks.
- **Quick Config Access**: Easily edit the JSON configuration file right from the Menu Bar.

## System Requirements
- macOS 13.0 or later.
- Swift toolchain (if building from source).

## Installation & Usage

### 1. Build & Run as a Command Line App (Dev)
Shows directly in the Menu Bar but runs as a Terminal Process:
```bash
swift run
```

### 2. Package as a macOS App (.app)
For convenience (no need to keep a Terminal window open) and to allow the app to launch on startup, bundle it into a `.app`:
```bash
# Build the release version (optimized)
swift build -c release

# Run the packaging script
chmod +x bundle_app.sh
./bundle_app.sh
```
Once completed, the `NetSwitcher.app` will be available in the `dist/` directory.

## Configuration (profiles.json)
Network configurations are stored as a JSON file at:
`~/Library/Application Support/NetSwitcher/profiles.json`

You can create or edit this file directly from the **Open Config** menu item.

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
- [ ] **UI Menu Editor**: Create a native window editor instead of manually changing `profiles.json`.
- [ ] **Keyboard Shortcuts**: Assign global hotkeys for switching to specific profiles instantly.
- [ ] **Export & Import**: Share network configurations across different Apple devices easily.
