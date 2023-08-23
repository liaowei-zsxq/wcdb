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

#import "AllTypesObject+WCTTableCoding.h"
#import "AllTypesObject.h"
#import "BackupTestCase.h"
#import "SizeBasedFactory.h"

@interface RetrieveTests : BackupTestCase

@end

@implementation RetrieveTests

- (void)test_empty
{
    [self
    executeTest:^{
        self.path = [self.directory stringByAppendingPathComponent:@"empty"];
        TestCaseAssertEqual([self.database retrieve:nil], -1);
        self.path = nil;
    }];
}

- (void)doTestObjectsRetrieved
{
    [self doTestObjects:self.objects
                 andSQL:@"SELECT identifier, content FROM testTable ORDER BY rowid ASC"
            bySelecting:^NSArray<NSObject<WCTTableCoding>*>* {
                return [self.table getObjects];
            }];
}

- (void)doTestObjectsNotRetrieved
{
    [self doTestObjects:@[]
                 andSQL:@"SELECT type, name, tbl_name, rootpage, sql FROM sqlite_master WHERE name == 'testTable' ORDER BY rowid ASC"
            bySelecting:^NSArray<NSObject<WCTTableCoding>*>* {
                return [self.database getObjectsOfClass:WCTMaster.class fromTable:WCTMaster.tableName where:WCTMaster.name == self.tableName];
            }];
}

- (void)doTestRetrieve
{
    __block double lastPercentage = 0;
    __block BOOL sanity = YES;
    double score = [self.database retrieve:^(double percentage, double increment) {
        if (percentage - lastPercentage != increment
            || increment <= 0) {
            TestCaseFailure();
            sanity = NO;
        }
        lastPercentage = percentage;
    }];
    TestCaseAssertTrue(sanity);
    TestCaseAssertEqual(score, 1.0);
    TestCaseAssertEqual(lastPercentage, 1.0);
}

- (void)doTestRetrieveFailed
{
    __block double lastPercentage = 0;
    __block BOOL sanity = YES;
    double score = [self.database retrieve:^(double percentage, double increment) {
        if (percentage - lastPercentage != increment
            || increment <= 0) {
            TestCaseFailure();
            sanity = NO;
        }
        lastPercentage = percentage;
    }];
    TestCaseAssertTrue(sanity);
    TestCaseAssertNotEqual(score, 1.0);
    TestCaseAssertEqual(lastPercentage, 1.0);
}

#pragma mark - Non-Corrupted
- (void)test_retrieve_with_backup_and_deposit
{
    [self
    executeTest:^{
        TestCaseAssertTrue([self.database backup]);
        TestCaseAssertTrue([self.database deposit]);

        [self doTestRetrieve];
        [self doTestObjectsRetrieved];
    }];
}

- (void)test_retrieve_with_backup_and_without_deposit
{
    __block double mechanicScore = 0;
    __block double crawlerScore = 0;
    __block double summaryScore = 0;

    __block double mechanicCost = 0;
    __block double crawlerCost = 0;
    __block double summaryCost = 0;

    __block double mechanicSpeed = 0;
    __block double crawlerSpeed = 0;

    __block double mechanicSize = 0;
    __block double crawlerSize = 0;

    __block double mechanicWeight = 0;
    __block double crawlerWeight = 0;
    [self.database traceError:^(WCTError* error) {
        if (error.level == WCTErrorLevelNotice
            && error.code == WCTErrorCodeNotice) {
            NSDictionary* userInfo = error.userInfo;
            if ([error.message isEqualToString:@"Mechanic Retrieve Report."]) {
                mechanicCost = ((NSString*) [userInfo objectForKey:@"Cost"]).doubleValue;
                mechanicSize = ((NSString*) [userInfo objectForKey:@"Size"]).doubleValue;
                mechanicSpeed = ((NSString*) [userInfo objectForKey:@"Speed"]).doubleValue;
                mechanicWeight = ((NSString*) [userInfo objectForKey:@"Weight"]).doubleValue;
                mechanicScore = ((NSString*) [userInfo objectForKey:@"Score"]).doubleValue;
            } else if ([error.message isEqualToString:@"Crawler Retrieve Report."]) {
                crawlerCost = ((NSString*) [userInfo objectForKey:@"Cost"]).doubleValue;
                crawlerSize = ((NSString*) [userInfo objectForKey:@"Size"]).doubleValue;
                crawlerSpeed = ((NSString*) [userInfo objectForKey:@"Speed"]).doubleValue;
                crawlerWeight = ((NSString*) [userInfo objectForKey:@"Weight"]).doubleValue;
                crawlerScore = ((NSString*) [userInfo objectForKey:@"Score"]).doubleValue;
            } else if ([error.message isEqualToString:@"Summary Retrieve Report."]) {
                summaryCost = ((NSString*) [userInfo objectForKey:@"Cost"]).doubleValue;
                summaryScore = ((NSString*) [userInfo objectForKey:@"Score"]).doubleValue;
            }
        }
    }];
    [self
    executeTest:^{
        TestCaseAssertTrue([self.database backup]);

        [self doTestRetrieve];
        [self doTestObjectsRetrieved];

        TestCaseAssertTrue(mechanicCost > 0);
        TestCaseAssertTrue(mechanicSize > 0);
        TestCaseAssertEqual(mechanicScore, 1);
        TestCaseAssertTrue(mechanicSpeed > 0);
        TestCaseAssertEqual(mechanicWeight, 100); // for 100 percent

        TestCaseAssertTrue(crawlerCost > 0);
        TestCaseAssertTrue(crawlerSize > 0);
        TestCaseAssertEqual(crawlerScore, 1);
        TestCaseAssertTrue(crawlerSpeed > 0);
        TestCaseAssertEqual(crawlerWeight, 100); // for 100 percent

        TestCaseAssertTrue(summaryCost > 0);
        TestCaseAssertEqual(summaryScore, 1);
    }];
}

