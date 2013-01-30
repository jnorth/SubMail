// SubImapSelectCommand.m
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

#import "SubImapSelectCommand.h"

#import "SubImapConnectionData.h"

@implementation SubImapSelectCommand {
  NSString *_mailbox;

  NSMutableDictionary *_data;
}

+ (id)commandWithMailboxPath:(NSString *)mailbox {
  return [[self alloc] initWithMailboxPath:mailbox];
}

+ (id)commandWithInbox {
  return [[self alloc] initWithMailboxPath:@"INBOX"];
}

- (id)initWithMailboxPath:(NSString *)mailbox {
  self = [super init];

  if (self) {
    _mailbox = mailbox;
    _data = [NSMutableDictionary dictionary];
  }

  return self;
}

- (NSString *)name {
  return @"SELECT";
}

- (BOOL)canExecuteInState:(SubImapClientState)state {
  switch (state) {
    case SubImapClientStateAuthenticated:
    case SubImapClientStateSelected:
      return YES;
    default:
      return NO;
  }
}

- (NSArray *)render {
  return @[
    [SubImapConnectionData dataWithString:self.tag],
    [SubImapConnectionData SP],
    [SubImapConnectionData dataWithString:[self name]],
    [SubImapConnectionData SP],
    [SubImapConnectionData dataWithQuotedString:_mailbox],
    [SubImapConnectionData CRLF],
  ];
}

- (BOOL)handleUntaggedResponse:(SubImapResponse *)response {
  switch (response.type) {
    case SubImapResponseTypeFlags:{
      _data[@"flags"] = response.data;
      return YES;
    }
    case SubImapResponseTypeExists:{
      _data[@"exists"] = response.data;
      return YES;
    }
    case SubImapResponseTypeRecent:{
      _data[@"recent"] = response.data;
      return YES;
    }
    case SubImapResponseTypeOk:{
      if ([response isUntagged]) {
        if ([response.data[@"code"] isEqualToString:@"PERMANENTFLAGS"]) {
          _data[@"permanentflags"] = response.data[@"flags"];
          return YES;
        }
        if (response.data[@"uidvalidity"]) {
          _data[@"uidvalidity"] = response.data[@"uidvalidity"];
          return YES;
        }
        if (response.data[@"uidnext"]) {
          _data[@"uidnext"] = response.data[@"uidnext"];
          return YES;
        }
      }
      return NO;
    }
    default:
      return NO;
  }
}

- (BOOL)handleTaggedResponse:(SubImapResponse *)response {
  if (![response isType:SubImapResponseTypeOk]) {
    [self makeError:@"Unable to select mailbox."];
  }

  _data[@"message"] = response.data[@"message"];
  _data[@"mailbox"] = _mailbox;

  self.result = _data;

  return YES;
}

@end