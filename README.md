# HideBar Ultra 🚀

A modern, high-performance, open-source macOS menu bar manager built from the ground up for **macOS 27 (Golden Gate)** and Apple Silicon.

---

## 🌟 Why HideBar Ultra?

In macOS 27, Apple redesigned the menu bar into an isolated unified window architecture and deprecated legacy pixel-spacer tricks used by older tools like Hidden Bar and Dozer.

**HideBar Ultra** leverages:

1. **Accessibility Spatial Mapping (`AXUIElement`)**: Scans `com.apple.MenuBarAgent` to find exact $(x, y)$ coordinate frames for every running menu bar icon.
2. **Dynamic Allowlist Convergence**: Evaluates which icons sit to the left of the `|` separator (to hide) vs. right of the separator (to keep).
3. **Native macOS 27 Assertion Engine**: Communicates with `MenuBarClientCore` to seamlessly hide selected third-party items without causing screen stutter, displaced notch items, or clipped status bar gaps.
4. **Resilient Hotkey Recovery**: Includes a global keyboard listener (`Cmd + Control + H`) that guarantees you can always toggle visibility even if icons shift.

---

## 🧭 How to Use

1. **Grant Accessibility Permission**:
   - macOS requires Accessibility access so HideBar Ultra can detect icon coordinates in the menu bar.
   - When launched, grant permission under **System Settings → Privacy & Security → Accessibility**.
2. **Set Your Dividing Line**:
   - Hold `⌘ Command` and drag the separator (`|`) to your desired dividing point.
   - Any app icon placed to the **left** of the separator will be hidden.
   - Any app icon placed to the **right** of the separator will stay visible.
3. **Toggle Hide/Show**:
   - **Click the Chevron (`>`)**: Toggles between hidden and expanded states.
   - **Global Shortcut**: Press `⌘ + Ctrl + H` anywhere to toggle.
   - **Right-Click**: Opens Preferences or Quits the app.

---

## 🛠 Building & Publishing to GitHub

```bash
# Clone the repository
git clone https://github.com/gokulkannanganesamoorthy/hide-bar.git
cd hide-bar

# Build the release binary
swift build -c release

# Bundle and code sign
mkdir -p HideBar.app/Contents/MacOS
cp .build/release/HideBar HideBar.app/Contents/MacOS/HideBar
codesign --force --deep -s - HideBar.app

# Run the app
open HideBar.app
```

---

## 📄 License

MIT License. Open source and ready for community contributions.
