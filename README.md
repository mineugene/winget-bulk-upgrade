# winget bulk upgrade

Verify and install/upgrade multiple packages listed in `winget-upgrade.json`.

![sample run](screenshots/run_example.png)


## About

The [Windows Package Manager](https://docs.microsoft.com/en-us/windows/package-manager/winget/) is an open source client designed for command-line usage.

### Limitation to address
Currently, `winget {install,upgrade}` is unable to read multiple programs as positional arguments.

### To solve this limitation...
This script asynchronously verifies the given package names with a `winget search` query. Then it sequentially installs programs that are not already installed. If a program is already installed, the script will upgrade it if a later version exists; otherwise, the upgrade is skipped.


## Usage

:exclamation: Save all your work before running this script. See [notes](#notes) below :exclamation:

1. Update `winget-upgrade.json` with the exact package ID found using `winget search <pkg-name>`.
For example, `winget search git` shows the package ID is `Git.Git`. Therefore,
```json
{
    "programs": [
        "Git.Git"
    ]
}
```

2. In PowerShell 5.1 (admin) or later, run the following command:
```
.\winget-upgrade.ps1
```


## Notes
- Unfortunately, using winget to install some programs (e.g. Visual Studio, Microsoft Teams, LibreOffice) triggers an **automatic system restart**. See [here](https://github.com/microsoft/winget-cli/issues/229
) to follow the GitHub issue thread. Make sure to **SAVE YOUR WORK** before running any `winget {install,upgrade}` commands.
