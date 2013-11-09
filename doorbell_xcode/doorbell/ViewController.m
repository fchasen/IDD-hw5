//
//  ViewController.m
//  doorbell
//
//  Created by Fred Jacksier-Chasen on 11/5/13.
//  Copyright (c) 2013 Fred Jacksier-Chasen. All rights reserved.
//

#import "ViewController.h"

static NSString * const kServiceUUID = @"195AE58A-437A-489B-B0CD-B7C9C394BAE4";
static NSString * const readCharacteristicUUID = @"21819AB0-C937-4188-B0DB-B9621E1696CD";
static NSString * const writeCharacteristicUUID = @"5FC569A0-74A9-4FA4-B8B7-8354C86E45A4";

@interface ViewController ()
    
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // Start up the CBCentralManager
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    // And somewhere to store the incoming data
    _data = [[NSMutableData alloc] init];
    
    [responseLabel setText:@""];
    [connectedTo setText:@"Disconnected"];
    
//    bellButton.layer.borderWidth = 5;
//    bellButton.layer.borderColor = [UIColor lightGrayColor].CGColor;
//    bellButton.layer.cornerRadius = 50;
//    bellButton.layer.masksToBounds = YES;
//    [bellButton setBackgroundImage:[UIImage imageNamed:@"pACE3-9028432enh-z6.jpg"] forState:UIControlStateNormal];
    
//    NSString *pewPewPath = [[NSBundle mainBundle] pathForResource:@"pew-pew-lei" ofType:@"caf"];
//	NSURL *pewPewURL = [NSURL fileURLWithPath:pewPewPath];
//	AudioServicesCreateSystemSoundID((__bridge CFURLRef)pewPewURL, &_pewPewSound);
}

- (void)viewWillDisappear:(BOOL)animated
{
    // Don't keep it going while we're not showing.
    [self.centralManager stopScan];
    NSLog(@"Scanning stopped");
    
    if (self.discoveredPeripheral) {
        // Cancel our subscription to the characteristic
        //    [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
        
        // and disconnect from the peripehral
        [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
    }

    
    [super viewWillDisappear:animated];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state != CBCentralManagerStatePoweredOn) {
        connectSwitch.on = false;
        self.canConnect = [NSNumber numberWithInt:0];
        // Deal with all the states correctly
        switch (central.state) {
            case CBCentralManagerStateResetting:
                NSLog(@"BLE: Resetting");
            case CBCentralManagerStateUnsupported:
                NSLog(@"BLE: Unsupported");
            case CBCentralManagerStateUnauthorized:
                NSLog(@"BLE: Unauthorized");
            case CBCentralManagerStatePoweredOff:
                NSLog(@"BLE: Off");
            default:
                NSLog(@"Central Manager did change state");
                break;
        }
        return;
    }
    
    // The state must be CBCentralManagerStatePoweredOn...
    
    connectSwitch.on = true;
    self.canConnect = [NSNumber numberWithInt:1];
    [self scan];
    
}

/** Scan for peripherals - specifically for our service's 128bit CBUUID
 */
- (void)scan
{
    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:kServiceUUID]]
                                                options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
    
    NSLog(@"Scanning started");
}

