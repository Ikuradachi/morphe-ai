# WSL Setup Guide

Guide to set up Ubuntu on WSL and configure the Morphe AI workspace environment.

## 1. Install Ubuntu on WSL

Open PowerShell or Command Prompt as Administrator and install WSL with Ubuntu:

```powershell
wsl --install
```

If WSL is already installed, ensure the Ubuntu distribution is active:

```powershell
wsl --install -d Ubuntu
```

## 2. Clone Repository

Open your WSL Ubuntu terminal and run:

```bash
git clone -b ikura https://github.com/Ikuradachi/morphe-ai.git
cd morphe-ai
```

## 3. Run Environment Setup Scripts

Navigate to the `wsl` directory, make the setup scripts executable, and run them:

```bash
cd wsl
chmod +x mt.sh setup-morphe-workspace.sh check-version.sh reverse-tools.sh
./mt.sh
./setup-morphe-workspace.sh
```

- [mt.sh](mt.sh): Updates system packages and configures `mise`.
- [setup-morphe-workspace.sh](setup-morphe-workspace.sh): Installs runtimes, Android SDK, tools like `apkid`, and dependencies.

## 4. Restart WSL

After completion, close your WSL terminal. In PowerShell or Command Prompt, run:

```powershell
wsl --shutdown
```

Then launch your WSL/Ubuntu terminal again to load the updated environment.
