import AppKit
import Darwin

@main
enum NetHaloMain {
    static func main() {
        if CommandLine.arguments.contains("--self-test") {
            exit(SelfCheck.run())
        }

        if CommandLine.arguments.contains("--render-preview") {
            exit(PreviewRenderer.run())
        }

        let application = NSApplication.shared
        let delegate = AppDelegate()

        application.delegate = delegate
        application.run()

        withExtendedLifetime(delegate) {}
    }
}
