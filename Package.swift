import PackageDescription


let package = Package(
  name: "Requests",
  dependencies: [
    .Package(url: "https://github.com/bytethenoodle/Inquiline", "0.3.4"),
  ]
)
