# Debugger Script Assessment (2026-03-29)

## Scope

This report assesses the scripts currently committed in this repository:

- `APITracer/CreateCdbScripts.bat`
- `APITracer/APIs.csv`
- `SerialDumper/serialdumper.bat`
- `TraverseHeap/traverseheap.bat`
- `AppverifierScripts/InstallAppVerifier.bat`
- `AppverifierScripts/RunUnderAppVerifier.bat`
- `DumpPID/dumppid.txt`
- `DumpPID/dumpproc.txt`

The goal of this document is to determine whether these scripts are likely to be functional on a modern Windows 10/11 machine with current debugging tools, and what would need to change or be provided to make them usable.

## Methodology

This assessment is based on:

1. Static review of every committed script and data file in the repository.
2. Review of the scripts' inline comments and assumptions.
3. Cross-checking those assumptions against current Microsoft documentation for:
   - Debugging Tools for Windows / WinDbg installation
   - Managed-code debugging with Windows debuggers
   - Application Verifier
   - Windows SDK distribution model
4. Historical context from the repository author's blog post:
   - https://mithunshanbhag.github.io/2018/11/13/awesome-dev-tools-that-I-rarely-use-now.html

## Important limitation

This repository was assessed from a Linux sandbox, not from a Windows host with the debuggers installed. That means:

- I **did not execute** the `.bat` files.
- I **did not attach** WinDbg/CDB/NTSD to live Windows processes.
- I **did not install** Debugging Tools for Windows or Application Verifier in this environment.

So the verdicts below are a combination of static correctness, dependency availability, and modern compatibility risk. Where I say "functional," that means "appears viable on a modern Windows machine if the documented prerequisites are met," not "executed and proven in this sandbox."

## Current debugger/tooling landscape

Based on current Microsoft documentation and current distribution guidance:

