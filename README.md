 # Clone Organization repos

This repository provides scripts to efficiently clone all repositories from a GitHub organization. Both Bash and Python scripts are included for flexibility. At successful run of the script you will get as __new Directory with the Organization name__ (as defined in config) with a cloning instance's __datetime stamp__.

## Setup

### Configuration File

You can use a `config.env` file to set the organization name and API URL for cloning:

```env
# config.env example
ORG_NAME=YourOrgName
API_URL=https://api.github.com/orgs
```

- `ORG_NAME`: The default GitHub organization to clone from. If not set, defaults to `DeltaE`.
- `API_URL`: The base API URL for GitHub. Usually does not need to be changed.

If you provide an organization name as a command-line argument, it will override the value in `config.env`.


1. **Create a Python virtual environment:**

  ```bash
  make venv
  ```

2. **Install dependencies:**

  (Python only, add dependencies to `requirements.txt` if needed)

  ```bash
  make install
  ```


## Usage


### Bash script

Run the Bash script to clone all repositories from a GitHub organization:

```bash
make run_bash
```

### Python script

Run the Python script (uses the virtual environment):

```bash
make run_py
```

#### Custom organization name
By default, both scripts use `DeltaE` as the organization name. To specify another organization, pass it as an argument:

```bash
python3 clone_org_repos.py <organization_name>
./clone_org_repos.bash <organization_name>
```

#### GitHub Token
Set the `GITHUB_TOKEN` environment variable for private repositories or higher API rate limits:

```bash
export GITHUB_TOKEN=your_token_here
```


## Files

- `clone_org_repos.bash`: Bash script for cloning repositories.
- `clone_org_repos.py`: Python script for cloning repositories.
- `Makefile`: Minimal makefile for easy usage.
- `.venv/`: Python virtual environment directory.
- `requirements.txt`: Python dependencies for the script.


## Notes


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

- Ensure you have Python 3 installed.
- Customize `requirements.txt` for additional Python dependencies.
