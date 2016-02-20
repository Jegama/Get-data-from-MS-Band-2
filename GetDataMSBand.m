/*---------------------------------------------------------------------------------------------------
 *
 * Using MIT License.
 * Microsoft Corporation All rights reserved.
 *
 * Author: Jegama
 * ------------------------------------------------------------------------------------------------*/

#import "RegisterNotificationViewController.h"
#include <math.h>

@interface RegisterNotificationViewController ()<MSBClientManagerDelegate, UITextViewDelegate, MFMailComposeViewControllerDelegate>
{
    double tempHR;
    double tempST;
    double tempGSR;
    
    NSString *timeString;
    NSString *hrString;
    NSString *stString;
    NSString *gsrString;
    
    NSMutableArray *timeArray;
    NSMutableArray *hrArray;
    NSMutableArray *stArray;
    NSMutableArray *gsrArray;
}


@property (nonatomic, weak) MSBClient *client;
@end

@implementation RegisterNotificationViewController


// Create UI for the phone, connect to the MsBand
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Setup View
    [self markReady:NO];
    self.txtOutput.delegate = self;
    UIEdgeInsets insets = [self.txtOutput textContainerInset];
    insets.top = 20;
    insets.bottom = 20;
    [self.txtOutput setTextContainerInset:insets];
    
    // Setup Band
    [MSBClientManager sharedManager].delegate = self;
    NSArray *clients = [[MSBClientManager sharedManager] attachedClients];
    self.client = [clients firstObject];
    if (self.client == nil)
    {
        [self output:@"Failed! No Bands attached."];
        return;
    }
    
    [[MSBClientManager sharedManager] connectClient:self.client];
    [self output:[NSString stringWithFormat:@"Please wait. Connecting to Band <%@>", self.client.name]];
    
    // Setup user notification permission
    [self setupUserNotificationPermission];
    
}

// Dispose of any resources that can be recreated.

 - (void)didReceiveMemoryWarning {
 [super didReceiveMemoryWarning];
 }


// Send a message and start measuring HR
- (IBAction)didTapStartButton:(id)sender
{
     // For the Messages
     __weak typeof(self) weakSelf = self;

    if ([self.client.sensorManager heartRateUserConsent] == MSBUserConsentGranted)
    {
        [self startSensorsUpdates];
    }
    else
    {
        [self output:@"Requesting user consent for accessing HeartRate..."];
        __weak typeof(self) weakSelf = self;
        [self.client.sensorManager requestHRUserConsentWithCompletion:^(BOOL userConsent, NSError *error) {
            if (userConsent)
            {
                [weakSelf startSensorsUpdates];
            }
            else
            {
                [weakSelf sampleDidCompleteWithOutput:@"User consent declined."];
            }
        }];
    }
}

-(IBAction)didTapStopButtom:(id)sender{
    // Stop sensors
    [self.client.sensorManager stopHeartRateUpdatesErrorRef:nil];
    [self sampleDidCompleteWithOutput:@"HR updates stopped..."];
    [self.client.sensorManager stopSkinTempUpdatesErrorRef:nil];
    [self sampleDidCompleteWithOutput:@"ST updates stopped..."];
    [self.client.sensorManager stopGSRUpdatesErrorRef:nil];
    [self sampleDidCompleteWithOutput:@"GSR updates stopped..."];
    
    // Export arrays
    NSMutableString *csv = [NSMutableString stringWithString:@"Time,HR,ST,GSR,Stress Level,Y/N Stress"];
    
    NSUInteger count = [timeArray count];
    for (NSUInteger i=0; i<count; i++ ) {
        [csv appendFormat:@"\n%@,%@,%@,%@",
         [timeArray objectAtIndex:i],
         [hrArray objectAtIndex:i],
         [stArray objectAtIndex:i],
         [gsrArray objectAtIndex:i]
         ];
    }
    
    //CREATE FILE
    
    NSError *error;
    
    // Create file manager
    NSString *documentsDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"MSBand2_data.csv"];

    // Write to the file
    BOOL res = [csv writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    if (!res) {
        NSLog(@"Error %@ while writing to file %@", [error localizedDescription], csv );
    }
    
    // Send by email
    if (![MFMailComposeViewController canSendMail]) {
        NSLog(@"Mail services are not available.");
        return;
    } else {
        MFMailComposeViewController* composeVC = [[MFMailComposeViewController alloc] init];
        composeVC.mailComposeDelegate = self;
        
        // Configure the fields of the interface.
        [composeVC setToRecipients:@[@"address@domain.com"]];
        [composeVC setSubject:@"Exported data"];
        [composeVC setMessageBody:@"The data is attached" isHTML:NO];
        [composeVC addAttachmentData:[NSData dataWithContentsOfFile:filePath]
                            mimeType:@"text/csv" fileName:@"MSBand2_data.csv"];
        
        // Present the view controller modally.
        [self presentViewController:composeVC animated:YES completion:nil];
    }
    
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    // Check the result or perform other tasks.
    
    // Dismiss the mail compose view controller.
    [self dismissViewControllerAnimated:YES completion:nil];
}


