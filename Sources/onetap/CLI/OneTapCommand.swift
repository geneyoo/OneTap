import ArgumentParser

@main
struct OneTapCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tap",
        abstract: "IDE-less iOS development. One tap to build, install, and run.",
        version: "1.0.0",
        subcommands: [
            ClaimCommand.self,
            ReleaseCommand.self,
            StatusCommand.self,
            RunCommand.self,
            BuildCommand.self,
            InstallCommand.self,
            LaunchCommand.self,
            LogsCommand.self,
            ScreenshotCommand.self,
            GCCommand.self,
        ],
        defaultSubcommand: StatusCommand.self
    )
}
