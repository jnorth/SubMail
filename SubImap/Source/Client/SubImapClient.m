// SubImapClient.m
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

#import "SubImapClient.h"

#import "SubImapParser.h"
#import "SubImapResponse.h"

@implementation SubImapClient {
  // Connection
  SubImapConnection *_connection;
  BOOL _connectionHasSpace;

  // Delegates
  NSMutableArray *_delegates;

  // Command queue
  NSMutableArray *_commandQueue;
  SubImapCommand *_activeCommand;
  NSUInteger _commandNumber;

  // Parser
  SubImapParser *_parser;
}

+ (instancetype)clientWithConnection:(SubImapConnection *)connection {
  return [[self alloc] initWithConnection:connection];
}

- (id)initWithConnection:(SubImapConnection *)connection {
  self = [self init];

  if (self) {
    _connection = connection;
    _connectionHasSpace = NO;
    [_connection addDelegate:self];

    _delegates = [NSMutableArray array];

    _commandQueue = [NSMutableArray array];
    _activeCommand = nil;
    _commandNumber = 0;

    _parser = [SubImapParser parser];

    self.state = SubImapClientStateDisconnected;
  }

  return self;
}

- (void)dealloc {
  [_connection removeDelegate:self];
}

#pragma mark -

- (SubImapConnection *)connection {
  return _connection;
}

- (void)enqueueCommand:(SubImapCommand *)command {
  // Generate tag
  NSString *tag = [self generateTag];
  command.tag = tag;

  // Add command to queue
  [_commandQueue addObject:command];

  // Delegate: didEnqueueCommand
  for (id<SubImapClientDelegate>delegate in _delegates) {
    if ([delegate respondsToSelector:@selector(client:didEnqueueCommand:)]) {
      [delegate client:self didEnqueueCommand:command];
    }
  }

  // Process queue
  [self processCommandQueue];
}

- (void)dequeueAllCommands {
  // Delegate: DidDequeueCommand
  for (SubImapCommand *command in _commandQueue) {
    for (id<SubImapClientDelegate>delegate in _delegates) {
      if ([delegate respondsToSelector:@selector(client:didDequeueCommand:)]) {
        [delegate client:self didDequeueCommand:command];
      }
    }
  }

  _activeCommand = nil;
  [_commandQueue removeAllObjects];
  _commandNumber = 0;
}

#pragma mark Delegates

- (void)addDelegate:(id<SubImapClientDelegate>)delegate {
  [_delegates addObject:delegate];
}

- (void)removeDelegate:(id<SubImapClientDelegate>)delegate {
  [_delegates removeObject:delegate];
}

#pragma mark -

- (NSString *)generateTag {
  return [NSString stringWithFormat:@"#%lu", _commandNumber++];
}

- (void)setState:(SubImapClientState)state {
  if (state == _state) {
    return;
  }

  _state = state;

  // Delegate: DidChangeState
  for (id<SubImapClientDelegate>delegate in _delegates) {
    if ([delegate respondsToSelector:@selector(client:didChangeState:)]) {
      [delegate client:self didChangeState:_state];
    }
  }

  // If a command wasn't able to be executed before
  // it might be able to now
  [self processCommandQueue];
}

#pragma mark Commands & Responses

- (void)processCommandQueue {
  if (_activeCommand || !_connectionHasSpace || !_commandQueue.count) {
    return;
  }

  // Get queued command
  SubImapCommand *command = [self nextCommand];
  if (!command) return;

  // Command had an error setting up
  if (command.error) {
    [command complete];
    return;
  }

  // Send command
  _activeCommand = command;
  _connectionHasSpace = NO;

  // Delegate: WillSendCommand
  for (id<SubImapClientDelegate>delegate in _delegates) {
    if ([delegate respondsToSelector:@selector(client:willSendCommand:)]) {
      [delegate client:self willSendCommand:command];
    }
  }

  for (SubImapConnectionData *data in [SubImapConnectionData compressDataList:[command render]]) {
    [_connection write:data];
  }

  // Delegate: DidSendCommand
  for (id<SubImapClientDelegate>delegate in _delegates) {
    if ([delegate respondsToSelector:@selector(client:didSendCommand:)]) {
      [delegate client:self didSendCommand:command];
    }
  }
}

- (SubImapCommand *)nextCommand {
  SubImapCommand *command;

  for (SubImapCommand *possibleCommand in _commandQueue) {
    if ([possibleCommand canExecuteInState:self.state]) {
      command = possibleCommand;
      break;
    }
  }

  if (command) {
    [_commandQueue removeObject:command];
    return command;
  }

  return nil;
}

- (void)processResponse:(SubImapResponse *)response {
  // Throw out all continuation responses
  if ([response isType:SubImapResponseTypeContinue]) {
    // Clean up IDLE commands
    if ([_activeCommand.name isEqualToString:@"IDLE"]) {
      [_activeCommand complete];
      _activeCommand = nil;
      [self processCommandQueue];
    }

    return;
  }

  // Forward the response to the active command
  if ([_activeCommand handleResponse:response]) {
    if ([response isResult]) {
      // Update state
      if (response.status) {
        self.state = [_activeCommand stateFromState:self.state];
      }

      // Process next command
      _activeCommand = nil;
      [self processCommandQueue];
    }
  }
}

#pragma mark SubImapConnectionDelegate

- (void)connectionDidOpen:(SubImapConnection *)connection {
  self.state = SubImapClientStateUnauthenticated;
}

- (void)connectionDidClose:(SubImapConnection *)connection {
  self.state = SubImapClientStateDisconnected;
  _commandNumber = 0;
  _activeCommand = nil;
}

- (void)connectionHasSpace:(SubImapConnection *)connection {
  _connectionHasSpace = YES;
  [self processCommandQueue];
}

- (void)connection:(SubImapConnection *)connection didReceiveResponseData:(NSData *)data {
  // Delegate: WillParseResponseData
  for (id<SubImapClientDelegate>delegate in _delegates) {
    if ([delegate respondsToSelector:@selector(client:parser:willParseResponseData:)]) {
      [delegate client:self parser:_parser willParseResponseData:data];
    }
  }

  NSError *error;
  SubImapResponse *response = [_parser parseResponseData:data error:&error];

  if (error) {
    // Delegate: DidEncounterParserError
    for (id<SubImapClientDelegate>delegate in _delegates) {
      if ([delegate respondsToSelector:@selector(client:didEncounterParserError:)]) {
        [delegate client:self didEncounterParserError:error];
      }
    }
  }

  else {
    // Delegate: DidReceiveResponse
    for (id<SubImapClientDelegate>delegate in _delegates) {
      if ([delegate respondsToSelector:@selector(client:didReceiveResponse:)]) {
        [delegate client:self didReceiveResponse:response];
      }
    }

    // Process response
    [self processResponse:response];
  }
}

@end