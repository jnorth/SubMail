// SubImapConnection.h
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

#import "SubImapConnectionData.h"
#import "SubImapResponse.h"

@class SubImapConnection;


@protocol SubImapConnectionDelegate <NSObject>
@optional
- (void)connectionDidOpen:(SubImapConnection *)connection;
- (void)connectionDidClose:(SubImapConnection *)connection;
- (void)connectionHasSpace:(SubImapConnection *)connection;
- (void)connection:(SubImapConnection *)connection didSendData:(NSData *)data;
- (void)connection:(SubImapConnection *)connection didReceiveData:(NSData *)data;
- (void)connection:(SubImapConnection *)connection didReceiveResponse:(SubImapResponse *)response;
- (void)connection:(SubImapConnection *)connection didEncounterParserError:(NSError *)error;
- (void)connection:(SubImapConnection *)connection didEncounterStreamError:(NSError *)error;
@end


@interface SubImapConnection : NSObject <NSStreamDelegate>

@property NSUInteger readBufferSize;

/*
 * RFC2088 - LITERAL+
 * http://www.ietf.org/rfc/rfc2088.txt
 */
@property BOOL supportLiteralPlus;

@property id<SubImapConnectionDelegate> delegate;

+ (id)connectionWithHost:(NSString *)host;

/*
 * Host can be the server's hostname or ip address.
 */
- (id)initWithHost:(NSString *)host;

/*
 * Open input and output streams to the supplied host, attempting
 * to auto-detect the correct port and security settings.
 */
- (BOOL)open;

/*
 * Closes the connection's input and output streams.
 *
 * The connection can not be used until it is opened again.
 *
 * Consider sending an IMAPLogoutCommand instead.
 */
- (BOOL)close;

/*
 * Returns YES if the input and output streams are open or active.
 */
- (BOOL)isOpen;

/*
 * Writes data to the server.
 */
- (void)write:(SubImapConnectionData *)data;

@end