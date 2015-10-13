//
//  AppController.m
//  b-music
//
//  Created by Sergey P on 01.10.13.
//  Copyright (c) 2013 Sergey P. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  1. The above copyright notice and this permission notice shall be included
//     in all copies or substantial portions of the Software.
//
//  2. This Software cannot be used to archive or collect data such as (but not
//     limited to) that of events, news, experiences and activities, for the
//     purpose of any concept relating to diary/journal keeping.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "AppController.h"

@implementation AppController{
    
    NSDictionary * _currentTrack;
    
    NSMutableArray * _viewPlaylist;//Playlist for table
    NSMutableArray * _soundPlaylist;//Playlist for playing
    NSMutableArray * _shufflePlaylist;
    NSMutableDictionary * _imageList;
    
    NSString * _currentTableRow;//For table whitch one cell is shown
    BOOL _isInitialLoadingFinish;//Indicator starting app
//    BOOL _userHoldKey;//global key event holding indicator
    
    CGSize _windowSize;//size player
    BOOL _scrobbleIndicator;//Shows send track has been sent or not
}
- (id)init
{
    self = [super init];
    if (self) {
        
        _vkAPI=[[vkAPI alloc] init];
        [_vkAPI setDelegate:self];
        
        _lastfmAPI=[[LastfmAPI alloc] init];
        [_lastfmAPI setDelegate:self];
        
        _PC=[[PlayerController alloc] init];
        [_PC setDelegate:self];
        _currentTableRow=@"MainRow";
        
        //Delegate notafications
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    }
    return self;
}


/*
 *  Preferences Delegate
 *****************************/
#pragma mark Preferences Delegate
-(void)updateMenuBarIcon{
    if (Settings.sharedInstance.settings.showIconMenubar) { //Add status bar
        [self addStatusBarItem];
    }else{
        [self removeStatusBarItem];
    }
}

-(void)updateDockIcon{
    if(Settings.sharedInstance.settings.showArtworkDock){
        NSImage * image = [_imageList objectForKey:_currentTrack];
        [NSApp setApplicationIconImage: image];
    }else{
        [NSApp setApplicationIconImage: nil];
    }
}
-(void)logoutVkFromPreferences{
    [self.vkAPI logout];
}

/*
 *  Lastfm API Delegate
 *****************************/
#pragma mark LastfmAPI Delegate

-(void)finishAuthorizeLastfm{
    NSLog(@"FinishAuthorise lastfm");
    if (!preferences) return;
    [preferences updateProfileLastfm];
}

/*
 *  Api VK Delegate
 *****************************/
#pragma mark vkAPI Delegate
-(void) finishAuthVK{
    NSLog(@"Finish auth vk");
    [self loadMainPlaylist];
    [[[NSApp delegate] window] makeKeyAndOrderFront:self];
    [self authorizationVK:NO];
    
    if (!preferences) return;
    [preferences updateProfileVk];
}

-(void) beginAuthVK{
    [self authorizationVK:YES];
}

/*
 *                                  Window Methods
 *
 *****************************************************************************************/
#pragma mark Window Delegate
-(void)windowDidResize:(NSNotification *)notification{
    NSEvent *event = [[NSApplication sharedApplication] currentEvent];
    if ([event type]==6) {
         id window=[[NSApp delegate] window];
        _windowSize=[window frame].size;
    }
}


