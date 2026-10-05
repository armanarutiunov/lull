import Foundation
import SwiftUI

@main
enum Main {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.first == "status" else {
            LullApp.main()
            return
        }
        exit(StatusCommand.run(json: arguments.contains("--json")))
    }
}

enum StatusCommand {
    static func run(json: Bool) -> Int32 {
        guard let data = try? Data(contentsOf: StatusFile.url) else {
            FileHandle.standardError.write(Data("No status yet at \(StatusFile.url.path). Is Lull running?\n".utf8))
            return 1
        }
        if json {
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
            return 0
        }
        guard let status = try? StatusFile.decoder.decode(StatusFile.self, from: data) else {
            FileHandle.standardError.write(Data("Couldn't read \(StatusFile.url.path).\n".utf8))
            return 1
        }
        print(status.summary())
        return 0
    }
}
