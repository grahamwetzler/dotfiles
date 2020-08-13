function hide
    # Set the hidden flag to hide the file in Macos Finder.app
    chflags hidden $argv[1]
end