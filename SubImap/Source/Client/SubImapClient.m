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
  // Parser
  SubImapParser *_parser;

  // Connection
  SubImapConnection *_connection;
  BOOL _connectionHasSpace;

  // Command queue
  NSMutableArray *_commandQueue;
  SubImapCommand *_activeCommand;
  NSUInteger _commandNumber;

  // Response queue
  NSMutableArray *_responseQueue;

  // State
  NSString *_greeting;
  NSString *_currentMailbox;
  NSMutableSet *_capabilities;
}

+ (id)clientWithConnection:(SubImapConnection *)connection {
  return [[self alloc] initWithConnection:connection];
}

- (id)initWithConnection:(SubImapConnection *)connection {
  self = [self init];

  if (self) {
    _parser = [SubImapParser parser];

    _connection = connection;
    _connection.delegate = self;
    _connectionHasSpace = NO;

    _commandQueue = [NSMutableArray array];
    _activeCommand = nil;
    _commandNumber = 0;

    _responseQueue = [NSMutableArray array];

    _greeting = nil;
    _currentMailbox = nil;
    _capabilities = [NSMutableSet set];

    self.state = SubImapClientStateDisconnected;
  }

  return self;
}

- (SubImapConnection *)connection {
  return _connection;
}

- (void)sendCommand:(SubImapCommand *)command {
  [self enqueueCommand:command];
  [self processCommandQueue];
}

- (BOOL)hasCapability:(NSString *)capability {
  return [_capabilities containsObject:capability];
}

#pragma mark -

#pragma mark Commands & Responses

- (void)enqueueCommand:(SubImapCommand *)command {
  // Generate tag
  NSString *tag = [self generateTag];
  command.tag = tag;

  // Add command to queue
  [_commandQueue addObject:command];
}

- (void)processCommandQueue {
  if (_activeCommand || !_connectionHasSpace || !_commandQueue.count) {
    return;
  }

  // Get queued command
  SubImapCommand *command = nil;

  for (SubImapCommand *possibleCommand in _commandQueue) {
    if ([self validateCommand:possibleCommand]) {
      command = possibleCommand;
      break;
    }
  }

  if (!command) {
    return;
  }

  [_commandQueue removeObject:command];

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

  // Listen for SELECT result
  if ([[command name] isEqualToString:@"SELECT"]) {
    [self hijackCommand:command resultBlock:^(SubImapCommand *command){
      if (!command.error) {
        _currentMailbox = command.result[@"mailbox"];
        self.state = SubImapClientStateSelected;

        // Delegate: DidSelectMailbox
        if (self.delegate && [self.delegate respondsToSelector:@selector(client:didSelectMailbox:)]) {
          [self.delegate performSelector:@selector(client:didSelectMailbox:) withObject:self withObject:_currentMailbox];
        }
      }
    }];
  }

  // Listen for LOGIN result
  if ([[command name] isEqualToString:@"LOGIN"]) {
    [self hijackCommand:command resultBlock:^(SubImapCommand *command){
      if (!command.error) {
        self.state = SubImapClientStateAuthenticated;
      }
    }];
  }
}

- (BOOL)validateCommand:(SubImapCommand *)command {
  if (![command canExecuteInState:self.state]) {
    return NO;
  }

  // LOGIN command can not be executed if the LOGINDISABLED
  // capability is advertised
  if ([[command name] isEqualToString:@"LOGIN"] && [_capabilities containsObject:@"LOGINDISABLED"]) {
    return NO;
  }

  return YES;
}

- (void)processResponseQueue {
  // Save handled responses so we can remove them
  NSMutableArray *responsesToRemove = [NSMutableArray array];

  // Try to process the queued responses
  for (SubImapResponse *response in _responseQueue) {
    if ([self processResponse:response]) {
      [responsesToRemove addObject:response];
    }
  }

  // Remove handled responses
  [_responseQueue removeObjectsInArray:responsesToRemove];
}

- (BOOL)processResponse:(SubImapResponse *)response {
  // Some responses are never sent to commands. Instead
  // we just handle them here

  // - Throw out all continuation responses
  if ([response isType:SubImapResponseTypeContinue]) {
    // Clean up IDLE commands
    if ([_activeCommand.name isEqualToString:@"IDLE"]) {
      _activeCommand = nil;
    }
    return YES;
  }

  // - Greeting response
  if (!_greeting && [response isUntagged] && [response isType:SubImapResponseTypeOk]) {
    _greeting = response.data[@"message"];
    return YES;
  }

  // Other responses change the client state, but we
  // still want to forward them to commands.

  // - Capability
  if ([response isType:SubImapResponseTypeCapability]) {
    [self addCapabilities:response.data];
  } else if ([response isType:SubImapResponseTypeOk] && response.data[@"capabilities"]) {
    [self addCapabilities:response.data[@"capabilities"]];
  }

  // Now we can try to forward the response to the active command

  if ([_activeCommand handleResponse:response]) {
    // If the active command is complete, try to queue up the next command
    if ([response isResult]) {
      SubImapCommand *nextCommand = _activeCommand.nextCommand;
      BOOL canSendNextCommand = nextCommand && _activeCommand.error == nil;
      _activeCommand = nil;

      if (canSendNextCommand) {
        [self enqueueCommand:nextCommand];
      }

      [self processCommandQueue];
    }

    return YES;
  }

  // Lastly, we can throw out certain responses that
  // were not handled by the active command

  // - Capability
//  if ([response isType:IMAPResponseTypeCapability]) {
//    return YES;
//  }

  return YES;
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

  // Enqueue response
  [_responseQueue addObject:response];

  // Process queue
//  if ([response isResult]) {
    [self processResponseQueue];
//  }
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
  _state = state;

  // Delegate: DidChangeState
  if (self.delegate && [self.delegate respondsToSelector:@selector(client:didChangeState:)]) {
    [self.delegate client:self didChangeState:_state];
  }

  // If a command wasn't able to be executed before
  // it might be able to now
  [self processCommandQueue];
}

- (void)addCapabilities:(NSArray *)capabilities {
  for (NSString *capability in capabilities) {
    [_capabilities addObject:[capability uppercaseString]];
  }
}

- (void)hijackCommand:(SubImapCommand *)command resultBlock:(SubImapResultBlock)block {
  SubImapResultBlock previousBlock = command.resultBlock;

  SubImapResultBlock hijackBlock = ^(SubImapCommand *command) {
    if (previousBlock) {
      previousBlock(command);
    }

    block(command);
  };

  command.resultBlock = hijackBlock;
}

#pragma mark Dealloc

- (void)dealloc {
  _connection.delegate = nil;
}

@end