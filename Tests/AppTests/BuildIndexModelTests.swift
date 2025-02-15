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

import Plot
import XCTVapor


class BuildIndexModelTests: AppTestCase {

    func test_init_no_name() async throws {
        // Tests behaviour when we're lacking data
        // setup package without package name
        let pkg = try savePackage(on: app.db, "1".url)
        try await Repository(package: pkg,
                             defaultBranch: "main",
                             forks: 42,
                             license: .mit,
                             name: "bar",
                             owner: "foo",
                             stars: 17,
                             summary: "summary").save(on: app.db)
        try Version(package: pkg, latest: .defaultBranch).save(on: app.db).wait()
        let (pkgInfo, buildInfo) = try await PackageController.BuildsRoute
            .query(on: app.db, owner: "foo", repository: "bar")

        // MUT
        let m = BuildIndex.Model(packageInfo: pkgInfo, buildInfo: buildInfo)

        // validate
        XCTAssertNotNil(m)
    }

    func test_completedBuildCount() throws {
        let m = BuildIndex.Model.mock
        // mock contains build for three Swift versions, 5.3, 5.4, 5.5
        // each has the same default setup:
        // - 4 x .ok
        // - 1 x .failed
        // - 1 x .triggered
        // -> 5 completed per Swift version (4 x .ok + .failed)
        // -> 15 completed per package version
        //    (there are 3 versions, default branch, release, and beta)
        // -> 45 completed overall
        // -> 44 minus the linux/5.5 build to test .none
        // -> 44 the tvos/5.5 build to test .timeout does not change the completed tally
        // -> 43 minus the watchos/5.5 build to test .infrastructureError
        // -> 43 completed in total
        XCTAssertEqual(m.completedBuildCount, 43)
    }

    func test_packageURL() throws {
        let m = BuildIndex.Model.mock
        XCTAssertEqual(m.packageURL, "/foo/foobar")
    }

    func test_buildMatrix() throws {
        // setup
        let id = UUID()
        let stable: [BuildInfo] = [
            .init(id: id, swiftVersion: .init(5, 6, 0), platform: .ios, status: .ok),
            .init(id: id, swiftVersion: .init(5, 5, 0), platform: .macosXcodebuild, status: .ok),
            .init(id: id, swiftVersion: .init(5, 4, 0), platform: .tvos, status: .ok),
        ]
        let latest: [BuildInfo] = [
            .init(id: id, swiftVersion: .init(5, 5, 0), platform: .macosSpm, status: .failed),
            .init(id: id, swiftVersion: .init(5, 4, 0), platform: .tvos, status: .ok),
        ]
        let model = BuildIndex.Model.init(owner: "foo",
                                          ownerName: "Foo",
                                          repositoryName: "bar",
                                          packageName: "bar",
                                          buildGroups: [
                                            .init(name: "1.2.3", kind: .release, builds: stable),
                                            .init(name: "2.0.0-b1", kind: .preRelease, builds: []),
                                            .init(name: "main", kind: .defaultBranch, builds: latest),
                                          ])

        // MUT
        let matrix = model.buildMatrix

        // validate
        XCTAssertEqual(matrix.values.keys.count, 24)
        XCTAssertEqual(
            matrix.values[.init(swiftVersion: .v5_6, platform: .ios)]?.map(\.column.label),
            ["1.2.3", "2.0.0-b1", "main"]
        )
        XCTAssertEqual(
            matrix.values[.init(swiftVersion: .v5_6, platform: .ios)]?.map(\.value?.status),
            .some([.ok, nil, nil])
        )
        XCTAssertEqual(
            matrix.values[.init(swiftVersion: .v5_5,
                                platform: .macosXcodebuild)]?.map(\.value?.status),
            [.ok, nil, nil]
        )
        XCTAssertEqual(
            matrix.values[.init(swiftVersion: .v5_5, platform: .macosSpm)]?.map(\.value?.status),
            [nil, nil, .failed]
        )
        XCTAssertEqual(
            matrix.values[.init(swiftVersion: .v5_4, platform: .tvos)]?.map(\.value?.status),
            [.ok, nil, .ok]
        )
    }

