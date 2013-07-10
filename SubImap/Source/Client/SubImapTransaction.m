// SubImapTransaction.m
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