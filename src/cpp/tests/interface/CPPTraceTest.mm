//
// Created by qiuwenchen on 2022/8/13.
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

#import "CPPTestCase.h"

@interface CPPTraceTests : CPPTableTestCase

@end

@implementation CPPTraceTests

- (void)test_trace_sql
{
    WCDB::StatementPragma statement = WCDB::StatementPragma().pragma(WCDB::Pragma::userVersion());

    BOOL tested = NO;
    self.database->traceSQL([&](long tag, const WCDB::UnsafeStringView &path, const WCDB::UnsafeStringView &sql, const void *) {
        XCTAssertEqual(tag, self.database->getTag());
        XCTAssertTrue(path.equal(self.database->getPath()));
        if (strcmp(sql.data(), statement.getDescription().data()) == 0) {
            tested = YES;
        }
    });
    TestCaseAssertTrue(self.database->execute(statement));
    TestCaseAssertTrue(tested);

    self.database->traceSQL(nullptr);
}

- (void)test_trace_performance
{
    TestCaseAssertTrue([self createValueTable]);

    WCDB::MultiRowsValue objects = [Random.shared autoIncrementTestCaseValuesWithCount:10000];

    NSMutableArray<NSString *> *expectedFootprints = [[NSMutableArray alloc] initWithObjects:
                                                                             @"BEGIN IMMEDIATE",
                                                                             @"INSERT INTO testTable(identifier, content) VALUES(?1, ?2)",
                                                                             @"COMMIT",
                                                                             nil];
    self.database->tracePerformance(nullptr);
    self.database->tracePerformance([&](long tag, const WCDB::UnsafeStringView &path, const WCDB::UnsafeStringView &sql, double cost, const void *) {
        XCTAssertEqual(tag, self.database->getTag());
        XCTAssertTrue(path.equal(self.database->getPath()));
        XCTAssertTrue(cost >= 0);
        if (strcmp(sql.data(), expectedFootprints.firstObject.UTF8String) == 0) {
            [expectedFootprints removeObjectAtIndex:0];
        }
    });
    TestCaseAssertTrue(self.database->insertRows(objects, self.columns, self.tableName.UTF8String));
    TestCaseAssertTrue(expectedFootprints.count == 0);
    self.database->tracePerformance(nil);
}

- (void)test_global_trace_error
{
    BOOL tested = NO;
    WCDB::Database::globalTraceError(nullptr);
    WCDB::Database::globalTraceError([&](const WCDB::Error &error) {
        if (error.level == WCDB::Error::Level::Error
            && strcmp(error.getPath().data(), self.path.UTF8String) == 0
            && error.getTag().value() == self.database->getTag()
            && error.code() == WCDB::Error::Code::Error
            && strcmp(error.getSQL().data(), "SELECT 1 FROM dummy") == 0) {
            tested = YES;
        }
    });

    TestCaseAssertTrue(self.database->canOpen());
    TestCaseAssertFalse(self.database->execute(WCDB::StatementSelect().select(1).from("dummy")));
    TestCaseAssertTrue(tested);
}

- (void)test_trace_error
{
    BOOL tested = NO;
    self.database->traceError([&](const WCDB::Error &error) {
        TestCaseAssertCPPStringEqual(error.getPath().data(), self.path.UTF8String);
        TestCaseAssertEqual(error.getTag().value(), self.database->getTag());
        if (error.level == WCDB::Error::Level::Error
            && error.code() == WCDB::Error::Code::Error
            && strcmp(error.getSQL().data(), "SELECT 1 FROM dummy") == 0) {
            tested = YES;
        }
    });

    TestCaseAssertTrue(self.database->canOpen());
    TestCaseAssertFalse(self.database->execute(WCDB::StatementSelect().select(1).from("dummy")));
    TestCaseAssertTrue(tested);
}

