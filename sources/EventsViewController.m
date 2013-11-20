//
//  EventsViewController.m
//  CineQuest
//
//  Created by Loc Phan on 10/9/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "EventsViewController.h"
#import "EventDetailViewController.h"
#import "CinequestAppDelegate.h"
#import "Schedule.h"
#import "NewsViewController.h"
#import "DDXML.h"
#import "DataProvider.h"


@implementation EventsViewController

@synthesize data;
@synthesize days;
@synthesize eventsTableView;
@synthesize index;
@synthesize activityIndicator;

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark -
#pragma mark UIViewController Methods

- (void) viewDidLoad
{
    [super viewDidLoad];
	
	self.title = @"Events";
	
	delegate = appDelegate;
	mySchedule = delegate.mySchedule;
	
	// Initialize data and days
	data = [[NSMutableDictionary alloc] init];
	days = [[NSMutableArray alloc] init];
	index = [[NSMutableArray alloc] init];
	backedUpDays	= [[NSMutableArray alloc] init];
	backedUpIndex	= [[NSMutableArray alloc] init];
	backedUpData	= [[NSMutableDictionary alloc] init];

	if (delegate.isOffSeason)
	{
		self.eventsTableView.hidden = YES;
		return;
	}

	[self reloadData:nil];
}

- (void) viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
}

- (void) viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
}

#pragma mark -
#pragma mark Actions

- (IBAction) reloadData:(id)sender
{
	self.eventsTableView.hidden = YES;
	
	[activityIndicator startAnimating];
	
	[data removeAllObjects];
	[days removeAllObjects];
	[index removeAllObjects];
	
	[self performSelectorOnMainThread:@selector(startParsingXML) withObject:nil waitUntilDone:NO];
}

- (void)addEvents:(id)sender
{
	int counter = 0;
	for (int section = 0; section < [days count]; section++) 
	{
		NSString *day = [days objectAtIndex:section];
		NSMutableArray *rows = [data objectForKey:day];
		for (int row = 0; row < [rows count];row++ )
		{
			Schedule *item = [rows objectAtIndex:row];
			if(item.isSelected)
			{
				// NSLog(@"%@",item.title);
				Schedule *schedule = item;
				
				BOOL isAlreadyAdded = NO;
				for(int i=0; i < [mySchedule count]; i++) {
					Schedule *obj = [mySchedule objectAtIndex:i];
					if (obj.ID == schedule.ID)
					{
						isAlreadyAdded = YES;
						// NSLog(@"%@ ID: %d",schedule.title,schedule.ID);
						break;
					}
				}
				if (!isAlreadyAdded) 
				{
					[mySchedule addObject:schedule];
					counter++;
				}
			}
		}
	}
		
	if (counter != 0)
	{
		[self syncTableDataWithScheduler];
		[self.eventsTableView reloadData];

		[delegate jumpToScheduler];
	}
}

- (void)refine:(id)sender
{
	// Back button
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
																				style:UIBarButtonItemStyleDone
																				target:self
																				action:@selector(back:)];
	// Remove rows
	NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
	NSMutableArray *itemsBeingDeleted = [[NSMutableArray alloc] init];
	
	for (int section = 0; section < [days count]; section++)
	{
		NSString *day = [days objectAtIndex:section];
		NSMutableArray *rows = [data objectForKey:day];
		
		for (int row = 0; row < [rows count]; row++) 
		{
			Schedule *item = [rows objectAtIndex:row];
			if (!item.isSelected) 
			{
				[indexPaths addObject:[NSIndexPath indexPathForRow:row inSection:section]];
				[itemsBeingDeleted addObject:item];
			}
			else
			{
				//NSLog(@"%@ - %@",item.time,item.title);
			}
			
		}
		
		[rows removeObjectsInArray:itemsBeingDeleted];
		[itemsBeingDeleted removeAllObjects];
	}
	
	// Remove sections
	NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
	
	int i = 0;
	for (NSString *day in days) 
	{
		NSMutableArray *rows = [data objectForKey:day];
		if ([rows count] == EMPTY) 
		{
			[data removeObjectForKey:day];
			[indexSet addIndex:i];
		}
		i++;
	}
	[days removeObjectsAtIndexes:indexSet];
	[index removeObjectsAtIndexes:indexSet];
	
	// Start updating table
	[self.eventsTableView beginUpdates];
	
	[self.eventsTableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:NO];
	
	[self.eventsTableView deleteSections:indexSet withRowAnimation:NO];
	
	[self.eventsTableView endUpdates];
	
	// add push animation
	CATransition *transition = [CATransition animation];
	transition.type = kCATransitionPush;
	transition.subtype = kCATransitionFromTop;
	transition.duration = 0.3;
	[[self.eventsTableView layer] addAnimation:transition forKey:nil];
	
	// reload data
	[self.eventsTableView reloadData];
}

