# dbg-scripts 🛠️

Random scripts to aid debugging on Windows. 🪟

## Disclaimer ⚠️

These scripts are provided **as-is**. They were written a long time ago for older
Windows debugging setups and may not be completely functional on modern Windows
machines without changes to paths, tools, symbols, or environment setup.

Most of the scripts assume you already have the Windows debugging tools
installed, and some of them also expect additional tools such as ADPlus or
Application Verifier.

## Scripts 📚

### APITracer/CreateCdbScripts.bat 🔎

Creates two CDB script files (`scriptDbg.txt` and `scriptBP.txt`) that can be
used to record CLR API usage based on entries from `APITracer/APIs.csv`.

Usage:

```bat
CreateCdbScripts.bat [option [options]...] [/noisy]
```

Options:

- `/dbg` - record debugging (`ICorDebug*`) APIs
- `/prf` - record profiling (`ICorProfiler*`) APIs
- `/sym` - record symbol-store APIs
- `/metadata` - record metadata APIs
- `/hosting` - record hosting APIs
- `/noisy` - include frequently used APIs that are skipped by default

Example:

```bat
CreateCdbScripts.bat /dbg /prf
```

Generated debugger usage (from the script comments):

```bat
cdb -cf "scriptdbg.txt" -G -o [filename]
cdb -cf "scriptdbg.txt" -G -o -p [process id]
cdb -cf "scriptdbg.txt" -G -o -pn [process name]
```

Notes:

- Reads API definitions from `APITracer/APIs.csv`
- The script comments note that private symbols may be required for breakpoints
  to bind correctly

### APITracer/APIs.csv 🧾

Companion data file used by `CreateCdbScripts.bat`. It contains the API list,
categories, and breakpoint locations used to generate the CDB scripts.

### SerialDumper/serialdumper.bat 💾

Launches ADPlus to grab process dumps at periodic intervals.

Usage:

```bat
serialdumper.bat <program> <args to program>
serialdumper.bat -p <process id>
serialdumper.bat -pn <process name>
serialdumper.bat -cleanup
```

Notes:

- Assumes ADPlus, CDB, and related debugging tools are already installed
- The script comments note that it should be run from an elevated window on
  Vista and later

### TraverseHeap/traverseheap.bat 🧠

Uses CDB to attach to a process, runs `!traverseheap`, and writes the XML output
to a timestamped file under `%TEMP%\DUMPS`.

Usage:

```bat
traverseheap.bat -p <process id>
traverseheap.bat -pn <process name>
```

Notes:

- The script assumes a CLR v4 process by default
- For CLR v2 processes, the script comments say the SOS load command may need to
  be changed from `.loadby sos clr` to `.loadby sos mscorwks`
- Assumes CDB and related debugging tools are already installed

### AppverifierScripts/InstallAppVerifier.bat ✅

Installs or uninstalls Application Verifier.

Usage:

```bat
InstallAppVerifier.bat install
InstallAppVerifier.bat uninstall
```

Notes:

- Intended to be run elevated
- The script expects an Application Verifier MSI layout relative to the script

### AppverifierScripts/RunUnderAppVerifier.bat 🧪

Runs a target executable under Application Verifier.

Usage:

```bat
RunUnderAppVerifier.bat <program> <args to program>
```

Notes:

- If the first argument is not an `.exe`, the script simply runs the command as-is
- The script comments note that the environment must already be initialized and
  that AppVerifier must already be installed

### DumpPID/dumppid.txt 📦

CDB command script that creates a full dump, captures module and stack
information, copies symbols and binaries into a temporary folder, and opens the
result in Explorer.

Example usage:

```bat
cdb -cf DumpPID\dumppid.txt -p <process id>
```

### DumpPID/dumpproc.txt 📂

Companion CDB command script similar to `dumppid.txt`.

Example usage:

```bat
cdb -cf DumpPID\dumpproc.txt -pn <process name>
```
