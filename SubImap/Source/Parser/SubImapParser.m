// SubImapParser.m
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

#import "SubImapParser.h"

NSString *const SubImapParserErrorDomain = @"Parser.SubMail.sublink.ca";

@implementation SubImapParser

+ (id)parser {
  return [[self alloc] init];
}

+ (id)parserWithTokenizer:(SubImapTokenizer *)tokenizer {
  return [[self alloc] initWithTokenizer:tokenizer];
}

- (id)init {
  return [self initWithTokenizer:nil];
}

- (id)initWithTokenizer:(SubImapTokenizer *)tokenizer {
  self = [super init];

  if (self) {
    if (!tokenizer) {
      tokenizer = [SubImapTokenizer tokenizer];
    }

    self.tokenizer = tokenizer;
  }

  return self;
}

#pragma mark - Parsers

- (SubImapResponse *)parseResponseData:(NSData *)data error:(NSError **)error {
  self.tokenizer.data = data;

  // Parse based on tag
  SubImapToken *token = [self.tokenizer pullTokenOfType:SubImapTokenTypeTag error:error];
  if (*error) return nil;

  // Sub-parsers
  if ([token.value isEqualToString:@"*"]) {
    return [self untaggedResponse:error];
  } else if ([token.value isEqualToString:@"+"]) {
    return [self continuationResponse:error];
  } else {
    return [self taggedResponseWithTag:token.value error:error];
  }
}

#pragma mark - Sub-parsers

- (SubImapResponse *)continuationResponse:(NSError **)error {
  SubImapToken *token;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // resp-text
  id data = [self parseTextData:error];
  if (*error) return nil;

  // resp-text
  return [SubImapResponse responseWithType:SubImapResponseTypeContinue data:data];
}

- (SubImapResponse *)taggedResponseWithTag:(NSString *)tag error:(NSError **)error {
  SubImapToken *token;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // Command name
  token = [self.tokenizer peekTokenOfType:SubImapTokenTypeAtom error:error];
  if (*error) return nil;

  // Only these responses can be tagged
  if ([@[@"OK", @"NO", @"BAD"] containsObject:token.value]) {
    return [self textResponseWithTag:tag error:error];
  }

  // Unknown command error
  [self error:error code:SubImapParserErrorUnknownCommand format:@"Unknown response command '%@'.", token.value];

  return nil;
}

- (SubImapResponse *)untaggedResponse:(NSError **)error {
  SubImapToken *token;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // Number commands
  if ([self.tokenizer peekTokenIsType:SubImapTokenTypeNumber]) {
    return [self numberResponse:error];
  }

  // Command name
  token = [self.tokenizer peekTokenOfType:SubImapTokenTypeAtom error:error];
  if (*error) return nil;

  // Status response
  if ([@[@"OK", @"NO", @"BAD", @"PREAUTH", @"BYE"] containsObject:token.value]) {
    return [self textResponseWithTag:nil error:error];
  }

  // Capability
  if ([token.value isEqualToString:@"CAPABILITY"]) {
    return [self capabilityResponse:error];
  }

  // List / Lsub
  if ([@[@"LIST", @"LSUB"] containsObject:token.value]) {
    return [self mailboxListResponse:error];
  }

  // Status
  if ([token.value isEqualToString:@"STATUS"]) {
    return [self mailboxStatusResponse:error];
  }

  // Search
  if ([token.value isEqualToString:@"SEARCH"]) {
    return [self searchResponse:error];
  }

  // Flags
  if ([token.value isEqualToString:@"FLAGS"]) {
    return [self flagsResponse:error];
  }

  // Unknown command
  [self error:error code:SubImapParserErrorUnknownCommand format:@"Unknown response command '%@'.", token.value];

  return nil;
}

- (SubImapResponse *)textResponseWithTag:(NSString *)tag error:(NSError **)error {
  SubImapToken *token;

  // Command
  SubImapToken *commandToken = token = [self.tokenizer pullTokenOfType:SubImapTokenTypeAtom error:error];
  if (*error) return nil;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // resp-text
  id data = [self parseTextData:error];
  if (*error) return nil;

  // Status
  BOOL status = [@[@"OK", @"PREAUTH", @"BYE"] containsObject:commandToken.value];

  return [SubImapResponse responseWithStatus:status type:[SubImapResponse typeFromString:commandToken.value] tag:tag data:data];
}

- (SubImapResponse *)capabilityResponse:(NSError **)error {
  id data = [self parseCapabilityData:error];
  if (*error) return nil;

  if (!data) {
    [self error:error code:0 message:@"Unable to parse capability response."];
    return nil;
  }

  return [SubImapResponse responseWithType:SubImapResponseTypeCapability data:data];
}

