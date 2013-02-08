// SubImapClient.h
// SubMail
//
// Copyright (c) 2012 Joseph North (http://sublink.ca/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "SubImapConnection.h"
#import "SubImapConnectionData.h"
#import "SubImapCommand.h"
#import "SubImapResponse.h"

@class SubImapClient;

@protocol SubImapClientDelegate <NSObject>
@optional
- (void)clientDidConnect:(SubImapClient *)client;
- (void)clientDidDisconnect:(SubImapClient *)client;
- (void)client:(SubImapClient *)client didSendCommand:(SubImapCommand *)command;
- (void)client:(SubImapClient *)client didReceiveResponse:(SubImapResponse *)response;
- (void)client:(SubImapClient *)client didSendData:(NSData *)data;
- (void)client:(SubImapClient *)client didReceiveData:(NSData *)data;
- (void)client:(SubImapClient *)client didChangeState:(SubImapClientState)state;
- (void)client:(SubImapClient *)client didEncounterParserError:(NSError *)error;
- (void)client:(SubImapClient *)client didEncounterStreamError:(NSError *)error;
@end


@interface SubImapClient : NSObject <SubImapConnectionDelegate>

@property (nonatomic) SubImapClientState state;
@property id<SubImapClientDelegate> delegate;

+ (instancetype)clientWithConnection:(SubImapConnection *)connection;
- (id)initWithConnection:(SubImapConnection *)connection;

- (SubImapConnection *)connection;

- (void)enqueueCommand:(SubImapCommand *)command;

@end