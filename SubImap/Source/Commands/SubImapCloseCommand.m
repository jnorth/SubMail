//
//  SubImapCloseCommand.m
//  SubMail
//
//  Created by Sublink Interactive on 2013-07-19.
//  Copyright (c) 2013 Sublink Interactive. All rights reserved.
//

#import "SubImapCloseCommand.h"
#import "SubImapConnectionData.h"

@implementation SubImapCloseCommand

+ (id)command {
  return [[self alloc] init];
}

- (NSString *)name {
  return @"CLOSE";
}

- (BOOL)canExecuteInState:(SubImapClientState)state {
  switch (state) {
    case SubImapClientStateSelected:
      return YES;
    default:
      return NO;
  }
}

- (SubImapClientState)stateFromState:(SubImapClientState)state {
  return (state == SubImapClientStateSelected)
    ? SubImapClientStateAuthenticated
    : state;
}

- (NSArray *)render {
  return @[
    [SubImapConnectionData dataWithString:self.tag],
    [SubImapConnectionData SP],
    [SubImapConnectionData dataWithString:self.name],
    [SubImapConnectionData CRLF],
  ];
}

- (BOOL)handleTaggedResponse:(SubImapResponse *)response {
  if (!response.status) {
    [self setErrorCode:1 message:@"Unable to close mailbox."];
  }

  return YES;
}

@end