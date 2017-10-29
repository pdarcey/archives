#!/usr/bin/env xcrun swift

import Foundation

/*
    Create Aliases
    ===========
    Read in a text file containing a list of names. Create a folder for the first name on each line, and aliases to that
    folder for subsequent names on the same line
    
*/

// MARK: - Setup (Read command-line variables and set defaults)

/// Structure used to parse/store input variables from the command line
/// Also sets default values
func setup(_ commandLineArguments: [String]? = CommandLine.arguments) {
    // Set default values
    let fileManager = FileManager.default
    let defaultFolderPath: String = "/Volumes/Archives/Sets"
    let namesTxt: String = "/Volumes/Archives/Names.txt"
    var folderURL: URL = URL.init(fileURLWithPath: defaultFolderPath)
    var namesURL: URL = URL.init(fileURLWithPath: namesTxt)
        
    // Process launch arguments
    // http://ericasadun.com/2014/06/12/swift-at-the-command-line/
    if let arguments = commandLineArguments {
        for (index, argument) in arguments.enumerated() {
            switch argument {
            case "-h", "-help", "-?":			 // Help
                displaySyntaxError()
            case "-o", "-output":			     // Alternative folder path
                folderURL = URL.init(fileURLWithPath: arguments[index + 1])
            case "-n", "-names":                 // Alternative names path
                namesURL = URL.init(fileURLWithPath: arguments[index + 1])
            default:
                print("\(argument)")
            }
        }
    }
    
    createAliases(folderURL, for:namesURL)
}

/// Add error message to Setup
func displaySyntaxError(_ additionalMessage: String? = nil) {
    print("usage: groupFiles [/path/to/folder] [-n, -names /path/to/namesFile] [-h, -help]")
    if let message = additionalMessage {
        print("\(message)\n")
    }
    print("OPTIONS\n")
    print("/path/to/folder          Default is /Volumes/Archives/Sets")
    print("-n /path/to/namesFile    Default is /Volumes/Archives/Names.txt")
    print("-h, -help                This help message")
    exit(0)
}

/// Group Files
func createAliases(_ folderURL: URL, `for` namesURL: URL) {
    var foldersCreated = 0
    var aliasesCreated = 0

    do {
        let inputNames = try String(contentsOfFile:namesURL.path, encoding: String.Encoding.utf8) 
        let lines = inputNames.components(separatedBy: "\n")
        for line in lines {
            let names = line.components(separatedBy: ", ")
            let newFolder = names.first!
            let newFolderURL = folderURL.appendingPathComponent(newFolder)
            createFolder(newFolderURL)
            foldersCreated += 1
            for name in names.dropFirst(1) {
                let aliasURL = folderURL.appendingPathComponent(name)
                createAlias(aliasURL, for:newFolderURL)
                aliasesCreated += 1
            }
        }           
    } catch let err as NSError {
    // do something with Error
    print(err)
    exit(1)
    }
    
    // Print output
    print("\(aliasesCreated) aliases created for \(foldersCreated) folders")
}

func createFolder(_ folder: URL) {
    let fileManager = FileManager.default

    if !fileManager.fileExists(atPath: folder.path) {
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            print("Error creating folder at \(folder.path)")
        }
    } else {
        print("Duplicate: File/link \(folder.lastPathComponent) already exists")
    }
}

func createAlias(_ alias: URL, `for` folder: URL) {
    let fileManager = FileManager.default

    if !fileManager.fileExists(atPath: alias.path) {
        do {
            try fileManager.createSymbolicLink(at: alias, withDestinationURL: folder)
        } catch {
            print("Error creating alias at \(alias.path) for \(folder.path)")
        }
    } else {
        print("Duplicate: File/link \(alias.lastPathComponent) already exists")
    }
}

// Script
setup()

