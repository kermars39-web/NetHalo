import AppKit
import Darwin

@main
enum GlanceBarMain {
    static func main() {
        if CommandLine.arguments.contains("--self-test") {
            exit(SelfCheck.run())
        }

        let application = NSApplication.shared
        let delegate = AppDelegate()

        application.delegate = delegate
        application.run()

        withExtendedLifetime(delegate) {}
    }
}
