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
    - [Third-Party Code](#third-party-code)


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

- `CMakeLists.txt`: CMake build configuration file.
- `README.md`: This file, providing an overview of the project.
- `src/`: Directory containing the source code of the TimeArc app.
  - `main.cpp`: The main entry point of the application.
  - `service/`: Implementation of the TimeArc service.
    - `windows/`: Implementation for Windows platform.
    - `linux/`: Implementation for Linux platform.
    - `macos/`: Implementation for macOS platform.
    - `shared/`: Shared code for all platforms.
  - `services/`: Provide user-facing time tracking services. This will later be reimplemented to support SQLite database.
  - Others.
- `qml/`: Directory containing QML files for the user interface.
  - `main.qml`: The main QML file defining the UI layout and components.
  - Others.
- `resources/`: Directory for application resources such as icons, images, and other assets.
- `thirdparty/`: Directory for third-party libraries and dependencies used in the project.

### Code Style

This project follows the Google C++ Style Guide for C/C++ code. Please follow the existing code style and structure when contributing to the project.

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

### Third-Party Code

This project incorporates code from other open-source projects, which are distributed under their own terms:

- **Qt**: LGPLv3.0 (with exceptions).
- **SQLite**: Public Domain.
- **Parson**: MIT License.
