//
//  PLViewController.m
//  ProximityLight
//
//  Created by Chris Miles on 27/03/2014.
//  Copyright (c) 2014 Chris Miles. All rights reserved.
//

#import "PLViewController.h"

#import "ESTBeaconManager.h"

#import <LIFXKit/LIFXKit.h>


static CLBeaconMajorValue const PLBeaconMajor = 23862;
static CLBeaconMinorValue const PLBeaconMinor = 46588;


@interface PLViewController () <ESTBeaconManagerDelegate>

@property (strong, nonatomic) ESTBeaconManager *beaconManager;
@property (assign, nonatomic) UIBackgroundTaskIdentifier bgTask;

@property (weak, nonatomic) IBOutlet UILabel *stateLabel;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

@end


@implementation PLViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.beaconManager = [[ESTBeaconManager alloc] init];
    self.beaconManager.delegate = self;

    ESTBeaconRegion *region = [[ESTBeaconRegion alloc] initWithProximityUUID:ESTIMOTE_PROXIMITY_UUID major:PLBeaconMajor minor:PLBeaconMinor identifier:@"estimote"];
    region.notifyOnEntry = YES;
    region.notifyOnExit = YES;

    [self.beaconManager startMonitoringForRegion:region];
    //[self.beaconManager startRangingBeaconsInRegion:region];
}


#pragma mark - Light Control

- (void)requestLightUpdateWithStateIsOn:(BOOL)switchOn
{
    DLog(@"Requesting light switch %@", (switchOn ? @"ON" : @"OFF"));

    UIApplication *application = [UIApplication sharedApplication];

    self.bgTask = [application beginBackgroundTaskWithExpirationHandler: ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            DLog(@"Background task expired for request light switch %@", (switchOn ? @"ON" : @"OFF"));
            [application endBackgroundTask:self.bgTask];
            self.bgTask = UIBackgroundTaskInvalid;
        });
    }];

    if (switchOn)
    {
        [self notifyWithMessage:@"Switching light on"];
        [[self controlledLight] setPowerState:LFXPowerStateOn];
    }
    else
    {
        [self notifyWithMessage:@"Switching light off"];
        [[self controlledLight] setPowerState:LFXPowerStateOff];
    }

    // Allow some background task time for LIFX request to get through, for when app is backgrounded
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DLog(@"Background task ending for request light switch %@", (switchOn ? @"ON" : @"OFF"));
        [application endBackgroundTask:self.bgTask];
        self.bgTask = UIBackgroundTaskInvalid;
    });
}

- (LFXLight *)controlledLight
{
    LFXNetworkContext *localNetworkContext = [[LFXClient sharedClient] localNetworkContext];
    LFXLight *light = [localNetworkContext.allLightsCollection firstLightForLabel:@"Office"];
    return light;
}

- (IBAction)lightOnAction:(__unused id)sender
{
    [self requestLightUpdateWithStateIsOn:YES];
}

- (IBAction)lightOffAction:(__unused id)sender
{
    [self requestLightUpdateWithStateIsOn:NO];
}


#pragma mark - Notify

- (void)notifyWithMessage:(NSString *)message
{
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.fireDate = [NSDate date];
    notification.alertBody = message;
    notification.soundName = UILocalNotificationDefaultSoundName;
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
}


#pragma mark - ESTBeaconManagerDelegate

- (void)beaconManager:(__unused ESTBeaconManager *)manager didDetermineState:(CLRegionState)state forRegion:(ESTBeaconRegion *)region
{
    DLog(@"state: %ld region: %@", state, region);

    self.stateLabel.text = [NSString stringWithFormat:@"State: %@ (%@)", NSStringFromCLRegionState(state), region];

    if (state == CLRegionStateInside)
    {
        [self requestLightUpdateWithStateIsOn:YES];
    }
    else if (state == CLRegionStateOutside)
    {
        [self requestLightUpdateWithStateIsOn:NO];
    }
}

- (void)beaconManager:(__unused ESTBeaconManager *)manager didDiscoverBeacons:(NSArray *)beacons inRegion:(ESTBeaconRegion *)region
{
    DLog(@"beacons: %@ region: %@", beacons, region);
}

- (void)beaconManager:(__unused ESTBeaconManager *)manager didEnterRegion:(ESTBeaconRegion *)region
{
    DLog(@"region: %@", region);

    self.statusLabel.text = [NSString stringWithFormat:@"Did enter region at %@", [NSDate date]];
    [self requestLightUpdateWithStateIsOn:YES];
}

- (void)beaconManager:(__unused ESTBeaconManager *)manager didExitRegion:(ESTBeaconRegion *)region
{
    DLog(@"region: %@", region);

    self.statusLabel.text = [NSString stringWithFormat:@"Did exit region at (%@)", [NSDate date]];
    [self requestLightUpdateWithStateIsOn:NO];
}

- (void)beaconManager:(__unused ESTBeaconManager *)manager didFailDiscoveryInRegion:(ESTBeaconRegion *)region
{
    DLog(@"region: %@", region);
}

- (void)beaconManager:(__unused ESTBeaconManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(ESTBeaconRegion *)region
{
    DLog(@"beacons: %@ region: %@", beacons, region);
}

- (void)beaconManager:(__unused ESTBeaconManager *)manager monitoringDidFailForRegion:(ESTBeaconRegion *)region withError:(NSError *)error
{
    DLog(@"region: %@ error: %@", region, error);
}

- (void)beaconManager:(__unused ESTBeaconManager *)manager rangingBeaconsDidFailForRegion:(ESTBeaconRegion *)region withError:(NSError *)error
{
    DLog(@"region: %@ error: %@", region, error);
}

- (void)beaconManagerDidStartAdvertising:(ESTBeaconManager *)manager error:(NSError *)error
{
    DLog(@"manager: %@ error: %@", manager, error);
}


#pragma mark - Functions

NS_INLINE NSString *
NSStringFromCLRegionState(CLRegionState state)__attribute__((const));

NS_INLINE NSString *
NSStringFromCLRegionState(CLRegionState state)
{
    NSString *value = nil;

    switch (state) {
        case CLRegionStateUnknown:
            value = @"Unknown";
            break;

        case CLRegionStateInside:
            value = @"Inside";
            break;

        case CLRegionStateOutside:
            value = @"Outside";
            break;

        default:
            break;
    }

    return value;
}

@end