// TILE
- (MSBTile *)tileWithBadgingEnabled
{
    NSString *tileName = @"PushAndLocal";
    
    MSBIcon *tileIcon = [MSBIcon iconWithUIImage:[UIImage imageNamed:@"C.png"] error:nil];
    MSBIcon *smallIcon = [MSBIcon iconWithUIImage:[UIImage imageNamed:@"Cc.png"] error:nil];
    
    // You should generate your own TileID for your own Tile to prevent collisions with other Tiles.
    NSUUID *tileID = [[NSUUID alloc] initWithUUIDString:@"CCCDBA9F-12FD-47A5-83A9-E7270A43BB99"];
    MSBTile *tile = [MSBTile tileWithId:tileID name:tileName tileIcon:tileIcon smallIcon:smallIcon error:nil];
    [tile setBadgingEnabled:YES];
    return tile;
}


- (void)startSensorsUpdates
{
    timeString = [[NSString alloc]init];
    hrString = [[NSString alloc]init];
    stString = [[NSString alloc]init];
    gsrString = [[NSString alloc]init];
    
    timeArray = [[NSMutableArray alloc]init];
    hrArray = [[NSMutableArray alloc]init];
    stArray = [[NSMutableArray alloc]init];
    gsrArray = [[NSMutableArray alloc]init];
    
    tempHR = 1;
    tempST = 1;
    tempGSR = 1;
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd.MM.YY HH:mm:ss"];
    NSDate *currentDate = [NSDate date];
    NSString *dateString = [dateFormatter stringFromDate:currentDate];
    
    [self output:@"The records started at:"];
    [self output:dateString];
    
    
    
    // ------------------- Sensor: HR -------------------
    [self output:@"Starting HR updates..."];
    void (^handler)(MSBSensorHeartRateData *, NSError *) = ^(MSBSensorHeartRateData *heartRateData, NSError *error) {
        if (MSBSensorHeartRateQualityAcquiring) {
            // Acquiring. Do nothing.
        } else {
            //Locked
            [self output: [NSString stringWithFormat:@"Heart Rate: %3u bpm",
                           (unsigned int)heartRateData.heartRate]];
            if (heartRateData.heartRate < tempHR - 1) {
                last_hr = 0;
            } else if (heartRateData.heartRate > tempHR + 1) {
                last_hr = 2;
            } else {
                last_hr = 1;
            }
            tempHR = heartRateData.heartRate;
        }
        
        //NSLog(@"%@", heartRateData);
    };
    
    NSError *stateError;
    if (![self.client.sensorManager startHeartRateUpdatesToQueue:nil errorRef:&stateError withHandler:handler])
    {
        [self sampleDidCompleteWithOutput:stateError.description];
        return;
    }
    
    // ------------------- Sensor: ST -------------------
    [self output:@"Starting ST updates..."];
    void (^handler2)(MSBSensorSkinTemperatureData *, NSError *) = ^(MSBSensorSkinTemperatureData *STData, NSError *error) {
        [self output: [NSString stringWithFormat:@"Skin temperature: %3f ºC",
                       (double)STData.temperature]];
        if (STData.temperature < tempST - 1) {
            last_st = 0;
        } else if (STData.temperature > tempST + 1) {
            last_st = 2;
        } else {
            last_st = 1;
        }
        tempST =  STData.temperature;
    };
    
    NSError *stateError2;
    if (![self.client.sensorManager startSkinTempUpdatesToQueue:nil errorRef:&stateError2 withHandler:handler2])
    {
        [self sampleDidCompleteWithOutput:stateError2.description];
        return;
    }
    
    // ------------------- Sensor: GSR -------------------
    [self output:@"Starting GSR updates..."];
    void (^handler3)(MSBSensorGSRData *, NSError *error) = ^(MSBSensorGSRData *GSRData, NSError *error) {
        [self output: [NSString stringWithFormat:@"GSR: %3u kOhm",
                       (unsigned int)GSRData.resistance]];
        if (GSRData.resistance < tempGSR - 1) {
            last_gsr = 0;
        } else if (GSRData.resistance > tempGSR + 1) {
            last_gsr = 2;
        } else {
            last_gsr = 1;
        }
        tempGSR = GSRData.resistance;
        
        // Transform to string to save it to array
        hrString = [NSString stringWithFormat:@"%3f", tempHR];
        stString = [NSString stringWithFormat:@"%3f", tempST];
        gsrString = [NSString stringWithFormat:@"%3f", tempGSR];
        
        // Add to array
        [stArray addObject:stString];
        [gsrArray addObject:gsrString];
        [hrArray addObject:hrString];
        NSDate *currentDate = [NSDate date];
        timeString = [dateFormatter stringFromDate:currentDate];
        [timeArray addObject:timeString];
        
    };
    
    NSError *stateError3;
    if (![self.client.sensorManager startGSRUpdatesToQueue:nil errorRef:&stateError3 withHandler:handler3])
    {
        [self sampleDidCompleteWithOutput:stateError3.description];
        return;
    }
    
    // Stop Updates after 20 minutes
    // [self performSelector:@selector(stopSensorsUpdates) withObject:nil afterDelay:1200];
}


