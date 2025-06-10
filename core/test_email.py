from unittest.mock import Mock, patch

from django.contrib.auth import get_user_model
from django.core import mail
from django.template.loader import render_to_string
from django.test import TestCase

from .models import Parish

User = get_user_model()


class EmailTemplateTest(TestCase):
    def setUp(self):
        self.parish = Parish.objects.create(name="Test Parish", address="123 Test St")
        self.user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="testpass123",
            full_name="Test User",
            associated_parish=self.parish,
            requested_ministry_details="I want to start a youth ministry.",
        )

    def test_admin_notification_email_templates(self):
        context = {"user": self.user, "admin_url": "http://testserver/admin/core/user/"}

        subject = render_to_string(
            "core/emails/admin_notification_subject.txt", context
        ).strip()
        message = render_to_string("core/emails/admin_notification_body.txt", context)

        self.assertEqual(subject, "New Ministry Leader Registration Request")
        self.assertIn("Test User", message)
        self.assertIn("test@example.com", message)
        self.assertIn("Test Parish", message)
        self.assertIn("youth ministry", message)
        self.assertIn("http://testserver/admin/core/user/", message)

    def test_approval_email_templates(self):
        context = {"user": self.user, "login_url": "http://testserver/login/"}

        subject = render_to_string("core/emails/approval_subject.txt", context).strip()
        message = render_to_string("core/emails/approval_body.txt", context)

        self.assertEqual(subject, "Your Hogtown Catholic Account is Approved")
        self.assertIn("Test User", message)
        self.assertIn("approved", message)
        self.assertIn("http://testserver/login/", message)

    def test_rejection_email_templates(self):
        context = {"user": self.user}

        subject = render_to_string("core/emails/rejection_subject.txt", context).strip()
        message = render_to_string("core/emails/rejection_body.txt", context)

        self.assertEqual(subject, "Hogtown Catholic Account Update")
        self.assertIn("Test User", message)
        self.assertIn("not approved", message)


class EmailIntegrationTest(TestCase):
    def setUp(self):
        self.parish = Parish.objects.create(name="Test Parish", address="123 Test St")

        self.admin_user = User.objects.create_user(
            username="admin",
            email="admin@example.com",
            password="testpass123",
            full_name="Admin User",
            role="admin",
            status="approved",
        )

    @patch("core.views.send_mail")
    def test_registration_sends_admin_notification(self, mock_send_mail):
        from django.test import Client
        from django.urls import reverse

        client = Client()

        with patch("core.fields.requests.post") as mock_captcha:
            # Mock successful captcha
            mock_response = Mock()
            mock_response.status_code = 200
            mock_response.json.return_value = {"success": True}
            mock_captcha.return_value = mock_response

            response = client.post(
                reverse("register"),
                {
                    "username": "newuser",
                    "email": "newuser@example.com",
                    "full_name": "New User",
                    "password1": "testpass123!",
                    "password2": "testpass123!",
                    "associated_parish": self.parish.id,
                    "requested_ministry_details": "Youth ministry",
                    "procaptcha-response": "valid-token",
                },
            )

            self.assertEqual(response.status_code, 302)
            mock_send_mail.assert_called()

            # Check the email was sent with correct parameters
            call_args = mock_send_mail.call_args
            self.assertIn(
                "New Ministry Leader Registration Request", call_args[1]["subject"]
            )
            self.assertIn("admin@example.com", call_args[1]["recipient_list"])

    def test_email_backend_configuration(self):
        # Test that email backend is configured for testing
        from django.conf import settings

        # In tests, Django automatically uses locmem backend
        self.assertIn("EmailBackend", settings.EMAIL_BACKEND)

    def test_email_sending_with_console_backend(self):
        # Test actual email sending using Django's test email backend
        from django.conf import settings
        from django.core.mail import send_mail

        # Temporarily change to locmem backend for testing
        original_backend = settings.EMAIL_BACKEND
        settings.EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"

        try:
            send_mail(
                subject="Test Subject",
                message="Test message",
                from_email="test@example.com",
                recipient_list=["recipient@example.com"],
            )

            self.assertEqual(len(mail.outbox), 1)
            self.assertEqual(mail.outbox[0].subject, "Test Subject")
            self.assertEqual(mail.outbox[0].to, ["recipient@example.com"])
        finally:
            settings.EMAIL_BACKEND = original_backend

    def test_email_template_context_variables(self):
        # Test that all required context variables are available in templates
        user = User.objects.create_user(
            username="contextuser",
            email="context@example.com",
            password="testpass123",
            full_name="Context User",
            associated_parish=self.parish,
            requested_ministry_details="Context ministry details",
        )

        # Test admin notification context
        admin_context = {"user": user, "admin_url": "http://testserver/admin/"}

        admin_message = render_to_string(
            "core/emails/admin_notification_body.txt", admin_context
        )
        self.assertIn(user.full_name, admin_message)
        self.assertIn(user.email, admin_message)
        self.assertIn(user.associated_parish.name, admin_message)
        self.assertIn(user.requested_ministry_details, admin_message)
        self.assertIn(admin_context["admin_url"], admin_message)

        # Test approval context
        approval_context = {"user": user, "login_url": "http://testserver/login/"}

        approval_message = render_to_string(
            "core/emails/approval_body.txt", approval_context
        )
        self.assertIn(user.full_name, approval_message)
        self.assertIn(approval_context["login_url"], approval_message)
