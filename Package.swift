import PackageDescription

let package = Package(
    name: "File",
    dependencies: [
        .Package(url: "https://github.com/VeniceX/Venice.git", majorVersion: 0, minor: 8),
        .Package(url: "https://github.com/Zewo/String.git", majorVersion: 0, minor: 7),
        .Package(url: "https://github.com/Zewo/POSIX.git", majorVersion: 0, minor: 5),
    ]
)
