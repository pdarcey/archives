#!/usr/bin/env xcrun swift

import Foundation

/*
    Group Files
    ===========
    Look for folders that contain the string " - " and group them by whatever precedes that string
    (i.e. look for (and, if necessary, create) a folder with the prefix and move matching folders/files into that folder)
    
*/

// MARK: - Setup (Read command-line variables and set defaults)

/// Group Files
/// Structure used to parse/store input variables from the command line
/// Also sets default values
func setup(_ commandLineArguments: [String]? = CommandLine.arguments) {
    // Set default values
    let defaultFolderPath: String = "/Volumes/Archives/Sets"
    var folderURL: URL = URL.init(fileURLWithPath: defaultFolderPath)
    var deleteDuplicates = false
        
    // Process launch arguments
    // http://ericasadun.com/2014/06/12/swift-at-the-command-line/
    if let arguments = commandLineArguments {
        for (index, argument) in arguments.dropFirst().enumerated() {
            switch argument.first! {
            case "/".first!:
                folderURL = URL.init(fileURLWithPath: argument)
                
            case "-".first!:
                switch argument {
                case "-h", "-help", "-?":			 // Help
                    displaySyntaxError()
                case "-o", "-output":			     // Alternative folder path
                    folderURL = URL.init(fileURLWithPath: arguments[index + 1])
                case "-d":                           // Delete duplicates
                    deleteDuplicates = true
                default:
                    displaySyntaxError()
                }
            default:
                displaySyntaxError()
            }
        }
    }
    
    groupFiles(folderURL, deleteDuplicates: deleteDuplicates)
}

/// Add error message to Setup
func displaySyntaxError(_ additionalMessage: String? = nil) {
    print("\nusage: groupFiles [-o /path/to/folder] [-h, -help]")
    if let message = additionalMessage {
        print("\(message)\n")
    }
    print("OPTIONS\n")
    print("-o /path/to/folder   Default is /Volumes/Archives/Sets")
    print("-h, -help            This help message")
    exit(0)
}

/// Group Files
func groupFiles(_ url: URL, deleteDuplicates: Bool = false) {
    let fileManager = FileManager.default
    var filesFound = 0
    var newFolders: Set<String> = []
    var otherProblems: Set<String> = []
    var allNames: Set<String> = []
    
    do {
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)             // [URL]
        let contentsNames = contents.map { $0.lastPathComponent }    // [String]
        for fileOrFolder in contents {
            if let names = getPrefix(fileOrFolder) {
                filesFound += 1
                // Move the folder into the first name's folder
                let name = names[0].trimmingCharacters(in: CharacterSet.init(charactersIn: " "))
                allNames.insert(name)
                if !contentsNames.contains(name) {
                    do {
                        try fileManager.createDirectory(at: url.appendingPathComponent(name), withIntermediateDirectories: true)
                        newFolders.insert(name)
                    } catch {
                        otherProblems.insert("Error creating directory \(url.appendingPathComponent(name))")
                    }
                }
                let firstNameURL = url.appendingPathComponent(name)
                let results = moveFile(fileOrFolder, to: firstNameURL, deleteDuplicates: deleteDuplicates)
                otherProblems = otherProblems.union(results)
                
                // Create symlinks/aliases for each name except the first
                for aName in names.dropFirst() {
                    let name = aName.trimmingCharacters(in: CharacterSet.init(charactersIn: " "))
                    if !contentsNames.contains(name) {
                        do {
                            try fileManager.createDirectory(at: url.appendingPathComponent(name), withIntermediateDirectories: true)
                            newFolders.insert(name)
                        } catch {
                            otherProblems.insert("Error creating directory \(url.appendingPathComponent(name))")
                        }
                    }
                    let results = makeLink(at: url.appendingPathComponent(name).appendingPathComponent(fileOrFolder.lastPathComponent), to: firstNameURL.appendingPathComponent(fileOrFolder.lastPathComponent))
                    otherProblems = otherProblems.union(results)
                    allNames.insert(name)
                }
            }
        }
    } catch {
        otherProblems.insert("Could not get contents of directory at \(url)")
    }
    
    // Print output
    print("\(filesFound) folders processed\n\nModified \(allNames.sorted())\n\n\(newFolders.count) folders created: \(newFolders.sorted())\n\n\(otherProblems.count) Problems:")
    for problem in otherProblems.sorted() {
        print("\(problem)")
    }
}


func getPrefix(_ url: URL) -> [String]? {
    let characterSet = CharacterSet.init(charactersIn: ",&")
    let fullName = url.lastPathComponent
    let allNames = fullName.components(separatedBy: " - ")
    if allNames.count > 1 {
        
        return allNames[0].components(separatedBy: characterSet)
    }
    
    return nil
}

func makeLink(at url: URL, to fileOrFolder: URL) -> Set<String> {
    var otherProblems: Set<String> = []
    let fileManager = FileManager.default
    // Resolve symbolic link for destination, if necessary
    do {
        // If url is not an alias, this resolves to url
        let toURL = try URL.init(resolvingAliasFileAt: url)
    
        if !fileManager.fileExists(atPath: toURL.path) {
            do {
                try fileManager.createSymbolicLink(at: toURL, withDestinationURL: fileOrFolder)
            } catch {
                otherProblems.insert("Error creating alias at  \(url.path) for \(fileOrFolder.path)")
            }
        } else {
            otherProblems.insert("Duplicate: File/link (\(toURL.lastPathComponent)) already exists")
        }
    } catch {
        otherProblems.insert("Destination is not a valid URL")
    }
    
    return otherProblems
}

func moveFile(_ fileOrFolder: URL, to url: URL, deleteDuplicates: Bool) -> Set<String> {
    var otherProblems: Set<String> = []
    let fileManager = FileManager.default
    // Resolve symbolic link for destination, if necessary
    do {
        // If url is not an alias, this resolves to url
        let toURL = try URL.init(resolvingAliasFileAt: url)
    
        var isDirectory: ObjCBool = ObjCBool(false)
        if fileManager.fileExists(atPath: toURL.path, isDirectory: &isDirectory) {
            let name = fileOrFolder.lastPathComponent
            if !fileManager.fileExists(atPath: toURL.appendingPathComponent(name).path) {
                do {
                    try fileManager.moveItem(at: fileOrFolder, to: toURL.appendingPathComponent(name))
                } catch {
                    otherProblems.insert("Failed to move \(fileOrFolder.lastPathComponent) to \(url)\nError: \(error)")
                }
            } else {
                if deleteDuplicates {
                    let results = deleteFolder(fileOrFolder)
                    otherProblems = otherProblems.union(results)
                } else {
                    otherProblems.insert("Duplicate: \(fileOrFolder.lastPathComponent)")
                }
            }
        } else {
                otherProblems.insert("Destination (\(toURL)) is not a directory")
        }
    } catch {
        otherProblems.insert("Destination is not a valid URL")
    }
    
    return otherProblems
}

func deleteFolder(_ folder: URL) -> Set<String> {
    var otherProblems: Set<String> = []
    let fileManager = FileManager.default
    do {
        try fileManager.removeItem(at: folder)
        otherProblems.insert("Duplicate: \(folder.lastPathComponent) (deleted)")
    } catch {
        otherProblems.insert("Failed to delete duplicate:\(folder.lastPathComponent)\nError: \(error)")
    }

    return otherProblems
}

// Script
setup()


