import UIKit
import MetalKit

class Wrapper {
    static let shared = Wrapper()
    private let wrapper:MTLWapper = MTLWapper();
    let width:Int32 = 1080
    let height:Int32 = 1920
    var view:MetalView? = nil
    private init() {
        view = wrapper.view(width,height)
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey:Any]? = nil) -> Bool {
        
        let bounds = UIScreen.main.bounds
        self.window = UIWindow(frame:bounds);
        let vc:MetalViewController? = MetalViewController()
        if(self.window != nil) && (vc != nil) {
            self.window!.rootViewController = vc
            
            let nc = NotificationCenter.default
            nc.addObserver(forName: Notification.Name("Appear"),object:nil,queue: nil,using:{(notification) -> Void in DispatchQueue.main.async {
                    self.window!.makeKeyAndVisible()
                }
            })
            
            let view:MetalView? = Wrapper.shared.view
            if(view != nil) {
                vc!.view.addSubview(view!);
                let h:Int = Int(Double(Wrapper.shared.height)*(bounds.width/Double(Wrapper.shared.width)))
                view!.frame = CGRect(x:0, y:(Int(bounds.height)-h)>>1, width:Int(bounds.width), height:h)
                view!.backgroundColor = UIColor.lightGray
                
            }
        }
        else {
            self.window!.rootViewController = UIViewController()
            self.window!.rootViewController?.view.backgroundColor = UIColor.blue
            self.window!.makeKeyAndVisible()
        }
        
        return true
    }
}
