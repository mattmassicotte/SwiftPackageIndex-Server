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


extension PackageController.PackageResult {

    func authors() -> [Link]? {
        // TODO: fill in
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/175
        return nil
    }

    func activity() -> PackageShow.Model.Activity? {
        guard repository.lastPullRequestClosedAt != nil else { return nil }

        let openIssues = Link(label: pluralizedCount(repository.openIssues, singular: "open issue"),
                              url: package.url.droppingGitExtension + "/issues")
        let openPRs = Link(label: pluralizedCount(repository.openPullRequests, singular: "open pull request"),
                           url: package.url.droppingGitExtension + "/pulls")
        let lastIssueClosed = repository.lastIssueClosedAt.map { "\(date: $0, relativeTo: Current.date())" }
        let lastPRClosed = repository.lastPullRequestClosedAt.map { "\(date: $0, relativeTo: Current.date())" }
        return .init(openIssuesCount: repository.openIssues,
                     openIssues: openIssues,
                     openPullRequests: openPRs,
                     lastIssueClosedAt: lastIssueClosed,
                     lastPullRequestClosedAt: lastPRClosed)
    }

}


// MARK: - Build info


extension PackageController.PackageResult {

    typealias BuildInfo = PackageShow.Model.BuildInfo
    typealias NamedBuildResults = PackageShow.Model.NamedBuildResults
    typealias SwiftVersionResults = PackageShow.Model.SwiftVersionResults
    typealias PlatformResults = PackageShow.Model.PlatformResults

    func swiftVersionBuildInfo() -> BuildInfo<SwiftVersionResults>? {
        .init(
            stable: versions.latest(for: .release).flatMap(Self.buildResults),
            beta: versions.latest(for: .preRelease).flatMap(Self.buildResults),
            latest: versions.latest(for: .defaultBranch).flatMap(Self.buildResults))

    }

    func platformBuildInfo() -> BuildInfo<PlatformResults>? {
        .init(
            stable: versions.latest(for: .release).flatMap(Self.buildResults),
            beta: versions.latest(for: .preRelease).flatMap(Self.buildResults),
            latest: versions.latest(for: .defaultBranch).flatMap(Self.buildResults)
        )
    }

    static func buildResults(_ version: Version) -> NamedBuildResults<SwiftVersionResults>? {
        guard let builds = version.$builds.value,
              let referenceName = version.reference?.description else { return nil }
        // For each reported swift version pick major/minor version matches
        let v5_1 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_1) }
        let v5_2 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_2) }
        let v5_3 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_3) }
        let v5_4 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_4) }
        let v5_5 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_5) }
        // ... and report the status
        return
            .init(referenceName: referenceName,
                  results: .init(status5_1: v5_1.buildStatus,
                                 status5_2: v5_2.buildStatus,
                                 status5_3: v5_3.buildStatus,
                                 status5_4: v5_4.buildStatus,
                                 status5_5: v5_5.buildStatus)
            )
    }

    static func buildResults(_ version: Version) -> NamedBuildResults<PlatformResults>? {
        guard let builds = version.$builds.value,
              let referenceName = version.reference?.description else { return nil }
        // For each reported platform pick appropriate build matches
        let ios = builds.filter { $0.platform.isCompatible(with: .ios) }
        let linux = builds.filter { $0.platform.isCompatible(with: .linux) }
        let macos = builds.filter { $0.platform.isCompatible(with: .macos) }
        let macosArm = builds.filter { $0.platform.isCompatible(with: .macosArm) }
        let tvos = builds.filter { $0.platform.isCompatible(with: .tvos) }
        let watchos = builds.filter { $0.platform.isCompatible(with: .watchos) }
        // ... and report the status
        return
            .init(referenceName: referenceName,
                  results: .init(iosStatus: ios.buildStatus,
                                 linuxStatus: linux.buildStatus,
                                 macosStatus: macos.buildStatus,
                                 macosArmStatus: macosArm.buildStatus,
                                 tvosStatus: tvos.buildStatus,
                                 watchosStatus: watchos.buildStatus)
            )
    }

}


extension Array where Element == Build {
    var buildStatus: PackageShow.Model.BuildStatus {
        guard !isEmpty else { return .unknown }
        if anySucceeded {
            return .compatible
        } else {
            return anyPending ? .unknown : .incompatible
        }
    }
}


private extension Build.Platform {
    func isCompatible(with other: PackageShow.Model.PlatformCompatibility) -> Bool {
        switch self {
            case .ios:
                return other == .ios
            case .macosSpm, .macosXcodebuild:
                return other == .macos
            case .macosSpmArm, .macosXcodebuildArm:
                return other == .macosArm
            case .tvos:
                return other == .tvos
            case .watchos:
                return other == .watchos
            case .linux:
                return other == .linux
        }
    }
}
