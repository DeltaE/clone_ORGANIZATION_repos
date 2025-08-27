<img src="docs/static/org_gitrepo_cloner_logo_202508.png" alt="Cloner Logo" width="200"/>


 # Clone Organization repos

This repository provides scripts to efficiently clone all repositories from a GitHub organization. Both Bash and Python scripts are included for flexibility. At successful run of the script you will get the cloned repositories inside '__cloned_repos__' (configurable folder name). Use the [config file](https://github.com/DeltaE/clone_ORGANIZATION_repos/blob/main/config.env) to set your __GITHUB_TOKEN__ to access private clones from the organization.

> 🆕 **If the cloned repo exists, 🔄 it will sync the repos with the latest available version.**

NOTE: Current setup is designed for Linux (or WSL2)/MACOs. Windows setup will be coming soon...

## Quick Start

Follow these steps to clone all repositories from a GitHub organization:

 > Windows instructions to be added in next release !

### Linux/MAC
1. **Clone this repository:**
  ```bash
  git clone https://github.com/DeltaE/clone_ORGANIZATION_repos.git
  cd clone_ORGANIZATION_repos
  ```

2. **Edit `config.env`:**
   > __DeltaE__ research lab folks can skip this step!
  - Set `ORG_NAME` to your organization name (default: `DeltaE`).
  - Set `GITHUB_TOKEN` if you need access to private repositories or higher API rate limits.

3. **Create a Python virtual environment:**
  ```bash
  make venv
  ```

4. **Install dependencies:**
  ```bash
  make install
  ```

5. Activate Virtual Environment
  ```bash
  source .venv/bin/activate
  ```

6. **Run the cloning script:**
  - The script will automatically clone new repositories or sync existing ones if the organization folder already exists
  - A detailed summary report (`clone_summary.txt`) is generated with operation history and results
  - Bash version:
    ```bash
    make run_bash
    ```
    __OR__
  - Python version (uses the virtual environment):
    ```bash
    make run_py
    ```

---

**Find your cloned repositories:**
  - All repositories will be inside the folder defined by `MASTER_FOLDER` (default: `cloned_repos`).
  - Repositories are organized by organization: `<MASTER_FOLDER>/<ORG_NAME>/`
  - Example: `cloned_repos/DeltaE/`
  - A `clone_summary.txt` file tracks all clone/sync operations with timestamps and results.

---
## Customizations Guide

### Configuration File

You can use a `config.env` file to set the organization name and API URL for cloning:

```env
# config.env example
ORG_NAME=YourOrgName
API_URL=https://api.github.com/orgs
# Optional: GitHub token for private repos and higher API rate limits
GITHUB_TOKEN=your_token_here
```
#### Configuration Variables

- `ORG_NAME`: The default GitHub organization to clone from. If not set, defaults to `DeltaE`.
- `API_URL`: The base API URL for GitHub. Usually does not need to be changed.
- `MASTER_FOLDER`: The base folder where all cloned repositories will be stored. Defaults to `cloned_repos`.
- `GITHUB_TOKEN`: (Optional) GitHub token for authenticating API requests. Set this to access private repositories and increase API rate limits. If not set, only public repositories are accessible and rate limits are lower.
  > [How to manage your github tokens?](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)

__Note__: If you provide an organization name as a command-line argument, it will override the value in `config.env`.


## Usage


### Cloning Scripts (Choose one based on your OS)

#### Linux/macOS
> 🆕 **If the cloned repo exists, 🔄 `make run_bash` or `make run_py` will sync the repos with the latest available version.**
> 
| Command / Script                          | Description                                                                 |
|-------------------------------------------|-----------------------------------------------------------------------------|
| `make run_bash`                          | Clone or sync repositories from the organization (Bash script)              |
| `make run_py`                            | Clone or sync repositories from the organization (Python script)            |
| `python3 clone_org_repos.py <org>`        | Clone/sync repositories from a custom organization using Python             |
| `./clone_org_repos.bash <org>`           | Clone/sync repositories from a custom organization using Bash               |

- __NOTE__: 
  Remember to activate virtual environment, when you use this repo

  ```bash
  source .venv/bin/activate
  ```

### Environment & Token Setup
| Command / Script                          | Description                                                                 |
|-------------------------------------------|-----------------------------------------------------------------------------|
| `export GITHUB_TOKEN=your_token_here`     | Set token for private repos or higher API rate limits (optional)            |


## Files

- `clone_org_repos.bash`: Bash script for cloning repositories.
- `clone_org_repos.py`: Python script for cloning repositories.
- `Makefile`: Minimal makefile for easy usage.
- `.venv/`: Python virtual environment directory.
- `requirements.txt`: Python dependencies for the script.


## Folder Naming Convention

- All cloned repositories are stored in the folder defined by `MASTER_FOLDER` (default: `cloned_repos`, configurable in `config.env`)
- Repositories are organized by organization name directly under the master folder
- **Smart behavior**: Scripts automatically detect if repositories already exist and will sync them instead of re-cloning

### Folder Structure

```text
cloned_repos/
├── DeltaE/
│   ├── clone_summary.txt    # Operation history and results
│   ├── repo1/
│   ├── repo2/
│   └── repo3/
└── AnotherOrg/
    ├── clone_summary.txt
    ├── project1/
    └── project2/
```

### Clone Summary File

Each organization folder contains a `clone_summary.txt` file that tracks:
- Organization name and operation timestamps
- List of cloned/synced repositories with status
- Success/failure counts for each operation
- Complete operation history

## Notes

- For Python script usage, ensure you have Python 3 installed.
- Customize `requirements.txt` for additional Python dependencies.
