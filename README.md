# DUTImporter4OpenPLC

Tool for importing IEC 61131-3 DUTs (such as `STRUCT`s and `ENUM`s) declared as plain text into an OpenPLC `project.json` file.
The tool parses DUT definitions from `.st` or `.txt` files and converts them into a format compatible with OpenPLC projects.
Both Linux and Windows executables are provided, but building from source is recommended as this allows easy modification.
The example types used when testing has also been provided.

## Features

The following elements are currently supported:

- Removing comments (OpenPLC does not support comments inside structs)
- Base types
- Strings
- Initial values
- Single-dimension arrays
- Multi-dimensional arrays
- Nested structs
- Arrays of user-defined types
- Enumerated types

### Build from source

Requires the Free Pascal Compiler.
This will work for both Linux and Windows:

```bash
git clone <repository-url>
cd <directory>
fpc DUTImporter4OpenPLC.pas
```

### How to use
The script expects a file or a folder containing DUTs decalred in separate .st or .txt fiels, as you would in Codesys as inputs, and
expetcs the path to your OpenPLC project. Make sure to backup your OpenPLC project before use!!!

Run from terminal (ommit "./" on Windows):

```bash
./DUTImport4OpenPLC <Path to STRUCT> <Path to project.json>
```

