# HideBar

A menu bar manager built for macOS 27 and Apple Silicon.

## Overview

In macOS 27, status items cannot be pushed off-screen using dummy spacing items. HideBar uses Accessibility APIs to observe status item coordinates and interacts with the system assessment framework to hide items placed to the left of the separator.

## Features

- Dynamic spatial sorting via Accessibility APIs
- Native system-level status item concealment
- Configurable separator line (`|`) to set hide boundaries
- Global shortcut (`Cmd + Ctrl + H`) to toggle visibility

## Usage

1. Grant Accessibility permissions under **System Settings > Privacy & Security > Accessibility**.
2. Hold `Cmd` and drag the separator (`|`) to your desired dividing position.
3. Items to the left of `|` are hidden; items to the right remain visible.
4. Click the chevron or press `Cmd + Ctrl + H` to toggle visibility.

## Build

```bash
git clone https://github.com/gokulkannanganesamoorthy/hide-bar.git
cd hide-bar
swift build -c release
mkdir -p HideBar.app/Contents/MacOS
cp .build/release/HideBar HideBar.app/Contents/MacOS/HideBar
codesign --force --deep -s - HideBar.app
open HideBar.app
```

## License

MIT
