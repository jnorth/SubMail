// SubImapTokenizer.m
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

#import "SubImapTokenizer.h"

@implementation SubImapTokenizer {
  NSData *_data;
  NSUInteger _position;
}

+ (id)tokenizer {
  return [[self alloc] init];
}

+ (id)tokenizerForData:(NSData *)data {
  return [[self alloc] initWithData:data];
}

- (id)initWithData:(NSData *)data {
  self = [super init];

  if (self) {
    [self setData:data];
  }

  return self;
}

#pragma mark -

- (void)setData:(NSData *)data {
  _data = data;
  _position = 0;
}

- (SubImapToken *)peekTokenOfType:(SubImapTokenType)type error:(NSError **)error {
  NSUInteger pos = _position;
  SubImapToken *token = [self nextTokenOfType:type error:error];
  _position = pos;

  if (error && *error) {
    return nil;
  } else {
    return token;
  }
}

- (SubImapToken *)pullTokenOfType:(SubImapTokenType)type error:(NSError **)error {
  NSUInteger pos = _position;
  SubImapToken *token = [self nextTokenOfType:type error:error];

  if (error && *error) {
    _position = pos;
    return nil;
  } else {
    return token;
  }
}

- (BOOL)peekTokenIsType:(SubImapTokenType)type {
  return [self peekTokenOfType:type error:nil] != nil;
}

- (BOOL)pullTokenIsType:(SubImapTokenType)type {
  return [self pullTokenOfType:type error:nil] != nil;
}

#pragma mark -
#pragma mark Main Tokenizer

- (SubImapToken *)nextTokenOfType:(SubImapTokenType)type error:(NSError **)error {
  // Check if we are at the end
  if ([self isAtEnd] && type != SubImapTokenTypeEOF) {
    if (error) {
      *error = [self error:SubImapTokenizerErrorUnexpectedToken message:[NSString stringWithFormat:@"Unexpected EOF token at position %lu.", _position]];
    }

    return nil;
  }

  SubImapToken *token;

  switch (type) {
    case SubImapTokenTypeEOF:{
      if ([self isAtEnd]) return [SubImapToken token:SubImapTokenTypeEOF value:nil position:_position];
      break;
    }

    case SubImapTokenTypeCRLF:{
      if ((token = [self crlfToken])) return token;
      break;
    }

    case SubImapTokenTypeNil:{
      if ((token = [self nilToken])) return token;
      break;
    }

    case SubImapTokenTypeSpace:
    case SubImapTokenTypeBracketOpen:
    case SubImapTokenTypeBracketClose:
    case SubImapTokenTypeParenOpen:
    case SubImapTokenTypeParenClose:{
      if ((token = [self symbolTokenWithType:type])) return token;
      break;
    }

    case SubImapTokenTypeNumber:{
      if ((token = [self numberToken])) return token;
      break;
    }

    case SubImapTokenTypeAtom:{
      if ((token = [self atomToken])) return token;
      break;
    }

    case SubImapTokenTypeText:{
      if ((token = [self textToken])) return token;
      break;
    }

    case SubImapTokenTypeTextParam:{
      if ((token = [self textParamToken])) return token;
      break;
    }

    case SubImapTokenTypeFlag:{
      if ((token = [self flagToken])) return token;
      break;
    }

    case SubImapTokenTypeTag:{
      if ((token = [self tagToken])) return token;
      break;
    }

    case SubImapTokenTypeMessageAttribute:{
      if ((token = [self messageAttributeToken])) return token;
      break;
    }

    case SubImapTokenTypeString:{
      if ((token = [self stringToken])) return token;
      break;
    }

    case SubImapTokenTypeQuotedString:{
      if ((token = [self quotedStringToken])) return token;
      break;
    }

    case SubImapTokenTypeLiteral:{
      if ((token = [self literalToken])) return token;
      break;
    }

    default:{
      break;
    }
  }

  // Set error
  if (error) {
    *error = [self error:SubImapTokenizerErrorUnexpectedToken
                 message:[NSString stringWithFormat:@"Unable to find expected '%@' token. %@",
                          [SubImapToken stringFromType:type],
                          [self errorString]]];
  }
  
  return nil;
}

