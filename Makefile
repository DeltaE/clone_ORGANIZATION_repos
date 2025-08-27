# Minimal Makefile for running scripts in venv
VENV=.venv
PYTHON=$(VENV)/bin/python

.PHONY: venv install run_bash run_py activate_venv

activate_venv:
	@echo "To activate the venv, run: source $(VENV)/bin/activate"

venv:
	python3 -m venv $(VENV)

install:
	$(PYTHON) -m pip install --upgrade pip
	$(PYTHON) -m pip install -r requirements.txt || true

run_bash:
	bash clone_org_repos.bash

run_py:
	$(PYTHON) clone_org_repos.py
