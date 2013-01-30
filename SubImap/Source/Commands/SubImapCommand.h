// SubImapCommand.h
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

#import "SubImapTypes.h"
#import "SubImapResponse.h"

@interface SubImapCommand : NSObject

/*
 * IMAP commands are 'tagged' so that we can match
 * responses to their command.
 */
@property NSString *tag;

@property NSError *error;

@property id result;

@property (copy) SubImapResultBlock resultBlock;

@property SubImapCommand *nextCommand;

/*
 * Commands should return the name of the command, as defined
 * in the various RFCs. Should be uppercase.
 */
- (NSString *)name;

/*
 * Some commands can only be executed in certain
 * server states.
 */
- (BOOL)canExecuteInState:(SubImapClientState)state;

/*
 * Returns an array of IMAPConnectionData objects that will be sent
 * to the server.
 */
- (NSArray *)render;

- (BOOL)handleResponse:(SubImapResponse *)response;
- (BOOL)handleUntaggedResponse:(SubImapResponse *)response;
- (BOOL)handleTaggedResponse:(SubImapResponse *)response;

- (void)makeError:(NSString *)message;

@end