//
//  LYFPhotosManager.m
//  LYFAlbum
//
//  Created by 李玉枫 on 2018/12/6.
//  Copyright © 2018 李玉枫. All rights reserved.
//

#import "LYFPhotosManager.h"
#import "LYFAlbumViewController.h"
#import "LYFPhotoManger.h"
#import "UtilsMacros.h"

@implementation LYFPhotosManager

//+(void)showPhotosManager:(UIViewController *)viewController withMaxImageCount:(NSInteger)maxCount withAlbumArray:(void(^)(NSMutableArray<LYFPhotoModel *> *albumArray))albumArray {
+(void)showPhotosManager:(UIViewController *)viewController withMaxImageCount:(NSInteger)maxCount selectComplete:(void(^)(UIImage *selectedImage))selectComplete {
    //如首次使用则会弹出系统询问框
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (status == PHAuthorizationStatusAuthorized) {
                LYFAlbumViewController *controller = [[LYFAlbumViewController alloc] init];
                controller.confirmAction = ^{
                    //albumArray([LYFPhotoManger standardPhotoManger].photoModelList);
                    LYFPhotoModel *photoModel = [LYFPhotoManger standardPhotoManger].photoModelList.firstObject;
                    selectComplete(photoModel.highDefinitionImage);
                };
                
                UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:controller];
                
                [LYFPhotoManger standardPhotoManger].maxCount = maxCount;
                
                navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
                [viewController presentViewController:navigationController animated:YES completion:nil];
            }else{
                UIAlertController *alertViewController = [UIAlertController alertControllerWithTitle:XTLS(@"XT_Access_Photos") message:XTLS(@"XT_Not_Allowed_Photos") preferredStyle:UIAlertControllerStyleAlert];
                
                UIAlertAction *action1 = [UIAlertAction actionWithTitle:XTLS(@"XT_settings") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                    if ([[UIApplication sharedApplication] canOpenURL:url]) {
                        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
                    }
                }];
                UIAlertAction *action2 = [UIAlertAction actionWithTitle:XTLS(@"XT_Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                }];
                
                [alertViewController addAction:action1];
                [alertViewController addAction:action2];
                
                //相当于之前的[actionSheet show];
                [viewController presentViewController:alertViewController animated:YES completion:nil];
            }
        });
    }];
}

@end
