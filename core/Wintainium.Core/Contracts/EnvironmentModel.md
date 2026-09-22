# Wintainium Environment Model Contract

## Purpose

The environment model is the Core-owned snapshot of machine facts that can affect update planning and artifact compatibility.

It separates environment discovery from decision logic. Core obtains the facts; later decision stages consume the snapshot rather than reading process or operating-system globals independently.

## Current Facts

Get-WintainiumEnvironment returns:

- OperatingSystem — normalized operating-system family. The current Core implementation reports Windows.
- OperatingSystemVersion — operating-system version string.
- OperatingSystemBuild — operating-system build number.
- MachineArchitecture — normalized OS/machine architecture: x64, x86, arm64, arm, or unknown.
- ProcessArchitecture — normalized current process architecture: x64, x86, arm64, arm, or unknown.

MachineArchitecture is derived from the operating system architecture, not the architecture of the PowerShell process. This distinction allows a 32-bit process to describe a 64-bit operating system correctly.

## Testability

The function accepts an optional Overrides object. Overrides are a test seam and an explicit future integration seam for callers that already possess a trusted environment snapshot.

Tests can therefore exercise architecture and version-dependent decision logic without mutating the host operating system.

## Boundary

The environment model:

- does not inspect installed applications;
- does not perform provider discovery;
- does not select releases or artifacts;
- does not download or execute anything;
- does not contain GUI presentation state;
- does not persist state.

Future environment facts should be added only when a Core decision or provider contract has a concrete need for them.