/** This callback comes whenever a peripheral that is advertising the TRANSFER_SERVICE_UUID is discovered.
 *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
 *  we start the connection process
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    // Reject any where the value is above reasonable range
    if (RSSI.integerValue > -15) {
        NSLog(@"Signal: too high");
        return;
    }
    
    // Reject if the signal strength is too low to be close enough (Close is around -22dB)
    if (RSSI.integerValue < -150) {
        NSLog(@"Signal: too low");
        return;
    }
    
    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    
    // Ok, it's in range - have we already seen it?
    if (self.discoveredPeripheral != peripheral) {
        
        // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
        self.discoveredPeripheral = peripheral;
        
        // And connect
        NSLog(@"Connecting to peripheral %@", peripheral);
//        [connectedTo setText:peripheral.name];
        [connectedTo setText:@"1234 Fake Street"];
        
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}

/** If the connection fails for whatever reason, we need to deal with it.
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect to %@. (%@)", peripheral, [error localizedDescription]);
    [self cleanup];
}

/** We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral Connected");
    
    // Stop scanning
    [self.centralManager stopScan];
    NSLog(@"Scanning stopped");
    
    // Clear the data that we may already have
    [self.data setLength:0];
    
    // Make sure we get the discovery callbacks
    peripheral.delegate = self;
    
    // Search only for services that match our UUID
    [peripheral discoverServices:@[[CBUUID UUIDWithString:kServiceUUID]]];
    
    
}


/** The Transfer Service was discovered
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering services: %@", [error localizedDescription]);
        [self cleanup];
        return;
    }
    
    // Discover the characteristic we want...
    NSLog(@"Looking for Services: found %lu", [peripheral.services count]);
    // Loop through the newly filled peripheral.services array, just in case there's more than one.
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:readCharacteristicUUID], [CBUUID UUIDWithString:writeCharacteristicUUID]] forService:service];
    }
}


/** The Transfer characteristic was discovered.
 *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    // Deal with errors (if any)
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        [self cleanup];
        return;
    }
    
    self.service = service;
    
    // Again, we loop through the array, just in case.
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:writeCharacteristicUUID]]) {
            self.writeCharacteristic  = characteristic;
            NSLog(@"write found: %@", characteristic);
        }

        
        
        
        // And check if it's the right one
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:readCharacteristicUUID]]) {
            NSLog(@"read found");
            // If it is, subscribe to it
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
    
    // Once this is complete, we just need to wait for the data to come in.
}


/** This callback lets us know more data has arrived via notification on the characteristic
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error discovering characteristics: %@", [error localizedDescription]);
        return;
    }
    
    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    
    // Have we got everything we need?
    if ([stringFromData isEqualToString:@"EOM"]) {
        
        // We have, so show the data,
        [self.textview setText:[[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding]];
        
        // Cancel our subscription to the characteristic
        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
        
        // and disconnect from the peripehral
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
    
    // Otherwise, just add the data on to what we already have
    [self.data appendData:characteristic.value];
    
    // Log it
    NSLog(@"Received: %@", stringFromData);
    [responseLabel setText:stringFromData];
}


/** The peripheral letting us know whether our subscribe/unsubscribe happened or not
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
    }
    
    // Exit if it's not the transfer characteristic
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:readCharacteristicUUID]]) {
        return;
    }
    
    // Notification has started
    if (characteristic.isNotifying) {
        NSLog(@"Notification began on %@", characteristic);
    }
    
    // Notification has stopped
    else {
        // so disconnect from the peripheral
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}


/** Once the disconnection happens, we need to clean up our local copy of the peripheral
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Peripheral Disconnected");
    self.discoveredPeripheral = nil;
    
    [connectedTo setText:@"Disconnected"];
    
    // We're disconnected, so start scanning again
    [self scan];
}


/** Call this when things either go wrong, or you're done with the connection.
 *  This cancels any subscriptions if there are any, or straight disconnects if not.
 *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
 */
- (void)cleanup
{
    // Don't do anything if we're not connected
    if (!self.discoveredPeripheral.isConnected) {
        return;
    }
    
    // See if we are subscribed to a characteristic on the peripheral
    if (self.discoveredPeripheral.services != nil) {
        for (CBService *service in self.discoveredPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:readCharacteristicUUID]]) {
                        if (characteristic.isNotifying) {
                            // It is notifying, so unsubscribe
                            [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            
                            // And we're done.
                            return;
                        }
                    }
                }
            }
        }
    }
    
    // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
    [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
}

- (IBAction)pushed:(UIButton*)sender{
    NSLog(@"Ring Ring");
    [responseLabel setText:@""];
    
//    uint16_t val = 2;
//    NSData * valData = [NSData dataWithBytes:&val length:sizeof (val)];
    self.dataToSend = [@"Ring" dataUsingEncoding:NSUTF8StringEncoding];
    
    if (nil == self.writeCharacteristic)
    {
        NSLog(@"No valid writeCharacteristic");
        return;
    }
    
    [self.discoveredPeripheral writeValue:self.dataToSend forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithResponse];
    
//    AudioServicesPlaySystemSound(_pewPewSound);
    
}

- (IBAction)ringBell:(UIButton*)sender{
    NSLog(@"Ring Ring");
    
    [responseLabel setText:@""];
    
//    CBCharacteristic *characteristic = [self.centralManager findCharacteristicFromUUID:writeCharacteristicUUID service:self.service];
    
    self.dataToSend = [@"ring" dataUsingEncoding:NSUTF8StringEncoding];
    
//    CBCharacteristic *characteristic = [self.discoveredPeripheral findCharacteristicFromUUID:writeCharacteristicUUID service:self.service];
    
    //uint16_t val = 2;
    //NSData * valData = [NSData dataWithBytes:&val length:sizeof (val)];
    
    if (nil == self.writeCharacteristic)
    {
        NSLog(@"No valid writeCharacteristic");
        return;
    }
    
    [self.discoveredPeripheral writeValue:self.dataToSend forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithResponse];
    
    //[self.discoveredPeripheral writeValue:self.dataToSend forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithoutResponse];
}

- (void) peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:
(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"Did write characteristic value : %@ with ID %@", characteristic.value, characteristic.UUID);
    NSLog(@"With error: %@", [error localizedDescription]);
    
    //code...
}

-(IBAction)toggleConnect:(id)sender{
    NSLog(@"on");
    [responseLabel setText:@""];
    
    if(connectSwitch.on) {
        NSLog(@"on");
        // ... so start scanning
        if(self.canConnect == [NSNumber numberWithInt:1]){
            [self scan];
        } else {
            connectSwitch.on = false;
        }
    }
    
    else {
        NSLog(@"off");
        [self.centralManager stopScan];
        NSLog(@"Scanning stopped");
        
        if (self.discoveredPeripheral) {
            // Cancel our subscription to the characteristic
            //    [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
            
            // and disconnect from the peripehral
            [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
        }
    }
    
}

@end
