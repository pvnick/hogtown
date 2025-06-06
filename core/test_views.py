from datetime import date, datetime, time
from unittest.mock import Mock, patch

from django.contrib.auth import get_user_model
from django.test import Client, TestCase
from django.urls import reverse

from .models import Category, Event, Ministry, Parish

User = get_user_model()


class PublicViewsTest(TestCase):
    def setUp(self):
        self.client = Client()
        self.parish = Parish.objects.create(
            name="Test Parish",
            address="123 Test St, Test City, FL 32601",
            website_url="https://testparish.org",
            phone_number="(352) 555-1234",
        )

    def test_parish_directory_view(self):
        response = self.client.get(reverse("parish_directory"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Test Parish")

    def test_parish_detail_view(self):
        response = self.client.get(reverse("parish_detail", args=[self.parish.id]))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Test Parish")

    def test_event_calendar_view(self):
        response = self.client.get(reverse("event_calendar"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Events")

    def test_parish_detail_404(self):
        response = self.client.get(reverse("parish_detail", args=[99999]))
        self.assertEqual(response.status_code, 404)


class RegistrationViewTest(TestCase):
    def setUp(self):
        self.client = Client()
        self.parish = Parish.objects.create(name="Test Parish", address="123 Test St")

        # Create an admin user for email notifications
        self.admin_user = User.objects.create_user(
            username="admin",
            email="admin@example.com",
            password="testpass123",
            full_name="Admin User",
            role="admin",
            status="approved",
        )

    def test_registration_page_loads(self):
        response = self.client.get(reverse("register"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Register as Ministry Leader")
        self.assertContains(response, "Full Name")
        self.assertContains(response, "Tell us about your ministry")

    @patch("core.views.send_mail")
    @patch("core.fields.requests.post")
    def test_successful_registration(self, mock_captcha_post, mock_send_mail):
        # Mock successful captcha verification
        mock_captcha_response = Mock()
        mock_captcha_response.status_code = 200
        mock_captcha_response.json.return_value = {"success": True}
        mock_captcha_post.return_value = mock_captcha_response

        response = self.client.post(
            reverse("register"),
            {
                "username": "newuser",
                "email": "newuser@example.com",
                "full_name": "New User",
                "password1": "testpass123!",
                "password2": "testpass123!",
                "associated_parish": self.parish.id,
                "requested_ministry_details": "I want to start a youth ministry.",
                "procaptcha-response": "valid-token",
            },
        )

        self.assertEqual(response.status_code, 302)  # Redirect to success page
        self.assertEqual(response.url, reverse("registration_success"))

        # Check user was created
        user = User.objects.get(username="newuser")
        self.assertEqual(user.email, "newuser@example.com")
        self.assertEqual(user.status, "pending")
        self.assertEqual(user.role, "leader")

        # Check admin notification email was sent
        mock_send_mail.assert_called()

    @patch("core.fields.requests.post")
    def test_registration_with_invalid_captcha(self, mock_captcha_post):
        # Mock failed captcha verification
        mock_captcha_response = Mock()
        mock_captcha_response.status_code = 200
        mock_captcha_response.json.return_value = {"success": False}
        mock_captcha_post.return_value = mock_captcha_response

        response = self.client.post(
            reverse("register"),
            {
                "username": "newuser",
                "email": "newuser@example.com",
                "full_name": "New User",
                "password1": "testpass123!",
                "password2": "testpass123!",
                "associated_parish": self.parish.id,
                "requested_ministry_details": "I want to start a youth ministry.",
                "procaptcha-response": "invalid-token",
            },
        )

        self.assertEqual(response.status_code, 200)  # Stays on form
        self.assertContains(response, "error")

        # Check user was not created
        self.assertFalse(User.objects.filter(username="newuser").exists())

    def test_registration_success_page(self):
        response = self.client.get(reverse("registration_success"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Registration Submitted Successfully")
        self.assertContains(response, "pending review")


class MinistryPortalViewTest(TestCase):
    def setUp(self):
        self.client = Client()
        self.parish = Parish.objects.create(name="Test Parish", address="123 Test St")

        self.user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="testpass123",
            full_name="Test User",
            status="approved",
        )

        self.ministry = Ministry.objects.create(
            owner_user=self.user,
            associated_parish=self.parish,
            name="Test Ministry",
            description="A test ministry",
            contact_info="Contact info",
        )

    def test_ministry_portal_requires_login(self):
        response = self.client.get(reverse("ministry_portal"))
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response.url)

    def test_ministry_portal_with_login(self):
        self.client.login(username="testuser", password="testpass123")
        response = self.client.get(reverse("ministry_portal"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Test Ministry")

    def test_ministry_detail_view(self):
        response = self.client.get(reverse("ministry_detail", args=[self.ministry.id]))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Test Ministry")


class EventViewTest(TestCase):
    def setUp(self):
        self.client = Client()
        self.parish = Parish.objects.create(name="Test Parish", address="123 Test St")

        self.user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="testpass123",
            full_name="Test User",
            status="approved",
        )

        self.ministry = Ministry.objects.create(
            owner_user=self.user,
            associated_parish=self.parish,
            name="Test Ministry",
            description="A test ministry",
            contact_info="Contact info",
        )

    def test_event_create_requires_login(self):
        response = self.client.get(reverse("event_create"))
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response.url)

    def test_event_create_form_loads(self):
        self.client.login(username="testuser", password="testpass123")
        response = self.client.get(reverse("event_create"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Create New Event")
        self.assertContains(response, "This is a recurring event")

    def test_create_adhoc_event(self):
        self.client.login(username="testuser", password="testpass123")
        response = self.client.post(
            reverse("event_create"),
            {
                "associated_ministry": self.ministry.id,
                "title": "Test Event",
                "description": "A test event",
                "location": "Test Location",
                "is_recurring": False,
                "start_datetime": "2025-06-15T19:00",
                "end_datetime": "2025-06-15T21:00",
            },
        )

        self.assertEqual(response.status_code, 302)  # Redirect after creation

        event = Event.objects.get(title="Test Event")
        self.assertFalse(event.is_recurring)
        self.assertEqual(event.associated_ministry, self.ministry)

    def test_create_recurring_event(self):
        self.client.login(username="testuser", password="testpass123")
        response = self.client.post(
            reverse("event_create"),
            {
                "associated_ministry": self.ministry.id,
                "title": "Weekly Meeting",
                "description": "Weekly ministry meeting",
                "location": "Parish Hall",
                "is_recurring": True,
                "series_start_date": "2025-01-01",
                "series_end_date": "2025-12-31",
                "start_time_of_day": "19:00",
                "end_time_of_day": "21:00",
                "recurrence_rule": "FREQ=WEEKLY;BYDAY=WE",
            },
        )

        self.assertEqual(response.status_code, 302)  # Redirect after creation

        event = Event.objects.get(title="Weekly Meeting")
        self.assertTrue(event.is_recurring)
        self.assertEqual(event.recurrence_rule, "FREQ=WEEKLY;BYDAY=WE")


class CalendarAPIViewTest(TestCase):
    def setUp(self):
        self.client = Client()
        self.parish = Parish.objects.create(name="Test Parish", address="123 Test St")

        self.user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="testpass123",
            full_name="Test User",
            status="approved",
        )

        self.ministry = Ministry.objects.create(
            owner_user=self.user,
            associated_parish=self.parish,
            name="Test Ministry",
            description="A test ministry",
            contact_info="Contact info",
        )

        # Create test events
        self.adhoc_event = Event.objects.create(
            associated_ministry=self.ministry,
            title="Test Event",
            description="A test event",
            location="Test Location",
            is_recurring=False,
            start_datetime=datetime(2025, 6, 15, 19, 0),
            end_datetime=datetime(2025, 6, 15, 21, 0),
        )

    def test_calendar_events_api(self):
        response = self.client.get(
            reverse("calendar_events_api"),
            {"start": "2025-06-01T00:00:00Z", "end": "2025-06-30T23:59:59Z"},
        )

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("events", data)
        self.assertEqual(len(data["events"]), 1)
        self.assertEqual(data["events"][0]["title"], "Test Event")

    def test_calendar_events_api_no_params(self):
        response = self.client.get(reverse("calendar_events_api"))
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["events"], [])