- (void)test_global_trace_sql
{
    WCDB::StatementPragma statement = WCDB::StatementPragma().pragma(WCDB::Pragma::userVersion());

    BOOL tested = NO;
    WCDB::Database::globalTraceSQL([&](long tag, const WCDB::UnsafeStringView &path, const WCDB::UnsafeStringView &sql, const void *) {
        if (!path.equal(self.database->getPath())) {
            return;
        }
        XCTAssertEqual(tag, self.database->getTag());
        if (strcmp(sql.data(), statement.getDescription().data()) == 0) {
            tested = YES;
        }
    });
    TestCaseAssertTrue(self.database->execute(statement));
    TestCaseAssertTrue(tested);

    WCDB::Database::globalTraceError(nullptr);
}

- (void)test_global_trace_performance
{
    WCDB::MultiRowsValue objects = [Random.shared autoIncrementTestCaseValuesWithCount:10000];

    NSMutableArray<NSString *> *expectedFootprints = [[NSMutableArray alloc] initWithObjects:
                                                                             @"BEGIN IMMEDIATE",
                                                                             @"INSERT INTO testTable(identifier, content) VALUES(?1, ?2)",
                                                                             @"COMMIT",
                                                                             nil];
    WCDB::Database::globalTracePerformance([&](long tag, const WCDB::UnsafeStringView &path, const WCDB::UnsafeStringView &sql, double cost, const void *) {
        if (!path.equal(self.database->getPath())) {
            return;
        }
        XCTAssertTrue(cost >= 0);
        XCTAssertEqual(tag, self.database->getTag());
        if (strcmp(sql.data(), expectedFootprints.firstObject.UTF8String) == 0) {
            [expectedFootprints removeObjectAtIndex:0];
        }
    });
    TestCaseAssertTrue([self createValueTable]);
    TestCaseAssertTrue(self.database->insertRows(objects, self.columns, self.tableName.UTF8String));
    TestCaseAssertTrue(expectedFootprints.count == 0);
    WCDB::Database::globalTracePerformance(nil);
}

- (void)test_trace_db_operation
{
    long tag = 0;
    WCDB::StringView path;
    int openHandleCount = 0;
    int tableCount = 0;
    int indexCount = 0;
    WCDB::Database::globalTraceDatabaseOperation([&](WCDB::Database &database,
                                                     WCDB::Database::Operation operation,
                                                     WCDB::StringViewMap<WCDB::Value> &info) {
        switch (operation) {
        case WCDB::Database::Operation::Create:
            path = database.getPath();
            break;
        case WCDB::Database::Operation::SetTag:
            tag = database.getTag();
            break;
        case WCDB::Database::Operation::OpenHandle: {
            openHandleCount++;
            TestCaseAssertTrue(info[WCDB::Database::MonitorInfoKeyHandleCount].intValue() == 1);
            TestCaseAssertTrue(info[WCDB::Database::MonitorInfoKeyHandleOpenTime].intValue() > 0);
            TestCaseAssertTrue(info[WCDB::Database::MonitorInfoKeySchemaUsage].intValue() > 0);
            TestCaseAssertTrue(info[WCDB::Database::MonitorInfoKeyTriggerCount].intValue() == 0);
            tableCount = (int) info[WCDB::Database::MonitorInfoKeyTableCount].intValue();
            indexCount = (int) info[WCDB::Database::MonitorInfoKeyIndexCount].intValue();
        } break;
        }
    });
    TestCaseAssertTrue([self createValueTable]);
    TestCaseAssertTrue(self.database->execute(WCDB::StatementCreateIndex()
                                              .createIndex("testIndex")
                                              .table(self.tableName)
                                              .indexed(WCDB_FIELD(CPPTestCaseObject::content))));

    TestCaseAssertTrue(tag = self.database->getTag());
    TestCaseAssertCPPStringEqual(path.data(), self.database->getPath().data());
    TestCaseAssertTrue(openHandleCount == 1);

    self.database->close();
    TestCaseAssertTrue(self.database->insertRows([Random.shared autoIncrementTestCaseValuesWithCount:10], self.columns, self.tableName.UTF8String));

    TestCaseAssertTrue(openHandleCount == 2);
    TestCaseAssertTrue(tableCount == 4);
    TestCaseAssertTrue(indexCount == 1);
    WCDB::Database::globalTraceDatabaseOperation(nullptr);
}

@end
