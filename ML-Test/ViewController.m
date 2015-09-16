//
//  ViewController.m
//  ConnectionMLApi
//
//  Created by usuario on 12/8/15.
//  Copyright (c) 2015 RockAndApp. All rights reserved.
//
//  This ViewController have a tableView inside with a custom "auto load more" items
//  In this simple implementation instead of use the default UISeachController is only implemented a textField and button to custom search
//  TODO if is necessary, implement image caching

#import "ViewController.h"
#import "SearchTableViewCell.h"
#import "ItemDetailsViewController.h"

@interface ViewController () <NSURLSessionDelegate,UITableViewDelegate, UITableViewDataSource>

@property (strong, nonatomic) NSMutableData *recievedData;
@property (weak, nonatomic) NSMutableDictionary  *resultsDictionary;
@property (weak, nonatomic) NSURLResponse *recievedResponse;
@property (weak, nonatomic) NSError *connectionError;
@property (weak, nonatomic) NSDictionary *Results;
@property (strong, nonatomic) NSMutableArray *titles;
@property (strong, nonatomic) NSMutableArray *images;
@property (strong, nonatomic) NSMutableArray *prices;
@property (strong, nonatomic) NSMutableArray *itemsId;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"ML-Search";
    self.loadingIndicator.hidden = YES;
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:nil action:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)searchButton:(id)sender {
    if(self.textField.text.length){
        self.searchButton.hidden = YES;
        self.loadingIndicator.hidden = NO;
        [self.loadingIndicator startAnimating];
        NSString *stringRequest = [self.textField.text stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        self.titles = [NSMutableArray new];
        self.images = [NSMutableArray new];
        self.prices = [NSMutableArray new];
        self.itemsId = [NSMutableArray new];
        
        NSInteger startRow = 0;
        [self searchRequest:stringRequest offset:startRow];
        [self.view endEditing:YES];
    }
    else {
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Alert" message:@"You need type something" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [self.view endEditing:YES];
    }
}

//Connection Data Delegate Methods

-(void)searchRequest:(NSString *)request offset:(NSInteger)offset{
    self.recievedData = [[NSMutableData alloc]init];
    
    NSString *Url = [[NSString alloc]initWithFormat:@"https://api.mercadolibre.com/sites/MLA/search?q=%@&offset=%li", request, (long)offset];
    
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                          delegate:self
                                                     delegateQueue:nil];
    NSURLSessionDataTask *dataTask =
    [session dataTaskWithURL:[NSURL URLWithString:Url]
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
                       if (!jsonError) {
                           self.Results = self.resultsDictionary[@"results"];
                           for (NSDictionary *results in self.Results){
                               NSString *titleString = [results objectForKey:@"title"];
                               NSString *imagesURL = [results objectForKey:@"thumbnail"];
                               NSString *price = [results objectForKey:@"price"];
                               NSString *itemId = [results objectForKey:@"id"];
                               [self.prices addObject:price];
                               [self.titles addObject:titleString];
                               [self.images addObject:imagesURL];
                               [self.itemsId addObject:itemId];
                           }
                           
                          dispatch_async(dispatch_get_main_queue(), ^{
                              self.tableView.hidden = NO;
                              [self.loadingIndicator stopAnimating];
                              self.loadingIndicator.hidden = YES;
                              self.searchButton.hidden = NO;
                              [self.tableView reloadData];
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


//TableView Delegate Methods

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.titles.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 105;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    static NSString *cellIdentifier = @"cellDefault";
    SearchTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if(!cell){
        cell = [[SearchTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                           reuseIdentifier:cellIdentifier];
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"CustomCell" owner:self options:nil];
        cell = [nib objectAtIndex:0];
    }
    
    if (indexPath.row == [self.titles count] - 1)
    {
        [self reloadTableView];
    }
    
    cell.titleLabel.text = self.titles[indexPath.row];
    cell.thumbnail.image = [UIImage imageNamed:@"default_avatar"];
    
    //Set NSFormatter to display product price
    NSNumberFormatter *currencyFormatter = [[NSNumberFormatter alloc] init];
    [currencyFormatter setCurrencySymbol:@"$"];
    [currencyFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    cell.price.text = [currencyFormatter stringForObjectValue:self.prices[indexPath.row]];
    
    //Download Images with Session
    
    NSString *url = self.images[indexPath.row];
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                          delegate:self
                                                     delegateQueue:nil];
    NSURLSessionDownloadTask *getImageTask =
    [session downloadTaskWithURL:[NSURL URLWithString:url]
     
               completionHandler:^(NSURL *location,
                                   NSURLResponse *response,
                                   NSError *error) {
                   
                   UIImage *downloadedImage =
                   [UIImage imageWithData:
                    [NSData dataWithContentsOfURL:location]];
                   
                   dispatch_async(dispatch_get_main_queue(), ^{
                       UITableViewCell *updateCell = [self.tableView cellForRowAtIndexPath:indexPath];
                       if(updateCell){
                           cell.thumbnail.image = downloadedImage;
                       }
                   });
               }];
    [getImageTask resume];
    
    return cell;
}

- (void)reloadTableView
{
    // the last row after added new items
    NSInteger endingRow = [self.titles count];
    NSString *stringRequest = [self.textField.text stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self searchRequest:stringRequest offset:endingRow];
    
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    ItemDetailsViewController *detailItem = [[ItemDetailsViewController alloc] initWithNibName:@"ItemDetailsViewController" bundle:nil];
    detailItem.itemId = self.itemsId[indexPath.row];
    [self.navigationController pushViewController:detailItem animated:YES];
}
@end







