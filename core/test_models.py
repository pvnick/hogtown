from datetime import date, datetime, time

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.test import TestCase

from .models import Category, Event, EventException, Ministry, Parish

User = get_user_model()


class ParishModelTest(TestCase):
    def setUp(self):
        self.parish = Parish.objects.create(
            name="Test Parish",
            address="123 Test St, Test City, FL 32601",
            website_url="https://testparish.org",
            phone_number="(352) 555-1234",
            mass_schedule="Saturday 6:00 PM, Sunday 8:00 AM & 10:30 AM",
        )

    def test_parish_creation(self):
        self.assertEqual(self.parish.name, "Test Parish")
        self.assertEqual(str(self.parish), "Test Parish")

    def test_parish_fields(self):
        self.assertTrue(self.parish.address)
        self.assertTrue(self.parish.website_url)
        self.assertTrue(self.parish.phone_number)
        self.assertTrue(self.parish.mass_schedule)


class UserModelTest(TestCase):
    def setUp(self):
        self.parish = Parish.objects.create(name="Test Parish", address="123 Test St")

    def test_user_creation_defaults(self):
        user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="testpass123",
            full_name="Test User",
        )
        self.assertEqual(user.role, "leader")
        self.assertEqual(user.status, "pending")
        self.assertEqual(str(user), "Test User (test@example.com)")

    def test_user_with_parish(self):
        user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="testpass123",
            full_name="Test User",
            associated_parish=self.parish,
        )
        self.assertEqual(user.associated_parish, self.parish)

    def test_user_role_choices(self):
        admin_user = User.objects.create_user(
            username="admin",
            email="admin@example.com",
            password="testpass123",
            full_name="Admin User",
            role="admin",
        )
        self.assertEqual(admin_user.role, "admin")

    def test_user_status_choices(self):
        user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="testpass123",
            full_name="Test User",
            status="approved",
        )
        self.assertEqual(user.status, "approved")


class CategoryModelTest(TestCase):
    def test_category_creation(self):
        category = Category.objects.create(name="Service & Outreach")
        self.assertEqual(str(category), "Service & Outreach")

    def test_category_unique_name(self):
        Category.objects.create(name="Unique Category")
        with self.assertRaises(Exception):
            Category.objects.create(name="Unique Category")


class MinistryModelTest(TestCase):
    def setUp(self):
        self.parish = Parish.objects.create(name="Test Parish", address="123 Test St")
        self.user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="testpass123",
            full_name="Test User",
        )
        self.category = Category.objects.create(name="Test Category")

    def test_ministry_creation(self):
        ministry = Ministry.objects.create(
            owner_user=self.user,
            associated_parish=self.parish,
            name="Test Ministry",
            description="A test ministry",
            contact_info="Contact info here",
        )
        ministry.categories.add(self.category)

        self.assertEqual(str(ministry), "Test Ministry")
        self.assertEqual(ministry.owner_user, self.user)
        self.assertEqual(ministry.associated_parish, self.parish)
        self.assertIn(self.category, ministry.categories.all())


class EventModelTest(TestCase):
    def setUp(self):
        self.parish = Parish.objects.create(name="Test Parish", address="123 Test St")
        self.user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="testpass123",
            full_name="Test User",
        )
        self.ministry = Ministry.objects.create(
            owner_user=self.user,
            associated_parish=self.parish,
            name="Test Ministry",
            description="A test ministry",
            contact_info="Contact info here",
        )

    def test_adhoc_event_creation(self):
        event = Event.objects.create(
            associated_ministry=self.ministry,
            title="Test Event",
            description="A test event",
            location="Test Location",
            is_recurring=False,
            start_datetime=datetime(2025, 1, 15, 19, 0),
            end_datetime=datetime(2025, 1, 15, 21, 0),
        )
        self.assertEqual(str(event), "Test Event")
        self.assertFalse(event.is_recurring)

    def test_recurring_event_creation(self):
        event = Event.objects.create(
            associated_ministry=self.ministry,
            title="Weekly Meeting",
            description="Weekly ministry meeting",
            location="Parish Hall",
            is_recurring=True,
            series_start_date=date(2025, 1, 1),
            series_end_date=date(2025, 12, 31),
            start_time_of_day=time(19, 0),
            end_time_of_day=time(21, 0),
            recurrence_rule="FREQ=WEEKLY;BYDAY=WE",
        )
        self.assertTrue(event.is_recurring)
        self.assertEqual(event.recurrence_rule, "FREQ=WEEKLY;BYDAY=WE")

    def test_event_validation_adhoc(self):
        event = Event(
            associated_ministry=self.ministry,
            title="Invalid Event",
            description="Missing dates",
            location="Test Location",
            is_recurring=False
            # Missing start_datetime and end_datetime
        )
        with self.assertRaises(ValidationError):
            event.clean()

    def test_event_validation_recurring(self):
        event = Event(
            associated_ministry=self.ministry,
            title="Invalid Recurring Event",
            description="Missing recurrence data",
            location="Test Location",
            is_recurring=True
            # Missing required recurring fields
        )
        with self.assertRaises(ValidationError):
            event.clean()


class EventExceptionModelTest(TestCase):
    def setUp(self):
        self.parish = Parish.objects.create(name="Test Parish", address="123 Test St")
        self.user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="testpass123",
            full_name="Test User",
        )
        self.ministry = Ministry.objects.create(
            owner_user=self.user,
            associated_parish=self.parish,
            name="Test Ministry",
            description="A test ministry",
            contact_info="Contact info here",
        )
        self.event = Event.objects.create(
            associated_ministry=self.ministry,
            title="Weekly Meeting",
            description="Weekly ministry meeting",
            location="Parish Hall",
            is_recurring=True,
            series_start_date=date(2025, 1, 1),
            start_time_of_day=time(19, 0),
            end_time_of_day=time(21, 0),
            recurrence_rule="FREQ=WEEKLY;BYDAY=WE",
        )

    def test_cancelled_exception(self):
        exception = EventException.objects.create(
            event=self.event,
            original_occurrence_date=date(2025, 1, 15),
            status="cancelled",
        )
        self.assertEqual(exception.status, "cancelled")
        self.assertIn("cancelled", str(exception))

    def test_rescheduled_exception(self):
        exception = EventException.objects.create(
            event=self.event,
            original_occurrence_date=date(2025, 1, 15),
            status="rescheduled",
            new_start_datetime=datetime(2025, 1, 16, 20, 0),
            new_end_datetime=datetime(2025, 1, 16, 22, 0),
        )
        self.assertEqual(exception.status, "rescheduled")
        self.assertTrue(exception.new_start_datetime)
        self.assertTrue(exception.new_end_datetime)

    def test_rescheduled_exception_validation(self):
        exception = EventException(
            event=self.event,
            original_occurrence_date=date(2025, 1, 15),
            status="rescheduled"
            # Missing new_start_datetime and new_end_datetime
        )
        with self.assertRaises(ValidationError):
            exception.clean()

    def test_unique_together_constraint(self):
        EventException.objects.create(
            event=self.event,
            original_occurrence_date=date(2025, 1, 15),
            status="cancelled",
        )
        with self.assertRaises(Exception):
            EventException.objects.create(
                event=self.event,
                original_occurrence_date=date(2025, 1, 15),
                status="rescheduled",
            )