- (void)test_retrieve_without_backup_and_with_deposit
{
    [self
    executeTest:^{
        TestCaseAssertTrue([self.database deposit]);

        [self doTestRetrieve];
        [self doTestObjectsRetrieved];
    }];
}

- (void)test_retrieve_without_backup_and_deposite
{
    [self
    executeTest:^{
        [self doTestRetrieve];
        [self doTestObjectsRetrieved];
    }];
}

#pragma mark - Corrupted
- (void)test_retrieve_corrupted_with_backup_and_deposit
{
    [self
    executeTest:^{
        TestCaseAssertTrue([self.database backup]);

        TestCaseAssertTrue([self.database corruptHeaderWithinCloseAfterTruncatedCheckpoint]);

        TestCaseAssertTrue([self.database deposit]);

        [self doTestRetrieve];

        [self doTestObjectsRetrieved];
    }];
}

- (void)test_retrieve_corrupted_with_backup_and_without_deposit
{
    [self
    executeTest:^{
        TestCaseAssertTrue([self.database backup]);

        TestCaseAssertTrue([self.database corruptHeaderWithinCloseAfterTruncatedCheckpoint]);

        [self doTestRetrieve];

        [self doTestObjectsRetrieved];
    }];
}

- (void)test_retrieve_corrupted_without_backup_and_with_deposit
{
    [self
    executeTest:^{
        TestCaseAssertTrue([self.database corruptHeaderWithinCloseAfterTruncatedCheckpoint]);

        TestCaseAssertTrue([self.database deposit]);

        [self doTestRetrieveFailed];

        [self doTestObjectsNotRetrieved];
    }];
}

- (void)test_retrieve_all_types
{
    Class oldClass = self.tableClass;
    NSString* oldTableName = self.tableName;
    [self
    executeTest:^{
        self.tableClass = AllTypesObject.class;
        self.tableName = Random.shared.tableName;
        TestCaseAssertTrue([self createTable]);

        AllTypesObject* maxObject = [AllTypesObject maxObject];
        TestCaseAssertTrue([self.table insertObject:maxObject]);

        AllTypesObject* minObject = [AllTypesObject minObject];
        TestCaseAssertTrue([self.table insertObject:minObject]);

        AllTypesObject* emptyObject = [AllTypesObject emptyObject];
        TestCaseAssertTrue([self.table insertObject:emptyObject]);

        AllTypesObject* nilObject = [AllTypesObject nilObject];
        TestCaseAssertTrue([self.table insertObject:nilObject]);

        TestCaseAssertTrue([self.database retrieve:nil] == 1.0f);

        AllTypesObject* selectedMaxObject = [self.table getObjectWhere:AllTypesObject.type == maxObject.type];
        TestCaseAssertTrue([selectedMaxObject isEqual:maxObject]);

        AllTypesObject* selectedMinObject = [self.table getObjectWhere:AllTypesObject.type == minObject.type];
        TestCaseAssertTrue([selectedMinObject isEqual:minObject]);

        AllTypesObject* selectedEmptyObject = [self.table getObjectWhere:AllTypesObject.type == emptyObject.type];
        TestCaseAssertTrue([selectedEmptyObject isEqual:emptyObject]);

        AllTypesObject* selectedNilObject = [self.table getObjectWhere:AllTypesObject.type == nilObject.type];
        TestCaseAssertTrue([selectedNilObject isEqual:nilObject]);

        self.tableClass = oldClass;
        self.tableName = oldTableName;
    }];
}

#ifndef WCDB_QUICK_TESTS
- (void)test_backup_huge_database
{
    [self
    testBackup:^{
        SizeBasedFactory* factory = [[SizeBasedFactory alloc] initWithDirectory:self.class.cacheRoot];
        factory.quality = 6LL * 1024 * 1024 * 1024; // 6GB > 4GB
        factory.tolerance = 0.02;

        [factory produce:self.path];

        TestCaseAssertTrue([self.database backup]);

        TestCaseAssertTrue([self.database corruptHeaderWithinCloseAfterTruncatedCheckpoint]);

        __block double percentage = 0;
        TestCaseAssertEqual([self.database retrieve:^(double progress, double increment) {
                                WCDB_UNUSED(increment);
                                double newPercentage = progress * 100.0;
                                if (newPercentage - percentage >= 1.0) {
                                    TestCaseLog(@"Retrieving %.2f%%", newPercentage);
                                    percentage = newPercentage;
                                }
                            }],
                            1.0);
    }];
}

- (void)test_retrieve_huge_database
{
    [self
    testBackup:^{
        SizeBasedFactory* factory = [[SizeBasedFactory alloc] initWithDirectory:self.class.cacheRoot];
        factory.quality = 6LL * 1024 * 1024 * 1024; // 6GB > 4GB
        factory.tolerance = 0.02;

        [factory produce:self.path];

        __block double percentage = 0;
        TestCaseAssertEqual([self.database retrieve:^(double progress, double increment) {
                                WCDB_UNUSED(increment);
                                double newPercentage = progress * 100.0;
                                if (newPercentage - percentage >= 1.0) {
                                    TestCaseLog(@"Retrieving %.2f%%", newPercentage);
                                    percentage = newPercentage;
                                }
                            }],
                            1.0);
    }];
}
#endif

@end
