import AppKit

let args = Array(CommandLine.arguments.dropFirst())

// If command line arguments were provided (other than macOS system arguments like -psn)
let isCliInvocation = args.contains(where: { arg in
    arg.starts(with: "--") || arg.starts(with: "-") && !arg.starts(with: "-psn")
})

if isCliInvocation {
    CLI.run(arguments: args)
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
