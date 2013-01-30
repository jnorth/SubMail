// SubImapResponse.m
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

#import "SubImapResponse.h"

@implementation SubImapResponse

+ (id)responseWithStatus:(BOOL)status type:(SubImapResponseType)type tag:(NSString *)tag data:(id)data {
  SubImapResponse *response = [[self alloc] init];
  response.status = status;
  response.type = type;
  response.tag = tag;
  response.data = data;
  return response;
}

+ (id)responseWithType:(SubImapResponseType)type data:(id)data {
  return [self responseWithStatus:YES type:type tag:nil data:data];
}

+ (SubImapResponseType)typeFromString:(NSString *)string {
  return (SubImapResponseType)[[self typeNames] indexOfObject:string];
}

+ (NSString *)stringFromType:(SubImapResponseType)type {
  return [self typeNames][type];
}

- (id)init {
  self = [super init];

  if (self) {
    self.status = NO;
    self.type = SubImapResponseTypeUnknown;
    self.tag = nil;
    self.data = nil;
  }

  return self;
}

- (BOOL)isTagged {
  return self.tag != nil;
}

- (BOOL)isUntagged {
  return self.tag == nil;
}

- (BOOL)isContinuation {
  return [self isType:SubImapResponseTypeContinue];
}

- (BOOL)isResult {
  return [self isTagged] && (
    [self isType:SubImapResponseTypeBad] ||
    [self isType:SubImapResponseTypeNo] ||
    [self isType:SubImapResponseTypeOk]
  );
}

- (BOOL)isType:(SubImapResponseType)type {
  return self.type == type;
}

- (NSString *)description {
  NSString *status = [NSString stringWithFormat:@"  status:%@\n", self.status ? @"YES" : @"NO"];
  NSString *type = [NSString stringWithFormat:@"  type:%@\n", [SubImapResponse stringFromType:self.type]];
  NSString *tag = [NSString stringWithFormat:@"  tag:%@\n", self.tag ? self.tag : @"NIL"];
  NSString *data = [NSString stringWithFormat:@"  data:%@\n", self.data ? self.data : @"NIL"];
  return [NSString stringWithFormat:@"IMAPResponse(\n%@%@%@%@)", status, type, tag, data];
}

+ (NSArray *)typeNames {
  static NSMutableArray *names = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    names = [NSMutableArray array];
    [names insertObject:@"*UNKNOWN*"     atIndex:SubImapResponseTypeUnknown];

    // RFC3501 7.5. Status Responses
    [names insertObject:@"OK"            atIndex:SubImapResponseTypeOk];
    [names insertObject:@"NO"            atIndex:SubImapResponseTypeNo];
    [names insertObject:@"BAD"           atIndex:SubImapResponseTypeBad];
    [names insertObject:@"PREAUTH"       atIndex:SubImapResponseTypePreauth];
    [names insertObject:@"BYE"           atIndex:SubImapResponseTypeBye];

    // RFC3501 7.5. Server and Mailbox Status
    [names insertObject:@"CAPABILITY"    atIndex:SubImapResponseTypeCapability];
    [names insertObject:@"LIST"          atIndex:SubImapResponseTypeList];
    [names insertObject:@"LSUB"          atIndex:SubImapResponseTypeLsub];
    [names insertObject:@"STATUS"        atIndex:SubImapResponseTypeStatus];
    [names insertObject:@"SEARCH"        atIndex:SubImapResponseTypeSearch];
    [names insertObject:@"FLAGS"         atIndex:SubImapResponseTypeFlags];

    // RFC3501 7.5. Mailbox Size
    [names insertObject:@"EXISTS"        atIndex:SubImapResponseTypeExists];
    [names insertObject:@"RECENT"        atIndex:SubImapResponseTypeRecent];

    // RFC3501 7.5. Message Status
    [names insertObject:@"EXPUNGE"       atIndex:SubImapResponseTypeExpunge];
    [names insertObject:@"FETCH"         atIndex:SubImapResponseTypeFetch];

    // RFC3501 7.5. Command Continuation Request
    [names insertObject:@"CONTINUE"      atIndex:SubImapResponseTypeContinue];
  });

  return names;
}

@end