#pragma mark Tokenizer Helpers

/*
 * Returns YES if the tokenizer position is at the end of our data.
 *
 * It is not safe to use the peek/pull character methods if we are
 * at the end.
 */
- (BOOL)isAtEnd {
  return _position >= [_data length];
}

- (BOOL)hasSpace:(NSUInteger)size {
  return _position + size < [_data length];
}

- (char)peekCharacter {
  if ([self isAtEnd]) {
    return 0;
  }

  char *data = (char *)[_data bytes];
  char character = data[_position];
  return character;
}

- (char)pullCharacter {
  if ([self isAtEnd]) {
    return 0;
  }

  char *data = (char *)[_data bytes];
  char character = data[_position];
  _position++;
  return character;
}

- (NSData *)scan:(BOOL(^)(char))block {
  NSUInteger pos = _position;

  while (![self isAtEnd]) {
    char character = [self peekCharacter];

    if (!block(character)) {
      break;
    }

    _position++;
  }

  if (pos != _position) {
    return [_data subdataWithRange:NSMakeRange(pos, _position - pos)];
  } else {
    return nil;
  }
}

- (SubImapToken *)scanForType:(SubImapTokenType)type test:(BOOL(^)(char))block {
  NSUInteger pos = _position;

  while (![self isAtEnd]) {
    char character = [self peekCharacter];

    if (!block(character)) {
      break;
    }

    _position++;
  }

  if (pos != _position) {
    NSData *data = [_data subdataWithRange:NSMakeRange(pos, _position - pos)];
    NSString *value = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    return [SubImapToken token:type value:value position:pos];
  } else {
    _position = pos;
    return nil;
  }
}

- (NSString *)pullString:(NSString *)string {
  // Check bounds
  if ([_data length] < _position + [string length]) {
    return NO;
  }

  // Pull string from data
  NSData *data = [_data subdataWithRange:NSMakeRange(_position, [string length])];
  NSString *dataString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];

  // Compare strings
  if ([string compare:dataString options:NSCaseInsensitiveSearch] == NSOrderedSame) {
    _position += [string length];
    return string;
  } else {
    return nil;
  }
}

#pragma mark Tokenizers

- (SubImapToken *)crlfToken {
  NSUInteger pos = _position;
  return [self pullString:@"\r\n"]
    ? [SubImapToken token:SubImapTokenTypeCRLF value:nil position:pos]
    : nil;
}

- (SubImapToken *)nilToken {
  NSUInteger pos = _position;
  return [self pullString:@"NIL"]
    ? [SubImapToken token:SubImapTokenTypeNil value:nil position:pos]
    : nil;
}

- (SubImapToken *)symbolTokenWithType:(SubImapTokenType)type {
  char character = [self peekCharacter];
  SubImapToken *token;

  if (character == ' ' && type == SubImapTokenTypeSpace) {
    token = [SubImapToken token:SubImapTokenTypeSpace value:nil position:_position];
  } else if (character == '[' && type == SubImapTokenTypeBracketOpen) {
    token = [SubImapToken token:SubImapTokenTypeBracketOpen value:nil position:_position];
  } else if (character == ']' && type == SubImapTokenTypeBracketClose) {
    token = [SubImapToken token:SubImapTokenTypeBracketClose value:nil position:_position];
  } else if (character == '(' && type == SubImapTokenTypeParenOpen) {
    token = [SubImapToken token:SubImapTokenTypeParenOpen value:nil position:_position];
  } else if (character == ')' && type == SubImapTokenTypeParenClose) {
    token = [SubImapToken token:SubImapTokenTypeParenClose value:nil position:_position];
  }

  if (token) {
    _position++;
  }

  return token;
}

- (SubImapToken *)numberToken {
  return [self scanForType:SubImapTokenTypeNumber test:^BOOL(char character) {
    return [self isDigit:character];
  }];
}

- (SubImapToken *)atomToken {
  return [self scanForType:SubImapTokenTypeAtom test:^BOOL(char character) {
    return [self isAtomCharacter:character];
  }];
}

