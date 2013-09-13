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


extern NSString * const SubImapCommandErrorDomain;


/*
 * SubImapCommand
 *
 * This class represents an IMAP command, and handles any related responses.
 *
 * Override this to add support for new IMAP commands.
 */
@interface SubImapCommand : NSObject

@property (readonly) BOOL isComplete;

/*
 * IMAP commands are 'tagged' so that we can match responses to their command.
 *
 * This is automatically assigned when added to a SubImapClient.
 */
@property NSString *tag;

/*
 * If your command failed in any way, you should set this to indicate what
 * went wrong. Should be nil if no problems occured.
 */
@property NSError *error;

/*
 * The result of the command. This will be different for each subclass.
 */
@property id result;

/*
 * When a command handles it's tagged response, this result block is called.
 *
 * At this point, the command is considered complete, either successfully or
 * unsucessfully. You can now check the error and result properties.
 */
- (void)addCompletionBlock:(SubImapCompletionBlock)block;

/*
 * Calls the completion handlers.
 *
 * This is automatically called when YES is returned from your Tagged
 * response handler, or if an error is set before rendering.
 */
- (void)complete;

/*
 * Sets the error and calls complete.
 */
- (void)failWithErrorCode:(NSInteger)code message:(NSString *)message;

#pragma mark - Override

/*
 * Override this with the name of your command, as defined
 * in the various RFCs. Should be uppercase.
 */
- (NSString *)name;

/*
 * Override this to return the valid states for your command.
 *
 * Defaults to none.
 */
- (BOOL)canExecuteInState:(SubImapClientState)state;

/*
 * Override this with your collection of ConnectionData objects that
 * will be sent to the connection.
 *
 * You must include your command's tag, and a terminating CRLF.
 */
- (NSArray *)render;

/*
 * Override this to extract any untagged responses that might be related
 * to your command.
 *
 * Return YES if you found it to be related, or NO if not.
 */
- (BOOL)handleUntaggedResponse:(SubImapResponse *)response;

/*
 * Override this to handle your command's tagged response.
 *
 * This should only be called when it's tag matches your command's tag.
 *
 * Return YES if the response was related, or NO if not. Will probably
 * always be related as the tags match.
 */
- (BOOL)handleTaggedResponse:(SubImapResponse *)response;

/*
 * Override this to change the client's state.
 *
 * Only called after the command has handled it's tagged response.
 */
- (SubImapClientState)stateFromState:(SubImapClientState)state;


#pragma mark - Helpers

/*
 * This should not be overridden.
 *
 * Calls the other two handlers depending on the response type. It also
 * calls the resultBlock when the command's tagged response is handled.
 */
- (BOOL)handleResponse:(SubImapResponse *)response;

/*
 * This should not be overridden.
 *
 * If something went wrong when handling a response, you should set the
 * command's error using this method.
 *
 * You may still set the command's result if anything useful was extracted.
 */
- (void)setErrorCode:(NSInteger)code message:(NSString *)message;

@end