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

  // Command queue
  NSMutableArray *_commandQueue;
  SubImapCommand *_activeCommand;
  NSUInteger _commandNumber;
}

+ (instancetype)clientWithConnection:(SubImapConnection *)connection {
  return [[self alloc] initWithConnection:connection];
}

- (id)initWithConnection:(SubImapConnection *)connection {
  self = [self init];

  if (self) {
    _connection = connection;
    _connection.delegate = self;
    _connectionHasSpace = NO;

    _commandQueue = [NSMutableArray array];
    _activeCommand = nil;
    _commandNumber = 0;

    self.state = SubImapClientStateDisconnected;
  }

  return self;
}

#pragma mark -

- (SubImapConnection *)connection {
  return _connection;
}

- (void)enqueueCommand:(SubImapCommand *)command {
  // Generate tag
  NSString *tag = [self generateTag];
  command.tag = tag;

  // Add command to queue, and process
  [_commandQueue addObject:command];
  [self processCommandQueue];
}

- (void)dequeueAllCommands {
  _activeCommand = nil;
  [_commandQueue removeAllObjects];
  _commandNumber = 0;
}

#pragma mark -
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

  for (SubImapConnectionData *data in [SubImapConnectionData compressDataList:[command render]]) {
    [_connection write:data];
  }

  // Delegate: DidSendCommand
  if (self.delegate && [self.delegate respondsToSelector:@selector(client:didSendCommand:)]) {
    [self.delegate performSelector:@selector(client:didSendCommand:) withObject:self withObject:command];
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
    }

    return;
  }

  // Forward the response to the active command
  if ([_activeCommand handleResponse:response]) {
    if ([response isResult]) {
      // Update state
      self.state = [_activeCommand stateFromState:self.state];

      // Process next command
      _activeCommand = nil;
      [self processCommandQueue];
    }
  }

  return;
}

#pragma mark IMAPConnectionDelegate

- (void)connectionDidOpen:(SubImapConnection *)connection {
  self.state = SubImapClientStateUnauthenticated;

  // Delegate: DidConnect
  if (self.delegate && [self.delegate respondsToSelector:@selector(clientDidConnect:)]) {
    [self.delegate performSelector:@selector(clientDidConnect:) withObject:self];
  }
}

- (void)connectionDidClose:(SubImapConnection *)connection {
  self.state = SubImapClientStateDisconnected;
  _commandNumber = 0;
  _activeCommand = nil;

  // Delegate: DidDisconnect
  if (self.delegate && [self.delegate respondsToSelector:@selector(clientDidDisconnect:)]) {
    [self.delegate performSelector:@selector(clientDidDisconnect:) withObject:self];
  }
}

- (void)connectionHasSpace:(SubImapConnection *)connection {
  _connectionHasSpace = YES;
  [self processCommandQueue];
}

- (void)connection:(SubImapConnection *)connection didSendData:(NSData *)data {
  // Delegate: DidSendData
  if (self.delegate && [self.delegate respondsToSelector:@selector(client:didSendData:)]) {
    [self.delegate performSelector:@selector(client:didSendData:) withObject:self withObject:data];
  }
}

- (void)connection:(SubImapConnection *)connection didReceiveData:(NSData *)data {
  // Delegate: DidReceiveData
  if (self.delegate && [self.delegate respondsToSelector:@selector(client:didReceiveData:)]) {
    [self.delegate performSelector:@selector(client:didReceiveData:) withObject:self withObject:data];
  }
}

- (void)connection:(SubImapConnection *)connection didReceiveResponse:(SubImapResponse *)response {
  // Delegate: DidReceiveResponse
  if (self.delegate && [self.delegate respondsToSelector:@selector(client:didReceiveResponse:)]) {
    [self.delegate performSelector:@selector(client:didReceiveResponse:) withObject:self withObject:response];
  }

  // Process response
  [self processResponse:response];
}

- (void)connection:(SubImapConnection *)connection didEncounterParserError:(NSError *)error {
  // Delegate: DidEncounterParserError
  if (self.delegate && [self.delegate respondsToSelector:@selector(client:didEncounterParserError:)]) {
    [self.delegate performSelector:@selector(client:didEncounterParserError:) withObject:self withObject:error];
  }
}

- (void)connection:(SubImapConnection *)connection didEncounterStreamError:(NSError *)error {
  // Delegate: DidEncounterStreamError
  if (self.delegate && [self.delegate respondsToSelector:@selector(client:didEncounterStreamError:)]) {
    [self.delegate performSelector:@selector(client:didEncounterStreamError:) withObject:self withObject:error];
  }
}

#pragma mark Helpers

- (NSString *)generateTag {
  return [NSString stringWithFormat:@"#%lu", _commandNumber++];
}

- (void)setState:(SubImapClientState)state {
  if (state == _state) {
    return;
  }

  _state = state;

  // Delegate: DidChangeState
  if (self.delegate && [self.delegate respondsToSelector:@selector(client:didChangeState:)]) {
    [self.delegate client:self didChangeState:_state];
  }

  // If a command wasn't able to be executed before
  // it might be able to now
  [self processCommandQueue];
}

#pragma mark -

- (void)dealloc {
  _connection.delegate = nil;
}

@end