- (SubImapToken *)textToken {
  return [self scanForType:SubImapTokenTypeText test:^BOOL(char character){
    return [self isTextCharacter:character];
  }];
}

- (SubImapToken *)textParamToken {
  return [self scanForType:SubImapTokenTypeTextParam test:^BOOL(char character){
    return [self isTextParameterCharacter:character];
  }];
}

- (SubImapToken *)flagToken {
  NSInteger pos = _position;
  NSData *value;

  // Check bounds
  if (![self hasSpace:2]) {
    return nil;
  }

  char prefix = [self peekCharacter];

  if (prefix == '\\') {
    _position++;

    // \*
    char star = [self peekCharacter];

    if (star == '*') {
      _position++;
      value = [_data subdataWithRange:NSMakeRange(pos, _position - pos)];
    }

    // \atom
    else {
      [self scan:^BOOL(char character) {
        return [self isAtomCharacter:character];
      }];
      value = [_data subdataWithRange:NSMakeRange(pos, _position - pos)];
    }
  }

  // Flag Keyword
  else {
    value = [self scan:^BOOL(char character) {
      return [self isAtomCharacter:character];
    }];
  }

  if (value) {
    NSString *s = [[NSString alloc] initWithData:value encoding:NSASCIIStringEncoding];
    return [SubImapToken token:SubImapTokenTypeFlag value:s position:pos];
  } else {
    _position = pos;
    return nil;
  }
}

- (SubImapToken *)tagToken {
  char character = [self peekCharacter];

  if (character == '*') {
    _position++;
    return [SubImapToken token:SubImapTokenTypeTag value:@"*" position:_position];
  }

  if (character == '+') {
    _position++;
    return [SubImapToken token:SubImapTokenTypeTag value:@"+" position:_position];
  }

  return [self scanForType:SubImapTokenTypeTag test:^BOOL(char character){
    return [self isTagCharacter:character];
  }];
}

- (SubImapToken *)messageAttributeToken {
  return [self scanForType:SubImapTokenTypeMessageAttribute test:^BOOL(char character) {
    return [self isMessageAttributeCharacter:character];
  }];
}

- (SubImapToken *)stringToken {
  return [self scanForType:SubImapTokenTypeString test:^BOOL(char character) {
    return [self isAStringCharacter:character];
  }];
}

- (SubImapToken *)quotedStringToken {
  NSUInteger pos = _position;
  char character = [self peekCharacter];
  NSMutableData *data = [NSMutableData data];
  BOOL inEscapeChar = NO;

  if (character != '"') {
    return nil;
  }

  while (![self isAtEnd]) {
    _position++;
    character = [self peekCharacter];

    if (inEscapeChar) {
      if (character == '"' || character == '\\') {
        inEscapeChar = NO;
      } else {
        _position = pos;
        return nil;
      }
    } else {
      if (character == '"') {
        _position++;
        break;
      }

      if (character == '\\') {
        inEscapeChar = YES;
        continue;
      }
    }

    [data appendBytes:&character length:1];
  }

  if (character != '"') {
    _position = pos;
    return nil;
  }

  NSString *value = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
  return [SubImapToken token:SubImapTokenTypeQuotedString value:value position:pos];
}

- (SubImapToken *)literalToken {
  NSInteger pos = _position;

  // {
  if ([self pullCharacter] != '{') {
    _position = pos;
    return nil;
  }

  // Scan for bytes number
  NSData *byteCount = [self scan:^BOOL(char testCharacter) {
    return [self isDigit:testCharacter];
  }];

  if (!byteCount) {
    _position = pos;
    return nil;
  }

  NSInteger bytes = [[[NSString alloc] initWithData:byteCount encoding:NSASCIIStringEncoding] integerValue];

  if (bytes < 0) {
    _position = pos;
    return nil;
  }

  // }
  if ([self pullCharacter] != '}') {
    _position = pos;
    return nil;
  }

  // CRLF
  if (![self pullString:@"\r\n"]) {
    _position = pos;
    return nil;
  }

  // Ensure we have enough bytes to read
  if ([_data length] + _position < bytes) {
    _position = pos;
    return nil;
  }

  // Read literal bytes
  NSData *literal = [_data subdataWithRange:NSMakeRange(_position, bytes)];
  _position += bytes;

  // Read bytes into string
  NSString *value = [[NSString alloc] initWithData:literal encoding:NSUTF8StringEncoding];

  return [SubImapToken token:SubImapTokenTypeLiteral value:value position:pos];
}


