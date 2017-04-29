import PackageDescription


let package = Package(
  name: "Requests",
  dependencies: [
    .Package(url: "https://github.com/bytethenoodle/Inquiline", majorVersion: 0, minor: 3),
  ]
)