- (SubImapResponse *)mailboxListResponse:(NSError **)error {
  SubImapToken *token;
  NSMutableDictionary *mailbox = [NSMutableDictionary dictionary];

  // Command name
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeAtom error:error];
  if (*error) return nil;

  NSString *command = token.value;

  // Space
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // Flag list
  if ([self.tokenizer peekTokenIsType:SubImapTokenTypeParenOpen]) {
    id data = [self parseFlagListData:error];
    if (*error) return nil;
    if (!data) {
      [self error:error code:0 message:@"Flag list was not found in mailbox listing."];
      return nil;
    }

    mailbox[@"flags"] = data;
  }

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // Path delimiter
  id delimiter = [self parseNString:error];
  if (*error) return nil;

  if ([delimiter length] > 1) {
    [self error:error code:0 format:@"Mailbox delimiter can only be a single character '%@'.", delimiter];
    return nil;
  }

  mailbox[@"delimiter"] = delimiter;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // Path
  id path = [self parseAString:error];
  if (*error) return nil;
  mailbox[@"path"] = path;

  return [SubImapResponse responseWithType:[SubImapResponse typeFromString:command] data:mailbox];
}

- (SubImapResponse *)mailboxStatusResponse:(NSError **)error {
  SubImapToken *token;
  NSMutableDictionary *data = [NSMutableDictionary dictionary];

  // Command name
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeAtom error:error];
  if (*error) return nil;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // Mailbox name
  id path = [self parseAString:error];
  if (*error) return nil;
  data[@"mailbox"] = path;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // Attr list
  id attrs = [self parseStatusAttributeListData:error];
  if (*error) return nil;
  if (!attrs) {
    [self error:error code:0 message:@"Unable to parse status attribute list."];
    return nil;
  }

  for (NSString *key in attrs) {
    data[key] = attrs[key];
  }

  return [SubImapResponse responseWithType:SubImapResponseTypeStatus data:data];
}

- (SubImapResponse *)searchResponse:(NSError **)error {
  SubImapToken *token;
  NSMutableArray *data = [NSMutableArray array];

  // Command name
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeAtom error:error];
  if (*error) return nil;

  while (1) {
    // SP
    if (![self.tokenizer pullTokenIsType:SubImapTokenTypeSpace]) {
      break;
    }

    // Number
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeNumber error:error];
    if (*error) return nil;

    [data addObject:@([token.value integerValue])];
  }

  return [SubImapResponse responseWithType:SubImapResponseTypeSearch data:data];
}

- (SubImapResponse *)flagsResponse:(NSError **)error {
  SubImapToken *token;

  // Command name
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeAtom error:error];
  if (*error) return nil;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // Flags
  id flags = [self parseFlagListData:error];
  if (*error) return nil;
  if (!flags) {
    [self error:error code:0 message:@"Unable to parse FLAGS response. Empty list."];
    return nil;
  }

  return [SubImapResponse responseWithType:SubImapResponseTypeFlags data:flags];
}

- (SubImapResponse *)numberResponse:(NSError **)error {
  SubImapToken *token;

  // Number
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeNumber error:error];
  if (*error) return nil;

  NSNumber *number = @([token.value integerValue]);

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // Command name
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeAtom error:error];
  if (*error) return nil;

  NSString *command = token.value;

  // Simple
  if ([@[@"EXISTS", @"RECENT", @"EXPUNGE"] containsObject:command]) {
    return [SubImapResponse responseWithType:[SubImapResponse typeFromString:command] data:number];
  }

  // Fetch
  if ([command isEqualToString:@"FETCH"]) {
    // SP
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
    if (*error) return nil;

    // Message
    id message = [self parseMessageAttributeData:error];
    if (*error) return nil;
    return [SubImapResponse responseWithType:SubImapResponseTypeFetch data:message];
  }

  // Unknown command
  [self error:error code:SubImapParserErrorUnknownCommand format:@"Unknown command '%@'", command];
  return nil;
}

#pragma mark - Data parsers

/*
 * Parses a resp-text message.
 *
 * eg: [CODE] Message
 */
- (id)parseTextData:(NSError **)error {
  SubImapToken *token;
  NSMutableDictionary *data = [NSMutableDictionary dictionary];

  // Response code
  NSMutableDictionary *code = [self parseTextCodeData:error];
  if (*error) return nil;

  if (code) {
    data = code;
  }

  // Response text
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeText error:error];
  if (*error) return nil;

  data[@"message"] = token.value;

  return data;
}

/*
 * Parses a resp-text response code.
 *
 * eg: [ALERT]
 *
 * resp-text-code  =
 *   "ALERT" / "PARSE" / "READ-ONLY" / "READ-WRITE" / "TRYCREATE" /
 *   capability-data /
 *   "UIDNEXT" SP nz-number / "UIDVALIDITY" SP nz-number / "UNSEEN" SP nz-number /
 *   "BADCHARSET" [SP "(" astring *(SP astring) ")" ] /
 *   "PERMANENTFLAGS" SP "(" [flag-perm *(SP flag-perm)] ")" /
 *   atom [SP 1*<any TEXT-CHAR except "]">]
 */
