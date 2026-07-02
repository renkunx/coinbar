import SwiftUI

@main
struct CoinBarApp: App {
    @StateObject private var priceStore = PriceStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel(priceStore: priceStore)
        } label: {
            if let image = MenuBarLabelRenderer.render(priceStore: priceStore) {
                Image(nsImage: image)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
