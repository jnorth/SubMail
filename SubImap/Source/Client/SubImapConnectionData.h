// SubImapConnectionData.h
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

@interface SubImapConnectionData : NSObject

@property NSData *data;
@property BOOL isLiteral;

+ (id)data:(NSData *)data;
+ (id)literalData:(NSData *)data;
+ (id)dataWithString:(NSString *)string;
+ (id)dataWithQuotedString:(NSString *)string;
+ (id)literalDataWithString:(NSString *)string encoding:(NSStringEncoding)encoding;
+ (id)dataWithInteger:(NSInteger)integer;
+ (id)CRLF;
+ (id)SP;

/*
 * Tries to reduce the number of stream writes by concatinating
 * adjacent non-literal objects.
 *
 * The dataList is expected to contain only ConnectionData
 * objects. Result is undefined otherwise.
 */
+ (NSArray *)compressDataList:(NSArray *)dataList;

@end