- (id)parseTextCodeData:(NSError **)error {
  SubImapToken *token;
  NSMutableDictionary *data = [NSMutableDictionary dictionary];

  // [
  if (![self.tokenizer pullTokenIsType:SubImapTokenTypeBracketOpen]) {
    return nil;
  }

  // Code type
  token = [self.tokenizer peekTokenOfType:SubImapTokenTypeAtom error:error];
  if (*error) return nil;

  NSString *code = token.value;

  // Simple code
  if ([@[@"ALERT", @"PARSE", @"READ-ONLY", @"READ-WRITE", @"TRYCREATE"] containsObject:code]) {
    [self.tokenizer pullTokenOfType:SubImapTokenTypeAtom error:error];
    data[@"code"] = code;
  }

  // Capability
  else if ([code isEqualToString:@"CAPABILITY"]) {
    id capabilities = [self parseCapabilityData:error];
    if (*error) return nil;
    if (capabilities) {
      data[@"code"] = code;
      data[@"capabilities"] = capabilities;
    }
  }

  // Number parameters
  else if ([@[@"UIDNEXT", @"UIDVALIDITY", @"UNSEEN"] containsObject:code]) {
    [self.tokenizer pullTokenOfType:SubImapTokenTypeAtom error:error];

    // SP
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
    if (*error) return nil;

    // Number
    id number = [self parseNonZeroNumber:error];
    if (*error) return nil;
    data[[code lowercaseString]] = number;
  }

  // Permanentflags
  else if ([code isEqualToString:@"PERMANENTFLAGS"]) {
    [self.tokenizer pullTokenOfType:SubImapTokenTypeAtom error:error];
    data[@"code"] = code;

    // SP
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
    if (*error) return nil;

    // Flags (not optional)
    id flags = [self parseFlagListData:error];
    if (*error) return nil;
    if (!flags) {
      [self error:error code:0 message:@"Unable to parse permanent flags list."];
    }

    data[@"flags"] = flags;
  }

  // Badcharset
  else if ([code isEqualToString:@"BADCHARSET"]) {
    [self.tokenizer pullTokenOfType:SubImapTokenTypeAtom error:error];
    data[@"code"] = code;

    // SP
    if ([self.tokenizer pullTokenIsType:SubImapTokenTypeSpace]) {
      // Charsets (optional)
      id charsets = [self parseStringListData:error];
      if (*error) return nil;
      if (charsets) {
        data[@"charsets"] = charsets;
      }
    }
  }

  // Atom with optional parameter
  else {
    [self.tokenizer pullTokenOfType:SubImapTokenTypeAtom error:error];
    data[@"code"] = code;

    // SP
    if ([self.tokenizer pullTokenIsType:SubImapTokenTypeSpace]) {
      // Parameter
      token = [self.tokenizer pullTokenOfType:SubImapTokenTypeTextParam error:error];
      if (*error) return nil;
      if (token) {
        data[[code lowercaseString]] = token.value;
      }
    }
  }

  // ]
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeBracketClose error:error];
  if (*error) return nil;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  return data;
}

/*
 * Parses capabilities.
 *
 * capability-data = "CAPABILITY" *(SP capability) SP "IMAP4rev1" *(SP capability)
 * capability      = ("AUTH=" auth-type) / atom
 * auth-type       = atom
 */
- (id)parseCapabilityData:(NSError **)error {
  SubImapToken *token;
  NSMutableArray *data = [NSMutableArray array];

  // CAPABILITY
  [self.tokenizer pullTokenOfType:SubImapTokenTypeAtom error:error];
  if (*error) return nil;

  while (1) {
    // SP
    if (![self.tokenizer pullTokenIsType:SubImapTokenTypeSpace]) {
      break;
    }

    // Atom
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeAtom error:error];
    if (*error) return nil;

    [data addObject:token.value];
  }

  return data;
}

/*
 * Parses a list of STATUS attributes.
 *
 * status-att-list =  status-att SP number *(SP status-att SP number)
 * status-att      = "MESSAGES" / "RECENT" / "UIDNEXT" / "UIDVALIDITY" / "UNSEEN"
 */
- (id)parseStatusAttributeListData:(NSError **)error {
  SubImapToken *token;
  NSMutableDictionary *data = [NSMutableDictionary dictionary];

  // (
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenOpen error:error];
  if (*error) return nil;

  while (1) {
    // Attribute
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeAtom error:error];
    if (*error) return nil;

    NSString *attribute = token.value;

    if (![@[@"MESSAGES", @"RECENT", @"UIDNEXT", @"UIDVALIDITY", @"UNSEEN"] containsObject:attribute]) {
      [self error:error code:0 format:@"Unknown status attribute '%@'.", attribute];
      return nil;
    }

    // SP
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
    if (*error) return nil;

    // Number
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeNumber error:error];
    if (*error) return nil;

    data[[attribute lowercaseString]] = @([token.value integerValue]);

    // )
    if ([self.tokenizer peekTokenIsType:SubImapTokenTypeParenClose]) {
      break;
    }

    // SP
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
    if (*error) return nil;
  }

  // )
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenClose error:error];
  if (*error) return nil;

  return data;
}

/*
 * Parses a list of flags. May return an empy array.
 *
 * Guaranteed to cause an error if nil is returned.
 *
 * eg: (\Flag1 \Flag2)
 */
