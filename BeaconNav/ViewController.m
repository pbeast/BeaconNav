//
//  ViewController.m
//  BeaconNav
//
//  Created by Pavel Yankelevich on 3/16/15.
//  Copyright (c) 2015 PavelY. All rights reserved.
//

#import "ViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "SVProgressHUD.h"
#import "FCFileManager.h"
#import "AppDelegate.h"
#import "Parse/Parse.h"

#import "CommonUtils.h"

#define LEARNING_SAMPLING_SIZE 10
#define SAMPLING_SIZE 2

@interface ViewController ()<CLLocationManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate> {

    CLLocationManager   *locationManager;
    float mapScale;
    float horizontalMapShift;
    float mapBearing;
    
    BOOL learningRegion;
    NSMutableDictionary *mapData;
    
    CALayer* destinationLayer;

    PFObject* regionToLearn;
    NSMutableDictionary* learningData;
    NSMutableDictionary* samplingData;
    NSInteger samplingMaxRSSI;
    NSNumber *samplingMaxMajor;

    int samplesToTake;
    
    int samplesTaken;
    
    short building;
    short floor;
    
}

@property (weak, nonatomic) IBOutlet UIImageView *mapView;
@property (strong, nonatomic) UIImageView *usersDirection;

@property (weak, nonatomic) IBOutlet UILabel *debugView;

@property (strong, nonatomic)NSMutableArray *beaconPeripherals;
@property (strong, nonatomic)NSArray *beacons;
@property (strong, nonatomic)CBUUID *beaconServiceUUID;
@property (strong,nonatomic)CBCentralManager *bluetoothManager;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void) startLocationManager
{
    locationManager = [[CLLocationManager alloc] init];
    [locationManager setDelegate:self];
    [locationManager setDistanceFilter:kCLDistanceFilterNone];
    [locationManager setDesiredAccuracy:kCLLocationAccuracyBest];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0"))
    {
#pragma deploymate push "ignored-api-availability"
#pragma clang diagnostic push
#pragma ide diagnostic ignored "UnavailableInDeploymentTarget"
        [locationManager requestWhenInUseAuthorization];
#pragma clang diagnostic pop
#pragma deploymate pop
    }
    else
    {
//        [locationManager startUpdatingLocation];
        [locationManager startUpdatingHeading];

        [self getConfigAndStartMonitoring];
    }
}

- (void)showGeoservicesRequiredAlert
{
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"BeaconNav" message:@"Geolocation services required to determine your location. You can enable location services using «Settings» > «Privacy» > «Location Services»." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    
//    NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
//    [[UIApplication sharedApplication] openURL:settingsURL];
    
    [av show];
}

- (void)getConfigAndStartMonitoring
{
    [PFConfig getConfigInBackgroundWithBlock:^(PFConfig *config, NSError *error){
        NSUUID *activeProximityUUID = [[NSUUID alloc] initWithUUIDString:[config objectForKey:@"proximityUUID"]];
        CLBeaconRegion *beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:activeProximityUUID identifier:[config objectForKey:@"beaconsInUse"]];
        
        [locationManager startRangingBeaconsInRegion:beaconRegion];
    }];
}

-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
#pragma deploymate push "ignored-api-availability"
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways)
    {
//        [locationManager startUpdatingLocation];
        [locationManager startUpdatingHeading];

        [self getConfigAndStartMonitoring];

//        NSUUID *proximityUUID_MiniBeacons = [[NSUUID alloc] initWithUUIDString:@"E2C56DB5-DFFB-48D2-B060-D0F5A71096E0"];
//        NSUUID *proximityUUID_Kontact = [[NSUUID alloc] initWithUUIDString:@"a09aaa44-2b27-46da-93ea-1d3f84df6957"];
//
//        CLBeaconRegion *beaconRegion_MiniBeacons = [[CLBeaconRegion alloc] initWithProximityUUID:proximityUUID_MiniBeacons identifier:@"MiniBeacon"];
//
//        CLBeaconRegion *beaconRegion_Kontact = [[CLBeaconRegion alloc] initWithProximityUUID:proximityUUID_Kontact identifier:@"Kontact"];
//        
////        [locationManager startRangingBeaconsInRegion:beaconRegion_MiniBeacons];
//        [locationManager startRangingBeaconsInRegion:beaconRegion_Kontact];
    }
    else if (kCLAuthorizationStatusDenied == status){
        [self showGeoservicesRequiredAlert];
    }
#pragma deploymate pop
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    float direction = -[newHeading trueHeading];
    direction += mapBearing;
    
    [_usersDirection setTransform:CGAffineTransformMakeRotation(direction * M_PI / 180.0)];
}

