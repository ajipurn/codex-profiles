import AppKit
import SwiftUI

enum BrandImage {
    static var menuBar: NSImage {
        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            return image
        }

        var bundles = [Bundle.main]
        if let resources = Bundle.main.resourceURL,
           let packaged = Bundle(url: resources.appendingPathComponent("CodexProfiles_CodexProfiles.bundle")) {
            bundles.append(packaged)
        }
        #if SWIFT_PACKAGE
        // Packaged apps must not depend on the original SwiftPM build directory.
        if Bundle.main.bundleURL.pathExtension != "app" {
            bundles.append(.module)
        }
        #endif

        for bundle in bundles {
            if let url = bundle.url(forResource: "MenuBarIcon", withExtension: "png"),
               let image = NSImage(contentsOf: url)
            {
                image.isTemplate = true
                return image
            }
        }

        return NSImage(systemSymbolName: "person.2.fill", accessibilityDescription: "Codex Profiles")
            ?? NSImage()
    }
}
