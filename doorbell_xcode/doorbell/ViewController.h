//
//  ViewController.h
//  doorbell
//
//  Created by Fred Jacksier-Chasen on 11/5/13.
//  Copyright (c) 2013 Fred Jacksier-Chasen. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <AudioToolbox/AudioToolbox.h>

@interface ViewController : UIViewController <CBCentralManagerDelegate, CBPeripheralDelegate> {
    IBOutlet UISwitch *connectSwitch;
    IBOutlet  UILabel   *responseLabel;
    IBOutlet  UIButton   *bellButton;
    IBOutlet  UILabel   *connectedTo;
    
    SystemSoundID _pewPewSound;
}

    @property (strong, nonatomic) IBOutlet UITextView   *textview;
    @property (strong, nonatomic) CBCentralManager      *centralManager;
    @property (strong, nonatomic) CBPeripheral          *discoveredPeripheral;
    @property (strong, nonatomic) CBService             *service;
    @property (strong, nonatomic) CBCharacteristic      *writeCharacteristic;
    @property (strong, nonatomic) NSMutableData         *data;

    @property (strong, nonatomic) NSData                    *dataToSend;
    @property (nonatomic, readwrite) NSInteger              sendDataIndex;

    @property (strong, nonatomic) NSNumber                  *canConnect;

@end
