// SubImapTokenizerTests.m
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

#import "SubImapTokenizerTests.h"

#import <SubImap/SubImap.h>

@implementation SubImapTokenizerTests

#pragma mark - Helpers

- (void)tokenizeString:(NSString *)string type:(SubImapTokenType)type {
  NSData *data = [string dataUsingEncoding:NSASCIIStringEncoding];
  SubImapTokenizer *tokenizer = [SubImapTokenizer tokenizerForData:data];

  STAssertTrue([tokenizer peekTokenIsType:type], @"Could not find expected token (%@). %@", [SubImapToken stringFromType:type], tokenizer);
}

#pragma mark - Tests

- (void)testBasics {
  // SubImapTokenTypeCRLF
  [self tokenizeString:@"\r\n" type:SubImapTokenTypeCRLF];
  // SubImapTokenTypeNil
  [self tokenizeString:@"NIL" type:SubImapTokenTypeNil];
  // SubImapTokenTypeSpace
  [self tokenizeString:@" " type:SubImapTokenTypeSpace];
  // SubImapTokenTypeBracketOpen
  [self tokenizeString:@"[" type:SubImapTokenTypeBracketOpen];
  // SubImapTokenTypeBracketClose
  [self tokenizeString:@"]" type:SubImapTokenTypeBracketClose];
  // SubImapTokenTypeParenOpen
  [self tokenizeString:@"(" type:SubImapTokenTypeParenOpen];
  // SubImapTokenTypeParenClose
  [self tokenizeString:@")" type:SubImapTokenTypeParenClose];
  // SubImapTokenTypeNumber
  [self tokenizeString:@"1" type:SubImapTokenTypeNumber];
  // SubImapTokenTypeAtom
  [self tokenizeString:@"abc" type:SubImapTokenTypeAtom];
  // SubImapTokenTypeText
  [self tokenizeString:@"abc" type:SubImapTokenTypeText];
  // SubImapTokenTypeTextParam
  [self tokenizeString:@"abc" type:SubImapTokenTypeTextParam];
  // SubImapTokenTypeFlag
  [self tokenizeString:@"\\abc" type:SubImapTokenTypeFlag];
  // SubImapTokenTypeTag
  [self tokenizeString:@"tag" type:SubImapTokenTypeTag];
  // SubImapTokenTypeMessageAttribute
  [self tokenizeString:@"msg" type:SubImapTokenTypeMessageAttribute];
  // SubImapTokenTypeString
  [self tokenizeString:@"abc" type:SubImapTokenTypeString];
  // SubImapTokenTypeQuotedString
  [self tokenizeString:@"\"abc\"" type:SubImapTokenTypeQuotedString];
  // SubImapTokenTypeLiteral
  [self tokenizeString:@"{3}\r\nabc" type:SubImapTokenTypeLiteral];
}

@end