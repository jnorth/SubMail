// SubImapToken.m
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

#import "SubImapToken.h"

@implementation SubImapToken

+ (id)errorToken:(NSString *)message {
  return [[self alloc] initWithToken:SubImapTokenTypeError value:message position:0];
}

+ (id)token:(SubImapTokenType)type value:(NSString *)value position:(NSUInteger)position {
  return [[self alloc] initWithToken:type value:value position:position];
}

- (id)initWithToken:(SubImapTokenType)type value:(NSString *)value position:(NSUInteger)position {
  self = [super init];

  if (self) {
    self.type = type;
    self.value = value;
    self.position = position;
  }

  return self;
}

- (BOOL)isType:(SubImapTokenType)type {
  return self.type == type;
}

- (BOOL)isError {
  return self.type == SubImapTokenTypeError;
}

- (NSString *)typeName {
  return [[self class] stringFromType:self.type];
}

- (NSString *)description {
  NSString *value = self.value
    ? [NSString stringWithFormat:@":%@", self.value]
    : @"";
  return [NSString stringWithFormat:@"T(%@%@:%lu)", [self typeName], value, _position];
}

+ (NSString *)stringFromType:(SubImapTokenType)type {
  switch (type) {
    case SubImapTokenTypeError:            return @"ERR";
    case SubImapTokenTypeEOF:              return @"EOF";
    case SubImapTokenTypeCRLF:             return @"CRLF";
    case SubImapTokenTypeNil:              return @"NIL";
    case SubImapTokenTypeSpace:            return @"SP";
    case SubImapTokenTypeBracketOpen:      return @"BracketOpen";
    case SubImapTokenTypeBracketClose:     return @"BracketClose";
    case SubImapTokenTypeParenOpen:        return @"ParenOpen";
    case SubImapTokenTypeParenClose:       return @"ParenClose";
    case SubImapTokenTypeNumber:           return @"Number";
    case SubImapTokenTypeAtom:             return @"Atom";
    case SubImapTokenTypeText:             return @"Text";
    case SubImapTokenTypeTextParam:        return @"TextParam";
    case SubImapTokenTypeFlag:             return @"Flag";
    case SubImapTokenTypeTag:              return @"Tag";
    case SubImapTokenTypeMessageAttribute: return @"MsgAttr";
    case SubImapTokenTypeString:           return @"String";
    case SubImapTokenTypeQuotedString:     return @"QuotedString";
    case SubImapTokenTypeLiteral:          return @"Literal";
  }
}

@end