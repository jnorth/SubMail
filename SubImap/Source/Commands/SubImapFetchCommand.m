// SubImapFetchCommand.m
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

#import "SubImapFetchCommand.h"

#import "SubImapConnectionData.h"

@implementation SubImapFetchCommand {
  BOOL _useUIDs;
  NSArray *_IDs;

  NSMutableArray *_fetchResponses;
}

+ (id)commandWithSequenceIDs:(NSArray *)IDs {
  return [[self alloc] initWithIDs:IDs UID:NO];
}

+ (id)commandWithUIDs:(NSArray *)IDs {
  return [[self alloc] initWithIDs:IDs UID:YES];
}

+ (id)commandWithAll {
  return [[self alloc] initWithIDs:nil UID:NO];
}

- (id)initWithIDs:(NSArray *)IDs UID:(BOOL)useUIDs {
  self = [self init];

  if (self) {
    _IDs = IDs;
    _useUIDs = useUIDs;

    _fetchResponses = [NSMutableArray array];
  }

  return self;
}

- (NSString *)name {
  return @"FETCH";
}

- (BOOL)canExecuteInState:(SubImapClientState)state {
  switch (state) {
    case SubImapClientStateSelected:
      return YES;
    default:
      return NO;
  }
}

- (NSArray *)render {
  NSMutableArray *dataList = [NSMutableArray array];

  [dataList addObject:[SubImapConnectionData dataWithString:self.tag]];
  [dataList addObject:[SubImapConnectionData SP]];

  if (_useUIDs) {
    [dataList addObject:[SubImapConnectionData dataWithString:@"UID"]];
    [dataList addObject:[SubImapConnectionData SP]];
  }

  [dataList addObject:[SubImapConnectionData dataWithString:[self name]]];
  [dataList addObject:[SubImapConnectionData SP]];

  if (_IDs) {
    NSString *IDList = [_IDs componentsJoinedByString:@","];
    [dataList addObject:[SubImapConnectionData dataWithString:IDList]];
    [dataList addObject:[SubImapConnectionData SP]];
  } else {
    [dataList addObject:[SubImapConnectionData dataWithString:@"1:*"]];
    [dataList addObject:[SubImapConnectionData SP]];
  }

  if (self.fields == nil) {
    self.fields = @[@"ENVELOPE"];
  }

  [dataList addObject:[SubImapConnectionData dataWithString:@"("]];
  [dataList addObject:[SubImapConnectionData dataWithString:[self.fields componentsJoinedByString:@" "]]];
  [dataList addObject:[SubImapConnectionData dataWithString:@")"]];

  [dataList addObject:[SubImapConnectionData CRLF]];

  return dataList;
}

- (BOOL)handleUntaggedResponse:(SubImapResponse *)response {
  if ([response isType:SubImapResponseTypeFetch]) {
    [_fetchResponses addObject:response.data];
    return YES;
  }

  return NO;
}

- (BOOL)handleTaggedResponse:(SubImapResponse *)response {
  if (![response isType:SubImapResponseTypeOk]) {
    if (response.data[@"message"]) {
      [self makeError:response.data[@"message"]];
    } else {
      [self makeError:@"Unable to fetch messages."];
    }
  }

  self.result = _fetchResponses;

  return YES;
}

@end