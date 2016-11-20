import PackageDescription

let package = Package(
    name: "SwiftOnigurama", 
    targets: [
        Target(name: "SwiftOnigurama")
    ],
    dependencies: [
        .Package(url: "https://github.com/dmcyk/Coniguruma.git", majorVersion: 0)
    ]
)
