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

@testable import App

import XCTest


class PackageResultTests: AppTestCase {
    typealias PackageResult = PackageController.PackageResult

    func test_joined5() throws {
        do {
            let pkg = try savePackage(on: app.db, "1".url)
            try Repository(package: pkg,
                           defaultBranch: "main",
                           forks: 42,
                           license: .mit,
                           name: "bar",
                           owner: "foo",
                           stars: 17,
                           summary: "summary").save(on: app.db).wait()
            do {
                try App.Version(package: pkg,
                                latest: .defaultBranch,
                                reference: .branch("main")
                ).save(on: app.db).wait()
            }
            do {
                try App.Version(package: pkg,
                                latest: .release,
                                reference: .tag(1, 2, 3)
                ).save(on: app.db).wait()
            }
            do {
                try App.Version(package: pkg,
                                latest: .preRelease,
                                reference: .tag(2, 0, 0, "b1")
                ).save(on: app.db).wait()
            }
        }

        // MUT
        let res = try PackageController.PackageResult
            .query(on: app.db, owner: "foo", repository: "bar").wait()

        // validate
        XCTAssertEqual(res.model.url, "1")
        XCTAssertEqual(res.repository.name, "bar")
        XCTAssertEqual(res.defaultBranchVersion.reference, .branch("main"))
        XCTAssertEqual(res.releaseVersion?.reference, .tag(1, 2, 3))
        XCTAssertEqual(res.preReleaseVersion?.reference, .tag(2, 0, 0, "b1"))
    }

    func test_joined5_no_preRelease() throws {
        do {
            // FIXME: add unrelated package and version to test right/left join correctness
            let pkg = try savePackage(on: app.db, "1".url)
            try Repository(package: pkg,
                           defaultBranch: "main",
                           forks: 42,
                           license: .mit,
                           name: "bar",
                           owner: "foo",
                           stars: 17,
                           summary: "summary").save(on: app.db).wait()
            do {
                try App.Version(package: pkg,
                                latest: .defaultBranch,
                                reference: .branch("main")
                ).save(on: app.db).wait()
            }
            do {
                try App.Version(package: pkg,
                                latest: .release,
                                reference: .tag(1, 2, 3)
                ).save(on: app.db).wait()
            }
        }

        // MUT
        let res = try PackageController.PackageResult
            .query(on: app.db, owner: "foo", repository: "bar").wait()

        // validate
        XCTAssertEqual(res.model.url, "1")
        XCTAssertEqual(res.repository.name, "bar")
        XCTAssertEqual(res.defaultBranchVersion.reference, .branch("main"))
        XCTAssertEqual(res.releaseVersion?.reference, .tag(1, 2, 3))
    }

    func test_joined5_defaultBranch_only() throws {
        do {
            // FIXME: add unrelated package and version to test right/left join correctness
            let pkg = try savePackage(on: app.db, "1".url)
            try Repository(package: pkg,
                           defaultBranch: "main",
                           forks: 42,
                           license: .mit,
                           name: "bar",
                           owner: "foo",
                           stars: 17,
                           summary: "summary").save(on: app.db).wait()
            do {
                try App.Version(package: pkg,
                                latest: .defaultBranch,
                                reference: .branch("main")
                ).save(on: app.db).wait()
            }
        }

        // MUT
        let res = try PackageController.PackageResult
            .query(on: app.db, owner: "foo", repository: "bar").wait()

        // validate
        XCTAssertEqual(res.model.url, "1")
        XCTAssertEqual(res.repository.name, "bar")
        XCTAssertEqual(res.defaultBranchVersion.reference, .branch("main"))
    }

