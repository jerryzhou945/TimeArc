# TimeArc

TimeArc app.

## Project Structure

- `CMakeLists.txt`: CMake build configuration file.
- `README.md`: This file, providing an overview of the project.
- `src/`: Directory containing the source code of the TimeArc app.
  - `main.cpp`: The main entry point of the application.
  - `service/`: Implementation of the TimeArc service.
    - `windows`: Implementation for Windows platform.
    - `linux`: Implementation for Linux platform.
    - `macos`: Implementation for macOS platform.
    - `shared`: Shared code for all platforms.
  - `services/`: Provide user-facing time tracking services. This will later be reimplemented to support SQLite database.
  - Others.
- `qml/`: Directory containing QML files for the user interface.
  - `main.qml`: The main QML file defining the UI layout and components.
  - Others.
- `resources/`: Directory for application resources such as icons, images, and other assets.
- `thirdparty/`: Directory for third-party libraries and dependencies used in the project.
