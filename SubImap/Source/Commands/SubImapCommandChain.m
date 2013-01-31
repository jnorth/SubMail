// SubImapCommandChain.m
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

#import "SubImapCommandChain.h"

@implementation SubImapCommandChain {
	SubImapClient *_client;
	NSMutableArray *_blocks;
}

+ (id)chainWithClient:(SubImapClient *)client {
	return [[self alloc] initWithImapClient:client];
}

- (id)initWithImapClient:(SubImapClient *)client {
	self = [self init];

	if (self) {
		_client = client;
		_blocks = [NSMutableArray array];
	}

	return self;
}

#pragma mark -

- (void)run {
  [self runNextBlockWithResult:nil];
}

- (void)addBlock:(SubImapCommandChainBlock)block {
	[_blocks addObject:block];
}

#pragma mark -

- (void)runNextBlockWithResult:(id)result {
  if (_blocks.count <= 0) {
    return;
  }

  // Get next block
  SubImapCommandChainBlock block = _blocks[0];
  [_blocks removeObjectAtIndex:0];

  // Call block
  id obj = block(result);

  // Received command
  if ([obj isKindOfClass:[SubImapCommand class]]) {
    __weak SubImapCommand *command = obj;

    SubImapResultBlock tBlock = command.resultBlock;

    command.resultBlock = ^(SubImapCommand *c) {
      if (tBlock) {
        tBlock(command);
      }

      // Command has error
      if (c.error) {
        if (self.errorBlock) {
          self.errorBlock(c.error);
        }
      }

      // Command has result
      else {
        [self runNextBlockWithResult:c.result];
      }
    };

    [_client sendCommand:command];
  }

  // Received error
  else if ([obj isKindOfClass:[NSError class]]) {
    if (self.errorBlock) {
      self.errorBlock(obj);
    }
  }

  // Received unknown object
  else {
    [self runNextBlockWithResult:obj];
  }
}

@end