- (id)parseFlagListData:(NSError **)error {
  SubImapToken *token;
  NSMutableArray *data = [NSMutableArray array];

  // (
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenOpen error:error];
  if (*error) return nil;

  // )
  if (![self.tokenizer peekTokenIsType:SubImapTokenTypeParenClose]) {
    while (1) {
      // Flag
      token = [self.tokenizer pullTokenOfType:SubImapTokenTypeFlag error:error];
      if (*error) return nil;

      [data addObject:token.value];

      // )
      if ([self.tokenizer peekTokenIsType:SubImapTokenTypeParenClose]) {
        break;
      }

      // SP
      token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
      if (*error) return nil;
    }
  }

  // )
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenClose error:error];
  if (*error) return nil;
  
  return data;
}

/*
 * Parses a list of strings. May return an empty array.
 *
 * Guaranteed to cause an error if nil is returned.
 *
 * eg: (Text "Text" Text)
 */
- (id)parseStringListData:(NSError **)error {
  SubImapToken *token;
  NSMutableArray *data = [NSMutableArray array];

  // (
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenOpen error:error];
  if (*error) return nil;

  // )
  if ([self.tokenizer peekTokenIsType:SubImapTokenTypeParenClose]) {
    return data;;
  }

  while (1) {
    // String
    id string = [self parseAString:error];
    if (*error) return nil;
    [data addObject:string];

    // )
    if ([self.tokenizer peekTokenIsType:SubImapTokenTypeParenClose]) {
      break;
    }

    // SP
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
    if (*error) return nil;
  }

  // )
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenClose error:error];
  if (*error) return nil;
  
  return data;
}

/*
 * Parses message data.
 *
 * Guaranteed to cause an error if nil is returned.
 *
 * msg-att         =
 *   "("
 *     (msg-att-dynamic / msg-att-static)
 *     *(SP (msg-att-dynamic / msg-att-static))
 *   ")"
 *
 * msg-att-dynamic = "FLAGS" SP "(" [flag-fetch *(SP flag-fetch)] ")"
 *
 * msg-att-static  =
 *   "ENVELOPE" SP envelope /
 *   "INTERNALDATE" SP date-time /
 *   "RFC822" [".HEADER" / ".TEXT"] SP nstring /
 *   "RFC822.SIZE" SP number /
 *   "BODY" ["STRUCTURE"] SP body /
 *   "BODY" section ["<" number ">"] SP nstring /
 *   "UID" SP uniqueid
 */
- (id)parseMessageAttributeData:(NSError **)error {
  SubImapToken *token;
  NSMutableDictionary *data = [NSMutableDictionary dictionary];

  // (
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenOpen error:error];
  if (*error) return nil;

  // Attribute names
  NSArray *attributes = @[
    @"FLAGS",
    @"UID",
    @"INTERNALDATE",
    @"RFC822.SIZE",
    @"ENVELOPE",
    @"RFC822",
    @"RFC822.HEADER",
    @"RFC822.TEXT",
//    These are parsed specially
//    @"BODY",
//    @"BODY.PEEK",
//    @"BODYSTRUCTURE",
    @"X-GM-MSGID",
    @"X-GM-LABELS",
  ];

  while (1) {
    // Attribute name
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeMessageAttribute error:error];
    if (*error) return nil;

    NSString *attribute = [token.value uppercaseString];

    // SP
    if ([attributes containsObject:attribute]) {
      token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
      if (*error) return nil;
    }

    // FLAGS
    if ([attribute isEqualToString:@"FLAGS"]) {
      id flags = [self parseFlagListData:error];
      if (*error) return nil;
      data[@"flags"] = flags;
    }

    // UID
    else if ([attribute isEqualToString:@"UID"]) {
      id uid = [self parseNonZeroNumber:error];
      if (*error) return nil;
      data[@"uid"] = uid;
    }

    // INTERNALDATE
    else if ([attribute isEqualToString:@"INTERNALDATE"]) {
      id date = [self parseDateTimeData:error];
      if (*error) return nil;
      data[@"internaldate"] = date;
    }

    // RFC822.SIZE
    else if ([attribute isEqualToString:@"RFC822.SIZE"]) {
      token = [self.tokenizer pullTokenOfType:SubImapTokenTypeNumber error:error];
      if (*error) return nil;
      data[@"rfc.size"] = @([token.value integerValue]);
    }

    // ENVELOPE
    else if ([attribute isEqualToString:@"ENVELOPE"]) {
      id envelope = [self parseMessageEnvelopeData:error];
      if (*error) return nil;
      data[@"envelope"] = envelope;
    }

    // RFC822
    else if ([@[@"RFC822", @"RFC822.HEADER", @"RFC822.TEXT"] containsObject:attribute]) {
      id rfc = [self parseNString:error];
      if (*error) return nil;
      data[[attribute lowercaseString]] = rfc;
    }

    // BODY
    else if ([@[@"BODY", @"BODY.PEEK", @"BODYSTRUCTURE"] containsObject:attribute]) {
      id body = [self parseMessageBodyData:error];
      if (*error) return nil;
      data[@"body"] = body;
    }

    // X-GM-MSGID -- Gimap extension
    // https://developers.google.com/google-apps/gmail/imap_extensions
    else if ([attribute isEqualToString:@"X-GM-MSGID"]) {
      token = [self.tokenizer pullTokenOfType:SubImapTokenTypeNumber error:error];
      if (*error) return nil;
      data[@"x-gm-msgid"] = token.value;
    }

    // X-GM-LABELS -- Gimap extension
    // https://developers.google.com/google-apps/gmail/imap_extensions
    else if ([attribute isEqualToString:@"X-GM-LABELS"]) {
      id labels = [self parseGimapLabelListData:error];
      if (*error) return nil;
      data[@"x-gm-labels"] = labels;
    }

    // )
    if ([self.tokenizer peekTokenIsType:SubImapTokenTypeParenClose]) {
      break;
    }

    // SP
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
    if (*error) return nil;
  }

  // )
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenClose error:error];
  if (*error) return nil;

  return data;
}

