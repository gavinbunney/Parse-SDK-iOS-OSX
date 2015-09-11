//
//  NikitaInputStreamTests.m
//  Parse
//
//  Created by Richard Ross III on 9/11/15.
//  Copyright © 2015 Parse Inc. All rights reserved.
//

#import "PFTestCase.h"

#import <OCMock/OCMock.h>

#import "NikitaInputStream.h"

@interface NikitaInputStreamTests : PFTestCase

@end

@implementation NikitaInputStreamTests

- (NSString *)temporaryFilePath {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"nikitainputstream.dat"];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtPath:[self temporaryFilePath] error:NULL];

    [super tearDown];
}

- (void)testWillNotReadLastByte {
    NSOutputStream *outputStream = [NSOutputStream outputStreamToFileAtPath:[self temporaryFilePath] append:NO];
    NSInputStream *inputStream = (NSInputStream *)[[NikitaInputStream alloc] initWithFileAtPath:[self temporaryFilePath]];

    const uint8_t toWrite[16] = {
        0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7,
        0x8, 0x9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF
    };
    uint8_t toRead[sizeof(toWrite)] = { 0 };
    size_t size = sizeof(toWrite);

    [outputStream open];
    [inputStream open];

    XCTAssertEqual(size, [outputStream write:toWrite maxLength:size]);

    XCTAssertEqual(size - 1, [inputStream read:toRead maxLength:size]);
    XCTAssertEqual(0, memcmp(toRead, toWrite, size - 1));

    XCTAssertEqual(0, [inputStream read:toRead maxLength:size]);

    [(NikitaInputStream *)inputStream stopBlocking];

    XCTAssertEqual(1, [inputStream read:toRead maxLength:size]);

    XCTAssertEqual(toWrite[size - 1], toRead[0]);

    [inputStream close];
    [outputStream close];
}

- (void)testDelegate {
    id mockedDelegate = PFStrictProtocolMock(@protocol(NSStreamDelegate));

    NSOutputStream *outputStream = [NSOutputStream outputStreamToFileAtPath:[self temporaryFilePath] append:NO];
    NSInputStream *inputStream = (NSInputStream *)[[NikitaInputStream alloc] initWithFileAtPath:[self temporaryFilePath]];

    const uint8_t toWrite[16] = {
        0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7,
        0x8, 0x9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF
    };
    uint8_t toRead[sizeof(toWrite)] = { 0 };
    size_t size = sizeof(toWrite);

    [outputStream open];
    [outputStream write:toWrite maxLength:size];
    [outputStream close];

    inputStream.delegate = mockedDelegate;
    [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

    OCMExpect([mockedDelegate stream:inputStream handleEvent:NSStreamEventOpenCompleted]);
    OCMExpect([mockedDelegate stream:inputStream handleEvent:NSStreamEventHasBytesAvailable]);
    [inputStream open];

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    OCMVerifyAll(mockedDelegate);

    XCTAssertEqual(size - 1, [inputStream read:toRead maxLength:size]);
    XCTAssertEqual(0, [inputStream read:toRead maxLength:size]);

    OCMExpect([mockedDelegate stream:inputStream handleEvent:NSStreamEventHasBytesAvailable]);
    [(NikitaInputStream *)inputStream stopBlocking];
    OCMVerifyAll(mockedDelegate);

    OCMExpect([mockedDelegate stream:inputStream handleEvent:NSStreamEventEndEncountered]);
    XCTAssertEqual(1, [inputStream read:toRead maxLength:size]);
    XCTAssertEqual(0, [inputStream read:toRead maxLength:size]);

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    OCMVerifyAll(mockedDelegate);

    [inputStream close];
}

@end