-(void)windowDidBecomeMain:(NSNotification *)notification{ NSLog(@"DidBecomeMain");
    
    //add b-music to menu window
    [[NSApplication sharedApplication]addWindowsItem:[[NSApp delegate] window] title:@"b-music" filename:NO];
    
    if (!_isInitialLoadingFinish) {
        
        [self registerHandlerLinks];//Handler tokens /lastfm/vk
        
        //Print settings
        NSLog(@"%@",[Settings sharedInstance]);
        
        //add status bar item
        if (Settings.sharedInstance.settings.showIconMenubar) { //Add status bar
            [self addStatusBarItem];
        }
        
        [_Controls0 setDelegate:self];//Set delegation method
        
        [self addSubviewHelper:self.Controls0
                        slerve:self.Controls1];//Add view to superview (Controls1)
        
        [self addSubviewHelper:self.BottomControls0
                        slerve:self.BottomControls1];//Add view to superview (Bottom)
        
        [self.volume setProgress:Settings.sharedInstance.settings.volume];//Set volume on view
        
        if (Settings.sharedInstance.settings.alwaysOnTop) { //Set Always on top
            [[[NSApp delegate] window] setLevel:1000];
            [[self.windowMenu itemWithTag:4] setState:1];
            [[[NSApp delegate] window] setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces];
        }
        
        [[self.Controls2 viewWithTag:8] setFlag:Settings.sharedInstance.settings.shuffle];//Set shuffle on view
        [[self.controlsMenu itemWithTag:5] setState:Settings.sharedInstance.settings.shuffle];//Set shuffle on top in menu
        
        [[self.Controls2 viewWithTag:7] setFlag:Settings.sharedInstance.settings.repeat];//Set repeat on view
        [[self.controlsMenu itemWithTag:6] setState:Settings.sharedInstance.settings.repeat];//Set repeat on top in menu
        
        //Set search
        [[self.searchField cell]setFocusRingType:NSFocusRingTypeNone];
        
        //Setting size window
        _windowSize=[[NSApp delegate] window].frame.size;
        
        //TURN ON MENU
        [self switchMainMenuItems:YES];
        
        //Local Monitor hotkeys
        [NSEvent addLocalMonitorForEventsMatchingMask: NSKeyDownMask
                                              handler:^(NSEvent *event) { return [self localMonitorKeydownEvents:event];}];
        
        
        //------MediaKey
        if (!self.keyTap)
            self.keyTap= [[SPMediaKeyTap alloc] initWithDelegate:self];
        if([SPMediaKeyTap usesGlobalMediaKeyTap])
            [self.keyTap startWatchingMediaKeys];
        else
            NSLog(@"Media key monitoring disabled");
        //---EndMediakey
        
        _isInitialLoadingFinish=YES;
        
        [self loadMainPlaylist];
    }
    
    if (!Settings.sharedInstance.settings.token){
        [self.vkAPI logout];
    }
}

/*
 * Notafication center delagate
 *******************************/
#pragma mark Notafication Center
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center
     shouldPresentNotification:(NSUserNotification *)notification{
    return YES;
}

-(void)userNotificationCenter:(NSUserNotificationCenter *)center
      didActivateNotification:(NSUserNotification *)notification{
    [self gotoCurrentTrack:nil];
    [[[NSApp delegate] window] makeKeyWindow];
    [[[NSApp delegate] window] makeMainWindow];
}

/*
 *  ControlsView Methods Delegate
 ***************************************/
-(void)isHovered:(BOOL)flag{
    if (![_popoverVolume isShown]) {
        [self removeSubviews];
        if (flag) {
            [self addSubviewHelper:self.Controls0 slerve:self.Controls2];
        }else{
            [self addSubviewHelper:self.Controls0 slerve:self.Controls1];
        }
    }
}

/*
 * TEMP Methods
 ****************************************/
#pragma mark Temp

-(void)switchMainMenuItems:(BOOL)flag{
    //whole menu controls
    for (NSMenuItem * item in  [self.controlsMenu itemArray])
        [item setEnabled:flag];
    //Whole dock menu
    for (NSMenuItem * item in [self.dockMenu itemArray])
        [item setEnabled:flag];
    //Whole status menu
    for (NSMenuItem * item in [self.statusMenu itemArray])
        [item setEnabled:flag];
    //Whole viewmenu
    for (NSMenuItem * item in  [self.viewMenu itemArray])
        [item setEnabled:flag];
    //Partly mainmenu
    [[self.editMenu itemWithTag:3] setEnabled:flag];
}

-(void) authorizationVK:(BOOL)flag{
    id window=[[NSApp delegate] window];
    if ([window frame].size.height < 343|| [window frame].size.width < 223){
        CGRect rect = NSMakeRect( [window frame].origin.x, [window frame].origin.y, 223, 343);
        [window setFrame:rect display:YES animate:YES];
    }
    for (NSView * view in  [[[[NSApp delegate] window] contentView] subviews]) {
        [view setHidden:flag];
    }
    if (flag) {
        [self addSubviewHelper:[[[NSApp delegate] window] contentView] slerve:self.lockView];
        [self.lockView setHidden:!flag];
        [self.PC pause];
    }else{
        [self.lockView removeFromSuperview];
    }
    [self switchMainMenuItems:!flag];
}