- WinDbg is still supported and installable through the Microsoft Store / winget, and the classic debugger package is still available through the Windows SDK / WDK.
- CDB, KD, NTSD, GFlags, and UMDH remain part of the broader Debugging Tools for Windows family.
- Application Verifier is still documented and supported.
- Modern installations typically place the classic debugger tools under a Windows Kits path rather than an old custom path like `C:\tools\dbg\`.
- Managed-code debugging on current systems is more complex than it was in the Windows 7 / .NET Framework era, especially when the target is .NET Core / .NET 5+ / .NET 6+ / .NET 8+ rather than .NET Framework.

Useful references:

- https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/debugger-download-tools
- https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/
- https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/debugging-managed-code
- https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/application-verifier
- https://learn.microsoft.com/en-us/windows/apps/windows-sdk/downloads

## Executive summary

### Overall state

The repository is **not uniformly dead**, but it is **firmly rooted in a Windows 7 / old .NET Framework / old internal-lab setup**.

### High-level conclusion

- The **plain debugger command scripts** in `DumpPID/` look the healthiest and are the most likely to still work with little or no change.
- The **CDB script generator** in `APITracer/` is structurally sound, but only for a narrow, legacy scenario where the expected CLR modules and private symbols are available.
- The **batch wrappers** in `SerialDumper/`, `TraverseHeap/`, and `AppverifierScripts/` are the most fragile because they rely on:
  - hardcoded install paths,
  - old debugger layout assumptions,
  - older CLR naming/loading conventions,
  - or an internal environment that is not present in this repository.

### Verdict summary

| Path | Verdict | Confidence | Main reason |
|---|---|---:|---|
| `APITracer/CreateCdbScripts.bat` | Functional with setup | Medium | Batch logic is mostly fine, but usefulness depends on legacy CLR/private symbol availability |
| `APITracer/APIs.csv` | Valid data, legacy-targeted | High | Data file is intact, but the breakpoint targets are from old CLR/DBI scenarios |
| `SerialDumper/serialdumper.bat` | Likely broken | High | Hardcoded debugger path and dependence on old ADPlus automation |
| `TraverseHeap/traverseheap.bat` | Partially functional | High | Core idea still valid, but hardcoded CDB path and old CLR assumptions make it fragile |
| `AppverifierScripts/InstallAppVerifier.bat` | Functional with missing payload/setup | High | Script is simple, but required MSI payload is not in the repo |
| `AppverifierScripts/RunUnderAppVerifier.bat` | Partially functional / environment-bound | High | Depends on non-public env vars and directory layout not present here |
| `DumpPID/dumppid.txt` | Likely functional | Medium-High | Pure CDB command script with stable commands |
| `DumpPID/dumpproc.txt` | Likely functional | Medium-High | Same as above; appears to be a duplicate variant |

## Detailed assessment

---

## 1. `APITracer/CreateCdbScripts.bat`

### What it does

This batch file generates two debugger command files:

- `scriptDbg.txt`
- `scriptBP.txt`

It reads `APIs.csv`, filters APIs by category (`/dbg`, `/prf`, `/sym`, `/metadata`, `/hosting`), and emits unresolved CDB breakpoints that log whenever those APIs are called.

### What still looks healthy

- The batch syntax is standard and should still parse on current `cmd.exe`.
- The generated CDB commands (`bu`, `.sympath`, `.reload`, exception filter commands, `.printf`, `.logappend`) are classic debugger commands that still exist.
- It does not hardcode the debugger executable path; it only generates script files.

### What is risky / outdated

- The script itself explicitly notes that the breakpoints require **private symbols** to bind. That was already a limitation when the script was written, and it is still the biggest blocker now.
- The API list targets older CLR debugging/profiling/metadata interfaces. That aligns much more naturally with **.NET Framework-era** processes than with **CoreCLR/.NET 5+** processes.
- Several breakpoint locations in `APIs.csv` are CLR-internal names such as `mscordbi!Cordb...` and `mscordbi!Shim...`. Those names are tightly tied to a specific implementation and symbol set.
- The script assumes a workflow based on classic CDB and live breakpoint binding rather than modern trace-first or EventPipe/ETW-style diagnostics.

### As-is verdict

**Functional with setup** for a **legacy managed debugging scenario** where all of the following are true:

- CDB is available.
- The target is a matching .NET Framework-era scenario.
- The needed private symbols are available.
- The operator understands how to run the generated files under CDB.

### What would be needed to make it reliably usable today

- A documented, tested target scenario (for example: `.NET Framework 4.x process only`).
- A supported symbol story, especially if private symbols are required.
- Updated API/breakpoint targets if the goal is to support modern CoreCLR.
- A README example showing how to invoke the generated scripts with a modern debugger install.

---

## 2. `APITracer/APIs.csv`

### What it does

This is the data source for `CreateCdbScripts.bat`. It records API metadata, whether an API is noisy, and the debugger breakpoint location to bind.

### What still looks healthy

- The file is structured consistently enough for the `for /F` CSV parsing in the batch file.
- The data itself is not corrupted.
- As a repository artifact, it still conveys the intended trace surface area.

### What is risky / outdated

- Some entries do not have a breakpoint location, so those entries cannot produce useful breakpoints.
- The target interfaces and module/function names are legacy CLR/DBI-oriented.
- Even where the conceptual API still exists, the exact internal implementation symbol might not be practically bindable in a modern public setup.

### As-is verdict

**Valid data, but legacy-targeted.** It is not independently executable, and its real usefulness depends entirely on whether the old breakpoint symbols still exist and are available.

### What would be needed to make it reliably usable today

- Re-validate the breakpoint locations on a current Windows machine with current debugger bits.
- Separate rows that are still bindable from rows that are purely historical.
- Potentially split support into:
  - .NET Framework targets
  - CoreCLR targets

---

## 3. `SerialDumper/serialdumper.bat`

### What it does

This script generates an ADPlus XML configuration and then runs `adplus.vbs` to capture repeated hang-mode dumps.

### What still looks healthy

- The overall workflow is understandable and reasonable for its era.
- Using ADPlus in hang mode to gather repeated dumps was a standard pattern.

### What is risky / outdated

- It hardcodes `set DEBUGGERS_LOCATION=c:\tools\dbg\`.
  - That is the single clearest modern failure point.
  - Current debugger installs normally land under a Windows Kits path or Store app model, not `C:\tools\dbg\`.
- It assumes `adplus.vbs` exists in that location.
- ADPlus is a **legacy automation tool**; even if still obtainable in some debugger distributions, it is not the modern default workflow and is much more fragile than it used to be.
- The generated config preloads SOS with `.loadby sos clr`, which is specifically aimed at classic CLR naming, not general modern CoreCLR scenarios.
- The script contains no dependency checks before invoking `cscript %ADPLUS% ...`.

### As-is verdict

**Likely broken.**

On a typical modern Windows machine, I would expect it to fail unless someone first recreates the old debugger layout or edits the path.

### What would be needed to make it functional today

At minimum:

- Replace the hardcoded `C:\tools\dbg\` assumption with discovery of the actual debugger install path.
- Confirm that `adplus.vbs` is actually present in the installed toolset being used.
- Re-test the XML configuration against the currently shipped ADPlus/CDB behavior.
- Clarify whether the target is only .NET Framework or whether modern .NET is expected.

If maintaining this capability for current systems, a modern replacement using a currently supported dump-capture workflow would probably be more realistic than trying to preserve ADPlus indefinitely.

---

## 4. `TraverseHeap/traverseheap.bat`

### What it does

This script builds a small CDB command file, attaches to a process, runs `!traverseheap -xml heap.xml`, detaches, and moves the resulting XML file to a timestamped dump folder.

### What still looks healthy

- The overall model is simple and still conceptually valid.
- CDB attachment plus a short command file is a stable debugger workflow.
- The generated debugger commands themselves are straightforward.

### What is risky / outdated

- It hardcodes `set DEBUGGER_PATH=c:\tools\dbg\cdb.exe`.
- It assumes `.loadby sos clr`, which is specifically tailored to CLR v4 naming.
- The inline comments already admit the v2/v4 split, which is a sign the script is narrowly version-bound.
- For current .NET (CoreCLR/.NET 5+), SOS loading and DAC matching are more complicated than this script assumes.
- The timestamp logic uses `%date%` and `%time%` substring slicing. That is locale-sensitive and can break on machines that do not use the same regional format the script author expected.
- The help text at the bottom still says `dumpproc.bat`, which suggests the file was copied/adapted and not thoroughly refreshed.

### As-is verdict

**Partially functional.**

I would expect it to work only in a relatively friendly setup:

- classic CDB available,
- hardcoded path adjusted or recreated,
- target is a matching CLR process,
- system locale happens to match the timestamp parsing assumptions.

### What would be needed to make it functional today

- Replace hardcoded debugger path logic.
- Explicitly document supported runtime targets.
- Rework SOS loading for current runtime families.
- Replace locale-sensitive date parsing with a robust timestamp method.

---

## 5. `AppverifierScripts/InstallAppVerifier.bat`

### What it does

This installs or uninstalls Application Verifier by calling `msiexec` on an MSI expected to be present under a sibling `appverifier\<arch>\ApplicationVerifier.msi` directory.

### What still looks healthy

- The batch logic is simple.
- `msiexec` remains the right mechanism for MSI-based install/uninstall.
- The 32-bit vs 64-bit detection approach is old but understandable.

### What is risky / outdated

- The script assumes the Application Verifier MSI payload is present adjacent to the script. That payload is **not committed in this repository**.
- There is no existence check for the MSI before running `msiexec`.
- Modern users are more likely to install Application Verifier through the Windows SDK path than through a locally staged MSI tree next to the script.

### As-is verdict

**Functional with missing payload/setup.**

The script itself is not sophisticated enough to be the main problem. The real issue is that the repository does not contain the installer tree that the script expects.

### What would be needed to make it functional today

- Provide the expected MSI layout, or
- rewrite the usage instructions so the script points to the currently installed Application Verifier location, or
- drop the installer wrapper and just document how to install AppVerifier from the current SDK.

---

## 6. `AppverifierScripts/RunUnderAppVerifier.bat`

### What it does

This script enables multiple AppVerifier layers for a target executable, runs the process under CDB, exports the resulting AppVerifier log to XML, scans it for errors, prints the XML, and then removes the verifier settings.

### What still looks healthy

- The overall AppVerifier workflow still makes sense for native-process validation.
- The use of `appverif.exe` is still aligned with Application Verifier.
- The cleanup logic is sensible.

### What is risky / outdated

- It depends on environment variables such as `BVT_ROOT`, `EXT_ROOT`, and `_tgtcpu`.
  - Those are not set or explained anywhere in this repository.
  - They strongly suggest the script was written for an internal or lab-specific test harness.
- It expects `cdb.exe` under `%BVT_ROOT%\common\tools\%_tgtcpu%\debuggers\cdb.exe`.
  - That layout is not present in this repo and is unlikely to exist on a random external machine.
- `_NT_SYMBOL_PATH` is built from that same assumed environment.
- The debugger command string is long and brittle.
- Although AppVerifier still exists, the value proposition is much stronger for native components than for modern managed runtimes.

### As-is verdict

**Partially functional / environment-bound.**

I would not consider this a standalone public script in its current form. It looks like a wrapper around a larger test-lab environment that is absent from the repo.

### What would be needed to make it functional today

- Document every required environment variable and folder layout.
- Replace lab-specific paths with discovery of installed tools.
- Clarify supported target types (native only, native-heavy, .NET Framework only, etc.).
- Validate whether the chosen AppVerifier layers and stop settings still match intended use on current Windows versions.

---

## 7. `DumpPID/dumppid.txt`

### What it does

This is a plain CDB script that:

- sets up a symbol path,
- reloads symbols,
- creates a full dump (`.dump /ma Process.dmp`),
- captures module and stack information,
- copies the dump, symbols, and binaries into `%TEMP%\TEMP_DUMP\`,
- opens the result in Explorer.

### What still looks healthy

- The commands used are classic debugger commands that have been stable for a long time.
- It does not depend on any hardcoded debugger install path because it is a debugger command file, not a launcher.
- Its core use case is still valid.

### What is risky / outdated

- The `.shell` commands are quote-heavy and may be fragile if any file path contains awkward characters.
- The symbol-copy and binary-copy loops assume a fairly normal shell environment.
- It is more of a power-user script than a polished tool.

### As-is verdict

**Likely functional.**

Of all the assets in this repo, this is one of the better candidates to still work with only minor environmental friction.

### What would be needed to make it dependable today

- A short README example showing how to invoke it with current CDB.
- Optional cleanup of the shell quoting if someone wants it to be more robust.

---

## 8. `DumpPID/dumpproc.txt`

### What it does

It appears to be the same kind of CDB script as `dumppid.txt`, with nearly identical content.

### What still looks healthy

Same strengths as `dumppid.txt`.

### What is risky / outdated

Same shell-quoting fragility as `dumppid.txt`.

### As-is verdict

**Likely functional.**

### What would be needed to make it dependable today

Same as `dumppid.txt`.

---

## Functional grouping

### Most likely to still work with limited effort

1. `DumpPID/dumppid.txt`
2. `DumpPID/dumpproc.txt`
3. `APITracer/CreateCdbScripts.bat` (but only in a narrow legacy scenario)

### Probably usable only after environment repair

1. `TraverseHeap/traverseheap.bat`
2. `AppverifierScripts/InstallAppVerifier.bat`
3. `AppverifierScripts/RunUnderAppVerifier.bat`

### Most likely to fail on a modern machine as-is

1. `SerialDumper/serialdumper.bat`

## Main classes of breakage across the repo

### 1. Hardcoded debugger paths

The old assumption that the tools live under `C:\tools\dbg\` is no longer reasonable for most current setups.

### 2. Old CLR naming and loading assumptions

Commands like `.loadby sos clr` assume an older CLR world. That is fine for classic .NET Framework, but it is not a generic modern managed-debugging solution.

### 3. Hidden environmental dependencies

Some scripts assume test-lab variables and directory layouts that are not included in the repo.

### 4. Private symbol dependency

At least one script is only as useful as the availability of implementation-specific private symbols.

### 5. Locale-sensitive shell logic

The timestamp generation in `TraverseHeap` is not robust across locales.

## What would need to be done to make this repo broadly usable again

If the goal is to preserve the scripts as working public utilities rather than historical artifacts, the minimum recovery plan would be:

1. **Define supported targets clearly**
   - .NET Framework only?
   - native processes only?
   - any support for .NET Core / .NET 5+?

2. **Remove hardcoded debugger paths**
   - detect installed debugger tools under Windows Kits / configured tool path.

3. **Document external prerequisites**
   - CDB / WinDbg install
   - Application Verifier install
   - symbol path requirements
   - admin/elevation requirements

4. **Separate public scripts from lab-internal scripts**
   - anything requiring `BVT_ROOT`, `EXT_ROOT`, `_tgtcpu`, or non-repo payloads should be clearly marked as environment-specific.

5. **Re-validate managed debugging assumptions**
   - especially for SOS loading, CLR/CoreCLR targeting, and symbol binding.

6. **Decide whether ADPlus remains in scope**
   - if yes, test it on a real Windows 10/11 machine with current debugger bits;
   - if not, mark `SerialDumper` as historical and recommend a modern replacement workflow.

## Suggested real-world validation order on a Windows machine

If you want to follow this assessment with actual hands-on verification, I would test in this order:

1. Install current debugger tools and verify where `cdb.exe` actually lands.
2. Run `DumpPID/dumppid.txt` manually through CDB on a simple native test process.
3. Run `DumpPID/dumpproc.txt` the same way.
4. Run `APITracer/CreateCdbScripts.bat` just to confirm it generates scripts correctly.
5. Try `TraverseHeap/traverseheap.bat` against a known .NET Framework process after fixing the debugger path locally.
6. Verify whether `adplus.vbs` is actually available before spending time on `SerialDumper`.
7. Install AppVerifier from the current SDK and test the AppVerifier scripts in an isolated VM.

## Bottom line

### If your question is: "Are these scripts still functional today?"

The honest answer is:

- **Some of them probably still are, in the right setup.**
- **Several are clearly not plug-and-play anymore.**
- **The repo as a whole should currently be treated as a historical debugging toolbox, not a modern ready-to-run toolkit.**

### File-by-file bottom line

- `DumpPID/*`: best chance of still being useful now.
- `APITracer/*`: interesting and probably salvageable for legacy CLR work, but symbol-dependent.
- `TraverseHeap/*`: concept still good, implementation assumptions are old.
- `AppverifierScripts/*`: tied to a missing environment/install layout.
- `SerialDumper/*`: weakest candidate for modern out-of-box success.

