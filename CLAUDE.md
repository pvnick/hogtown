# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Django web application project called "hogtown_project" with a core app.

## Development Commands

### Environment Setup
- Activate virtual environment: `source venv/bin/activate`
- Install dependencies: `pip install -r requirements.txt`

### Django Commands
- Run development server: `python manage.py runserver`
- Create migrations: `python manage.py makemigrations`
- Apply migrations: `python manage.py migrate`
- Create superuser: `python manage.py createsuperuser`
- Run tests: `python manage.py test`
- Collect static files: `python manage.py collectstatic`

### Project Structure
- `hogtown_project/`: Main Django project directory containing settings and configuration
- `core/`: Primary Django app for core functionality
- `venv/`: Python virtual environment (excluded from git)
- `requirements.txt`: Python package dependencies

## Development Notes

- Always activate the virtual environment before running Django commands
- The project uses Django 5.2.2
- Main app is called "core" - add new features here or create additional apps as needed