    func test_buildMatrix_no_beta() throws {
        // Test BuildMatrix mapping, in particular absence of a beta version
        // setup
        let id = UUID()
        let stable: [BuildInfo] = [
            .init(id: id, swiftVersion: .init(5, 6, 0), platform: .ios, status: .ok),
            .init(id: id, swiftVersion: .init(5, 5, 0), platform: .macosXcodebuild, status: .ok),
            .init(id: id, swiftVersion: .init(5, 4, 0), platform: .tvos, status: .ok),
        ]
        let latest: [BuildInfo] = [
            .init(id: id, swiftVersion: .init(5, 5, 0), platform: .macosSpm, status: .failed),
            .init(id: id, swiftVersion: .init(5, 4, 0), platform: .tvos, status: .ok),
        ]
        let model = BuildIndex.Model.init(owner: "foo",
                                          ownerName: "Foo",
                                          repositoryName: "bar",
                                          packageName: "bar",
                                          buildGroups: [
                                            .init(name: "1.2.3", kind: .release, builds: stable),
                                            .init(name: "main", kind: .defaultBranch, builds: latest),
                                          ])

        // MUT
        let matrix = model.buildMatrix

        // validate
        XCTAssertEqual(matrix.values.keys.count, 24)
        XCTAssertEqual(
            matrix.values[.init(swiftVersion: .v5_6, platform: .ios)]?.map(\.column.label),
            ["1.2.3", "main"]
        )
        XCTAssertEqual(
            matrix.values[.init(swiftVersion: .v5_6, platform: .ios)]?.map(\.value?.status),
            [.ok, nil]
        )
        XCTAssertEqual(
            matrix.values[.init(swiftVersion: .v5_5,
                                platform: .macosXcodebuild)]?.map(\.value?.status),
            [.ok, nil]
        )
        XCTAssertEqual(
            matrix.values[.init(swiftVersion: .v5_5,
                                platform: .macosSpm)]?.map(\.value?.status),
            [nil, .failed]
        )
        XCTAssertEqual(
            matrix.values[.init(swiftVersion: .v5_4, platform: .tvos)]?.map(\.value?.status),
            [.ok, .ok]
        )
    }

    func test_BuildCell() throws {
        let id = UUID()
        XCTAssertEqual(BuildCell("1.2.3", .release, id, .ok).node.render(), """
            <div class="succeeded"><a href="/builds/\(id.uuidString)">Build Succeeded</a></div>
            """)
        XCTAssertEqual(BuildCell("1.2.3", .release, id, .failed).node.render(), """
            <div class="failed"><a href="/builds/\(id.uuidString)">Build Failed</a></div>
            """)
        XCTAssertEqual(BuildCell("1.2.3", .release).node.render(), """
            <div><span>Build Pending</span></div>
            """)
    }

    func test_BuildItem() throws {
        // setup
        let id = UUID()
        let bi = BuildItem(index: .init(swiftVersion: .v5_7, platform: .ios),
                           values: [.init("1.2.3", .release, id, .ok),
                                    .init("2.0.0-b1", .preRelease),
                                    .init("develop", .defaultBranch, id, .failed)])

        // MUT - altogether now
        let node = bi.node

        let expectation: Node<HTML.ListContext> = .li(
            .class("row"),
            .div(
                .class("row-labels"),
                .strong("iOS")
            ),
            .div(
                .class("column-labels"),
                .div(.span(.class("stable"), .text("1.2.3"))),
                .div(.span(.class("beta"), .text("2.0.0-b1"))),
                .div(.span(.class("branch"), .text("develop")))
            ),
            .div(
                .class("results"),
                .div(.class("succeeded"), .a(.href("/builds/\(id.uuidString)"), .text("Build Succeeded"))),
                .div(.span(.text("Build Pending"))),
                .div(.class("failed"), .a(.href("/builds/\(id.uuidString)"), .text("Build Failed")))
            )
        )
        XCTAssertEqual(node.render(), expectation.render())
   }

}


fileprivate typealias BuildCell = BuildIndex.Model.BuildCell
fileprivate typealias BuildInfo = BuildIndex.Model.BuildInfo
fileprivate typealias BuildItem = BuildIndex.Model.BuildItem
fileprivate typealias RowIndex = BuildIndex.Model.RowIndex
