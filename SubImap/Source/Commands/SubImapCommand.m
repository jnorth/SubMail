// SubImapCommand.m
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

#import "SubImapCommand.h"

@implementation SubImapCommand {
  NSMutableArray *_completionBlocks;
}

- (void)addCompletionBlock:(SubImapCompletionBlock)block {
  if (!_completionBlocks) {
    _completionBlocks = [NSMutableArray array];
  }

  [_completionBlocks addObject:block];
}

- (NSString *)name {
  return nil;
}

- (BOOL)canExecuteInState:(SubImapClientState)state {
  return NO;
}

- (NSArray *)render {
  return nil;
}

- (BOOL)handleResponse:(SubImapResponse *)response {
  // Tagged response
  if ([response isResult]) {
    BOOL handled = [self handleTaggedResponse:response];
    if (handled) [self complete];
    return handled;
  }

  // Untagged response
  else {
    return [self handleUntaggedResponse:response];
  }
}

- (BOOL)handleUntaggedResponse:(SubImapResponse *)response {
  return NO;
}

- (BOOL)handleTaggedResponse:(SubImapResponse *)response {
  return YES;
}

- (SubImapClientState)stateFromState:(SubImapClientState)state {
  return state;
}

- (void)setErrorCode:(NSInteger)code message:(NSString *)message {
  NSError *error = [NSError errorWithDomain:@"SubImap.Command" code:code userInfo:@{
    NSLocalizedDescriptionKey:message ?: @"",
  }];

  self.error = error;
}

- (void)complete {
  for (SubImapCompletionBlock block in _completionBlocks) {
    block(self);
  }
}

@end