    func test_query_owner_repository() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       defaultBranch: "main",
                       forks: 42,
                       license: .mit,
                       name: "bar",
                       owner: "foo",
                       stars: 17,
                       summary: "summary").save(on: app.db).wait()
        let version = try App.Version(package: pkg,
                                      latest: .defaultBranch,
                                      packageName: "test package",
                                      reference: .branch("main"))
        try version.save(on: app.db).wait()

        // MUT
        let res = try PackageResult.query(on: app.db, owner: "foo", repository: "bar").wait()

        // validate
        XCTAssertEqual(res.package.id, pkg.id)
        XCTAssertEqual(res.repository.name, "bar")
    }

    func test_query_owner_repository_case_insensitivity() throws {
        // setup
        let pkg = try savePackage(on: app.db, "1".url)
        try Repository(package: pkg,
                       defaultBranch: "main",
                       forks: 42,
                       license: .mit,
                       name: "bar",
                       owner: "foo",
                       stars: 17,
                       summary: "summary").save(on: app.db).wait()
        let version = try App.Version(package: pkg,
                                      latest: .defaultBranch,
                                      packageName: "test package",
                                      reference: .branch("main"))
        try version.save(on: app.db).wait()

        // MUT
        let res = try PackageResult.query(on: app.db, owner: "Foo", repository: "bar").wait()

        // validate
        XCTAssertEqual(res.package.id, pkg.id)
    }

    func test_activity() throws {
        // setup
        let m: TimeInterval = 60
        let H = 60*m
        let d = 24*H
        let pkg = try savePackage(on: app.db, "https://github.com/Alamofire/Alamofire")
        try Repository(package: pkg,
                       lastIssueClosedAt: Date(timeIntervalSinceNow: -5*d),
                       lastPullRequestClosedAt: Date(timeIntervalSinceNow: -6*d),
                       name: "bar",
                       openIssues: 27,
                       openPullRequests: 1,
                       owner: "foo").create(on: app.db).wait()
        try Version(package: pkg, latest: .defaultBranch).save(on: app.db).wait()
        let pr = try PackageResult.query(on: app.db, owner: "foo", repository: "bar")
            .wait()

        // MUT
        let res = pr.activity()

        // validate
        XCTAssertEqual(res,
                       .init(openIssuesCount: 27,
                             openIssues: .init(label: "27 open issues",
                                               url: "https://github.com/Alamofire/Alamofire/issues"),
                             openPullRequests: .init(label: "1 open pull request",
                                                     url: "https://github.com/Alamofire/Alamofire/pulls"),
                             lastIssueClosedAt: "5 days ago",
                             lastPullRequestClosedAt: "6 days ago"))
    }

    func test_buildResults_swiftVersions() throws {
        // Test build success reporting - we take any success across platforms
        // as a success for a particular x.y swift version (4.2, 5.0, etc, i.e.
        // ignoring swift patch versions)
        
        // setup
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p, reference: .branch("main"))
        try v.save(on: app.db).wait()
        func makeBuild(_ status: Build.Status, _ platform: Build.Platform, _ version: SwiftVersion) throws {
            try Build(version: v, platform: platform, status: status, swiftVersion: version)
                .save(on: app.db)
                .wait()
        }
        // 5.1 - failed
        try makeBuild(.failed, .ios, .v5_1)
        try makeBuild(.failed, .macosXcodebuild, .v5_1)
        // 5.2 - no data - unknown
        // 5.3 - ok
        try makeBuild(.ok, .macosXcodebuild, .v5_3)
        // 5.4 - ok
        try makeBuild(.failed, .ios, .v5_3)
        try makeBuild(.ok, .macosXcodebuild, .v5_4)
        // 5.5 - ok
        try makeBuild(.failed, .ios, .v5_4)
        try makeBuild(.ok, .macosXcodebuild, .v5_5)
        try v.$builds.load(on: app.db).wait()

        // MUT
        let res: NamedBuildResults<SwiftVersionResults>? = PackageResult.buildResults(v)

        // validate
        XCTAssertEqual(res?.referenceName, "main")
        XCTAssertEqual(res?.results.v5_1, .init(parameter: .v5_1, status: .incompatible))
        XCTAssertEqual(res?.results.v5_2, .init(parameter: .v5_2, status: .unknown))
        XCTAssertEqual(res?.results.v5_3, .init(parameter: .v5_3, status: .compatible))
        XCTAssertEqual(res?.results.v5_4, .init(parameter: .v5_4, status: .compatible))
        XCTAssertEqual(res?.results.v5_5, .init(parameter: .v5_5, status: .compatible))
    }

    func test_buildResults_platforms() throws {
        // Test build success reporting - we take any success across swift versions
        // as a success for a particular platform
        // setup
        let p = try savePackage(on: app.db, "1")
        let v = try Version(package: p, reference: .branch("main"))
        try v.save(on: app.db).wait()
        func makeBuild(_ status: Build.Status, _ platform: Build.Platform, _ version: SwiftVersion) throws {
            try Build(version: v, platform: platform, status: status, swiftVersion: version)
                .save(on: app.db)
                .wait()
        }
        // ios - failed
        try makeBuild(.failed, .ios, .init(5, 2, 0))
        try makeBuild(.failed, .ios, .init(5, 0, 0))
        // macos - failed
        try makeBuild(.failed, .macosSpm, .init(5, 2, 0))
        try makeBuild(.failed, .macosXcodebuild, .init(5, 0, 0))
        // tvos - no data - unknown
        // watchos - ok
        try makeBuild(.failed, .watchos, .init(5, 2, 0))
        try makeBuild(.ok, .watchos, .init(5, 0, 0))
        try v.$builds.load(on: app.db).wait()

        // MUT
        let res: NamedBuildResults<PlatformResults>? = PackageResult.buildResults(v)

        // validate
        XCTAssertEqual(res?.referenceName, "main")
        XCTAssertEqual(res?.results.ios, .init(parameter: .ios, status: .incompatible))
        XCTAssertEqual(res?.results.macos, .init(parameter: .macos, status: .incompatible))
        XCTAssertEqual(res?.results.tvos, .init(parameter: .tvos, status: .unknown))
        XCTAssertEqual(res?.results.watchos, .init(parameter: .watchos, status: .compatible))
    }

    func test_swiftVersionBuildInfo() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        try Version(package: p, latest: .defaultBranch).save(on: app.db).wait()
        let v = try Version(package: p, latest: .release, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        // add builds
        try Build(version: v, platform: .macosXcodebuild, status: .ok, swiftVersion: .init(5, 3, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .ios, status: .failed, swiftVersion: .init(5, 2, 4))
            .save(on: app.db)
            .wait()
        let pr = try PackageResult.query(on: app.db, owner: "foo", repository: "bar").wait()

        // MUT
        let res = pr.swiftVersionBuildInfo()

        // validate
        XCTAssertEqual(res?.stable?.referenceName, "1.2.3")
        XCTAssertEqual(res?.stable?.results.v5_1, .init(parameter: .v5_1, status: .unknown))
        XCTAssertEqual(res?.stable?.results.v5_2, .init(parameter: .v5_2, status: .incompatible))
        XCTAssertEqual(res?.stable?.results.v5_3, .init(parameter: .v5_3, status: .compatible))
        XCTAssertEqual(res?.stable?.results.v5_4, .init(parameter: .v5_4, status: .unknown))
        XCTAssertEqual(res?.stable?.results.v5_5, .init(parameter: .v5_5, status: .unknown))
        XCTAssertNil(res?.beta)
        XCTAssertNil(res?.latest)
    }

    func test_platformBuildInfo() throws {
        // setup
        let p = try savePackage(on: app.db, "1")
        try Repository(package: p, name: "bar", owner: "foo").save(on: app.db).wait()
        try Version(package: p, latest: .defaultBranch).save(on: app.db).wait()
        let v = try Version(package: p, latest: .release, reference: .tag(.init(1, 2, 3)))
        try v.save(on: app.db).wait()
        // add builds
        try Build(version: v, platform: .macosXcodebuild, status: .ok, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        try Build(version: v, platform: .tvos, status: .failed, swiftVersion: .init(5, 2, 2))
            .save(on: app.db)
            .wait()
        let pr = try PackageResult.query(on: app.db, owner: "foo", repository: "bar").wait()

        // MUT
        let res = pr.platformBuildInfo()

        // validate
        XCTAssertEqual(res?.stable?.referenceName, "1.2.3")
        XCTAssertEqual(res?.stable?.results.ios, .init(parameter: .ios, status: .unknown))
        XCTAssertEqual(res?.stable?.results.macos, .init(parameter: .macos, status: .compatible))
        XCTAssertEqual(res?.stable?.results.tvos, .init(parameter: .tvos, status: .incompatible))
        XCTAssertEqual(res?.stable?.results.watchos, .init(parameter: .watchos, status: .unknown))
        XCTAssertNil(res?.beta)
        XCTAssertNil(res?.latest)
    }

}