- (CAShapeLayer*)createLayerFrom:(int)pointsCount Points:(CGPoint*)points
{
    UIBezierPath *path = [[UIBezierPath alloc] init] ;
    
    [path moveToPoint:CGPointMake(points[0].x * mapScale + horizontalMapShift, points[0].y * mapScale)];
    for (int i=1; i<pointsCount; i++) {
        [path addLineToPoint:CGPointMake(points[i].x * mapScale + horizontalMapShift, points[i].y * mapScale)];
    }
    
    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.path = path.CGPath;
    layer.lineWidth = 1;
    
    layer.lineJoin = kCALineJoinRound;
    
    return layer;
}

-(void)learnRegion:(id)sender
{
    learningRegion = !learningRegion;
    
    if (learningRegion){
        samplesToTake = LEARNING_SAMPLING_SIZE;
        learningData = [[NSMutableDictionary alloc] initWithCapacity:samplesToTake];
        
        [SVProgressHUD showInfoWithStatus:@"Please select region to learn" maskType:SVProgressHUDMaskTypeClear];
    }
    else
        [SVProgressHUD showInfoWithStatus:@"Learn canceled" maskType:SVProgressHUDMaskTypeClear];
    
    [self.navigationItem.leftBarButtonItem setTitle:(learningRegion ? @"Cancel" : @"Learn")];
}

//-(void)showMap:(id)sender
//{
//    NSError *error;
//    NSString *fileContents;
//
//    BOOL learnedMapDataFileExists = [FCFileManager existsItemAtPath:@"learnedMapData.json"];
//    if (learnedMapDataFileExists)
//    {
//        fileContents = [FCFileManager readFileAtPath:@"learnedMapData.json"];
//    }
//    else{
//        NSString *filepath = [[NSBundle mainBundle] pathForResource:@"mapData" ofType:@"json"];
//        fileContents = [NSString stringWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:&error];
//        if (error){
//            NSLog(@"Error reading file: %@", error.localizedDescription);
//            return;
//        }
//    }
//        
//    mapData = [[NSJSONSerialization JSONObjectWithData:[fileContents dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&error] mutableCopy];
//    
//    if (mapData == nil){
//        [_debugView setText:[error localizedDescription]];
//        return;
//    }
//    
//    [_usersDirection setHidden:!learnedMapDataFileExists];
//    
//    UIImage *map = [UIImage imageNamed:mapData[@"uri"]];
//    mapBearing = [mapData[@"bearing"] floatValue];
//    
//    CGSize mapViewSize = _mapView.frame.size;
//    
//    CGSize mapSize = [map size];
//    
//    mapScale = mapViewSize.height / mapSize.height;
//    
//    CGSize size = CGSizeApplyAffineTransform(mapSize, CGAffineTransformMakeScale(mapScale, mapScale));
//    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
//    
//    [map drawInRect:CGRectMake(0, 0, size.width, size.height)];
//    
//    UIImage *scaledMap = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//    
//    [_mapView setImage:scaledMap];
//    
//    horizontalMapShift = (_mapView.frame.size.width - size.width) / 2.0;
//
//    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Learn" style:UIBarButtonItemStylePlain target:self action:@selector(learnRegion:)];
//}

- (void)scanForBluetoothPerepherials
{
    self.bluetoothManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];
    self.beaconPeripherals = [[NSMutableArray alloc]init];
    self.beacons = [[NSArray alloc]init];
    self.beaconServiceUUID = [CBUUID UUIDWithString:@"955A1523-0FE2-F5AA-A094-84B8D4F3E8AD"];
}

-(void)viewWillAppear:(BOOL)animated
{
    samplingData = [[NSMutableDictionary alloc] initWithCapacity:SAMPLING_SIZE];
    samplesTaken = 0;
    samplingMaxRSSI = 0;
    
    CGRect r = self.view.bounds;
    _usersDirection = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"NorthDirection"]];
    [_usersDirection setFrame:CGRectMake(CGRectGetMidX(r) - 15, CGRectGetMidY(r) - 15, 30, 30)];
    [self.view addSubview:_usersDirection];
    [_usersDirection setHidden:YES];
    
//    [self scanForBluetoothPerepherials];
    
    building = -1;
    floor = -1;
    
    [self startLocationManager];
    
    UITapGestureRecognizer *mapTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapOnMap:)];
    
    //[[self view] bringSubviewToFront:_mapView];
    [[self view] addGestureRecognizer:mapTap];
    
    [SVProgressHUD showWithStatus:@"Searching for location..." maskType:SVProgressHUDMaskTypeGradient];
    
    [_debugView setText:@"Searching for location..."];
    [_debugView setBackgroundColor:[UIColor colorWithWhite:1.0 alpha:0.6]];
}

