import ExpoModulesCore
import UIKit

/// React Native's `Share` and `expo-sharing` take a single item; this shares any number of files plus a
/// message in one sheet, so all of a guest's photos reach WhatsApp together.
public class ShareSheetModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ShareSheet")

    /// Resolves `true` when something was shared, `false` when the sheet was closed.
    AsyncFunction("shareAsync") { (fileUrls: [URL], message: String?, promise: Promise) in
      guard let presenter = self.appContext?.utilities?.currentViewController() else {
        promise.reject("ERR_NO_SCREEN", "There is no screen to show the share sheet on.")
        return
      }

      var items: [Any] = fileUrls
      if let message, !message.isEmpty {
        items.append(message)
      }

      let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
      controller.completionWithItemsHandler = { _, completed, _, _ in
        promise.resolve(completed)
      }
      // iPad presents the sheet as a popover, which needs an anchor.
      controller.popoverPresentationController?.sourceView = presenter.view
      controller.popoverPresentationController?.sourceRect = CGRect(
        x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
      presenter.present(controller, animated: true)
    }
    .runOnQueue(.main)
  }
}
