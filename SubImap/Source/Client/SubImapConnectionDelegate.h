//
//  SubImapConnectionDelegate.h
//  SubMail
//
//  Created by Sublink Interactive on 2013-07-17.
//  Copyright (c) 2013 Sublink Interactive. All rights reserved.
//

@class SubImapConnection;

@protocol SubImapConnectionDelegate <NSObject>
@optional
- (void)connectionDidOpen:(SubImapConnection *)connection;
- (void)connectionDidClose:(SubImapConnection *)connection;
- (void)connectionHasSpace:(SubImapConnection *)connection;
- (void)connection:(SubImapConnection *)connection didSendData:(NSData *)data;
- (void)connection:(SubImapConnection *)connection didReceiveData:(NSData *)data;
- (void)connection:(SubImapConnection *)connection didReceiveResponseData:(NSData *)data;
- (void)connection:(SubImapConnection *)connection didEncounterStreamError:(NSError *)error;
@end