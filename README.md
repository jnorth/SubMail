# SubMail

A fast and small IMAP client library written in pure Objective-C.

Supports `RFC3501`, `RFC3502`, and `RFC2088`, and is easy to extend with
`SubImapCommand` subclasses.

## Quickstart

    // Create an IMAP connection and client
    SubImapConnection *connection = [SubImapConnection connectionWithHost:@"mail.google.com"];
    SubImapTransactionalClient *client = [SubImapTransactionalClient clientWithConnection:connection];

    // Create a new transaction
    // Any command returned in a block will be queued up, and its results will
    // be passed to the next block
    SubImapTransaction *transaction = [SubImapTransaction transaction];

    // Login to the server
    [transaction addBlock:^id(id result) {
      return [SubImapLoginCommand commandWithLogin:@"username" password:@"password"];
    }];

    // Select the inbox
    [transaction addBlock:^id(id result) {
      return [SubImapSelectCommand commandWithInbox];
    }];

    // Fetch the first 5 messages
    [transaction addBlock:^id(id result) {
      return [SubImapFetchCommand commandWithSequenceIDs:@[1, 2, 3, 4, 5]];
    }];

    [transaction addBlock:^id(id result) {
      NSArray *messages = result;
      NSLog(@"The first 5 messages in the inbox are: %@", messages);
    }];

    // Close the connection
    [transaction addBlock:^id(id result) {
      return [SubImapCloseCommand command];
    }];

    // Run the transaction
    [client enqueueTransaction:transaction];

## Usage

SubMail is broken down into 4 main concepts: connection, client, command, and
transaction. The library uses delegates and blocks to make asynchronous
communication with an IMAP server easy.

### `SubImapConnection`

A connection handles the low-level communication with an IMAP server.

Communication is done by writing `SubImapConnectionData` objects to the
connection and handling responses with a delegate that implements the
`SubImapConnectionDelegate` protocol.

    // Create a connection object. We just need the mail server hostname
    SubImapConnection *connection = [SubImapConnection connectionWithHost:@"mail.google.com"];
    [connection addDelegate:self];
    [connection open];

    // Send capability command when connection opens
    - (void)connectionDidOpen:(SubImapConnection *)connection {
      [connection write:[SubImapConnectionData dataWithString:@"a1 CAPABILITY\r\n"]];
    }

    // Print out the capabilities and close the connection
    - (void)client:(SubImapClient *)client didReceiveResponse:(SubImapResponse *)response {
      if ([response isType:SubImapResponseTypeCapability]) {
        NSLog(@"Capabilities: %@", response.capabilities);
        [connection write:[SubImapConnectionData dataWithString:@"a2 CLOSE\r\n"]];
      }
    }

    // Handle close event
    - (void)connectionDidClose:(SubImapConnection *)connection {
      NSLog(@"connection closed");
    }

### `SubImapClient`

Since writing data directly to an IMAP connection and handling responses
asynchronously can be tedious, the `SubImapClient` can be used to abstract away
the command-response process with `SubImapCommand` objects.

    // Create an IMAP connection and client
    SubImapConnection *connection = [SubImapConnection connectionWithHost:@"mail.google.com"];
    SubImapClient *client = [SubImapClient clientWithConnection:connection];

    // Send capabilities command, and handle its response
    SubImapCapabilitiesCommand *command = [SubImapCapabilitiesCommand command];

    [command addCompletionBlock:^(SubImapCommand *command) {
      if (command.error) {
        NSLog(@"Error: %@", command.error);
      } else {
        NSLog(@"Capabilities: %@", command.result);
      }
    }];

    [client enqueueCommand:command];

### `SubImapTransactionalClient`

Most actions when communicating with an IMAP server require chaining together
several commands. The `SubImapTransactionalClient` allows you to do this with
`SubImapTransaction` objects.

A transaction is similar to a Promise. It wraps asynchronous IMAP commands into
a chain of blocks. If a block returns a `SubImapCommand`, it is run and the next
block is executed with its result. If an error is encountered during any of the
commands, the chain is stopped and any error handler blocks are called.

    // Create an IMAP connection and client
    SubImapConnection *connection = [SubImapConnection connectionWithHost:@"mail.google.com"];
    SubImapTransactionalClient *client = [SubImapTransactionalClient clientWithConnection:connection];
    SubImapTransaction *transaction = [SubImapTransaction transaction];

    // Handle any errors
    [transaction addErrorBlock:^(NSError *error) {
      NSLog(@"Error: %@", error);
    }];

    // List server capabilities
    [transaction addBlock:^id(id result) {
      return [SubImapCapabilityCommand command];
    }];

    // Any return value will be passed to the next block
    [transaction addBlock:^id(id result) {
      NSArray *capabilities = result;
      NSLog(@"This server supports: %@", capabilities);
      return capabilities.count;
    }];

    [transaction addBlock:^id(id result) {
      NSLog(@"This server supports %@ features", result);
    }];

    [client enqueueTransaction:transaction];

## Commands

Although several IMAP commands are available in the library, it is easy to add
new ones by extending `SubImapCommand`.

    @implementation IdleCommand

    + (id)command {
      return [[self alloc] init];
    }

    - (NSString *)name {
      return @"IDLE";
    }

    - (BOOL)canExecuteInState:(SubImapClientState)state {
      return state == SubImapClientStateSelected;
    }

    - (NSArray *)render {
      return @[
        [SubImapConnectionData dataWithString:self.tag],
        [SubImapConnectionData SP],
        [SubImapConnectionData dataWithString:self.name],
        [SubImapConnectionData CRLF],
      ];
    }

    @end
