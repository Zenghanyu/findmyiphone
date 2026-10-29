//  BrushSDK
//
//  Created by XTMacMini on 2025/2/18.
//

#import "AppDelegate.h"
#import "MainViewController.h"
#import "XTBleWriteHelper.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

// 程序启动入口 | App Launch Entry
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // 初始化主页及导航栏 | Init MainVC & Nav
    MainViewController *mainVC = [[MainViewController alloc] init];
    UINavigationController *navMain = [[UINavigationController alloc] initWithRootViewController:mainVC];
   
    // 初始化主窗口并配置 | Init Main Window
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = navMain;
    [self.window makeKeyAndVisible];
    
    // 初始化蓝牙单例 | Init Bluetooth Singleton
    [XTBleWriteHelper shareInstance];
    
    return YES;
}

@end