#pragma mark Character Tests

- (BOOL)isDigit:(char)character {
  return (character >= '0' && character <= '9');
}

// tag             = 1*<any ASTRING-CHAR except "+">
- (BOOL)isTagCharacter:(char)character {
  if (character == '+') {
    return NO;
  }

  return [self isAStringCharacter:character];
}

// ATOM-CHAR       = <any CHAR except atom-specials>
// atom-specials   = "(" / ")" / "{" / SP / CTL / list-wildcards / quoted-specials / resp-specials
// list-wildcards  = "%" / "*"
// quoted-specials = DQUOTE / "\"
// resp-specials   = "]"
- (BOOL)isAtomCharacter:(char)character {
  if ([self isControlCharacter:character]) {
    return NO;
  }

  if (![self isASCIICharacter:character]) {
    return NO;
  }

  return (character != '(' &&
          character != ')' &&
          character != '{' &&
          character != ' ' &&
          character != '%' &&
          character != '*' &&
          character != '"' &&
          character != '\\' &&
          character != ']');
}

// Message Attribute characters
// a-z A-Z 0-9 . -
// "ENVELOPE"
// "INTERNALDATE"
// "RFC822" [".HEADER" / ".TEXT"]
// "RFC822.SIZE"
// "BODY" ["STRUCTURE"]
// "BODY"
// "UID"
// "FLAGS"
// "X-GM-MSGID"
- (BOOL)isMessageAttributeCharacter:(char)character {
  return (
    (character == '.') ||
    (character == '-') ||
    // 0-9
    (character >= 48 && character <= 57) ||
    // A-Z
    (character >= 65 && character <= 90) ||
    // a-z
    (character >= 97 && character <= 122)
  );
}

// <any TEXT-CHAR except "]">
- (BOOL)isTextParameterCharacter:(char)character {
  if (character == ']') {
    return NO;
  }

  return [self isTextCharacter:character];
}

// TEXT-CHAR       = <any CHAR except CR and LF>
- (BOOL)isTextCharacter:(char)character {
  if (character == '\r' || character == '\n') {
    return NO;
  }

  return [self isASCIICharacter:character];
}

// ASTRING-CHAR    = ATOM-CHAR / resp-specials
// resp-specials   = "]"
- (BOOL)isAStringCharacter:(char)character {
  if (character == ']') {
    return YES;
  }

  return [self isAtomCharacter:character];
}

// CHAR            = <any US-ASCII character (octets 0 - 127)>
- (BOOL)isASCIICharacter:(char)character {
  return (character >= 0 && character <= 127);
}

// CTL             = <any US-ASCII control character (octets 0 - 31) and DEL (127)>
- (BOOL)isControlCharacter:(char)character {
  return (character == 127 || (character >= 0 && character <= 31));
}

#pragma mark Error Helpers

- (NSString *)errorString {
  NSInteger pos = _position;
  NSInteger seekLength = 100;
  NSInteger rangeStart = MAX(0, pos - seekLength);
  NSInteger rangeLength = MIN([_data length] - rangeStart, rangeStart + (seekLength * 2));

  NSData *data = [_data subdataWithRange:NSMakeRange(rangeStart, rangeLength)];
  NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  NSString *prefix = [string substringToIndex:pos - rangeStart];
  NSString *suffix = [string substringFromIndex:pos - rangeStart];

  return [NSString stringWithFormat:@"[%ld...]%@[^]%@[...%ld]", rangeStart, prefix, suffix, rangeStart + rangeLength];
}

- (NSError *)error:(SubImapTokenizerError)code message:(NSString *)message {
  return [NSError errorWithDomain:NSStringFromClass([self class]) code:code userInfo:@{ NSLocalizedDescriptionKey: message }];
}

- (NSString *)description {
  return [self errorString];
}

@end