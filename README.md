<img src="docs/static/org_gitrepo_cloner_logo_202508.png" alt="Cloner Logo" width="200"/>


 # Clone Organization repos

This repository provides scripts to efficiently clone all repositories from a GitHub organization. Both Bash and Python scripts are included for flexibility. At successful run of the script you will get as __new Directory with the Organization name__ (as defined in config) with a cloning instance's __datetime stamp__. Use the [config file](https://github.com/DeltaE/clone_ORGANIZATION_repos/blob/main/config.env) to set your __GITHUB_TOKEN__ to access private clones from the organization.

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
  - All repositories will be in a folder named `<organization_name>_<YYYYMMDD_HHMMSS>`.

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


- `ORG_NAME`: The default GitHub organization to clone from. If not set, defaults to `DeltaE`.
- `API_URL`: The base API URL for GitHub. Usually does not need to be changed.
- `GITHUB_TOKEN`: (Optional) GitHub token for authenticating API requests. Set this to access private repositories and increase API rate limits. If not set, only public repositories are accessible and rate limits are lower.

__Note__: If you provide an organization name as a command-line argument, it will override the value in `config.env`.

### Configuration Variables

| Variable         | Description                                                                 |
|------------------|-----------------------------------------------------------------------------|
| `ORG_NAME`       | The GitHub organization to clone from. Defaults to `DeltaE` if not set.     |
| `API_URL`        | The base API URL for GitHub. Usually does not need to be changed.           |
| `GITHUB_TOKEN`   | (Optional) GitHub token for private repos and higher API rate limits.       |

If `GITHUB_TOKEN` is set, the script will use it to authenticate API requests, allowing access to private repositories and increasing the rate limit for cloning large organizations.





## Usage


### Cloning Scripts (Choose one based on your OS)

#### Linux/macOS
| Command / Script                          | Description                                                                 |
|-------------------------------------------|-----------------------------------------------------------------------------|
| `make run_bash`                          | Run the Bash script to clone all repositories from the organization         |
| `make run_py`                            | Run the Python script (uses the virtual environment) to clone repositories  |
| `python3 clone_org_repos.py <org>`        | Clone repositories from a custom organization using Python                  |
| `./clone_org_repos.bash <org>`           | Clone repositories from a custom organization using Bash                    |



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

When cloning, both scripts create a master folder named:

```
<organization_name>_<YYYYMMDD_HHMMSS>
```

For example, cloning the organization `DeltaE` on August 27, 2025 at 14:30:00 will create:

```
DeltaE_20250827_143000/
```

All repositories will be cloned inside this folder.

## Notes

- For Python script usage, ensure you have Python 3 installed.
- Customize `requirements.txt` for additional Python dependencies.
