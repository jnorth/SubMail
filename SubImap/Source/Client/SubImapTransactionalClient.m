//
//  SubImapTransactionalClient.m
//  SubMail
//
//  Created by Sublink Interactive on 2013-02-07.
//  Copyright (c) 2013 Sublink Interactive. All rights reserved.
//

#import "SubImapTransactionalClient.h"

@implementation SubImapTransactionalClient {
  NSMutableArray *_transactionQueue;
  SubImapTransaction *_activeTransaction;
}

- (id)init {
  self = [super self];

  if (self) {
    _transactionQueue = [NSMutableArray array];
  }

  return self;
}

#pragma mark -

- (void)enqueueTransaction:(SubImapTransaction *)transaction {
  if (!transaction) {
    return;
  }

  [transaction addBlock:^id(id result) {
    _activeTransaction = nil;
    [self processTransactionQueue];
    return nil;
  }];

  [transaction addErrorBlock:^(NSError *error) {
    _activeTransaction = nil;
    [self processTransactionQueue];
  }];

  [_transactionQueue addObject:transaction];
  [self processTransactionQueue];
}

- (void)dequeueAllCommands {
  [_transactionQueue removeAllObjects];
  _activeTransaction = nil;
  [super dequeueAllCommands];
}

#pragma mark -

- (void)processTransactionQueue {
  if (_activeTransaction || !_transactionQueue.count) {
    return;
  }

  // Get next transaction
  SubImapTransaction *transaction = _transactionQueue[0];
  [_transactionQueue removeObjectAtIndex:0];

  // Execute transaction
  _activeTransaction = transaction;
  [transaction runWithClient:self];
}

@end