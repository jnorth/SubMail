// SubImapConnection.m
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

#import "SubImapConnection.h"

#import "SubImapParser.h"

@implementation SubImapConnection {
  NSString *_host;
  SubImapParser *_parser;

  BOOL _didOpen;

  // Streams
  NSInputStream *_readStream;
  NSOutputStream *_writeStream;
  BOOL _writeStreamHasSpace;

  // Buffers
  NSMutableData *_readBuffer;
  NSMutableData *_responseBuffer;
  NSUInteger _literalBytesToRead;

  // Data queue
  NSMutableArray *_dataQueue;
  NSData *_activeLiteralData;
  BOOL _canWriteLiteralData;
}

+ (id)connectionWithHost:(NSString *)host {
  return [[self alloc] initWithHost:host];
}

- (id)initWithHost:(NSString *)host {
  self = [super init];

  if (self) {
    _host = host;
    _parser = [SubImapParser parser];

    self.supportLiteralPlus = NO;
    self.readBufferSize = 1024;
  }

  return self;
}

#pragma mark -

- (void)setup {
  _didOpen = NO;

  _readStream = nil;
  _writeStream = nil;
  _writeStreamHasSpace = NO;

  _readBuffer = [NSMutableData data];
  _responseBuffer = [NSMutableData data];
  _literalBytesToRead = 0;

  _dataQueue = [NSMutableArray array];
  _activeLiteralData = nil;
  _canWriteLiteralData = NO;
}

#pragma mark Connection

