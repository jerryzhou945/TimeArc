# TimeArc

TimeArc app.

Note: This project is currently in the early stages of development.

## Table of Contents

- [TimeArc](#timearc)
  - [Table of Contents](#table-of-contents)
  - [Installation](#installation)
  - [Usage](#usage)
    - [Basic Usage](#basic-usage)
    - [TimeArc Service](#timearc-service)
    - [Configuration](#configuration)
  - [Contributing](#contributing)
    - [Project Structure](#project-structure)
    - [Code Style](#code-style)
    - [To-Do List](#to-do-list)
  - [License](#license)
    - [Third-Party Components](#third-party-components)


## Installation

Not available yet.


## Usage

### Basic Usage

Not available yet.

### TimeArc Service

Not available yet.

### Configuration

Not available yet.


## Contributing

### Project Structure

- `CMakeLists.txt`: Root CMake entry point (project setup, target setup, install rules).
- `README.md`: This file, providing an overview of the project.
- `src/`: Directory containing the source code of the TimeArc app.
  - `CMakeLists.txt`: Source and include definitions for the main app target.
  - `include/`: Directory for header files.
    - `util.h`: Utility macros and declarations used across the project.
  - `main.cpp`: The main entry point of the application.
  - `service/`: Implementation of the TimeArc service.
    - `CMakeLists.txt`: Builds the standalone service binary with platform-specific sources.
    - `shared/`: Shared code for all platforms.
      - `app_env.h`: AppEnv struct.
      - `app_info.h`: AppInfo struct.
      - `database.h`: Database interface for time tracking data.
      - `database.c`: Implementation of the database interface.
    - `windows/`: Implementation for Windows platform.
      - `main.c`: The main entry point for the Windows service.
    - `linux/`: Implementation for Linux platform (it will support both X11 and Wayland).
      - `main.c`: The main entry point for the Linux service.
    - `macos/`: Implementation for macOS platform.
      - `TimeArcService.swift`: The main entry point for the macOS service.
  - `services/`: Provide user-facing time tracking services. This will later be reimplemented to support SQLite database.
  - Others.
- `qml/`: Directory containing QML files for the user interface.
  - `CMakeLists.txt`: QML file definitions for the UI module.
  - `main.qml`: The main QML file defining the UI layout and components.
  - Others.
- `resources/`: Directory for application resources such as icons, images, and other assets.
  - `CMakeLists.txt`: Resource file definitions bundled into the app.
- `thirdparty/`: Directory for third-party libraries and dependencies used in the project.
  - `CMakeLists.txt`: Aggregates third-party libraries and exposes them to app/service targets.
  - `sqlite3/CMakeLists.txt`: Builds SQLite as a static library and exports include directory.
  - `parson/CMakeLists.txt`: Builds Parson as a static library and exports include directory.

### Code Style

Please follow the existing code style and structure when contributing to the project.

### To-Do List

- [ ] Implement the core functionality of the TimeArc service for each platform (Windows, Linux, macOS).
- [ ] Implement the automated time tracking database.
- [ ] Implement the user-facing time tracking database.
- [ ] Implement the core data processing and analysis logic for time tracking.
- [ ] Compile Qt related code as dynamically linked libraries to satisfy license requirements.
- [ ] Include licenses for all third-party code in the UI.
- [ ] Implement the JSON parser for user preferences and configuration.


## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0).

### Third-Party Components

This project utilizes the following third-party libraries, which are distributed under their own terms:

- **Qt**: LGPLv3.0 (with exceptions).
- **SQLite**: Public Domain.
- **Parson**: MIT License.