- (NSString *) URLEncodedString:(NSString*)str {
    NSMutableString * output = [NSMutableString string];
    const char * source = [str UTF8String];
    unsigned long sourceLen = strlen(source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = (const unsigned char)source[i];
        if (false && thisChar == ' '){
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}

-(void) addStatusBarItem{
    statusItem=[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:self.statusMenu];
    [statusItem setHighlightMode:YES];
    if(self.PC.player.rate==1.0)
        [statusItem setImage:[NSImage imageNamed:@"pauseTemplate"]];
    else
        [statusItem setImage:[NSImage imageNamed:@"playTemplate"]];
}

-(void) removeStatusBarItem{
    [[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
}

- (void)registerHandlerLinks{
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self
                                                       andSelector:@selector(getUrl:withReplyEvent:)
                                                     forEventClass:kInternetEventClass
                                                        andEventID:kAEGetURL];
}

- (void)getUrl:( NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString * str=[[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSString * prefix=@"com.ttitt.b-music://";
    if (![str hasPrefix:prefix]) return;
    
    NSString * tokenString=[str substringFromIndex:prefix.length];
    
    if ([tokenString characterAtIndex:0]==63) {
        //LASTFM
        [self.lastfmAPI parseTokenUsernameFormString:tokenString];
    }else{
        //VK
        [self.vkAPI parseAccessTokenAndUserIdFormString:tokenString];
    }
}

-(NSEvent*) localMonitorKeydownEvents:(NSEvent*)event{
//    NSLog(@"%hu %@",event.keyCode, [[[NSApp keyWindow] firstResponder] className]);
//    return event;
    
    if (event.modifierFlags& NSCommandKeyMask) return event;
    
    if ([[[NSApp keyWindow] firstResponder] isKindOfClass:[NSTextView class]]){
        
        if (event.keyCode==125) {
            [_tableview keyDown:event];
        }else if (event.keyCode==126){
            [_tableview keyDown:event];
        }else if (event.keyCode==36 && _tableview.selectedRow>-1) {
            [[[_tableview viewAtColumn:0 row:_tableview.selectedRow makeIfNecessary:NO] viewWithTag:1] performClick:nil];
            return nil;
        }
        return event;
    }
    
    
    if (event.keyCode==36 && _tableview.selectedRow>-1) {
        [[[_tableview viewAtColumn:0 row:_tableview.selectedRow makeIfNecessary:NO] viewWithTag:1] performClick:nil];
        return nil;
    }
    [_tableview keyDown:event];
    return nil;
}

//----------------------------------------------------------------//
+(void)initialize;
{
	if([self class] != [AppController class]) return;
	
	// Register defaults for the whitelist of apps that want to use media keys
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             [SPMediaKeyTap defaultMediaKeyUserBundleIdentifiers], kMediaKeyUsingBundleIdentifiersDefaultsKey,
                                                             nil]];
}
-(void)mediaKeyTap:(SPMediaKeyTap*)keyTap receivedMediaKeyEvent:(NSEvent*)event;
{
	NSAssert([event type] == NSSystemDefined && [event subtype] == SPSystemDefinedEventMediaKeys, @"Unexpected NSEvent in mediaKeyTap:receivedMediaKeyEvent:");
	// here be dragons...
	int keyCode = (([event data1] & 0xFFFF0000) >> 16);
	int keyFlags = ([event data1] & 0x0000FFFF);
	BOOL keyIsPressed = (((keyFlags & 0xFF00) >> 8)) == 0xA;
	int keyRepeat = (keyFlags & 0x1);
	
	if (keyIsPressed) {
		NSString *debugString = [NSString stringWithFormat:@"%@", keyRepeat?@", repeated.":@"."];
		switch (keyCode) {
			case NX_KEYTYPE_PLAY:
                [self play:nil];
				debugString = [@"Play/pause pressed" stringByAppendingString:debugString];
				break;
            	
			case NX_KEYTYPE_FAST:
                if (!keyRepeat) [self next:nil];
				debugString = [@"Ffwd pressed" stringByAppendingString:debugString];
				break;
				
			case NX_KEYTYPE_REWIND:
                if (!keyRepeat) [self previous:nil];
				debugString = [@"Rewind pressed" stringByAppendingString:debugString];
				break;
			default:
				debugString = [NSString stringWithFormat:@"Key %d pressed%@", keyCode, debugString];
				break;
                // More cases defined in hidsystem/ev_keymap.h
		}
		NSLog(@"%@",debugString);
	}
}
//----------------------------------------------------------------//

//-(void) globalMonitorKeydownEvents:(NSEvent*)event{
//    if (!(event.modifierFlags&NSCommandKeyMask)) return;
////    NSLog(@"%li",event.data1);
//    switch (event.data1) {
//        case 1051136://Play
//            [self play:nil];
//            break;
//        case 1247745://ffwd
//            _userHoldKey=YES;
//            double change1=[[self.BottomControls1 viewWithTag:2] doubleValue]+[[self.BottomControls1 viewWithTag:2] maxValue]*2/100;
//            if (change1>[[self.BottomControls1 viewWithTag:2] maxValue]){
//                [self next:nil];
//                [[self.BottomControls1 viewWithTag:2] setProgress:0];
//                [self.PC setRuntime:0];
//            }else{
//                [[self.BottomControls1 viewWithTag:2] setProgress:change1];
//                [self.PC setRuntime:change1];
//            }
//            
//            break;
//        case 1248000://End ffwd
//            if (!_userHoldKey) [self next:nil];
//            _userHoldKey=NO;
//            break;
//        case 1313281://Rewind
//            _userHoldKey=YES;
//            double change=[[self.BottomControls1 viewWithTag:2] doubleValue]-[[self.BottomControls1 viewWithTag:2] maxValue]*2/100;
//            if (change<0){
//                [self previous:nil];
//                
//                [[self.BottomControls1 viewWithTag:2] setProgress:[[self.BottomControls1 viewWithTag:2] maxValue]];
//                [self.PC setRuntime:[[self.BottomControls1 viewWithTag:2] maxValue]];
//            }else{
//                [[self.BottomControls1 viewWithTag:2] setProgress:change];
//                [self.PC setRuntime:change];
//            }
//            break;
//        case 1313536://End Rewind
//            if (!_userHoldKey) [self previous:nil];
//            _userHoldKey=NO;
//            break;
//    }
//}

-(void) removeSubviews{
    [self.Controls1 removeFromSuperview];
    [self.Controls2 removeFromSuperview];
}

-(void) addSubviewHelper:(NSView*)master slerve:(NSView*)slerve{
    [master addSubview:slerve];
    [slerve setFrame:[master bounds]];
    [slerve setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
}

//Switcher to pause state in table view
-(void) setPauseStateForButton:(id)object state:(BOOL)flag{
    NSInteger num=(int)[_viewPlaylist indexOfObject:object];
    if (num>-1) [[[_tableview viewAtColumn:0 row:num makeIfNecessary:NO] viewWithTag:1] setPauseState:flag];
}


-(void) loadMainPlaylist{
    
    id response =[self.vkAPI audio_get];
    
    if (![self.vkAPI checkForErrorResponse:response]) return;//Some error happend
    
    _viewPlaylist=[[NSMutableArray alloc] initWithArray:[[response objectForKey:@"response"] objectForKey:@"items"]];
    _soundPlaylist=[_viewPlaylist mutableCopy];
    
    if (Settings.sharedInstance.settings.shuffle) { _shufflePlaylist=[self.PC generateShufflePlaylist:_soundPlaylist]; }
    
    [self.tableview performSelectorOnMainThread:@selector(reloadData)
                                     withObject:nil
                                  waitUntilDone:NO];
}

//Show preferences window
-(void) showPreferencesWichTag:(int)tag{
    
    if (!preferences) {
        preferences=[[Preferences alloc] initWithWindowNibName:@"Preferences"];
        [preferences setDelegate:self];
    }
    
    preferences.showViewWithTag = tag;
    [preferences showWindow:self];
}

/*
 *  Player Methods
 *******************************/
#pragma mark Player

-(void)nextTrack{
    [self next:self];
}
-(void) isPlayerPlaying:(BOOL)flag{
    [[self.Controls2 viewWithTag:3] setPauseState:flag];
    [self setPauseStateForButton:_currentTrack state:flag];
    
    NSString * state;
    if (flag) {
        state=@"Pause";
        [statusItem setImage:[NSImage imageNamed:@"pauseTemplate"]];
    }else{
        state=@"Play";
        [statusItem setImage:[NSImage imageNamed:@"playTemplate"]];
    }
    
    [[self.controlsMenu itemWithTag:1] setTitle:state];
    [[self.statusMenu itemWithTag:1] setTitle:state];
    [[self.dockMenu itemWithTag:1] setTitle:state];
    
}

-(void) durationTrack:(double)duration{
    NSString * title=[_currentTrack objectForKey:@"title"];
    NSString * artist=[_currentTrack objectForKey:@"artist"];
    NSString * durationString=[_currentTrack objectForKey:@"duration"];
    
    [[self.Controls1 viewWithTag:1] setStringValue:title];//Set title for player
    [[self.Controls1 viewWithTag:2] setStringValue:artist];//Set artist for player
    [[self.BottomControls1 viewWithTag:2] setMaxValue:duration];//Set duration for slider
    
    NSInteger num=(int)[_viewPlaylist indexOfObject:_currentTrack];
    
    _scrobbleIndicator=NO;//Reset inicator
    
    dispatch_queue_t downloadQueue = dispatch_queue_create("com.ttitt.b-music.lastfm", NULL);
    dispatch_async(downloadQueue, ^{
        if (num>-1){
            NSButton * btnPlayTableCell=[[_tableview viewAtColumn:0 row:num makeIfNecessary:NO] viewWithTag:1];
            
           
            
            //Set updateNowPlayng lastfm
            [self.lastfmAPI track_updateNowPlaying:artist
                                             track:title
                                          duration:durationString];
            
            NSImage * image;
            //Search artwork
            if (Settings.sharedInstance.settings.searchArtwork) {
                 image =[self.lastfmAPI getImageWithArtist:artist track:title size:3];
            }
            
            
            dispatch_async(dispatch_get_main_queue(), ^{
                //set dock icon
                if (Settings.sharedInstance.settings.showArtworkDock)
                    [NSApp setApplicationIconImage: image];
                
                if (!_imageList)
                    _imageList = [[NSMutableDictionary alloc]init];
                
                if (image){
                    [_imageList setObject:image forKey:_currentTrack];
                    [btnPlayTableCell setImage:image];
                }
            });
            
        }
    });
    
    
    //Show notafications
    if (Settings.sharedInstance.settings.showNotafications){
        
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = title;
        notification.informativeText = artist;
        
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    }
}


-(void) bufferingTrack:(double)seconds{
    [[self.BottomControls1 viewWithTag:2] setBuffering:seconds];
}
-(void) runtimeTrack:(double)seconds
       secondsString:(NSString *)str
            scrobble:(BOOL)scrobble{
    
    [[self.BottomControls1 viewWithTag:2] setProgress:seconds];
    [[self.BottomControls1 viewWithTag:1] setTitle:str];

    if (!_scrobbleIndicator && scrobble) {
        NSLog(@"SCROBBLE REQUEST");
        NSString * title=[_currentTrack objectForKey:@"title"];
        NSString * artist=[_currentTrack objectForKey:@"artist"];
        
        //Scrobbing request
        [self.lastfmAPI track_scrobble:artist
                                 track:title];
        _scrobbleIndicator=YES;
    }
}

/*
 *                                  TableView Methods
 *
 *****************************************************************************************/
#pragma mark Table

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView{ // count of table view items
    return [_viewPlaylist count];
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row{
    
    TableCellView * cellview=[tableView makeViewWithIdentifier:@"MainCell" owner:self];
    id obj=[_viewPlaylist objectAtIndex:row];
    [[cellview viewWithTag:2] setStringValue:[obj objectForKey:@"title"]];
    [[cellview viewWithTag:3] setStringValue:[obj objectForKey:@"artist"]];
    [[cellview viewWithTag:4] setTitle:[self.PC convertTime:[[obj objectForKey:@"duration"] doubleValue]]];
    
    [[cellview viewWithTag:1] setPauseState:([obj isEqualTo:_currentTrack])? YES : NO];
    
    
    if (_imageList) {
        
        NSImage * image = [_imageList objectForKey:obj];
        [[cellview viewWithTag:1] setImage:image];
    }
    
    return cellview;
}

-(void)tableViewSelectionDidChange:(NSNotification *)notification{
    if ([_currentTableRow isEqualToString:@"MainRow"]){
        [[self.editMenu itemWithTag:1] setEnabled:NO];
        [[self.editMenu itemWithTag:2] setEnabled:YES];
    }else if([_currentTableRow isEqualToString:@"SearchRow"]){
        [[self.editMenu itemWithTag:1] setEnabled:YES];
        [[self.editMenu itemWithTag:2] setEnabled:NO];
    }
}
- (NSTableRowView *)tableView:(NSTableView *)tableView
                rowViewForRow:(NSInteger)row{
    return [tableView makeViewWithIdentifier:_currentTableRow owner:self];
}

#pragma mark -
#pragma mark IBAcrions
/*
 *@ IBActions
 */

-(IBAction)supportLockScreenShowStore:(id)sender{
    [self showPreferencesWichTag:4];
}
-(IBAction)supportLockScreen:(id)sender{ NSLog(@"SupportLock Screen");
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://ttitt.ru/b-music/"]];
}

-(IBAction)loginAuthVk:(id)sender{ NSLog(@"loginAuthVk");
    [self.vkAPI login];
}
-(IBAction)signupAuthVk:(id)sender{ NSLog(@"signupAuthVk");
    [self.vkAPI signup];
}

-(IBAction)preferences:(id)sender{ NSLog(@"Preferences");
    [self showPreferencesWichTag:0];
}

-(IBAction)play:(id)sender{ NSLog(@"Play");
    [self setPauseStateForButton:_currentTrack state:NO];
    
    if ([sender isKindOfClass:[PlayButtonCell class]]) {
        NSInteger row=[_tableview rowForView:sender];
        
        if (![_soundPlaylist isEqualTo:_viewPlaylist]){ //Chech to play new playlist
            _soundPlaylist=[_viewPlaylist mutableCopy];
            _shufflePlaylist=[self.PC generateShufflePlaylist:_soundPlaylist];
        }
        
        id obj=[_soundPlaylist objectAtIndex:row];
        
        if ([obj isEqualTo:_currentTrack]) {
            if(self.PC.player.rate==1.0)  [self.PC pause];
            else [self.PC play];
        }else{
            _currentTrack=[[NSDictionary alloc] initWithDictionary:obj];
            [self.PC play:[_currentTrack objectForKey:@"url"]];
        }
    }else{
        if (_currentTrack==nil) {
            _currentTrack=[[NSDictionary alloc] initWithDictionary:[(Settings.sharedInstance.settings.shuffle)?_shufflePlaylist:_soundPlaylist objectAtIndex:0]];
            NSLog(@"%@",_currentTrack);
            [self.PC play:[_currentTrack objectForKey:@"url"]];
        }else{
            if(self.PC.player.rate==1.0) [self.PC pause];
            else [self.PC play];
        }
    }
}
-(IBAction)next:(id)sender{ NSLog(@"Next");
    [self setPauseStateForButton:_currentTrack state:NO];
    
    NSInteger num=(int)[(Settings.sharedInstance.settings.shuffle)?_shufflePlaylist:_soundPlaylist indexOfObject:_currentTrack]+1;
    if ([(Settings.sharedInstance.settings.shuffle)?_shufflePlaylist:_soundPlaylist count]-num < 1){
        num=0;
        if(Settings.sharedInstance.settings.shuffle){
            _shufflePlaylist=[self.PC generateShufflePlaylist:_soundPlaylist];
        }
    }
    _currentTrack=[[NSDictionary alloc] initWithDictionary:[(Settings.sharedInstance.settings.shuffle)?_shufflePlaylist:_soundPlaylist objectAtIndex:num]];
    [self.PC play:[_currentTrack objectForKey:@"url"]];
}
-(IBAction)previous:(id)sender{ NSLog(@"Previous");
    [self setPauseStateForButton:_currentTrack state:NO];
    NSInteger num=(int)[(Settings.sharedInstance.settings.shuffle)?_shufflePlaylist:_soundPlaylist indexOfObject:_currentTrack];
    if (num-1<0) num=0; else num-=1;
    _currentTrack=[[NSDictionary alloc] initWithDictionary:[(Settings.sharedInstance.settings.shuffle)?_shufflePlaylist:_soundPlaylist objectAtIndex:num]];
    [self.PC play:[_currentTrack objectForKey:@"url"]];
}
-(IBAction)decreaseVolume:(id)sender{ NSLog(@"Decrease volume");
    Settings.sharedInstance.settings.volume-=0.1;
    if (Settings.sharedInstance.settings.volume<0){ Settings.sharedInstance.settings.volume=0;}else if (Settings.sharedInstance.settings.volume==0){return;}
    [self.volume setProgress:Settings.sharedInstance.settings.volume];
    [self.PC.player setVolume:Settings.sharedInstance.settings.volume];
    [Settings.sharedInstance saveSettings];
}
-(IBAction)increaseVolume:(id)sender{ NSLog(@"IncreaseVolume");
    Settings.sharedInstance.settings.volume+=0.1;
    if (Settings.sharedInstance.settings.volume>2){
        Settings.sharedInstance.settings.volume=2;
    }else if (Settings.sharedInstance.settings.volume==2){
        return;
    }
    [self.volume setProgress:Settings.sharedInstance.settings.volume];
    [self.PC.player setVolume:Settings.sharedInstance.settings.volume];
    [Settings.sharedInstance saveSettings];
}
-(IBAction)mute:(id)sender{NSLog(@"Mute");
    Settings.sharedInstance.settings.volume=0;
    [self.volume setProgress:Settings.sharedInstance.settings.volume];
    [self.PC.player setVolume:Settings.sharedInstance.settings.volume];
    [Settings.sharedInstance saveSettings];
}
-(IBAction)shuffle:(id)sender{NSLog(@"Shuffle");
    Settings.sharedInstance.settings.shuffle=!Settings.sharedInstance.settings.shuffle;
    [[self.Controls2 viewWithTag:8] setFlag:Settings.sharedInstance.settings.shuffle];//Set shuffle on view
    [[self.controlsMenu itemWithTag:5] setState:Settings.sharedInstance.settings.shuffle];//Set shuffle on menu
    [Settings.sharedInstance saveSettings];
    if (Settings.sharedInstance.settings.shuffle)
        _shufflePlaylist=[self.PC generateShufflePlaylist:_soundPlaylist];
}
-(IBAction)repeat:(id)sender{NSLog(@"Repeat");
    Settings.sharedInstance.settings.repeat=!Settings.sharedInstance.settings.repeat;
    [[self.Controls2 viewWithTag:7] setFlag:Settings.sharedInstance.settings.repeat];//Set repear on view
    [[self.controlsMenu itemWithTag:6] setState:Settings.sharedInstance.settings.repeat];//Set repeat on menu
    [Settings.sharedInstance saveSettings];
}
-(IBAction)alwaysOnTop:(id)sender{NSLog(@"Always On top");
    if (!Settings.sharedInstance.settings.alwaysOnTop) {
        [[[NSApp delegate] window] setLevel:1000];
        [[self.windowMenu itemWithTag:4] setState:1];
        [[[NSApp delegate] window] setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces];
    }else{
        [[[NSApp delegate] window] setLevel:0];
        [[self.windowMenu itemWithTag:4] setState:0];
        [[[NSApp delegate] window] setCollectionBehavior: NSWindowCollectionBehaviorDefault];
    }
    Settings.sharedInstance.settings.alwaysOnTop=!Settings.sharedInstance.settings.alwaysOnTop;
    [Settings.sharedInstance saveSettings];
}


-(IBAction)visitWebsite:(id)sender{ NSLog(@"visitwebsite");
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://ttitt.ru/"]];
}


-(IBAction)more:(id)sender{ NSLog(@"More");
    [[_tableview viewAtColumn:0 row:[_tableview rowForView:sender] makeIfNecessary:NO] slideCell:150];
    [sender mouseExited:nil];
}

-(IBAction)buyInItunec:(id)sender{ NSLog(@"Buy In Itunes");
    
    NSInteger row=[_tableview rowForView:sender];
    id obj=[_viewPlaylist objectAtIndex:row];
    NSString * artist=[obj objectForKey:@"artist"];
    NSString * track=[obj objectForKey:@"title"];
    NSString *strURL = [NSString stringWithFormat:@"http://ttitt.ru/track?artist=%@&title=%@",[self URLEncodedString:artist], [self URLEncodedString:track]];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:strURL]];
}

-(IBAction)addTrack:(id)sender{NSLog(@"AddtTrack");
    NSInteger row=([sender isKindOfClass:[NSMenuItem class]])?[_tableview selectedRow]:[_tableview rowForView:sender];
    
    id obj=[_viewPlaylist objectAtIndex:row];
    
    BOOL result=[self.vkAPI audio_addWithOwner_id:[obj objectForKey:@"owner_id"]
                                          idTrack:[obj objectForKey:@"id"]];
    
    if (!result) return;// Some error happend
    
    [[[_tableview rowViewAtRow:row makeIfNecessary:NO] viewWithTag:4] setComplete];
    //[[_tableview viewAtColumn:0 row:_row makeIfNecessary:NO] slideCell:0];
}


-(IBAction)removeTrack:(id)sender{NSLog(@"RemoveTrack");
    
    NSInteger row=([sender isKindOfClass:[NSMenuItem class]])?[_tableview selectedRow]:[_tableview rowForView:sender];
    
    id obj=[_viewPlaylist objectAtIndex:row];
    
    BOOL result=[self.vkAPI audio_deleteWithOwner_id:[obj objectForKey:@"owner_id"]
                                             idTrack:[obj objectForKey:@"id"]];
    
    if (!result) return;// Some error happend
    
    if ([_soundPlaylist isEqualTo:_viewPlaylist]){ //Chech to play new playlist
        [_soundPlaylist removeObjectAtIndex:row];
    }
    
    [_viewPlaylist removeObjectAtIndex:row];
    [_tableview removeRowsAtIndexes:[[NSIndexSet alloc] initWithIndex:row] withAnimation:NSTableViewAnimationSlideUp];
}


-(IBAction)showVolume:(id)sender{ NSLog(@"ShowVolume");
    [self.popoverVolume showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMaxXEdge];
}


-(IBAction)volume:(id)sender{NSLog(@"Volume");
    NSEvent *event = [[NSApplication sharedApplication] currentEvent];
    BOOL endingDrag = event.type == NSLeftMouseUp;
    [sender setProgress:[sender floatValue]];
    Settings.sharedInstance.settings.volume=[sender floatValue];
    [self.PC.player setVolume:[sender floatValue]];
    if(endingDrag) [Settings.sharedInstance saveSettings];
}


-(IBAction)runtime:(id)sender{NSLog(@"Runtime");
    NSEvent *event = [[NSApplication sharedApplication] currentEvent];
    BOOL endingDrag = event.type == NSLeftMouseUp;
    [sender setProgress:[sender doubleValue]];
    if(endingDrag) [self.PC setRuntime:[sender doubleValue]];
}


-(IBAction)switchRuntime:(id)sender{ NSLog(@"Switch Runtime");
    Settings.sharedInstance.settings.runTime=!Settings.sharedInstance.settings.runTime;
    [Settings.sharedInstance saveSettings];
}


-(IBAction)showSearch:(id)sender{NSLog(@"ShowSearch");
    //Set search view height
    if ([self.searchViewHeight constant]>0) {
        [[self.searchViewHeight animator] setConstant:0];
        [self.searchField setEnabled:NO];
        
        [[self.Controls2 viewWithTag:6] setFlag:NO];//Show search button change color
    }else{
        [[self.searchViewHeight animator] setConstant:30];
        [self.searchField setEnabled:YES];
        [self.searchField selectText:nil];
        [[self.Controls2 viewWithTag:6] setFlag:YES];//Show search button change color
    }
}
-(IBAction)search:(id)sender{NSLog(@"Search");
    if ([sender stringValue].length!=0) {
        
        _currentTableRow=@"SearchRow";
        id response =[self.vkAPI audio_searchWithSearchQuery:[sender stringValue]];
        
        if (![self.vkAPI checkForErrorResponse:response]) return;//Some error happend
        
        _viewPlaylist=[[NSMutableArray alloc] initWithArray:[[response objectForKey:@"response"] objectForKey:@"items"]];
        
        [self.tableview performSelectorOnMainThread:@selector(reloadData)
                                         withObject:nil
                                      waitUntilDone:NO];
        
        if([[sender stringValue] isEqual:@"Sergey Popov"]){[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://vk.com/serji"]];}
        
    }else{
        [self loadMainPlaylist];
        _currentTableRow=@"MainRow";
    }
}


-(IBAction)showPlaylist:(id)sender{ NSLog(@"ShowPlaylist");
    
    CGRect rect;
    
    CGFloat widthPlayer=250;
    CGFloat heightPlayer=70;
    
    id window=[[NSApp delegate] window];
    
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        if ([sender tag]==2) {
            
            if ([self.searchViewHeight constant]>0)
                heightPlayer+=30;
            
            CGFloat xPos=[window frame].origin.x + [window frame].size.width - widthPlayer;
            CGFloat yPos=[window frame].origin.y  + [window frame].size.height - heightPlayer;
            
            rect=NSMakeRect(xPos, yPos, widthPlayer, heightPlayer);
            
        }else if ([sender tag]==1){
            
            CGFloat xPos=[window frame].origin.x + [window frame].size.width - _windowSize.width;
            CGFloat yPos=[window frame].origin.y  + [window frame].size.height - _windowSize.height;
            
            rect=NSMakeRect(xPos, yPos, _windowSize.width, _windowSize.height);
            
        }else if ([sender tag]==3){
            rect=[[NSScreen mainScreen] visibleFrame];
        }
    }else{
        if ([self.searchViewHeight constant]>0){
            heightPlayer+=30;
        }
        
        if ([window frame].size.width==widthPlayer && [window frame].size.height==heightPlayer) {
            
            CGFloat xPos=[window frame].origin.x + [window frame].size.width - _windowSize.width;
            CGFloat yPos=[window frame].origin.y  + [window frame].size.height - _windowSize.height;
            
            rect=NSMakeRect(xPos, yPos, _windowSize.width, _windowSize.height);
        
        }else{
            CGFloat xPos=[window frame].origin.x + [window frame].size.width - widthPlayer;
            CGFloat yPos=[window frame].origin.y  + [window frame].size.height - heightPlayer;
            
            rect=NSMakeRect(xPos, yPos, widthPlayer, heightPlayer);
        }
    }
    
    [window setFrame:rect display:YES animate:YES];
}

-(IBAction)minimize:(id)sender{NSLog(@"Minimize");
    id window=[[NSApp delegate] window];
    [window miniaturize:self];
}

-(IBAction)gotoCurrentTrack:(id)sender{ NSLog(@"Go to Current Track");
    int selectTrack=(int)[_viewPlaylist indexOfObject:_currentTrack];
    [_tableview scrollRowToVisible:selectTrack];
    [_tableview selectRowIndexes:[NSIndexSet indexSetWithIndex:selectTrack] byExtendingSelection:NO];
}
-(IBAction)close:(id)sender{ NSLog(@"Close");
    [[[NSApp delegate] window] close];
}

-(IBAction)logout:(id)sender{ NSLog(@"Logout");
    [self.vkAPI logout];
}

@end