-(void)viewDidLayoutSubviews{
//    [self showMap:self];
}

-(IBAction)dropLearnedData:(id)sender{
    for (PFObject* region in mapData[@"regions"]) {
        region[@"beacons"] = [NSDictionary dictionary];
        
        [region save];
    }
}

-(IBAction)tapOnMap:(id)sender
{
    if (mapData == nil)
        return;
    
    UITapGestureRecognizer *mapTap = sender;
    CGPoint tapLocation = [mapTap locationInView:_mapView];
    
    CAShapeLayer *layer;
    for (PFObject* region in mapData[@"regions"]) {
        UIBezierPath *path = [[UIBezierPath alloc] init] ;
        
        NSArray* regionPoints = region[@"points"];
        
        CGPoint point = CGPointMake([regionPoints[0][@"x"] floatValue] * mapScale + horizontalMapShift, [regionPoints[0][@"y"] floatValue] * mapScale);
        [path moveToPoint:point];

        for (int i = 1; i<[regionPoints count]; i++) {
            point = CGPointMake([regionPoints[i][@"x"] floatValue] * mapScale + horizontalMapShift, [regionPoints[i][@"y"] floatValue] * mapScale);
            [path addLineToPoint:point];
        }
        
        [path closePath];
        
        if ([path containsPoint:tapLocation]){
            layer = [CAShapeLayer layer];
            layer.path = path.CGPath;
            layer.lineWidth = 1;
            layer.strokeColor = [[UIColor colorWithHexString:region[@"color"]] CGColor];
            layer.fillColor = [[UIColor colorWithHexString:region[@"color"]] CGColor];
            layer.lineJoin = kCALineJoinRound;

            if (learningRegion){
                regionToLearn = region;
                [SVProgressHUD showProgress:0 status:@"Leaning Region" maskType:SVProgressHUDMaskTypeClear];
            }
            else{
                [SVProgressHUD showInfoWithStatus:region[@"name"]];
            }
            
            break;
        }
    }
    
    if (layer != nil){
        if (destinationLayer != nil){
            [_mapView.layer replaceSublayer:destinationLayer with:nil];
        }
        
        CABasicAnimation *flash = [CABasicAnimation animationWithKeyPath:@"opacity"];
        flash.fromValue = [NSNumber numberWithFloat:0.1];
        flash.toValue = [NSNumber numberWithFloat:0.6];
        flash.duration = 2.0;
        flash.autoreverses = YES;
        flash.repeatCount = HUGE_VALF;
        
        [layer addAnimation:flash forKey:@"flashAnimation"];
        
        [_mapView.layer addSublayer:layer];
        
        destinationLayer = layer;
    }
}

- (void)placeUserAtRegion:(NSDictionary *)closesedRegion
{
    NSArray* regionPoints = closesedRegion[@"points"];
    UIBezierPath *path = [[UIBezierPath alloc] init];
    
    CGPoint point = CGPointMake([regionPoints[0][@"x"] floatValue] * mapScale + horizontalMapShift, [regionPoints[0][@"y"] floatValue] * mapScale);
    [path moveToPoint:point];
    
    for (int i = 1; i<[regionPoints count]; i++) {
        point = CGPointMake([regionPoints[i][@"x"] floatValue] * mapScale + horizontalMapShift, [regionPoints[i][@"y"] floatValue] * mapScale);
        [path addLineToPoint:point];
    }
    
    [path closePath];
    
    CGRect regionBounds = CGPathGetBoundingBox([path CGPath]);
    
    CGPoint center = CGPointMake(CGRectGetMidX(regionBounds), CGRectGetMidY(regionBounds) + _mapView.frame.origin.y);
    
    [_usersDirection setCenter:center];
    [_usersDirection setHidden:NO];
}

