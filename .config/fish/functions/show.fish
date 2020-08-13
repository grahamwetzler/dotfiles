function show
    # Unset the hidden flag to show the file in Macos Finder.app
    chflags nohidden $argv[1]
end