/*
 * Parse a non-zero number.
 *
 * Guaranteed to cause an error if nil is returned.
 */
- (id)parseNonZeroNumber:(NSError **)error {
  SubImapToken *token;

  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeNumber error:error];
  if (*error) return nil;

  NSNumber *number = @([token.value integerValue]);

  if ([number intValue] < 1) {
    [self error:error code:0 format:@"Expected non-zero number (%@).", number];
    return nil;
  }

  return number;
}

/*
 * Parse a string or NIL.
 *
 * If NIL is found, an empty string will be returned.
 *
 * Guaranteed to cause an error if nil is returned.
 */
- (id)parseNString:(NSError **)error {
  SubImapToken *token;

  // Try NIL
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeNil error:nil];
  if (token) return @"";

  // Try string
  id string = [self parseString:error];
  if (*error) return nil;
  return string;
}

- (id)parseAString:(NSError **)error {
  SubImapToken *token;

  // Try atom string
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeString error:nil];
  if (token) return token.value;

  // Try string
  id string = [self parseString:error];
  if (*error) return nil;
  return string;
}

/*
 * Parse a string, being either a QuotedString or Literal.
 *
 * Guaranteed to cause an error if nil is returned.
 */
- (id)parseString:(NSError **)error {
  SubImapToken *token;

  // Try literal string
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeLiteral error:nil];
  if (token) return token.value;

  // Try quoted string
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeQuotedString error:nil];
  if (token) return token.value;

  // Error
  [self error:error code:0 format:@"Unable to parse string. Expected either a Literal or QuotedString. %@", self.tokenizer];
  return nil;
}

/*
 * Parse quoted date-time data.
 *
 * Guaranteed to cause an error if nil is returned.
 */
- (id)parseDateTimeData:(NSError **)error {
  SubImapToken *token;

  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeQuotedString error:error];
  if (*error) return nil;

  return [NSDate dateWithNaturalLanguageString:token.value];
}

/*
 * envelope        =
 *   "("
 *     env-date SP
 *     env-subject SP
 *     env-from SP
 *     env-sender SP
 *     env-reply-to SP
 *     env-to SP
 *     env-cc SP
 *     env-bcc SP
 *     env-in-reply-to SP
 *     env-message-id
 *   ")"
 * env-bcc         = "(" 1*address ")" / nil
 * env-cc          = "(" 1*address ")" / nil
 * env-date        = nstring
 * env-from        = "(" 1*address ")" / nil
 * env-in-reply-to = nstring
 * env-message-id  = nstring
 * env-reply-to    = "(" 1*address ")" / nil
 * env-sender      = "(" 1*address ")" / nil
 * env-subject     = nstring
 * env-to          = "(" 1*address ")" / nil
 */
- (id)parseMessageEnvelopeData:(NSError **)error {
  SubImapToken *token;
  id addresses;
  NSMutableDictionary *data = [NSMutableDictionary dictionary];

  // (
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenOpen error:error];
  if (*error) return nil;

  // env-date
  id date = [self parseNString:error];
  if (*error) return nil;
  data[@"date"] = date;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // env-subject
  id subject = [self parseNString:error];
  if (*error) return nil;
  data[@"subject"] = subject;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // env-from
  addresses = [self parseAddressList:error];
  if (*error) return nil;
  data[@"from"] = addresses;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // env-sender
  addresses = [self parseAddressList:error];
  if (*error) return nil;
  data[@"sender"] = addresses;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // env-reply-to
  addresses = [self parseAddressList:error];
  if (*error) return nil;
  data[@"reply-to"] = addresses;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // env-to
  addresses = [self parseAddressList:error];
  if (*error) return nil;
  data[@"to"] = addresses;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // env-cc
  addresses = [self parseAddressList:error];
  if (*error) return nil;
  data[@"cc"] = addresses;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // env-bcc
  addresses = [self parseAddressList:error];
  if (*error) return nil;
  data[@"bcc"] = addresses;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // env-in-reply-to
  id inReplyTo = [self parseNString:error];
  if (*error) return nil;
  data[@"in-reply-to"] = inReplyTo;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // env-message-id
  id mID = [self parseNString:error];
  if (*error) return nil;
  data[@"id"] = mID;

  // )
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenClose error:error];
  if (*error) return nil;

  return data;
}

