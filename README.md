# AutoChocoInternalizer

## Introduction
AutoChocoInternalizer is a tool designed to automatically internalize a list of Chocolatey packages and package them into a format that can be easily distributed, for example, via a USB drive. This tool is particularly useful for creating offline installers for Chocolatey packages, including their dependencies.

## Prerequisites
- Windows operating system
- PowerShell 5.1 or later
- Chocolatey 2.2.2 or later (compatible with non-licensed versions)
- Internet connection (for initial package download)

## Installation
1. Clone this repository:
   ```
   git clone https://github.com/rjohnson318/AutoChocoInternalizer.git
   ```
2. Navigate to the cloned directory:
   ```
   cd AutoChocoInternalizer
   ```

## Usage
1. Edit the `packages.csv` file to include the Chocolatey packages you want to internalize.
2. Run the main script:
   ```
   powershell -ExecutionPolicy Bypass -File .\createUsbPackups.ps1
   ```
3. The internalized packages will be available in the `3.repackedPackages` directory.

## Contributing
Contributions to AutoChocoInternalizer are welcome! Please follow these steps to contribute:
1. Fork the repository
2. Create a new branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact
If you have any questions or need support, please open an issue on the GitHub repository.
