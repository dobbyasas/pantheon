import Foundation

final class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        guard let rulesURL = Bundle.main.url(
            forResource: "blockerList",
            withExtension: "json"
        ) else {
            let error = NSError(
                domain: "com.pantheon.adblock.blocker",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The bundled blockerList.json is missing."]
            )
            context.cancelRequest(withError: error)
            return
        }

        let item = NSExtensionItem()
        item.attachments = [NSItemProvider(contentsOf: rulesURL)].compactMap { $0 }
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }
}
