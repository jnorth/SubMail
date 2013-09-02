//
//  SubImapLoginCommandTests.m
//  SubMail
//
//  Created by Sublink Interactive on 2013-09-02.
//  Copyright (c) 2013 Sublink Interactive. All rights reserved.
//

#import "SubImapLoginCommandTests.h"
#import <SubImap/SubImap.h>

@implementation SubImapLoginCommandTests

- (void)testRenderedLoginString {
  NSString *test = @"abcdefghijklmnopqrstuvwxyz1234567890";
  NSData *testData = [test dataUsingEncoding:NSUTF8StringEncoding];
  SubImapLoginCommand *command = [SubImapLoginCommand commandWithLogin:test password:@"password"];
  NSArray *output = [command render];

  STAssertTrue(output.count == 8, @"Login command rendered incorrect connection data.");

  SubImapConnectionData *data = [output objectAtIndex:4];
  STAssertTrue([data.data isEqualToData:testData], @"Login command rendered inccorect connection data.");
  STAssertTrue(!data.isLiteral, @"Login command rendered inccorect connection data.");
}

- (void)testRenderedLoginLiteral {
  NSString *test = @"abcdefghijklmnopqrstuvwxyz1234567890~!@#$%^&*()_+-=[]{}\\|\'\";:,./<>?";
  NSData *testData = [test dataUsingEncoding:NSUTF8StringEncoding];
  SubImapLoginCommand *command = [SubImapLoginCommand commandWithLogin:test password:@"password"];
  NSArray *output = [command render];

  STAssertTrue(output.count == 8, @"Login command rendered incorrect connection data.");

  SubImapConnectionData *data = [output objectAtIndex:4];
  STAssertTrue([data.data isEqualToData:testData], @"Login command rendered inccorect connection data.");
  STAssertTrue(data.isLiteral, @"Login command rendered inccorect connection data.");
}

@end