/*
 * Parses a list of address lists.
 *
 * Address lists may be NIL, in which case this returns
 * an empty array.
 */
- (id)parseAddressList:(NSError **)error {
  SubImapToken *token;
  NSMutableArray *data = [NSMutableArray array];

  // NIL
  if ([self.tokenizer pullTokenIsType:SubImapTokenTypeNil]) {
    return [NSArray array];
  }

  // (
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenOpen error:error];
  if (*error) return nil;

  while (1) {
    // Address
    id address = [self parseAddressData:error];
    if (*error) return nil;

    [data addObject:address];

    // )
    if ([self.tokenizer peekTokenIsType:SubImapTokenTypeParenClose]) {
      break;
    }

    // SP
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
    if (*error) return nil;
  }

  // )
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenClose error:error];
  if (*error) return nil;
  
  return data;
}

/*
 * address         =
 *   "("
 *     addr-name SP
 *     addr-adl SP
 *     addr-mailbox SP
 *     addr-host
 *   ")"
 * addr-adl        = nstring
 * ; Holds route from [RFC-2822] route-addr if
 * ; non-NIL
 * addr-host       = nstring
 * ; NIL indicates [RFC-2822] group syntax.
 * ; Otherwise, holds [RFC-2822] domain name
 * addr-mailbox    = nstring
 * ; NIL indicates end of [RFC-2822] group; if
 * ; non-NIL and addr-host is NIL, holds
 * ; [RFC-2822] group name.
 * ; Otherwise, holds [RFC-2822] local-part
 * ; after removing [RFC-2822] quoting
 * addr-name       = nstring
 * ; If non-NIL, holds phrase from [RFC-2822]
 * ; mailbox after removing [RFC-2822] quoting
 */
- (id)parseAddressData:(NSError **)error {
  SubImapToken *token;
  NSMutableDictionary *address = [NSMutableDictionary dictionaryWithCapacity:2];

  // (
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenOpen error:error];
  if (*error) return nil;

  // Address name
  id name = [self parseNString:error];
  if (*error) return nil;
  address[@"name"] = name;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // Address route -- Not used. RFC2822 lists it as obsolete
  [self parseNString:error];
  if (*error) return nil;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // Address mailbox -- Used as the local part of the email
  id mailbox = [self parseNString:error];
  if (*error) return nil;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // Address host -- Used as the domain part of the email
  id host = [self parseNString:error];
  if (*error) return nil;

  // )
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenClose error:error];
  if (*error) return nil;

  address[@"email"] = [NSString stringWithFormat:@"%@@%@", mailbox, host];

  return address;
}

/*
 * bodydata        =
 *   "BODY" ["STRUCTURE"] SP body /
 *   "BODY" section ["<" number ">"] SP nstring
 */
- (id)parseMessageBodyData:(NSError **)error {
  // Section
  if ([self.tokenizer peekTokenIsType:SubImapTokenTypeBracketOpen]) {
    id section = [self parseMessageBodySectionData:error];
    if (*error) return nil;
    return section;
  }

  // Structure
  else {
    // SP
    [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
    if (*error) return nil;

    // Body structure
    id structure = [self parseMessageBodyStructureData:error];
    if (*error) return nil;
    return structure;
  }
}

/*
 * Parses BODY[] message attributes.
 *
 * i.e. "BODY" section ["<" number ">"] SP nstring
 *
 * section         = "[" [section-spec] "]"
 *
 * section-spec    =
 *   section-msgtext /
 *   (section-part ["." section-text])
 *
 * section-msgtext =
 *   "HEADER" /
 *   "HEADER.FIELDS" [".NOT"] SP header-list /
 *   "TEXT"
 *
 * section-part    = nz-number *("." nz-number)
 *
 * section-text    = section-msgtext / "MIME"
 *
 * header-list     = "(" header-fld-name *(SP header-fld-name) ")"
 *
 * header-fld-name = astring
 */
- (id)parseMessageBodySectionData:(NSError **)error {
  SubImapToken *token;
  NSMutableDictionary *data = [NSMutableDictionary dictionary];

  // [
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeBracketOpen error:error];
  if (*error) return nil;

  // Section spec
  // TODO: Proper sections
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeAtom error:error];
  if (*error) return nil;
  data[@"section"] = token.value;

  // ]
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeBracketClose error:error];
  if (*error) return nil;

  // TODO: Section bytes

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // Data
  id nstring = [self parseNString:error];
  if (*error) return nil;
  data[@"data"] = nstring;

  return data;
}

