import AppKit

@main
enum UtekontorMain {
    static func main() {
        let app = NSApplication.shared
        let controller = AppController()
        app.setActivationPolicy(.accessory)
        app.delegate = controller
        app.run()
    }
}
