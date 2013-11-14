//
//  NewsViewController.h
//  CineQuest
//
//  Created by Loc Phan on 10/9/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

@interface NewsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIWebViewDelegate>
{
	//Stores a list of name
	NSMutableArray *sections;
	
	//Stores value: name of section
	//		 object: array of rows
	NSMutableDictionary *data;
}

@property (nonatomic, strong) UITableView *newsTableView;
@property (nonatomic, strong) UILabel *loadingLabel;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@end
