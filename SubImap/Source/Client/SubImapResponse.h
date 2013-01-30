// SubImapResponse.h
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

typedef enum {
  /*
   * Unknown response. Wasn't able to parse the type.
   */
  SubImapResponseTypeUnknown,

  /*
   * RFC3501 7.1. Status Responses
   *
   * OK - RFC3501 7.1.1.
   * When tagged, it indicates successful completion of the associated
   * command. When untagged, it is one of three possible greetings and
   * indicates successful connection to the server, in the
   * not-authenticated state.
   *
   * NO - RFC3501 7.1.2.
   * When tagged, it indicates unsuccessful completion of the
   * associated command. When untagged, it indicates a warning;
   * the command can still complete successfully.
   *
   * BAD - RFC3501 7.1.3.
   * When tagged, it reports a protocol-level error in the client's
   * command. When untagged, it indicates a protocol-level error for
   * which the associated command can not be determined; it can also
   * indicate an internal server failure.
   *
   * PREAUTH - RFC3501 7.1.4.
   * Untagged, and one of three possible greetings. It indicates that
   * the connection has already been authenticated by external means;
   * thus no LOGIN command is needed.
   *
   * BYE - RFC3501 7.1.5.
   * Untagged, and one of three possible greetings. Indicates that the
   * server is about to close the connection.
   *
   * All status responses include a string "message" which is meant to be
   * human-readable. They can optionally include a "code" which indicates
   * that other information was included.
   *
   *   Data: (NSDictionary *) {
   *     "code":    (NSString *) response code
   *     "message": (NSString *) human-readable text
   *   }
   *
   * The "code" may be one of the following:
   *
   * "ALERT"
   * The human-readable text contains a special alert that MUST be
   * presented to the user in a fashion that calls the user's
   * attention to the message.
   *
   * "BADCHARSET"
   * Optionally includes list of charsets. A SEARCH failed because
   * the given charset is not supported by this implementation. If
   * the optional list of charsets is given, this lists the charsets
   * that are supported by this implementation.
   *
   *     "charsets": (NSArray *)(NSString *) accepted charsets, possibly empty
   *
   * "CAPABILITY"
   * Includes a list of capabilities. This can appear in the initial
   * OK or PREAUTH response to transmit an initial capabilities list.
   * This makes it unnecessary for a client to send a separate
   * CAPABILITY command if it recognizes this response.
   *
   *     "capabilities": (NSArray *)(NSString *) the server's capabilites
   *
   * "PARSE"
   * The human-readable text represents an error in parsing the
   * [RFC-2822] header or [MIME-IMB] headers of a message in the
   * mailbox.
   *
   * "PERMANENTFLAGS"
   * Includes a list of flags, indicates which of the known flags the
   * client can change permanently. Any flags that are in the FLAGS
   * untagged response, but not the this list, can not be set
   * permanently. If the client attempts to STORE a flag that is not
   * in the this list, the server will either ignore the change or
   * store the state change for the remainder of the current session
   * only. This list can also include the special flag \*, which
   * indicates that it is possible to create new keywords by attempting
   * to store those flags in the mailbox.
   *
   *     "flags": (NSArray *)(NSString *) a list of permanent flags
   *
   * "READ-ONLY"
   * The mailbox is selected read-only, or its access while selected
   * has changed from read-write to read-only.
   *
   * "READ-WRITE"
   * The mailbox is selected read-write, or its access while selected
   * has changed from read-only to read-write.
   *
   * "TRYCREATE"
   * An APPEND or COPY attempt is failing because the target mailbox
   * does not exist (as opposed to some other reason). This is a hint
   * to the client that the operation can succeed if the mailbox is
   * first created by the CREATE command.
   *
   * "UIDNEXT"
   * Includes a decimal number, indicates the next unique identifier
   * value. Refer to section 2.3.1.1 for more information.
   *
   *     "uidnext": (NSUInteger) the next UID for the current mailbox
   *
   * "UIDVALIDITY"
   * Includes a decimal number, indicates the unique identifier
   * validity value. Refer to section 2.3.1.1 for more information.
   *
   *     "uidvalidity": (NSUInteger) the current mailbox's UID validity
   *
   * "UNSEEN"
   * Includes a decimal number, indicates the number of the first
   * message without the \Seen flag set.
   *
   *     "unseen": (NSUInteger) the mailbox's first unseen message
   */
  SubImapResponseTypeOk,
  SubImapResponseTypeNo,
  SubImapResponseTypeBad,
  SubImapResponseTypePreauth,
  SubImapResponseTypeBye,

  // RFC3501 7.2. Server and Mailbox Status

  /*
   * CAPABILITY - RFC3501 7.2.1.
   *
   * A listing of capability names that the server supports.
   *
   * A capability name which begins with "AUTH=" indicates that the
   * server supports that particular authentication mechanism.
   *
   * The LOGINDISABLED capability indicates that the LOGIN command is
   * disabled.
   *
   * Other capability names indicate that the server supports an
   * extension, revision, or amendment to the IMAP4rev1 protocol.
   *
   * Data: (NSArray *) capabilities
   */
  SubImapResponseTypeCapability,

  /*
   * LIST - RFC3501 7.2.2.
   * Information about a mailbox.
   *
   * LSUB - RFC3501 7.2.3.
   * Information about a subscribed mailbox.
   *
   * Data: (NSDictionary *) {
   *   "flags": (NSArray *) mailbox flags -- see RFC
   *   "delimiter": (NSString *) the mailbox path delimiter
   *   "path": (NSString *) the mailbox path
   * }
   */
  SubImapResponseTypeList,
  SubImapResponseTypeLsub,

  /*
   * STATUS - RFC3501 7.2.4.
   *
   * Information about the specified mailbox.
   *
   * Data: (NSDictionary *) {
   *   "mailbox": (NSString *) the mailbox path
   * }
   *
   * In addition to the mailbox, any number of the following keys
   * may be set, all of which relate to the mailbox:
   *
   *   "messages": (NSNumber *) the number of messages
   *   "recent": (NSNumber *) the number of recent messages
   *   "uidnext": (NSNumber *) the predicted next UID
   *   "uidvalidity": (NSNumber *) the UID validity
   */
  SubImapResponseTypeStatus,

  /*
   * SEARCH - RFC3502 7.2.5.
   *
   * A listing of sequence IDs or UIDs, depending on which SEARCH
   * command was used. The list may be empty.
   *
   * Data: (NSArray *)(NSNumber *) sequence IDs or UIDs
   */
  SubImapResponseTypeSearch,

  /*
   * FLAGS - RFC3501 7.2.6.
   *
   * A listing of flags relating to a mailbox.
   *
   * Data: (NSArray *)(NSString *) flags
   */
  SubImapResponseTypeFlags,

  // RFC3501 7.3. Mailbox Size

  /*
   * EXISTS - RFC3501 7.3.1.
   *
   * Reports the number of messages in the mailbox.
   *
   * Data: (NSNumber *) message count
   */
  SubImapResponseTypeExists,

  /*
   * RECENT - RFC3501 7.3.2.
   *
   * Reports the number of messages with the \Recent flag set.
   *
   * Data: (NSNumber *) recent message count
   */
  SubImapResponseTypeRecent,

  // RFC3501 7.4. Message Status

  /*
   * EXPUNGE - RFC3501 7.4.1.
   *
   * reports that the specified message sequence number has been
   * permanently removed from the mailbox.
   *
   * Note: The message sequence number for each successive message
   * in the mailbox is immediately decremented by 1.
   *
   * Data: (NSNumber *) sequence number of deleted message
   */
  SubImapResponseTypeExpunge,

  /*
   * FETCH - RFC3501
   */
  // TODO: document this
  SubImapResponseTypeFetch,

  // RFC3501 7.5. Command Continuation Request
  SubImapResponseTypeContinue
} SubImapResponseType;

@interface SubImapResponse : NSObject

@property BOOL status;
@property SubImapResponseType type;
@property NSString *tag;
@property id data;

+ (id)responseWithStatus:(BOOL)status type:(SubImapResponseType)type tag:(NSString *)tag data:(id)data;
+ (id)responseWithType:(SubImapResponseType)type data:(id)data;

+ (SubImapResponseType)typeFromString:(NSString *)string;
+ (NSString *)stringFromType:(SubImapResponseType)type;

- (BOOL)isTagged;
- (BOOL)isUntagged;
- (BOOL)isContinuation;
- (BOOL)isResult;
- (BOOL)isType:(SubImapResponseType)type;

@end