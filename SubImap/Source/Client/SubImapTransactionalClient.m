// SubImapTransactionClient.m
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