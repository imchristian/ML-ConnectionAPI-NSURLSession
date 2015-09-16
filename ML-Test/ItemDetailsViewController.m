//
//  ItemDetailsViewController.m
//  ConnectionMLApi
//
//  Created by usuario on 14/8/15.
//  Copyright (c) 2015 RockAndApp. All rights reserved.
//
//  This Controller handle all the data about the current item. First use a simple delegate methods connections to bring all the data and then push a new queue to show the appropiate images.
//

#import "ItemDetailsViewController.h"

@interface ItemDetailsViewController () <NSURLSessionDelegate>
@property (strong, nonatomic) NSMutableData *recievedData;
@property (weak, nonatomic) NSURLResponse *recievedResponse;
@property (weak, nonatomic) NSError *connectionError;
@property (weak, nonatomic) NSMutableDictionary  *resultsDictionary;
@property (strong, nonatomic) NSURLConnection *apiRequest;
@end

@implementation ItemDetailsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Details";
    //Check if exist some item
    if(self.itemId){
        [self searchRequest:self.itemId];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


//API Connection
-(void)searchRequest:(NSString *)request{
    NSString *urlString = [[NSString alloc] initWithFormat:@"https://api.mercadolibre.com/items/%@",request];
    
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                          delegate:self
                                                     delegateQueue:nil];
    NSURLSessionDataTask *dataTask =
    [session dataTaskWithURL:[NSURL URLWithString:urlString]
           completionHandler:^(NSData *data,
                               NSURLResponse *response,
                               NSError *error) {
               if (!error) {
                   NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
                   if (httpResp.statusCode == 200) {
                       NSError *jsonError;
                       self.resultsDictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                                options:NSJSONReadingAllowFragments
                                                                                  error:&jsonError];
                       NSLog(@"%@", self.resultsDictionary);
                       
                       if (!jsonError) {
                           dispatch_async(dispatch_get_main_queue(), ^{
                               [self fillTheItemFields:self.resultsDictionary];
                           });
                       }
                   }
               }
               else {
                   NSLog(@"%@", error);
               }
           }];
    
    [dataTask resume];
}

//Present all the information into the scene
-(void)fillTheItemFields:(NSDictionary *)dictionary {
    self.itemTitle.text = self.resultsDictionary[@"title"];
    NSLog(@"%@", self.itemTitle.text);
    self.stock.text = [NSString stringWithFormat:@"%@ disponibles", [self.resultsDictionary[@"available_quantity"] stringValue]];
    self.location.text = [NSString stringWithFormat:@"%@", self.resultsDictionary[@"seller_address"][@"city"][@"name"]];
    self.itemSold.text = [NSString stringWithFormat:@"%@ vendidos", [self.resultsDictionary[@"sold_quantity"] stringValue]];
    
    //Set NSFormatter to display product price
    NSNumberFormatter *currencyFormatter = [[NSNumberFormatter alloc] init];
    [currencyFormatter setCurrencySymbol:@"$"];
    [currencyFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    self.price.text = [currencyFormatter stringForObjectValue:self.resultsDictionary[@"price"]];
    
    //Load Id Images
    NSArray *picturesArray = self.resultsDictionary[@"pictures"];
    NSMutableArray *picturesId= [NSMutableArray new];
    
    for (NSDictionary *picturesDictionary in picturesArray){
        [picturesId addObject:picturesDictionary[@"id"]];
    }
    
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                          delegate:self
                                                     delegateQueue:nil];
    
    
    for (int i=0; i < picturesId.count; i++){
        NSString *urlString = [[NSString alloc] initWithFormat:@"https://api.mercadolibre.com/pictures/%@", picturesId[i]];
        NSURLSessionDataTask *dataTask =
        [session dataTaskWithURL:[NSURL URLWithString:urlString]
               completionHandler:^(NSData *data,
                                   NSURLResponse *response,
                                   NSError *error) {
                   if (!error) {
                       NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*) response;
                       if (httpResp.statusCode == 200) {
                           NSError *jsonError;
                           NSDictionary *imageDictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                                           options:NSJSONReadingAllowFragments
                                                                                             error:&jsonError];
                           if (!jsonError) {
                               for (NSMutableDictionary *picturesVariations in imageDictionary[@"variations"]){
                                   if([picturesVariations[@"size"] isEqual:@"400x400"]){
                                       NSString *picturesUrl = picturesVariations[@"url"];
                                       //Call the method to display the images into the UIScrollView
                                       [self showImages:picturesUrl index:i];
                                   }
                               }
                           }
                       }
                   }
                   else {
                       NSLog(@"%@", error);
                   }
               }];
        [dataTask resume];
    }
    
   self.imagesView.contentSize = CGSizeMake(self.imagesView.frame.size.width * picturesId.count, self.imagesView.frame.size.height);
}

-(void)showImages:(NSString *)picturesUrl index:(int)i{
        CGRect frame;
        frame.origin.x = self.imagesView.frame.size.width * i;
        frame.origin.y = 0;
        frame.size = self.imagesView.frame.size;
        
        self.imagesView.pagingEnabled = YES;
        
        UIImageView *imageView = [[UIImageView alloc]initWithFrame:frame];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_async(queue, ^{
        //load url image into NSData
        NSString *url = picturesUrl;
        NSData *picture = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
        //Call again the main queue to modify the UIScrollView
        dispatch_async(dispatch_get_main_queue(), ^{
            //convert data into image after completion
            imageView.image = [UIImage imageWithData:picture];
            [self.imagesView addSubview:imageView];
        });
        
    });
    
}
@end


