- (BOOL)open {
  [self setup];

  BOOL success = NO;

  // Create sockets
  CFReadStreamRef cfInputStream = NULL;
  CFWriteStreamRef cfOutputStream = NULL;

  int port = 993;
  CFStringRef cfHost = (CFStringRef)CFBridgingRetain(_host);
  CFStreamCreatePairWithSocketToHost(NULL, cfHost, port, &cfInputStream, &cfOutputStream);
  CFRelease(cfHost);

  // Configure sockets
  if (cfInputStream && cfOutputStream) {
    CFReadStreamSetProperty(cfInputStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
    CFWriteStreamSetProperty(cfOutputStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);

    // Negotiate SSL
    if (port == 993) {
      CFReadStreamSetProperty(cfInputStream, kCFStreamPropertySocketSecurityLevel, kCFStreamSocketSecurityLevelNegotiatedSSL);
      CFWriteStreamSetProperty(cfOutputStream, kCFStreamPropertySocketSecurityLevel, kCFStreamSocketSecurityLevelNegotiatedSSL);

      NSDictionary *settings = @{
        // (NSString *)kCFStreamSSLValidatesCertificateChain: @NO,
        // (NSString *)kCFStreamSSLAllowsAnyRoot: @YES, // Deprecated
        // (NSString *)kCFStreamSSLAllowsExpiredCertificates: @YES,
        // (NSString *)kCFStreamSSLPeerName: nil,
      };

      CFReadStreamSetProperty(cfInputStream, kCFStreamPropertySSLSettings, (CFTypeRef)settings);
      CFWriteStreamSetProperty(cfOutputStream, kCFStreamPropertySSLSettings, (CFTypeRef)settings);
    }

    // Bridge sockets
    _readStream = (NSInputStream *)CFBridgingRelease(cfInputStream);
    _writeStream = (NSOutputStream *)CFBridgingRelease(cfOutputStream);

    [_readStream setDelegate:self];
    [_readStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [_readStream open];

    [_writeStream setDelegate:self];
    [_writeStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [_writeStream open];

    success = YES;
  }

  // Error creating sockets
  else {
    [self close];
  }

  return success;
}

- (BOOL)close {
  _readStream.delegate = nil;
  _writeStream.delegate = nil;

  [_readStream close];
  [_writeStream close];

  // Delegate: DidClose
  if (self.delegate && [self.delegate respondsToSelector:@selector(connectionDidClose:)]) {
    [self.delegate performSelector:@selector(connectionDidClose:) withObject:self];
  }

  return
    [_readStream streamStatus] == NSStreamStatusClosed &&
    [_writeStream streamStatus] == NSStreamStatusClosed;
}

- (BOOL)isOpen {
  // Not initialized yet
  if (!_readStream || !_writeStream) {
    return NO;
  }

  // Check stream status
  NSStreamStatus inputStatus = [_readStream streamStatus];
  NSStreamStatus outputStatus = [_writeStream streamStatus];

  return
  (inputStatus == NSStreamStatusOpen || inputStatus == NSStreamStatusReading) &&
  (outputStatus == NSStreamStatusOpen || outputStatus == NSStreamStatusWriting);
}

#pragma mark Data

- (void)write:(SubImapConnectionData *)data {
  [_dataQueue addObject:data];
  [self streamWrite];
}

#pragma mark -

#pragma mark NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event {
//  NSDictionary *logLookup = @{
//    @(NSStreamEventEndEncountered):     @"END",
//    @(NSStreamEventErrorOccurred):      [NSString stringWithFormat:@"ERROR:%@", [stream streamError]],
//    @(NSStreamEventHasBytesAvailable):  @"HASBYTES",
//    @(NSStreamEventHasSpaceAvailable):  @"HASSPACE",
//    @(NSStreamEventNone):               @"NONE",
//    @(NSStreamEventOpenCompleted):      @"OPEN",
//  };
//
//  NSLog(@"STREAM:%@:%@", stream == _readStream ? @"IN" : @"OUT", logLookup[@(event)]);

  switch (event) {
    case NSStreamEventOpenCompleted:{
      break;
    }

    case NSStreamEventHasBytesAvailable: {
      [self streamRead];
      break;
    }

    case NSStreamEventHasSpaceAvailable:{
      _writeStreamHasSpace = YES;
      [self streamWrite];
      break;
    }

    case NSStreamEventEndEncountered:{
      [self close];
      break;
    }

    case NSStreamEventErrorOccurred:{
      // Delegate: DidEncounterStreamError
      if (self.delegate && [self.delegate respondsToSelector:@selector(connection:didEncounterStreamError:)]) {
        [self.delegate performSelector:@selector(connection:didEncounterStreamError:) withObject:self withObject:[stream streamError]];
      }
      break;
    }

    case NSStreamEventNone:
    default:
      break;
  }

  // Delegate: DidOpen
  if (!_didOpen && [self isOpen]) {
    _didOpen = YES;

    if (self.delegate && [self.delegate respondsToSelector:@selector(connectionDidOpen:)]) {
      [self.delegate performSelector:@selector(connectionDidOpen:) withObject:self];
    }
  }
}

- (void)streamWrite {
  // The write stream is not ready
  if (!_writeStreamHasSpace) {
    return;
  }

  // The write stream is ready, and we have data to write
  else if (_activeLiteralData || _dataQueue.count) {
    NSData *delegateData = nil;

    // Write pending literal data
    if (_activeLiteralData) {
      if (_canWriteLiteralData) {
        [_writeStream write:[_activeLiteralData bytes] maxLength:[_activeLiteralData length]];
        delegateData = _activeLiteralData;

        // Clear active literal
        _canWriteLiteralData = NO;
        _activeLiteralData = nil;

        // We wrote data to the stream
        _writeStreamHasSpace = NO;
      }
    }

    // Write data from queue
    else {
      SubImapConnectionData *data = [_dataQueue objectAtIndex:0];
      [_dataQueue removeObjectAtIndex:0];

      // Literal data
      if ([data isLiteral]) {
        // Create literal marker
        NSString *literalMarkerFormat = self.supportLiteralPlus ? @"{%lu+}\r\n" : @"{%lu}\r\n";
        NSString *literalMarker = [NSString stringWithFormat:literalMarkerFormat, [data.data length]];
        NSData *literalMarkerData = [literalMarker dataUsingEncoding:NSASCIIStringEncoding];
        delegateData = literalMarkerData;

        // Write literal marker to stream
        [_writeStream write:[literalMarkerData bytes] maxLength:[literalMarkerData length]];

        // With LITERAL+ support, we can just write our data without
        // waiting for a conitinuation response
        if (self.supportLiteralPlus) {
          [_writeStream write:[data.data bytes] maxLength:[data.data length]];
          NSMutableData *mdata = [NSMutableData dataWithData:delegateData];
          [mdata appendData:data.data];
          delegateData = mdata;
        }

        // Without LITERAL+ support, we have to queue our literal data
        // Our handleResponseData method will then check for continuation
        // responses and set the _canWriteLiteral flag
        else {
          _activeLiteralData = data.data;
        }
      }

      // Normal data
      else {
        // Write to stream
        [_writeStream write:[data.data bytes] maxLength:[data.data length]];
        delegateData = data.data;
      }

      // We wrote data to the stream
      _writeStreamHasSpace = NO;
    }

    // Delegate: DidSendData
    if (delegateData && self.delegate && [self.delegate respondsToSelector:@selector(connection:didSendData:)]) {
      [self.delegate performSelector:@selector(connection:didSendData:) withObject:self withObject:delegateData];
    }
  }

  // The write stream is ready, but we don't have any data to write
  else {
    // Delegate: HasSpace
    if (self.delegate && [self.delegate respondsToSelector:@selector(connectionHasSpace:)]) {
      [self.delegate performSelector:@selector(connectionHasSpace:) withObject:self];
    }
  }
}

- (void)streamRead {
  // Read bytes from stream
  uint8_t buffer[self.readBufferSize];
	NSInteger bytesRead = [_readStream read:buffer maxLength:self.readBufferSize];

  // Read failed, or read 0 bytes
  if (bytesRead <= 0) {
    return;
  }

  // Delegate: DidReceiveData
  if (self.delegate && [self.delegate respondsToSelector:@selector(connection:didReceiveData:)]) {
    NSData *data = [NSData dataWithBytes:buffer length:bytesRead];
    [self.delegate performSelector:@selector(connection:didReceiveData:) withObject:self withObject:data];
  }

  // Add bytes to buffer
  [_readBuffer appendBytes:buffer length:bytesRead];

  // IMAP responses are terminated with CRLF
  NSUInteger termLength = 2;
  NSData *term = [NSData dataWithBytes:"\x0D\x0A" length:termLength];

  // Calculate starting position
  NSUInteger bufferLength = [_readBuffer length];
  NSUInteger scannedPosition = bufferLength - bytesRead;

  while (1) {
    // Nothing left in the buffer
    if (bufferLength <= 0) {
      break;
    }

    // We are expecting literal bytes
    if (_literalBytesToRead > 0) {
      // Calculate how many bytes we can read
      NSInteger availableBytes = MIN(bufferLength, _literalBytesToRead);

      // Pull literal bytes from buffer
      [_responseBuffer appendBytes:[_readBuffer bytes] length:availableBytes];
      [_readBuffer replaceBytesInRange:NSMakeRange(0, availableBytes) withBytes:NULL length:0];

      // Reset scan positions
      _literalBytesToRead -= availableBytes;
      bufferLength -= availableBytes;
      scannedPosition = 0;
    }

    // We are not expecting literal bytes
    if (_literalBytesToRead <= 0) {
      // Not enough data for a full term yet
      if (bufferLength < termLength) {
        break;
      }

      // Since we've already scanned some of the previous
      // buffer, we only need to rescan enough of it to
      // ensure we didn't miss our term
      //  .             .             .             .
      // |B|B|B|B|B| |A|B|B|B|B| |A|A|B|B|B| |A|A|A|B|B|
      //  ^ ^ ^       ^ ^ ^       ^ ^ ^         ^ ^ ^
      NSUInteger scanPosition = (scannedPosition > termLength - 1)
        ? scannedPosition - termLength + 1
        : 0;

      // Scan for the term
      NSRange eol = [_readBuffer rangeOfData:term options:0 range:NSMakeRange(scanPosition, bufferLength - scanPosition)];

      // If the term is not found, wait for more bytes
      if (eol.location == NSNotFound) {
        break;
      }

      // Pull response from buffer
      NSUInteger responseLength = eol.location + eol.length;
      [_responseBuffer appendBytes:[_readBuffer bytes] length:responseLength];
      [_readBuffer replaceBytesInRange:NSMakeRange(0, responseLength) withBytes:NULL length:0];

      // Reset scan positions
      bufferLength -= responseLength;
      scannedPosition = 0;

      // We have to check if there is a literal to follow...
      _literalBytesToRead += [self bytesForLiteralMarkerInResponseBuffer];

      // If there are no more literal bytes to follow, we have a complete response
      if (_literalBytesToRead <= 0) {
        // Handle response
        [self handleResponseData:_responseBuffer];

        // Reset buffer
        _responseBuffer = [NSMutableData data];
      }
    }

    // continue;
  }
}

/*
 * Checks the responseBuffer for a literal marker. It is
 * assumed that the buffer is terminated by a CRLF.
 *
 * Returns: the number of bytes specified in the marker,
 *          or 0 if none found
 */
- (NSUInteger)bytesForLiteralMarkerInResponseBuffer {
  NSUInteger bufferLength = [_responseBuffer length];

  // {1}\r\n
  if (bufferLength < 5) {
    return 0;
  }

  // Literal markers take the form of: {123}\r\n
  // We want to start scanning from the } character, so
  // here we subtract the length of the CRLF term + 1
  NSInteger bracePos = bufferLength - 2 - 1;
  NSInteger idx = bracePos;

  // Since we are scanning backwards, we can exit out right
  // away if we don't see the term and end literal character }
  const char *bytes = [_responseBuffer bytes];
  const char *character = &bytes[idx];

  if (*character != '}') return 0;

  // Start scanning backwards
  while (idx--) {
    character = &bytes[idx];

    // Are we at the end of the literal?
    if (*character == '{') {
      character = &bytes[idx + 1];
      return [[[NSString alloc] initWithBytes:character length:bracePos - 1 encoding:NSASCIIStringEncoding] integerValue];
    }

    // If the character is not a digit, this isn't a literal
    if (*character < '0' || *character > '9') {
      break;
    }
  }
  
  return 0;
}

- (void)handleResponseData:(NSData *)data {
  // Parse response data
  NSError *error;
  SubImapResponse *response = [_parser parseResponseData:data error:&error];

  if (error) {
    // Delegate: DidEncounterParserError
    if (self.delegate && [self.delegate respondsToSelector:@selector(connection:didEncounterParserError:)]) {
      [self.delegate performSelector:@selector(connection:didEncounterParserError:) withObject:self withObject:error];
    }
    return;
  }

  // Delegate: DidReceiveResponse
  if (self.delegate && [self.delegate respondsToSelector:@selector(connection:didReceiveResponse:)]) {
    [self.delegate performSelector:@selector(connection:didReceiveResponse:) withObject:self withObject:response];
  }

  // Literal
  if ([response isContinuation] && _activeLiteralData) {
    _canWriteLiteralData = YES;
    [self streamWrite];
  }
}

#pragma mark Dealloc

- (void)dealloc {
  if ([self isOpen]) {
    [self close];
  }
}

@end