- (void)back:(id)sender
{
	// reload data
	[days removeAllObjects];
	[index removeAllObjects];
	
	[days addObjectsFromArray:backedUpDays];
	[index addObjectsFromArray:backedUpIndex];
	
	for (int section = 0; section < [days count]; section++) 
	{
		NSString *day = [days objectAtIndex:section];
		NSArray *rows = [backedUpData objectForKey:day];
		NSMutableArray *array = [[NSMutableArray alloc] init];
		for (int row = 0; row < [rows count]; row++) 
		{
			Schedule *item = [rows objectAtIndex:row];
			[array addObject:item];
		}
		[data setObject:array forKey:day];
	}
	
	// push animation
	CATransition *transition = [CATransition animation];
	transition.type = kCATransitionPush;
	transition.subtype = kCATransitionFromBottom;
	transition.duration = 0.3;
	[[self.eventsTableView layer] addAnimation:transition forKey:nil];
	
	// reload table data
	[self.eventsTableView reloadData];
}

#pragma mark -
#pragma mark Private Methods

- (void) startParsingXML
{
	NSData *xmlDocData = [[appDelegate dataProvider] events];
	
	DDXMLDocument *eventXMLDoc = [[DDXMLDocument alloc] initWithData:xmlDocData options:0 error:nil];
	DDXMLNode *rootElement = [eventXMLDoc rootElement];
	if ([rootElement childCount] == 2)
	{
		rootElement = [rootElement childAtIndex:1];
	}
	else
	{
		rootElement = [rootElement childAtIndex:3];
	}
	
	NSString *previousDay = @"empty";
	NSMutableArray *tempArray = [[NSMutableArray alloc] init];
	//NSLog(@"Child count: %d",[rootElement childCount]);
	for (int i = 0; i < [rootElement childCount]; i++)
	{
		DDXMLElement *child = (DDXMLElement*)[rootElement childAtIndex:i];
		NSDictionary *attributes;
		if ([child respondsToSelector:@selector(attributesAsDictionary)])
		{
			attributes = [child attributesAsDictionary];
		}
		else
		{
			continue;
		}
		
		NSString *ID		= [attributes objectForKey:@"schedule_id"];
		NSString *prg_id	= [attributes objectForKey:@"program_item_id"];
		NSString *type		= [attributes objectForKey:@"type"];
		NSString *title		= [attributes objectForKey:@"title"];
		NSString *start		= [attributes objectForKey:@"start_time"];
		NSString *end		= [attributes objectForKey:@"end_time"];
		NSString *venue		= [attributes objectForKey:@"venue"];
				
		Schedule *event	= [[Schedule alloc] init];
		
		event.ID		= ID;
		event.itemID	= prg_id;
		event.type		= type;
		event.title		= title;
		event.venue		= venue;
		
		//Start Time
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
		[dateFormatter setLocale:usLocale];
		[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
		NSDate *date = [dateFormatter dateFromString:start];
		event.startDate = date;
		[dateFormatter setDateFormat:@"hh:mm a"];
		event.startTime = [dateFormatter stringFromDate:date];
		//Date
		[dateFormatter setDateFormat:@"EEEE, MMMM d"];
		NSString *dateString = [dateFormatter stringFromDate:date];
		event.dateString = dateString;
		//End Time
		[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
		date = [dateFormatter dateFromString:end];
		event.endDate = date;
		[dateFormatter setDateFormat:@"hh:mm a"];
		event.endTime = [dateFormatter stringFromDate:date];
		if (![previousDay isEqualToString:dateString]) 
		{
			[data setObject:tempArray forKey:previousDay];
			previousDay = [[NSString alloc] initWithString:dateString];
			[days addObject:previousDay];
			
			[index addObject:[[previousDay componentsSeparatedByString:@" "] objectAtIndex: 2]];
			
			tempArray = [[NSMutableArray alloc] init];
			[tempArray addObject:event];
		}
		else
		{
			[tempArray addObject:event];
		}
		      
        [self.eventsTableView reloadData];
		self.eventsTableView.hidden = NO;
		self.eventsTableView.tableHeaderView = nil;
	}
	
	[data setObject:tempArray forKey:previousDay];
	
	// back up current data
	backedUpDays	= [[NSMutableArray alloc] initWithArray:days copyItems:YES];
	backedUpIndex	= [[NSMutableArray alloc] initWithArray:index copyItems:YES];
	backedUpData	= [[NSMutableDictionary alloc] initWithDictionary:data copyItems:YES];
	
	[activityIndicator stopAnimating];

	[self.eventsTableView reloadData];
	self.eventsTableView.hidden = NO;
	self.eventsTableView.tableHeaderView = nil;
}

- (void) syncTableDataWithScheduler
{
	NSUInteger i, count = [mySchedule count];
	
	// Sync current data
	for (int section = 0; section < [days count]; section++) 
	{
		NSString *day = [days objectAtIndex:section];
		NSMutableArray *rows = [data objectForKey:day];
		for (int row = 0; row < [rows count]; row++) 
		{
			Schedule *event = [rows objectAtIndex:row];
			//event.isSelected = NO;
			for (i = 0; i < count; i++) 
			{
				Schedule *obj = [mySchedule objectAtIndex:i];
				//NSLog(@"obj id:%d, event id:%d",obj.ID,event.ID);
				if (obj.ID == event.ID) 
				{
					//NSLog(@"Added: %@. Time: %@",obj.title,obj.timeString);
					event.isSelected = YES;
				}
			}
		}
	}
	
	// Sync backedUp Data
	for (int section = 0; section < [days count]; section++) 
	{
		NSString *day = [days objectAtIndex:section];
		NSArray *rows = [backedUpData objectForKey:day];
		for (int row = 0; row < [rows count]; row++) 
		{
			Schedule *event = [rows objectAtIndex:row];
			//event.isSelected = NO;
			for (i = 0; i < count; i++) 
			{
				Schedule *obj = [mySchedule objectAtIndex:i];
				if (obj.ID == event.ID) 
				{
					//NSLog(@"Added: %@.",obj.title);
					event.isSelected = YES;
				}
			}
		}
	}
}

#pragma mark -
#pragma mark UITableView DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [days count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSString *day = [days objectAtIndex:section];
	NSMutableArray *events = [data objectForKey:day];
	
    return [events count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
	
	NSUInteger section = [indexPath section];
	NSUInteger row = [indexPath row];
	
	NSString *date = [days objectAtIndex:section];
	NSMutableArray *events = [data objectForKey:date];
	Schedule *event = [events objectAtIndex:row];
	// get title
	NSString *displayString = [NSString stringWithFormat:@"%@",event.title];
    // set text color
	UIColor *textColor = [UIColor blackColor];
	
	// check if current cell is already added to mySchedule
	// if it is, display it as blue
	NSUInteger i, count = [mySchedule count];
	for (i = 0; i < count; i++)
	{
		Schedule *obj = [mySchedule objectAtIndex:i];
		
		if (obj.ID == event.ID) 
		{
			// NSLog(@"%@ was added.",obj.title);
			textColor = [UIColor blueColor];
			break;
		}
	}
	
	// get checkbox status
	BOOL checked = event.isSelected;
	UIImage *buttonImage = (checked) ? [UIImage imageNamed:@"checked.png"] : [UIImage imageNamed:@"unchecked.png"];
	
	UILabel *titleLabel;
	UILabel *timeLabel;
	UILabel *venueLabel;
	UIButton *checkButton;
	
	UITableViewCell *tempCell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (tempCell == nil)
	{
		tempCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
		
		titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(50,2,230,20)];
		titleLabel.tag = CELL_TITLE_LABEL_TAG;
		[tempCell.contentView addSubview:titleLabel];
		
		timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(50,21,150,20)];
		timeLabel.tag = CELL_TIME_LABEL_TAG;
		[tempCell.contentView addSubview:timeLabel];
		
		venueLabel = [[UILabel alloc] initWithFrame:CGRectMake(210,21,100,20)];
		venueLabel.tag = CELL_VENUE_LABEL_TAG;
		[tempCell.contentView addSubview:venueLabel];
		
		checkButton = [UIButton buttonWithType:UIButtonTypeCustom];
		checkButton.frame = CGRectMake(0,0,50,50);
		[checkButton setImage:buttonImage forState:UIControlStateNormal];
		
		[checkButton addTarget:self action:@selector(checkBoxButtonTapped:event:) forControlEvents:UIControlEventTouchUpInside];
		
		checkButton.backgroundColor = [UIColor clearColor];
		checkButton.tag = CELL_LEFTBUTTON_TAG;
		[tempCell.contentView addSubview:checkButton];
	}
	
	titleLabel = (UILabel*)[tempCell viewWithTag:CELL_TITLE_LABEL_TAG];
	titleLabel.text = displayString;
	titleLabel.textColor = textColor;
	
	timeLabel = (UILabel*)[tempCell viewWithTag:CELL_TIME_LABEL_TAG];
	timeLabel.text = [NSString stringWithFormat:@"Time: %@ - %@",event.startTime,event.endTime];
	timeLabel.font = [UIFont systemFontOfSize:[UIFont smallSystemFontSize]];
	timeLabel.textColor = textColor;
	
	venueLabel = (UILabel*)[tempCell viewWithTag:CELL_VENUE_LABEL_TAG];
	venueLabel.text = [NSString stringWithFormat:@"Venue: %@",event.venue];
	venueLabel.font = [UIFont systemFontOfSize:[UIFont smallSystemFontSize]];
	venueLabel.textColor = textColor;
	
	checkButton = (UIButton*)[tempCell viewWithTag:CELL_LEFTBUTTON_TAG];
	[checkButton setImage:buttonImage forState:UIControlStateNormal];
		
	if (textColor == [UIColor blueColor]) {
		checkButton.userInteractionEnabled = YES;
	} else {
		checkButton.userInteractionEnabled = YES;
	}
	
    return tempCell;
}

