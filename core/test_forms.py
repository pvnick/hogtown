from unittest.mock import Mock, patch

import requests

from django.test import TestCase

from .forms import MinistryLeaderRegistrationForm
from .models import Parish, User


class MinistryLeaderRegistrationFormTest(TestCase):
    def setUp(self):
        self.parish = Parish.objects.create(name="Test Parish", address="123 Test St")

        self.valid_form_data = {
            "username": "testuser",
            "email": "test@example.com",
            "full_name": "Test User",
            "password1": "testpass123!",
            "password2": "testpass123!",
            "associated_parish": self.parish.id,
            "requested_ministry_details": (
                "I want to start a youth ministry focused on community service."
            ),
            "captcha": "valid-captcha-token",
        }

    @patch("core.fields.requests.post")
    def test_valid_form_submission(self, mock_post):
        # Mock successful captcha verification
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"success": True}
        mock_post.return_value = mock_response

        form = MinistryLeaderRegistrationForm(data=self.valid_form_data)
        self.assertTrue(form.is_valid())

    @patch("core.fields.requests.post")
    def test_invalid_captcha(self, mock_post):
        # Mock failed captcha verification
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"success": False}
        mock_post.return_value = mock_response

        form = MinistryLeaderRegistrationForm(data=self.valid_form_data)
        self.assertFalse(form.is_valid())
        self.assertIn("captcha", form.errors)

    @patch("core.fields.requests.post")
    def test_captcha_network_error(self, mock_post):
        # Mock network error during captcha verification
        mock_post.side_effect = requests.RequestException("Network error")

        form = MinistryLeaderRegistrationForm(data=self.valid_form_data)
        self.assertFalse(form.is_valid())
        self.assertIn("captcha", form.errors)

    def test_missing_required_fields(self):
        form_data = self.valid_form_data.copy()
        form_data.pop("full_name")
        form_data.pop("requested_ministry_details")

        form = MinistryLeaderRegistrationForm(data=form_data)
        self.assertFalse(form.is_valid())
        self.assertIn("full_name", form.errors)
        self.assertIn("requested_ministry_details", form.errors)

    def test_password_mismatch(self):
        form_data = self.valid_form_data.copy()
        form_data["password2"] = "differentpassword"

        form = MinistryLeaderRegistrationForm(data=form_data)
        self.assertFalse(form.is_valid())
        self.assertIn("password2", form.errors)

    def test_invalid_email(self):
        form_data = self.valid_form_data.copy()
        form_data["email"] = "invalid-email"

        form = MinistryLeaderRegistrationForm(data=form_data)
        self.assertFalse(form.is_valid())
        self.assertIn("email", form.errors)

    @patch("core.fields.requests.post")
    def test_form_save(self, mock_post):
        # Mock successful captcha verification
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"success": True}
        mock_post.return_value = mock_response

        form = MinistryLeaderRegistrationForm(data=self.valid_form_data)
        self.assertTrue(form.is_valid())

        user = form.save()

        self.assertEqual(user.username, "testuser")
        self.assertEqual(user.email, "test@example.com")
        self.assertEqual(user.full_name, "Test User")
        self.assertEqual(user.associated_parish, self.parish)
        self.assertEqual(
            user.requested_ministry_details,
            "I want to start a youth ministry focused on community service.",
        )
        self.assertEqual(user.role, "leader")
        self.assertEqual(user.status, "pending")

    def test_duplicate_username(self):
        User.objects.create_user(
            username="testuser", email="existing@example.com", password="testpass123"
        )

        form = MinistryLeaderRegistrationForm(data=self.valid_form_data)
        self.assertFalse(form.is_valid())
        self.assertIn("username", form.errors)

    @patch("core.fields.requests.post")
    def test_duplicate_email(self, mock_post):
        # Mock successful captcha verification
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"success": True}
        mock_post.return_value = mock_response

        User.objects.create_user(
            username="existinguser", email="test@example.com", password="testpass123"
        )

        form = MinistryLeaderRegistrationForm(data=self.valid_form_data)
        self.assertFalse(form.is_valid())
        self.assertIn("email", form.errors)

    def test_parish_dropdown_choices(self):
        parish2 = Parish.objects.create(name="Second Parish", address="456 Test Ave")

        form = MinistryLeaderRegistrationForm()

        parish_choices = form.fields["associated_parish"].queryset
        self.assertIn(self.parish, parish_choices)
        self.assertIn(parish2, parish_choices)
        self.assertEqual(parish_choices.count(), 2)