/*
 * Parses BODY and BODYSTRUCTURE message attributes.
 *
 * body            = "(" (body-type-1part / body-type-mpart) ")"
 *
 * body-type-1part =
 *   (body-type-basic / body-type-msg / body-type-text) [SP body-ext-1part]
 *
 * body-type-mpart = 1*body SP media-subtype [SP body-ext-mpart]
 *
 * body-type-basic = media-basic SP body-fields
 *                   ; MESSAGE subtype MUST NOT be "RFC822"
 *
 * body-type-msg   =
 *   media-message SP body-fields SP envelope SP body SP body-fld-lines
 *
 * body-type-text  = media-text SP body-fields SP body-fld-lines
 *
 * body-ext-1part  =
 *   body-fld-md5 [SP body-fld-dsp [SP body-fld-lang [SP body-fld-loc *(SP body-extension)]]]
 *   ; MUST NOT be returned on non-extensible "BODY" fetch
 *
 * body-ext-mpart  =
 *   body-fld-param [SP body-fld-dsp [SP body-fld-lang [SP body-fld-loc *(SP body-extension)]]]
 *   ; MUST NOT be returned on non-extensible "BODY" fetch
 *
 * body-extension  = nstring / number / "(" body-extension *(SP body-extension) ")"
 *   ; Future expansion.  Client implementations MUST accept body-extension fields.
 *   ; Server implementations MUST NOT generate body-extension fields except as
 *   ; defined by future standard or standards-track revisions of this specification.
 *
 * body-fld-lines  = number
 *
 * body-fld-md5    = nstring
 *
 * body-fld-dsp    = "(" string SP body-fld-param ")" / nil
 *
 * body-fld-lang   = nstring / "(" string *(SP string) ")"
 *
 * body-fld-loc    = nstring
 *
 * media-basic     = ((DQUOTE ("APPLICATION" / "AUDIO" / "IMAGE" /
 *   "MESSAGE" / "VIDEO") DQUOTE) / string) SP media-subtype
 *   ; Defined in [MIME-IMT]
 *
 * media-message   = DQUOTE "MESSAGE" DQUOTE SP DQUOTE "RFC822" DQUOTE
 *                   ; Defined in [MIME-IMT]
 *
 * media-subtype   = string
 *                   ; Defined in [MIME-IMT]
 *
 * media-text      = DQUOTE "TEXT" DQUOTE SP media-subtype
 *                   ; Defined in [MIME-IMT]
 */
- (id)parseMessageBodyStructureData:(NSError **)error {
  SubImapToken *token;
  NSMutableDictionary *data = [NSMutableDictionary dictionary];

  // * 121 FETCH (
  //   BODY (
  //     ("TEXT" "PLAIN" ("CHARSET" "UTF-8") "<50ef78e869d17_12cb5132bee202937@domU-12-31-38-02-30-61.mail>" NIL "QUOTED-PRINTABLE" 2071 40)
  //     ("TEXT" "HTML" ("CHARSET" "UTF-8") "<50ef78e86a83b_12cb5132bee203014@domU-12-31-38-02-30-61.mail>" NIL "7BIT" 4619 97)
  //     "ALTERNATIVE"
  //   )
  // )

  // * 118 FETCH (BODY ((("TEXT" "PLAIN" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 3550 90)("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 81936 2018) "ALTERNATIVE") "MIXED"))
  // * 118 FETCH (
  //   BODY (
  //     (
  //       ("TEXT" "PLAIN" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 3550 90)
  //       ("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 81936 2018)
  //       "ALTERNATIVE"
  //     )
  //     "MIXED"
  //   )
  // )

  // * 5 FETCH (BODY ("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 38 1))

  // (
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenOpen error:error];
  if (*error) return nil;

  // Multi-part
  // (
  if ([self.tokenizer peekTokenIsType:SubImapTokenTypeParenOpen]) {
    data[@"parts"] = [NSMutableArray array];
    data[@"type"] = @"MULTIPART";

    while (1) {
      // SP
      if ([self.tokenizer pullTokenIsType:SubImapTokenTypeSpace]) {
        // Media sub-type
        id subtype = [self parseString:error];
        if (*error) return nil;
        data[@"subtype"] = [subtype uppercaseString];

        break;
      }

      // part
      id part = [self parseMessageBodyStructureData:error];
      if (*error) return nil;
      [data[@"parts"] addObject:part];
    }
  }

  // 1part
  else {
    id part = [self parseMessageBodyStructurePartData:error];
    if (*error) return nil;
    data = part;
  }

  // )
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenClose error:error];
  if (*error) return nil;

  return data;
}

