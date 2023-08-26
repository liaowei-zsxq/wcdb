//
// Created by sanhuazhang on 2019/05/02
//

/*
 * Tencent is pleased to support the open source community by making
 * WCDB available.
 *
 * Copyright (C) 2017 THL A29 Limited, a Tencent company.
 * All rights reserved.
 *
 * Licensed under the BSD 3-Clause License (the "License"); you may not use
 * this file except in compliance with the License. You may obtain a copy of
 * the License at
 *
 *       https://opensource.org/licenses/BSD-3-Clause
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "TestCase.h"

@interface TraceTests : TableTestCase

@end

@implementation TraceTests

- (void)test_trace_sql
{
    WCDB::StatementPragma statement = WCDB::StatementPragma().pragma(WCDB::Pragma::userVersion());

    __block BOOL tested = NO;
    [self.database traceSQL:^(WCTTag tag, NSString* path, UInt64, NSString* sql) {
        XCTAssertEqual(tag, self.database.tag);
        XCTAssertTrue([path isEqualToString:self.database.path]);
        if ([sql isEqualToString:@(statement.getDescription().data())]) {
            tested = YES;
        }
    }];
    TestCaseAssertTrue([self.database execute:statement]);
    TestCaseAssertTrue(tested);

    [self.database traceSQL:nil];
}

- (void)test_trace_performance
{
    TestCaseAssertTrue([self createTable]);

    NSArray<TestCaseObject*>* objects = [Random.shared autoIncrementTestCaseObjectsWithCount:10000];

    __block NSMutableArray* expectedFootprints = [[NSMutableArray alloc] initWithObjects:
                                                                         @"BEGIN IMMEDIATE",
                                                                         @"INSERT INTO testTable(identifier, content) VALUES(?1, ?2)",
                                                                         @"COMMIT",
                                                                         nil];
    [self.database tracePerformance:^(WCTTag tag, NSString* path, UInt64, NSString* sql, double cost) {
        XCTAssertEqual(tag, self.database.tag);
        XCTAssertTrue([path isEqualToString:self.database.path]);
        XCTAssertTrue(cost >= 0);
        if ([sql isEqualToString:expectedFootprints.firstObject]) {
            [expectedFootprints removeObjectAtIndex:0];
        }
    }];
    TestCaseAssertTrue([self.database insertObjects:objects intoTable:self.tableName]);
    TestCaseAssertTrue(expectedFootprints.count == 0);

    [self.database tracePerformance:nil];
}

- (void)test_global_trace_error
{
    self.tableClass = TestCaseObject.class;

    __block BOOL tested = NO;
    weakify(self);
    [WCTDatabase globalTraceError:nil];
    [WCTDatabase globalTraceError:^(WCTError* error) {
        strongify_or_return(self);
        if (error.level == WCTErrorLevelError
            && [error.path isEqualToString:self.path]
            && error.tag == self.database.tag
            && error.code == WCTErrorCodeError
            && [error.sql isEqualToString:@"SELECT 1 FROM dummy"]) {
            tested = YES;
        }
    }];

    TestCaseAssertTrue([self.database canOpen]);

    TestCaseAssertFalse([self.database execute:WCDB::StatementSelect().select(1).from(@"dummy")]);

    TestCaseAssertTrue(tested);
    [WCTDatabase globalTraceError:nil];
}

- (void)test_database_trace_error
{
    self.tableClass = TestCaseObject.class;

    __block BOOL tested = NO;
    weakify(self);
    [self.database traceError:^(WCTError* error) {
        strongify_or_return(self);
        TestCaseAssertTrue([error.path isEqualToString:self.path]);
        tested = YES;
    }];

    TestCaseAssertTrue([self.database canOpen]);

    TestCaseAssertFalse([self.database execute:WCDB::StatementSelect().select(1).from(@"dummy")]);
    TestCaseAssertTrue(tested);
}

- (void)test_global_trace_sql
{
    WCDB::StatementPragma statement = WCDB::StatementPragma().pragma(WCDB::Pragma::userVersion());

    __block BOOL tested = NO;
    [WCTDatabase globalTraceSQL:^(WCTTag tag, NSString* path, UInt64, NSString* sql) {
        if (![path isEqualToString:self.database.path]) {
            return;
        }
        XCTAssertEqual(tag, self.database.tag);
        if ([sql isEqualToString:@(statement.getDescription().data())]) {
            tested = YES;
        }
    }];
    TestCaseAssertTrue([self.database execute:statement]);
    TestCaseAssertTrue(tested);

    [WCTDatabase globalTraceSQL:nil];
}

- (void)test_global_trace_performance
{
    NSArray<TestCaseObject*>* objects = [Random.shared autoIncrementTestCaseObjectsWithCount:10000];

    __block NSMutableArray* expectedFootprints = [[NSMutableArray alloc] initWithObjects:
                                                                         @"BEGIN IMMEDIATE",
                                                                         @"INSERT INTO testTable(identifier, content) VALUES(?1, ?2)",
                                                                         @"COMMIT",
                                                                         nil];
    [WCTDatabase globalTracePerformance:^(WCTTag tag, NSString* path, UInt64, NSString* sql, double cost) {
        if (![path isEqualToString:self.database.path]) {
            return;
        }
        XCTAssertEqual(tag, self.database.tag);
        XCTAssertTrue(cost >= 0);
        if ([sql isEqualToString:expectedFootprints.firstObject]) {
            [expectedFootprints removeObjectAtIndex:0];
        }
    }];

    TestCaseAssertTrue([self createTable]);
    TestCaseAssertTrue([self.database insertObjects:objects intoTable:self.tableName]);
    TestCaseAssertTrue(expectedFootprints.count == 0);

    [WCTDatabase globalTracePerformance:nil];
}

- (void)test_global_trace_db_operation
{
    __block long tag = 0;
    __block NSString* path = nil;
    __block int openHandleCount = 0;
    __block int tableCount = 0;
    __block int indexCount = 0;
    [WCTDatabase globalTraceDatabaseOperation:^(WCTDatabase* database,
                                                WCTDatabaseOperation operation,
                                                NSDictionary* info) {
        switch (operation) {
        case WCTDatabaseOperation_Create:
            path = database.path;
            break;
        case WCTDatabaseOperation_SetTag:
            tag = database.tag;
            break;
        case WCTDatabaseOperation_OpenHandle: {
            openHandleCount++;
            TestCaseAssertTrue(((NSNumber*) info[WCTDatabaseMonitorInfoKeyHandleCount]).intValue == 1);
            TestCaseAssertTrue(((NSNumber*) info[WCTDatabaseMonitorInfoKeyHandleOpenTime]).intValue > 0);
            TestCaseAssertTrue(((NSNumber*) info[WCTDatabaseMonitorInfoKeySchemaUsage]).intValue > 0);
            TestCaseAssertTrue(((NSNumber*) info[WCTDatabaseMonitorInfoKeyTriggerCount]).intValue == 0);
            tableCount = ((NSNumber*) info[WCTDatabaseMonitorInfoKeyTableCount]).intValue;
            indexCount = ((NSNumber*) info[WCTDatabaseMonitorInfoKeyIndexCount]).intValue;
        } break;
        }
    }];

    TestCaseAssertTrue([self createTable]);
    TestCaseAssertTrue([self.database execute:WCDB::StatementCreateIndex()
                                              .createIndex("testIndex")
                                              .table(self.tableName)
                                              .indexed(TestCaseObject.content)]);

    TestCaseAssertTrue(tag == self.database.tag);
    TestCaseAssertStringEqual(path, self.database.path);
    TestCaseAssertTrue(openHandleCount == 1);

    [self.database close];
    TestCaseAssertTrue([self.database insertObjects:[Random.shared autoIncrementTestCaseObjectsWithCount:10] intoTable:self.tableName]);
    TestCaseAssertTrue(openHandleCount == 2);
    TestCaseAssertTrue(tableCount == 4);
    TestCaseAssertTrue(indexCount == 1);
    [WCTDatabase globalTraceDatabaseOperation:nil];
}

@end
