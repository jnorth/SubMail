// SubImapConnectionData.m
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

#import "SubImapConnectionData.h"

@implementation SubImapConnectionData

+ (id)data:(NSData *)data {
  return [[self alloc] initWithData:data literal:NO];
}

+ (id)literalData:(NSData  *)data {
  return [[self alloc] initWithData:data literal:YES];
}

+ (id)dataWithString:(NSString *)string {
  return [[self alloc] initWithData:[string dataUsingEncoding:NSASCIIStringEncoding] literal:NO];
}

+ (id)dataWithQuotedString:(NSString *)string {
  string = [string stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
  string = [NSString stringWithFormat:@"\"%@\"", string];
  return [[self alloc] initWithData:[string dataUsingEncoding:NSASCIIStringEncoding] literal:NO];
}

+ (id)literalDataWithString:(NSString *)string encoding:(NSStringEncoding)encoding {
  return [[self alloc] initWithData:[string dataUsingEncoding:encoding] literal:YES];
}

+ (id)dataWithInteger:(NSInteger)integer {
  return [self dataWithString:[NSString stringWithFormat:@"%ld", integer]];
}

+ (id)CRLF {
  return [[self alloc] initWithData:[NSData dataWithBytes:"\x0D\x0A" length:2] literal:NO];
}

+ (id)SP {
  return [[self alloc] initWithData:[NSData dataWithBytes:" " length:1] literal:NO];
}

+ (NSArray *)compressDataList:(NSArray *)dataList {
  NSMutableArray *list = [NSMutableArray array];
  NSMutableData *buffer;

  for (SubImapConnectionData *data in dataList) {
    // Concat two non-literal data objects if they are side-by-side
    if (!data.isLiteral && list.lastObject && ![list.lastObject isLiteral]) {
      buffer = [[list.lastObject data] mutableCopy];
      [list removeLastObject];
      [buffer appendData:data.data];
      data.data = buffer;
    }

    [list addObject:data];
  }

  return list;
}

- (id)initWithData:(NSData *)data literal:(BOOL)literal {
  self = [super init];

  if (self) {
    _data = data;
    _isLiteral = literal;
  }

  return self;
}

- (NSString *)description {
  return [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
}

@end