-(void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    if ([beacons count] == 0)
        return;
    
    NSString* debugInfo = [[NSString alloc] init];

    for (CLBeacon* beacon in beacons) {
        debugInfo = [debugInfo stringByAppendingFormat:@"R:%@; Major:%ld; Minor:%ld; RSSI:%li \r", [region identifier], [beacon major].longValue, [beacon minor].longValue, [beacon rssi] ];
    }
    //[_debugView setText:debugInfo];
    
    for (CLBeacon* beacon in beacons) {
        if ([beacon rssi] == 0){
            NSLog(@"Sample dropped from region %@ -> (%ld, %ld)", [region identifier], [beacon major].longValue, [beacon minor].longValue);

            //return;
        }
    }
    
    if (learningRegion && regionToLearn != nil){
        for (CLBeacon* beacon in beacons) {
            
            NSString* key = [NSString stringWithFormat:@"%d", [[beacon minor] intValue]];
            NSNumber *val = [learningData objectForKey:key];
            if (val == nil)
                [learningData setObject:@([beacon rssi]) forKey:key];
            else{
                [learningData setObject:@([beacon rssi] + [val longValue]) forKey:key];
            }
        }
        samplesToTake--;
        
        float progress = (((float)(LEARNING_SAMPLING_SIZE - samplesToTake)) / LEARNING_SAMPLING_SIZE);
        [SVProgressHUD showProgress:progress status:@"Learning Region" maskType:SVProgressHUDMaskTypeClear];

        if (samplesToTake == 0){
            learningRegion = NO;
            [self assignSamplingDataToRegion];
        }
    }
    else if (learningRegion == NO)
    {
        for (CLBeacon* beacon in beacons) {
            NSLog(@"%@", [beacon description]);
            NSString* key = [NSString stringWithFormat:@"%d", [[beacon minor] intValue]];
            NSNumber *val = [samplingData objectForKey:key];
            if (val == nil)
                [samplingData setObject:@([beacon rssi] / (float)SAMPLING_SIZE) forKey:key];
            else{
                [samplingData setObject:@([beacon rssi] / (float)SAMPLING_SIZE + [val longValue]) forKey:key];
            }
            
            if (abs([samplingData[key] intValue]) > samplingMaxRSSI)
            {
                samplingMaxRSSI = abs([samplingData[key] intValue]);
                samplingMaxMajor = [beacon major];
            }
        }

        samplesTaken ++;
        if (samplesTaken < SAMPLING_SIZE)
            return;
        
        unsigned short floorAtBuilding = [samplingMaxMajor unsignedShortValue];
        unsigned short _building = (floorAtBuilding & (0xFF << 8)) >> 8;
        unsigned short _floor = floorAtBuilding & 0xFF;
        
        if (_building != building || _floor != floor){
            mapData = nil;
            building = _building;
            floor = _floor;
            
            [self loadMapForFloor:_floor inBuilding:_building];
            return;
        }
        
        samplingMaxRSSI = 0;

        samplesTaken = 0;
        
        NSDictionary* closesedRegion = nil;
        if (mapData != nil){
            NSArray *regions = mapData[@"regions"];
            float minDistance = MAXFLOAT;

            for (NSDictionary* region in regions)
            {
                NSDictionary* regionBecons = region[@"beacons"];
                if ([regionBecons count] == 0)
                    continue;

                float distance = 0;
                for (NSString* beaconId in [regionBecons allKeys])
                {
                    NSNumber *sampledRSSI = samplingData[beaconId];
                    long rssi = sampledRSSI == nil ? 0 : [sampledRSSI intValue];
                    
                    distance += pow([regionBecons[beaconId] doubleValue] - rssi, 2);
                }
                
                distance = sqrt(distance);
                
                debugInfo = [debugInfo stringByAppendingFormat:@"%@ - %f\r", region[@"name"], distance];
                
                if (closesedRegion == nil || minDistance > distance){
                    minDistance = distance;
                    closesedRegion = region;
                }
            }
        }
        else{
            
            
        }
        
        [samplingData removeAllObjects];
        
        if (closesedRegion != nil)
            [self placeUserAtRegion:closesedRegion];
        else{
            [_usersDirection setHidden:YES];

            debugInfo = [debugInfo stringByAppendingFormat:@"Region Not Found"];
        }

        [_debugView setText:debugInfo];
    }
}

- (void)loadMapForFloor:(short)_floor inBuilding:(short)_building {
    NSDictionary* query = @{ @"building" : [NSNumber numberWithShort:_building], @"floor" : [NSNumber numberWithShort:_floor] };
    
    [PFCloud callFunctionInBackground:@"getMap" withParameters:query block:^(NSDictionary *result, NSError *error)
     {
         if (error != nil){
             
             
             return ;
         }
         
         mapData = [result mutableCopy];
         
         PFFile* mapFile = result[@"mapImage"];
         UIImage *map = [UIImage imageWithData:[mapFile getData]];
         
         mapBearing = [result[@"bearing"] floatValue];
         
         CGSize mapViewSize = _mapView.frame.size;
         
         CGSize mapSize = [map size];
         
         mapScale = mapViewSize.height / mapSize.height;
         
         CGSize size = CGSizeApplyAffineTransform(mapSize, CGAffineTransformMakeScale(mapScale, mapScale));
         UIGraphicsBeginImageContextWithOptions(size, YES, 0);
         
         [map drawInRect:CGRectMake(0, 0, size.width, size.height)];
         
         UIImage *scaledMap = UIGraphicsGetImageFromCurrentImageContext();
         UIGraphicsEndImageContext();
         
         [_mapView setImage:scaledMap];
         
         horizontalMapShift = (_mapView.frame.size.width - size.width) / 2.0;

         self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Learn" style:UIBarButtonItemStylePlain target:self action:@selector(learnRegion:)];
         self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(dropLearnedData:)];
         
         [SVProgressHUD dismiss];
     }];
}

