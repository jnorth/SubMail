//
//  SubImapClientDelegate.h
//  SubMail
//
//  Created by Sublink Interactive on 2013-07-17.
//  Copyright (c) 2013 Sublink Interactive. All rights reserved.
//

@class SubImapClient;

@protocol SubImapClientDelegate <NSObject>
@optional
- (void)client:(SubImapClient *)client didEnqueueCommand:(SubImapCommand *)command;
- (void)client:(SubImapClient *)client didDequeueCommand:(SubImapCommand *)command;
- (void)client:(SubImapClient *)client didSendCommand:(SubImapCommand *)command;
- (void)client:(SubImapClient *)client didReceiveResponse:(SubImapResponse *)response;
- (void)client:(SubImapClient *)client didChangeState:(SubImapClientState)state;
- (void)client:(SubImapClient *)client didEncounterParserError:(NSError *)error;
@end