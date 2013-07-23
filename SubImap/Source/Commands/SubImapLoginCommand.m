// SubImapLoginCommand.m
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

#import "SubImapLoginCommand.h"

#import "SubImapConnectionData.h"

@implementation SubImapLoginCommand {
  NSString *_login;
  NSString *_password;
}

+ (id)commandWithLogin:(NSString *)login password:(NSString *)password {
  return [[self alloc] initWithLogin:login password:password];
}

- (id)initWithLogin:(NSString *)login password:(NSString *)password {
  self = [super init];

  if (self) {
    if (!login || !password || !login.length || !password.length) {
      [self setErrorCode:5 message:@"Nil login or password given to login command."];
    }

    _login = login;
    _password = password;
  }

  return self;
}

- (NSString *)name {
  return @"LOGIN";
}

- (BOOL)canExecuteInState:(SubImapClientState)state {
  return state == SubImapClientStateUnauthenticated;
}

- (NSArray *)render {
  // Only use literals when absolutely necessary
  SubImapConnectionData *loginData = [self stringNeedsLiteral:_login]
    ? [SubImapConnectionData literalDataWithString:_login encoding:NSUTF8StringEncoding]
    : [SubImapConnectionData dataWithString:_login];

  SubImapConnectionData *passwordData = [self stringNeedsLiteral:_login]
    ? [SubImapConnectionData literalDataWithString:_password encoding:NSUTF8StringEncoding]
    : [SubImapConnectionData dataWithString:_password];

  return @[
    [SubImapConnectionData dataWithString:self.tag],
    [SubImapConnectionData SP],
    [SubImapConnectionData dataWithString:self.name],
    [SubImapConnectionData SP],
    loginData,
    [SubImapConnectionData SP],
    passwordData,
    [SubImapConnectionData CRLF],
  ];
}

- (BOOL)handleUntaggedResponse:(SubImapResponse *)response {
  return [response isType:SubImapResponseTypeCapability];
}

- (BOOL)handleTaggedResponse:(SubImapResponse *)response {
  if (![response isType:SubImapResponseTypeOk]) {
    [self setErrorCode:SubImapLoginCommandBadCredentialsError message:@"Unable to login to account."];
  }

  self.result = response.data[@"message"];

  return YES;
}

- (SubImapClientState)stateFromState:(SubImapClientState)state {
  if (state == SubImapClientStateUnauthenticated) {
    return SubImapClientStateAuthenticated;
  }

  return state;
}

// Only 'astring's should be sent as non-literals
- (BOOL)stringNeedsLiteral:(NSString *)string {
  // ASCII
  NSMutableCharacterSet *validCharacters = [NSCharacterSet characterSetWithRange:NSMakeRange(0, 127)];
  // Remove control characters
  [validCharacters removeCharactersInRange:NSMakeRange(0, 31)];
  [validCharacters removeCharactersInRange:NSMakeRange(127, 1)];
  // Remove atom specials, except ]
  [validCharacters removeCharactersInString:@"(){ %*\""];

  return [string rangeOfCharacterFromSet:[validCharacters invertedSet]].location != NSNotFound;
}

@end