// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SQLKit

/// Filters by the date in which the package's main branch was last updated.
///
/// Dates must be provided in the `YYYY-MM-DD` format.
///
/// Examples:
/// ```
/// last_commit:2020-07-01  - Last commit made on exactly July 1st 2020
/// last_commit:!2020-07-01 - Last commit made on any day other than July 1st 2020
/// last_commit:>2020-07-01 - Last commit made on any day more recent than July 1st 2020
/// last_commit:<2020-07-01 - Last commit made on any day older than July 1st 2020
/// ```
struct LastCommitSearchFilter: SearchFilter {
    static var key: SearchFilterKey = .lastCommit
    
    var bindableValue: Encodable
    var displayValue: String
    var operatorDescription: String
    var sqlOperator: SQLExpression

    init(value: String, comparison: SearchFilterComparison) throws {
        guard let date = DateFormatter.filterParseFormatter.date(from: value) else {
            throw SearchFilterError.invalidValueType
        }
        
        self.bindableValue = date
        self.displayValue = DateFormatter.filterDisplayFormatter.string(from: date)
        self.operatorDescription = comparison.description
        self.sqlOperator = comparison.defaultSqlOperator
    }
}
