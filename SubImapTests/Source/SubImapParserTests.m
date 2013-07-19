// SubImapParserTests.m
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

#import "SubImapParserTests.h"
#import "SubImapParser.h"

@implementation SubImapParserTests

- (void)testOKResponseWithEmptyMessage {
  NSString *testString = @"* OK [HIGHESTMODSEQ 58744]";
  NSData *testData = [testString dataUsingEncoding:NSASCIIStringEncoding];

  SubImapTokenizer *tokenizer = [SubImapTokenizer tokenizer];
  SubImapParser *parser = [SubImapParser parserWithTokenizer:tokenizer];

  NSError *error;
  SubImapResponse *response = [parser parseResponseData:testData error:&error];

  STAssertNil(error, @"Unable to parse response. %@", error);
  STAssertNotNil(response, @"Unable to parse response.");

  id code = response.data;
  STAssertNotNil(code, @"Incorrect code data. %@", code);
  STAssertTrue([code isKindOfClass:NSDictionary.class], @"Incorrect code data class '%@'.", NSStringFromClass([code class]));
  STAssertTrue([code[@"code"] isEqualToString:@"HIGHESTMODSEQ"], @"Incorrect code name '%@'.", code[@"code"]);
  STAssertTrue([code[@"highestmodseq"] isEqualToString:@"58744"], @"Incorrect code parameter '%@'.", code[@"highestmodseq"]);
}

- (void)testOKResponseWithoutText {
  NSString *testString = @"#1635 OK\r\n";
  NSData *testData = [testString dataUsingEncoding:NSASCIIStringEncoding];

  SubImapTokenizer *tokenizer = [SubImapTokenizer tokenizer];
  SubImapParser *parser = [SubImapParser parserWithTokenizer:tokenizer];

  NSError *error;
  SubImapResponse *response = [parser parseResponseData:testData error:&error];

  STAssertNil(error, @"Unable to parse response. %@", error);
  STAssertNotNil(response, @"Unable to parse response.");

  id data = response.data;
  STAssertNotNil(data, @"Incorrect data. %@", data);
  STAssertTrue([data isKindOfClass:NSDictionary.class], @"Incorrect data class '%@'.", NSStringFromClass([data class]));
  STAssertNil(data[@"message"], @"Incorrect data '%@'.", data[@"message"]);
}

- (void)testBadResponseWithMessage {
  NSString *testString = @"#1635 BAD Could not parse command\r\n";
  NSData *testData = [testString dataUsingEncoding:NSASCIIStringEncoding];

  SubImapTokenizer *tokenizer = [SubImapTokenizer tokenizer];
  SubImapParser *parser = [SubImapParser parserWithTokenizer:tokenizer];

  NSError *error;
  SubImapResponse *response = [parser parseResponseData:testData error:&error];

  STAssertNil(error, @"Unable to parse response. %@", error);
  STAssertNotNil(response, @"Unable to parse response.");

  id data = response.data;
  STAssertNotNil(data, @"Incorrect data. %@", data);
  STAssertTrue([data isKindOfClass:NSDictionary.class], @"Incorrect data class '%@'.", NSStringFromClass([data class]));
  STAssertTrue([data[@"message"] isEqualToString:@"Could not parse command"], @"Incorrect message '%@'.", data[@"message"]);
}

@end