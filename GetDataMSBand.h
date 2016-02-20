/*---------------------------------------------------------------------------------------------------
 *
 * Using MIT License.
 * Microsoft Corporation All rights reserved.
 *
 * Author: Jegama
 * ------------------------------------------------------------------------------------------------*/

#import <UIKit/UIKit.h>
#import <MicrosoftBandKit_iOS/MicrosoftBandKit_iOS.h>
#import <MessageUI/MFMailComposeViewController.h>

NSInteger *index_data;

@interface RegisterNotificationViewController : UIViewController <MFMailComposeViewControllerDelegate>

extern double tempHR;
extern double tempST;
extern double tempGSR;

extern NSString *timeString;
extern NSString *hrString;
extern NSString *stString;
extern NSString *gsrString;

extern NSMutableArray *timeArray;
extern NSMutableArray *hrArray;
extern NSMutableArray *stArray;
extern NSMutableArray *gsrArray;

@property (weak, nonatomic) IBOutlet UITextView *txtOutput;
@property (weak, nonatomic) IBOutlet UIButton *StartButton;

- (IBAction)didTapStartButton:(id)sender;



@end