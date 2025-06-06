# Hogtown Catholic

A Django web application for managing Catholic parishes, ministries, and events in Gainesville, Florida.

## Features

- **Public Directory**: Browse parishes, ministries, and events
- **Ministry Leader Registration**: Apply to become a ministry leader with admin approval
- **Ministry Portal**: Manage ministry profiles and events (ad-hoc and recurring)
- **Event Calendar**: Interactive calendar with filtering capabilities
- **Admin Dashboard**: Approve/reject registrations and manage core data

## Technology Stack

- **Backend**: Django 5.2.2
- **Database**: SQLite (development), configurable for production
- **Email**: Brevo (Sendinblue) integration via django-anymail
- **CAPTCHA**: Prosopo Procaptcha for bot protection
- **Authentication**: Custom approval-based authentication system

## Development Setup

### Prerequisites

- Python 3.11 or 3.12
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd hogtown
   ```

2. **Set up virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   pip install -r requirements-dev.txt  # For development
   ```

4. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

5. **Run migrations**
   ```bash
   python manage.py migrate
   ```

6. **Create superuser**
   ```bash
   python manage.py createsuperuser
   ```

7. **Run development server**
   ```bash
   python manage.py runserver
   ```

## Testing

### Running Tests

```bash
# Run all tests
python manage.py test

# Run with coverage
coverage run --source='.' manage.py test
coverage report --show-missing

# Run specific test modules
python manage.py test core.test_models
python manage.py test core.test_views
python manage.py test core.test_authentication
```

### Test Structure

- `test_models.py` - Unit tests for Django models
- `test_forms.py` - Form validation and field tests
- `test_views.py` - Integration tests for views and workflows
- `test_authentication.py` - Authentication backend and login tests
- `test_admin.py` - Admin interface and bulk action tests
- `test_email.py` - Email template and notification tests

### Continuous Integration

The project uses GitHub Actions for CI/CD with the following jobs:

- **test**: Runs test suite with coverage on Python 3.11 and 3.12
- **lint**: Code quality checks with flake8, black, and isort
- **security**: Security scanning with bandit and safety

## Configuration

### Environment Variables

Create a `.env` file based on `.env.example`:

```env
SECRET_KEY=your-secret-key-here
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

# Database
DATABASE_URL=sqlite:///db.sqlite3

# Prosopo Procaptcha
PROSOPO_SITE_KEY=your-prosopo-site-key
PROSOPO_SECRET_KEY=your-prosopo-secret-key

# Email
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
SENDINBLUE_API_KEY=your-brevo-api-key  # For production
```

### Production Deployment

For production deployment:

1. Set `DEBUG=False`
2. Configure a production database
3. Set up Brevo email service
4. Configure real Prosopo CAPTCHA keys
5. Set up proper static file serving
6. Use environment variables for sensitive settings

## Project Structure

```
hogtown/
├── core/                   # Main Django app
│   ├── models.py          # Data models
│   ├── views.py           # Views and business logic
│   ├── forms.py           # Form definitions
│   ├── admin.py           # Admin interface customization
│   ├── backends.py        # Custom authentication backend
│   ├── fields.py          # Custom form fields
│   ├── templates/         # HTML templates
│   └── test_*.py          # Test modules
├── hogtown_project/       # Django project settings
├── .github/workflows/     # CI/CD workflows
├── requirements.txt       # Production dependencies
├── requirements-dev.txt   # Development dependencies
├── .env.example          # Environment template
└── manage.py             # Django management script
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`python manage.py test`)
5. Run linting (`flake8 .`, `black .`, `isort .`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.