-(void)assignSamplingDataToRegion
{
    for (NSString* beaconMinor in [learningData allKeys]) {
        double val = [[learningData objectForKey:beaconMinor] doubleValue];
        double v = val / LEARNING_SAMPLING_SIZE;
        [learningData setObject:@(v) forKey:beaconMinor];
    }
    
    NSMutableDictionary *beacons = regionToLearn[@"beacons"];
    [beacons addEntriesFromDictionary:learningData];

    [regionToLearn save];
    
    regionToLearn = nil;
    
    [SVProgressHUD showInfoWithStatus:@"Region Learned" maskType:SVProgressHUDMaskTypeGradient];
    
    [self.navigationItem.leftBarButtonItem setTitle:@"Learn"];
}

- (BOOL)locationManagerShouldDisplayHeadingCalibration:(CLLocationManager *)manager{
    
    return YES;
}

-(void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error
{
    
}

-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"centralManagerDidUpdateState");
    if (central.state == CBCentralManagerStatePoweredOn)
    {
        [self.bluetoothManager scanForPeripheralsWithServices:nil options:nil];
        NSLog(@"centralManager powered on");
    }
    else
    {
        return;
    }
}

-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"I see an advertisement with identifer: %@, state: %ld, name: %@, services: %@, description: %@",
          [peripheral identifier],
          [peripheral state],
          [peripheral name],
          [peripheral services],
          [advertisementData description]);
    
    if ([[peripheral name] rangeOfString:@"MiniBeacon_"].length > 0){
        [self.bluetoothManager stopScan];
        [central connectPeripheral:peripheral options:nil];
    }
//
//    [self.beaconPeripherals addObject:peripheral];
//    self.beacons = [NSArray arrayWithArray:self.beaconPeripherals];
}

-(void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error{
    NSLog(@"didReadRSSI: %@, name: %@, RSSI: %@",
          [peripheral identifier],
          [peripheral name],
          [RSSI description]);
}

-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"didConnectPeripheral %@",peripheral.name);
    [peripheral readRSSI];

    [peripheral discoverServices:[NSArray arrayWithObject:self.beaconServiceUUID]];
}

-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"didDisconnectPeripheral %@",peripheral.name);
 
}

-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"didFailToConnectPeripheral %@",peripheral.name);
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NSLog(@"didDiscoverServices %@",peripheral.name);
    for(CBService *service in peripheral.services)
    {
        [peripheral discoverCharacteristics:nil forService:service];
//        if ([service.UUID isEqual:self.beaconServiceUUID]) {
//            NSLog(@"Beacon Config service found");
//            //[self.beaconPeripheral discoverCharacteristics:nil forService:service];
//        }
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"didDiscoverCharacteristics");
//    if ([service.UUID isEqual:self.beaconServiceUUID]) {
//        for(CBCharacteristic *characteristic in service.characteristics)
//        {
//            if ([characteristic.UUID isEqual:self.beaconUUIDCharacteristicUUID]) {
//                NSLog(@"UUID characteristic found: %@",characteristic.UUID);
//                self.beaconUUIDCharacteristic = characteristic;
//                [self.beaconPeripheral readValueForCharacteristic:characteristic];
//            }
//            else if ([characteristic.UUID isEqual:self.majorMinorCharacteristicUUID]) {
//                NSLog(@"Major Minor characteristic found: %@",characteristic.UUID);
//                self.majorMinorCharacteristic = characteristic;
//                [self.beaconPeripheral readValueForCharacteristic:characteristic];
//            }
//            else if ([characteristic.UUID isEqual:self.rssiCharacteristicUUID]) {
//                NSLog(@"RSSI characteristic found: %@",characteristic.UUID);
//                self.rssiCharacteristic = characteristic;
//                [self.beaconPeripheral readValueForCharacteristic:characteristic];
//            }
//            
//        }
//    }
}

@end
