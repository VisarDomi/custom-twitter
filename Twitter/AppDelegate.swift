import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: scene)
        window?.rootViewController = WebController()
        window?.makeKeyAndVisible()
    }

    // iOS ends only backgrounded apps; the page to reopen is saved on the way out.
    func sceneWillResignActive(_ scene: UIScene) { (window?.rootViewController as? WebController)?.saveSession() }
    func sceneDidEnterBackground(_ scene: UIScene) { (window?.rootViewController as? WebController)?.saveSession() }
}
