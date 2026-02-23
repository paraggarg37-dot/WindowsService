# Java HTTP Windows Service

This project provides a simple Java-based HTTP Server that is packaged and deployed as a Windows Service. The service is managed using [WinSW](https://github.com/winsw/winsw) (Windows Service Wrapper) and is bundled into a standard Windows MSI installer using the [WiX Toolset](https://wixtoolset.org/).

## Features
- Lightweight HTTP server running on port `8080`.
- Endpoints:
  - `GET /`: Welcome HTML page.
  - `GET /health`: JSON health check endpoint.
- Graceful shutdown hook.
- Fully automated MSI installer creation using Gradle and WiX.
- Uninstaller script to cleanly remove the service and application files.

## Architecture: How the EXE, XML, and JAR work together

A common misconception is that the Java `.jar` file is embedded directly inside the `.exe` file. In this project, that is **not** the case. Instead, they are deployed side-by-side and bundled together inside the MSI installer. Here is how the logic flows:

1. **The Wrapper (EXE)**: The `JavaHttpService.exe` is a generic pre-compiled binary from the [WinSW](https://github.com/winsw/winsw) project. It knows nothing about Java.
2. **The Configuration (XML)**: When Windows starts `JavaHttpService.exe`, WinSW automatically looks for an XML configuration file with the exact same name in the same directory (`JavaHttpService.xml`).
3. **Execution**: WinSW reads `JavaHttpService.xml`, which contains the instructions on what to actually execute:
   ```xml
   <executable>C:\Users\Chirag\.jdks\ms-21.0.10\bin\java.exe</executable>
   <arguments>-jar "%BASE%\JavaHttpService.jar"</arguments>
   ```
   *(Note: `%BASE%` is a WinSW variable that resolves to the directory where the `.exe` is located.)*
4. **The Installer (MSI)**: The WiX Toolset (`Product.wxs`) takes these three separate files (`JavaHttpService.exe`, `JavaHttpService.xml`, and `JavaHttpService.jar`) and packages them together into the final `JavaHttpService.msi` installer. When the user installs the MSI, it places all three files together in the `C:\Program Files\JavaHttpService` directory.

## Project Structure

Here is a breakdown of the key files and directories in this project and their purposes:

- **`src/main/java/org/example/Main.java`**
  The main Java source code. It uses `com.sun.net.httpserver.HttpServer` to run a lightweight HTTP server on port 8080. It handles the `/` and `/health` routes and includes a graceful shutdown hook.

- **`build.gradle`** & **`settings.gradle`**
  Gradle build configuration files. `build.gradle` is configured to build an executable "fat JAR" containing the application (`build/libs/JavaHttpService.jar`).

- **`winsw/JavaHttpService.xml`**
  The configuration file for WinSW (Windows Service Wrapper). It defines the service ID, display name, description, the executable to run (`java.exe`), arguments to pass (`-jar JavaHttpService.jar`), and rules for log rotation and failure restarts.

- **`installer/Product.wxs`**
  The WiX Toolset XML source file used to generate the `.msi` Windows installer. It defines the installation directory structure, bundles the JAR and WinSW wrapper, and contains custom actions to automatically install/start/stop/uninstall the Windows Service during the MSI installation and removal processes. It also includes a custom welcome dialog to optionally start the service immediately after installation.

- **`build-installer.ps1`**
  A PowerShell script that orchestrates the entire build process.
  1. Builds the fat JAR using Gradle.
  2. Downloads the WinSW executable if not already present.
  3. Stages the JAR, WinSW `.exe`, and `JavaHttpService.xml` into `installer/staging/`.
  4. Uses the WiX toolset (`candle.exe` and `light.exe`) to compile `Product.wxs` into the final `JavaHttpService.msi` installer in `installer/output/`.

- **`uninstall-service.ps1`**
  A PowerShell script to cleanly uninstall the service and the MSI. It stops the `JavaHttpService` if running, silently runs `msiexec /x` to uninstall the application, and verifies that the service registration and program files directory have been removed successfully. Requires Administrator privileges.

## Prerequisites for Building

To build the installer, you need the following installed on your system:
1. **Java JDK** (e.g., JDK 21). The `JAVA_HOME` environment variable should be set, or Java should be in your `PATH`.
2. **WiX Toolset v3.14** (or v3.11). Ensure `candle.exe` and `light.exe` are available.
3. **PowerShell**.

## How to Build the Installer

Run the `build-installer.ps1` script from an elevated PowerShell prompt:

```powershell
.\build-installer.ps1
```

If successful, the MSI installer will be generated at:
`installer\output\JavaHttpService.msi`

## Installation and Usage

1. Double-click the generated `JavaHttpService.msi` file.
2. Follow the setup wizard. You will have an option to start the service immediately.
3. Once running, you can test the server by navigating to:
   - `http://localhost:8080/`
   - `http://localhost:8080/health`

## Uninstallation

To cleanly remove the service and all its files, run the provided PowerShell script as an Administrator:

```powershell
.\uninstall-service.ps1
```

Alternatively, you can uninstall it from the Windows "Apps & Features" control panel.
