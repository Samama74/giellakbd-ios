import Sentry
import UIKit

final class AppNavControllerDelegate: NSObject, UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController,
                              willShow viewController: UIViewController,
                              animated _: Bool) {
        viewController.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        navigationController.setNavigationBarHidden(viewController is HideNavBar, animated: true)
    }

    func navigationController(_: UINavigationController,
                              animationControllerFor _: UINavigationController.Operation,
                              from _: UIViewController,
                              to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        toVC.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        return nil
    }
}

let str1 = "containing"
let str2 = "Bundle"

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    weak static var instance: AppDelegate!

    var window: UIWindow?
    var wantsKeyboardList = false

    let navController = UINavigationController(rootViewController: HomeController())

    //swiftlint:disable:next weak_delegate
    let ncDelegate = AppNavControllerDelegate()

    private let pahkat = PahkatWrapper()

    private var ipc: IPC?

    //swiftlint:disable identifier_name
    var enabledGiellaInputModes: [UITextInputMode] {
        UITextInputMode.activeInputModes.compactMap {
            let s = str1 + str2
            let v = $0.perform(Selector(s))
            if let x = v?.takeUnretainedValue() as? Bundle,
                let bunId = x.bundleIdentifier,
                let mainId = Bundle.main.bundleIdentifier {
                if bunId.contains(mainId) {
                    return $0
                }
            }
            return nil
        }
    }
    //swiftlint:enable identifier_name

    var enabledGiellaKeyboardLanguages: [String] {
        return enabledGiellaInputModes.compactMap { $0.primaryLanguage }
    }

    var isKeyboardEnabled: Bool {
        return !enabledGiellaInputModes.isEmpty
    }

    func application(_: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppDelegate.instance = self

        Strings.languageCode = KeyboardSettings.languageCode

        navController.delegate = ncDelegate

        window = UIWindow(frame: UIScreen.main.bounds)
        window!.rootViewController = navController
        window!.makeKeyAndVisible()

        let oneDay: Double = 60 * 60 * 24
        UIApplication.shared.setMinimumBackgroundFetchInterval(oneDay)

        if !isKeyboardEnabled, KeyboardSettings.firstLoad {
            KeyboardSettings.firstLoad = false
            navController.pushViewController(InstructionsController(), animated: false)
        }

        if let url = launchOptions?[UIApplication.LaunchOptionsKey.url] {
            if let url = url as? URL {
                parseUrl(url)
            }
        }

        pahkat?.forceRefreshRepos()
        pahkat?.downloadPackage()

        return true
    }

    func application(_ application: UIApplication,
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // TODO: check for actual updates and install those instead
        pahkat?.forceRefreshRepos()
        pahkat?.downloadPackage()
        completionHandler(.newData)
    }

    func applicationWillEnterForeground(_: UIApplication) {
        // I'd gladly use .NSExtensionHostWillEnterForeground but it doesn't work
        NotificationCenter.default.post(Notification(name: .HostingAppWillEnterForeground))
    }

    func parseUrl(_: URL) {
        guard Bundle.main.bundleIdentifier != nil else {
            return
        }
    }

    func application(_: UIApplication, open url: URL, options _: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        parseUrl(url)
        return true
    }
}
