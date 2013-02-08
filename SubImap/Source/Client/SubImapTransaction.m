//
//  SubImapTransaction.m
//  SubMail
//
//  Created by Sublink Interactive on 2013-02-07.
//  Copyright (c) 2013 Sublink Interactive. All rights reserved.
//

#import "SubImapTransaction.h"

#import "SubImapClient.h"

@implementation SubImapTransaction {
  NSMutableArray *_blocks;
  NSMutableArray *_errorBlocks;
}

+ (instancetype)transaction {
  return [[self alloc] init];
}

- (id)init {
  self = [super init];

  if (self) {
    _blocks = [NSMutableArray array];
    _errorBlocks = [NSMutableArray array];
  }

  return self;
}

#pragma mark -

- (void)addCommand:(SubImapCommand *)command {
  [self addBlock:^id(id result) {
    return command;
  }];
}

- (void)addBlock:(SubImapTransactionBlock)block {
  [_blocks addObject:block];
}

- (void)addErrorBlock:(SubImapTransactionErrorBlock)block {
  [_errorBlocks addObject:block];
}

- (void)runWithClient:(SubImapClient *)client {
  [self runNextBlockWithClient:client result:nil];
}

#pragma mark -

- (void)runNextBlockWithClient:(SubImapClient *)client result:(id)result {
  if (!_blocks.count) {
    return;
  }

  // Get next block
  SubImapTransactionBlock block = _blocks[0];
  [_blocks removeObjectAtIndex:0];

  // Call block
  id obj = block(result);

  // Received command
  if ([obj isKindOfClass:[SubImapCommand class]]) {
    [obj addCompletionBlock:^(SubImapCommand *command) {
      if (command.error) {
        [self callErrorBlockWithError:command.error];
      } else {
        [self runNextBlockWithClient:client result:command.result];
      }
    }];

    [client enqueueCommand:obj];
  }

  // Received error
  else if ([obj isKindOfClass:[NSError class]]) {
    [self callErrorBlockWithError:obj];
  }

  // Received unknown object
  else {
    [self runNextBlockWithClient:client result:obj];
  }
}

- (void)callErrorBlockWithError:(NSError *)error {
  for (SubImapTransactionErrorBlock block in _errorBlocks) {
    block(error);
  }
}

@end