#pragma mark - Helper methods

// TODO: fix bug with this method. The button is always enabled
- (void)markReady:(BOOL)ready
{
    [self output:ready ? @"SI": @"NO"];
    self.EmpecemosButton.enabled = ready;
    self.EmpecemosButton.alpha = ready ? 1.0 : 0.2;
}

- (void)output:(NSString *)message
{
    if (message)
    {
        self.txtOutput.text = [NSString stringWithFormat:@"%@\n%@", self.txtOutput.text, message];
        [self.txtOutput layoutIfNeeded];
        if (self.txtOutput.text.length > 0)
        {
            [self.txtOutput scrollRangeToVisible:NSMakeRange(self.txtOutput.text.length - 1, 1)];
        }
    }
}

// Needed for sensors
- (void)sampleDidCompleteWithOutput:(NSString *)output
{
    [self output:output];
    [self markReady:YES];
}


#pragma mark - UITextViewDelegate

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
    return NO;
}

#pragma mark - Local Notification

- (void)setupUserNotificationPermission
{
    if ([UIUserNotificationSettings class])
    {
        // Setup Notification Settings
        UIUserNotificationType types = UIUserNotificationTypeBadge |
        UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
        
        UIUserNotificationSettings *mySettings =
        [UIUserNotificationSettings settingsForTypes:types categories:nil];
        
        [[UIApplication sharedApplication] registerUserNotificationSettings:mySettings];
    }
}

#pragma mark - MSBClientManagerDelegate

- (void)clientManager:(MSBClientManager *)clientManager clientDidConnect:(MSBClient *)client
{
    [self markReady:YES];
    [self output:[NSString stringWithFormat:@"Band <%@> connected.", client.name]];
}

- (void)clientManager:(MSBClientManager *)clientManager clientDidDisconnect:(MSBClient *)client
{
    [self markReady:NO];
    [self output:[NSString stringWithFormat:@"Band <%@> disconnected.", client.name]];
}

- (void)clientManager:(MSBClientManager *)clientManager client:(MSBClient *)client didFailToConnectWithError:(NSError *)error
{
    [self output:[NSString stringWithFormat:@"Failed to connect to Band <%@>.", client.name]];
    [self output:error.description];
}

@end