- (id)parseMessageBodyStructurePartData:(NSError **)error {
  SubImapToken *token;
  NSMutableDictionary *data = [NSMutableDictionary dictionary];

  // Media type
  id type = [self parseString:error];
  if (*error) return nil;
  data[@"type"] = [type uppercaseString];

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // Media sub-type
  id subtype = [self parseString:error];
  if (*error) return nil;
  data[@"subtype"] = [subtype uppercaseString];

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // Body fields
  id fields = [self parseMessageBodyFieldsData:error];
  if (*error) return nil;
  for (NSString *key in fields) {
    data[key] = fields[key];
  }

  // Detect: MSG-MESSAGE
  if ([data[@"type"] isEqualToString:@"MESSAGE"] && [data[@"subtype"] isEqualToString:@"RFC822"]) {
    // TODO: Message sub-parts
  }

  // Detect: MSG-TEXT
  else if ([data[@"type"] isEqualToString:@"TEXT"]) {
    // SP
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
    if (*error) return nil;

    // * body-fld-lines  = number
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeNumber error:error];
    if (*error) return nil;
    data[@"lines"] = @([token.value integerValue]);
  }

  // Detect: MSG-BASIC
  else {
    // TODO: basic sub-parts
  }

  return data;
}

/*
 * body-fields     =
 *   body-fld-param SP body-fld-id SP body-fld-desc SP body-fld-enc SP body-fld-octets
 *
 * body-fld-param  = "(" string SP string *(SP string SP string) ")" / nil
 *
 * body-fld-id     = nstring
 *
 * body-fld-desc   = nstring
 *
 * body-fld-enc    =
 *   (DQUOTE ("7BIT" / "8BIT" / "BINARY" / "BASE64"/ "QUOTED-PRINTABLE") DQUOTE) / string
 *
 * body-fld-octets = number
 */
- (id)parseMessageBodyFieldsData:(NSError **)error {
  SubImapToken *token;
  NSMutableDictionary *data = [NSMutableDictionary dictionary];

  // fld-param
  id params = [self parseMessageBodyFieldsParamData:error];
  if (*error) return nil;
  data[@"params"] = params;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // fld-id
  id mid = [self parseNString:error];
  if (*error) return nil;
  data[@"mid"] = mid;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // fld-desc
  id desc = [self parseNString:error];
  if (*error) return nil;
  data[@"desc"] = desc;

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // fld-enc
  id encoding = [self parseString:error];
  if (*error) return nil;
  data[@"encoding"] = [encoding uppercaseString];

  // SP
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
  if (*error) return nil;

  // fld-octets
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeNumber error:error];
  if (*error) return nil;
  data[@"octets"] = @([token.value integerValue]);

  return data;
}

/*
 * body-fld-param  = "(" string SP string *(SP string SP string) ")" / nil
 */
- (id)parseMessageBodyFieldsParamData:(NSError **)error {
  SubImapToken *token;
  NSMutableDictionary *data = [NSMutableDictionary dictionary];

  // NIL
  if ([self.tokenizer pullTokenIsType:SubImapTokenTypeNil]) {
    return data;
  }

  // (
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenOpen error:error];
  if (*error) return nil;

  while (1) {
    // String
    id s1 = [self parseString:error];
    if (*error) return nil;

    // SP
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
    if (*error) return nil;

    // String
    id s2 = [self parseString:error];
    if (*error) return nil;

    data[[s1 lowercaseString]] = s2;

    // )
    if ([self.tokenizer peekTokenIsType:SubImapTokenTypeParenClose]) {
      break;
    }

    // SP
    token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
    if (*error) return nil;
  }

  // )
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenClose error:error];
  if (*error) return nil;

  return data;
}

#pragma mark Gimap

/*
 * Parses a list of Gimap labels. May return an empy array.
 *
 * Guaranteed to cause an error if nil is returned.
 *
 * eg: (\Flag1 \Flag2)
 */
- (id)parseGimapLabelListData:(NSError **)error {
  SubImapToken *token;
  NSMutableArray *data = [NSMutableArray array];

  // (
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenOpen error:error];
  if (*error) return nil;

  // )
  if (![self.tokenizer peekTokenIsType:SubImapTokenTypeParenClose]) {
    while (1) {
      // Label
      id label = [self parseGimapLabelData:error];
      if (*error) return nil;
      if (token) [data addObject:label];

      // )
      if ([self.tokenizer peekTokenIsType:SubImapTokenTypeParenClose]) {
        break;
      }

      // SP
      token = [self.tokenizer pullTokenOfType:SubImapTokenTypeSpace error:error];
      if (*error) return nil;
    }
  }

  // )
  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeParenClose error:error];
  if (*error) return nil;
  
  return data;
}

- (id)parseGimapLabelData:(NSError **)error {
  SubImapToken *token;

  token = [self.tokenizer pullTokenOfType:SubImapTokenTypeFlag error:nil];
  if (token) return token.value;

  id string = [self parseAString:error];
  if (*error) return nil;
  return string;
}

#pragma mark - Error Helpers

- (BOOL)error:(NSError **)error code:(SubImapParserError)code message:(NSString *)message {
  if (error) {
    *error = [NSError errorWithDomain:SubImapParserErrorDomain code:code userInfo:@{ NSLocalizedDescriptionKey:message }];
    return YES;
  }

  return NO;
}

- (BOOL)error:(NSError **)error code:(SubImapParserError)code format:(NSString *)format, ... {
  va_list args;
  va_start(args, format);
  BOOL r = [self error:error code:code message:[[NSString alloc] initWithFormat:format arguments:args]];
  va_end(args);
  return r;
}

@end