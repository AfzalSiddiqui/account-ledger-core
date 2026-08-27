// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "account-ledger-core",
    targets: [
        .executableTarget(
            name: "account-ledger-core"
        ),
        .testTarget(
            name: "account-ledger-coreTests",
            dependencies: ["account-ledger-core"]
        )
    ]
)