- (void)checkBoxButtonTapped:(id)sender event:(id)touchEvent
{
	NSSet *touches = [touchEvent allTouches];
	UITouch *touch = [touches anyObject];
	CGPoint currentTouchPosition = [touch locationInView:self.eventsTableView];
	NSIndexPath *indexPath = [self.eventsTableView indexPathForRowAtPoint:currentTouchPosition];
	NSInteger row = [indexPath row];
	NSInteger section = [indexPath section];
	
	if (indexPath != nil)
	{
		// get date
		NSString *dateString = [days objectAtIndex:section];
		
		// get film objects using dateString
		NSMutableArray *events = [data objectForKey:dateString];
		Schedule *event = [events objectAtIndex:row];
		
		// set checkBox's status
		BOOL checked = event.isSelected;
		event.isSelected = !checked;
		
		// get the current cell and the checkbox button 
		UITableViewCell *currentCell = [self.eventsTableView cellForRowAtIndexPath:indexPath];
		UIButton *checkBoxButton = (UIButton*)[currentCell viewWithTag:CELL_LEFTBUTTON_TAG];
		
		// set button's image
		UIImage *buttonImage = (checked) ? [UIImage imageNamed:@"unchecked.png"] : [UIImage imageNamed:@"checked.png"];
		[checkBoxButton setImage:buttonImage forState:UIControlStateNormal];
	}
}

- (NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section
{
	NSString *day = [days objectAtIndex:section];
	return day;
}

- (NSArray*)sectionIndexTitlesForTableView:(UITableView*)tableView
{
	return index;
}

#pragma mark -
#pragma mark UITableView delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSUInteger section = [indexPath section];
	NSUInteger row = [indexPath row];
	NSString *date = [days objectAtIndex:section];
	
	NSMutableArray *events = [data objectForKey:date];
	Schedule *event = [events objectAtIndex:row];

	NSString *eventId = [NSString stringWithFormat:@"%@", event.itemID];
	EventDetailViewController *eventDetail = [[EventDetailViewController alloc] initWithTitle:event.title
																				andDataObject:event
																				andId:eventId];
	[self.navigationController pushViewController:eventDetail animated:YES];

	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

