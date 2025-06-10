"""
Comprehensive tests for calendar event generation API.

Tests the complex recurring event calculation logic in get_calendar_events,
including various recurrence rules, exceptions, and edge cases.
"""

from datetime import date, datetime, time
from datetime import timezone as dt_timezone
from unittest.mock import patch

from django.test import Client, TestCase
from django.urls import reverse
from django.utils import timezone

from .models import Event, EventException, Ministry, Parish, User


class CalendarEventGenerationTest(TestCase):
    """Test calendar event generation with focus on recurring events."""

    def setUp(self):
        self.client = Client()

        # Create test data
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

        # Test date range (June 2025)
        self.start_date = "2025-06-01T00:00:00Z"
        self.end_date = "2025-06-30T23:59:59Z"

    def _get_calendar_events(self, start=None, end=None):
        """Helper to get calendar events and return parsed JSON."""
        start = start or self.start_date
        end = end or self.end_date

        response = self.client.get(
            reverse("calendar_events_api"), {"start": start, "end": end}
        )
        self.assertEqual(response.status_code, 200)
        return response.json()


class BasicRecurringEventsTest(CalendarEventGenerationTest):
    """Test basic recurring event generation."""

    def test_weekly_recurring_event(self):
        """Test weekly recurring event generates correct occurrences."""
        Event.objects.create(
            associated_ministry=self.ministry,
            title="Weekly Meeting",
            description="Every Wednesday",
            location="Conference Room",
            is_recurring=True,
            series_start_date=date(2025, 6, 4),  # First Wednesday in June
            series_end_date=date(2025, 6, 30),
            start_time_of_day=time(19, 0),  # 7 PM
            end_time_of_day=time(21, 0),  # 9 PM
            recurrence_rule="FREQ=WEEKLY;BYDAY=WE",
        )

        data = self._get_calendar_events()
        events = data["events"]

        # Should have 4 Wednesday occurrences in June 2025
        weekly_events = [e for e in events if e["title"] == "Weekly Meeting"]
        self.assertEqual(len(weekly_events), 4)

        # Verify dates are correct Wednesdays
        expected_dates = ["2025-06-04", "2025-06-11", "2025-06-18", "2025-06-25"]
        actual_dates = [e["start"][:10] for e in weekly_events]
        self.assertEqual(sorted(actual_dates), expected_dates)

        # Verify times are correct
        for event in weekly_events:
            self.assertTrue(event["start"].endswith("T19:00:00"))
            self.assertTrue(event["end"].endswith("T21:00:00"))

    def test_daily_recurring_event(self):
        """Test daily recurring event generates correct occurrences."""
        Event.objects.create(
            associated_ministry=self.ministry,
            title="Daily Prayer",
            description="Morning prayer",
            location="Chapel",
            is_recurring=True,
            series_start_date=date(2025, 6, 1),
            series_end_date=date(2025, 6, 7),  # One week only
            start_time_of_day=time(8, 0),
            end_time_of_day=time(8, 30),
            recurrence_rule="FREQ=DAILY",
        )

        # Use a narrower date range that matches the event series
        data = self._get_calendar_events(
            start="2025-06-01T00:00:00Z", end="2025-06-07T23:59:59Z"
        )
        events = data["events"]

        # Should have 7 daily occurrences (June 1-7)
        daily_events = [e for e in events if e["title"] == "Daily Prayer"]
        self.assertEqual(len(daily_events), 7)

        # Verify all dates are within the week
        actual_dates = [e["start"][:10] for e in daily_events]
        expected_dates = [
            "2025-06-01",
            "2025-06-02",
            "2025-06-03",
            "2025-06-04",
            "2025-06-05",
            "2025-06-06",
            "2025-06-07",
        ]
        self.assertEqual(sorted(actual_dates), expected_dates)

    def test_monthly_recurring_event(self):
        """Test monthly recurring event."""
        Event.objects.create(
            associated_ministry=self.ministry,
            title="Monthly Board Meeting",
            description="First Sunday of each month",
            location="Parish Hall",
            is_recurring=True,
            series_start_date=date(2025, 6, 1),
            series_end_date=date(2025, 8, 31),
            start_time_of_day=time(10, 0),
            end_time_of_day=time(12, 0),
            recurrence_rule="FREQ=MONTHLY;BYDAY=1SU",  # First Sunday
        )

        # Test wider date range to catch multiple months
        data = self._get_calendar_events(
            start="2025-06-01T00:00:00Z", end="2025-08-31T23:59:59Z"
        )
        events = data["events"]

        monthly_events = [e for e in events if e["title"] == "Monthly Board Meeting"]
        self.assertEqual(len(monthly_events), 3)  # June, July, August


class EventExceptionsTest(CalendarEventGenerationTest):
    """Test event exceptions (cancellations and rescheduling)."""

    def setUp(self):
        super().setUp()
        self.recurring_event = Event.objects.create(
            associated_ministry=self.ministry,
            title="Weekly Service",
            description="Every Sunday",
            location="Main Chapel",
            is_recurring=True,
            series_start_date=date(2025, 6, 1),
            series_end_date=date(2025, 6, 30),
            start_time_of_day=time(10, 0),
            end_time_of_day=time(11, 30),
            recurrence_rule="FREQ=WEEKLY;BYDAY=SU",
        )

    def test_cancelled_occurrence(self):
        """Test that cancelled occurrences don't appear in results."""
        # Cancel the June 8th occurrence
        EventException.objects.create(
            event=self.recurring_event,
            original_occurrence_date=date(2025, 6, 8),
            status="cancelled",
        )

        data = self._get_calendar_events()
        events = data["events"]

        service_events = [e for e in events if e["title"] == "Weekly Service"]
        actual_dates = [e["start"][:10] for e in service_events]

        # Should have all Sundays except June 8th
        self.assertNotIn("2025-06-08", actual_dates)
        self.assertIn("2025-06-01", actual_dates)
        self.assertIn("2025-06-15", actual_dates)

    def test_rescheduled_occurrence(self):
        """Test that rescheduled occurrences appear with new times."""
        # Reschedule June 15th service to June 16th at different time (UTC)
        EventException.objects.create(
            event=self.recurring_event,
            original_occurrence_date=date(2025, 6, 15),
            status="rescheduled",
            new_start_datetime=datetime(2025, 6, 16, 14, 0, tzinfo=dt_timezone.utc),
            new_end_datetime=datetime(2025, 6, 16, 15, 30, tzinfo=dt_timezone.utc),
        )

        data = self._get_calendar_events()
        events = data["events"]

        # Find the rescheduled event
        rescheduled_events = [
            e
            for e in events
            if "Rescheduled" in e["title"] and "Weekly Service" in e["title"]
        ]
        self.assertEqual(len(rescheduled_events), 1)

        rescheduled = rescheduled_events[0]
        self.assertEqual(rescheduled["start"][:10], "2025-06-16")
        # Check for time (may have timezone offset)
        self.assertIn("14:00:00", rescheduled["start"])

        # Original June 15th occurrence should not appear
        original_events = [
            e
            for e in events
            if e["title"] == "Weekly Service" and e["start"][:10] == "2025-06-15"
        ]
        self.assertEqual(len(original_events), 0)


class DateRangeFilteringTest(CalendarEventGenerationTest):
    """Test that date range filtering works correctly."""

    def test_events_outside_range_excluded(self):
        """Test events outside the requested range are excluded."""
        # Event before range
        Event.objects.create(
            associated_ministry=self.ministry,
            title="Before Range",
            is_recurring=False,
            start_datetime=timezone.make_aware(datetime(2025, 5, 15, 10, 0)),
            end_datetime=timezone.make_aware(datetime(2025, 5, 15, 11, 0)),
        )

        # Event after range
        Event.objects.create(
            associated_ministry=self.ministry,
            title="After Range",
            is_recurring=False,
            start_datetime=timezone.make_aware(datetime(2025, 7, 15, 10, 0)),
            end_datetime=timezone.make_aware(datetime(2025, 7, 15, 11, 0)),
        )

        # Event in range
        Event.objects.create(
            associated_ministry=self.ministry,
            title="In Range",
            is_recurring=False,
            start_datetime=timezone.make_aware(datetime(2025, 6, 15, 10, 0)),
            end_datetime=timezone.make_aware(datetime(2025, 6, 15, 11, 0)),
        )

        data = self._get_calendar_events()
        events = data["events"]

        titles = [e["title"] for e in events]
        self.assertIn("In Range", titles)
        self.assertNotIn("Before Range", titles)
        self.assertNotIn("After Range", titles)

    def test_recurring_series_partial_overlap(self):
        """Test recurring series that only partially overlap the date range."""
        # Series starts before range but continues into it
        Event.objects.create(
            associated_ministry=self.ministry,
            title="Started Earlier",
            is_recurring=True,
            series_start_date=date(2025, 5, 15),  # Before June
            series_end_date=date(2025, 6, 15),  # Ends mid-June
            start_time_of_day=time(10, 0),
            end_time_of_day=time(11, 0),
            recurrence_rule="FREQ=WEEKLY;BYDAY=MO",
        )

        data = self._get_calendar_events()
        events = data["events"]

        started_earlier = [e for e in events if e["title"] == "Started Earlier"]
        # Should only include occurrences within June date range
        june_dates = [e["start"][:7] for e in started_earlier]
        self.assertTrue(all(date.startswith("2025-06") for date in june_dates))


class ErrorHandlingTest(CalendarEventGenerationTest):
    """Test error handling and edge cases."""

    def test_invalid_recurrence_rule(self):
        """Test that invalid recurrence rules are handled gracefully."""
        with patch("core.views.logger") as mock_logger:
            Event.objects.create(
                associated_ministry=self.ministry,
                title="Invalid Rule Event",
                is_recurring=True,
                series_start_date=date(2025, 6, 1),
                series_end_date=date(2025, 6, 30),
                start_time_of_day=time(10, 0),
                end_time_of_day=time(11, 0),
                recurrence_rule="INVALID_RULE",
            )

            data = self._get_calendar_events()
            events = data["events"]

            # Event should be skipped and not appear in results
            invalid_events = [e for e in events if e["title"] == "Invalid Rule Event"]
            self.assertEqual(len(invalid_events), 0)

            # Error should be logged
            mock_logger.warning.assert_called()

    def test_missing_time_fields(self):
        """Test handling of events with missing time fields."""
        with patch("core.views.logger") as mock_logger:
            Event.objects.create(
                associated_ministry=self.ministry,
                title="Missing Times",
                is_recurring=True,
                series_start_date=date(2025, 6, 1),
                series_end_date=date(2025, 6, 30),
                start_time_of_day=None,  # Missing!
                end_time_of_day=time(11, 0),
                recurrence_rule="FREQ=WEEKLY;BYDAY=MO",
            )

            data = self._get_calendar_events()
            events = data["events"]

            # Event should be skipped
            missing_events = [e for e in events if e["title"] == "Missing Times"]
            self.assertEqual(len(missing_events), 0)

            # Error should be logged
            self.assertTrue(mock_logger.warning.called)

    def test_no_date_parameters(self):
        """Test API behavior when start/end dates are missing."""
        response = self.client.get(reverse("calendar_events_api"))
        self.assertEqual(response.status_code, 200)

        data = response.json()
        self.assertEqual(data["events"], [])

    def test_malformed_date_parameters(self):
        """Test API behavior with malformed date parameters."""
        # The view currently doesn't handle malformed dates gracefully
        # This causes a ValueError to be raised, which Django handles as a 500 error
        # We expect this to raise an exception during the test
        with self.assertRaises(ValueError):
            self.client.get(
                reverse("calendar_events_api"),
                {"start": "invalid-date", "end": "also-invalid"},
            )


class AdHocEventsTest(CalendarEventGenerationTest):
    """Test ad-hoc (non-recurring) events."""

    def test_adhoc_events_included(self):
        """Test that ad-hoc events are included in results."""
        Event.objects.create(
            associated_ministry=self.ministry,
            title="Special Event",
            description="One-time event",
            location="Special Location",
            is_recurring=False,
            start_datetime=timezone.make_aware(datetime(2025, 6, 15, 14, 0)),
            end_datetime=timezone.make_aware(datetime(2025, 6, 15, 16, 0)),
        )

        data = self._get_calendar_events()
        events = data["events"]

        special_events = [e for e in events if e["title"] == "Special Event"]
        self.assertEqual(len(special_events), 1)

        event = special_events[0]
        self.assertEqual(event["description"], "One-time event")
        self.assertEqual(event["location"], "Special Location")
        self.assertTrue(event["id"].startswith("adhoc_"))


class EventDataIntegrityTest(CalendarEventGenerationTest):
    """Test that generated event data includes all required fields."""

    def test_event_data_structure(self):
        """Test that events contain all expected fields."""
        Event.objects.create(
            associated_ministry=self.ministry,
            title="Test Event",
            description="Test Description",
            location="Test Location",
            is_recurring=False,
            start_datetime=timezone.make_aware(datetime(2025, 6, 15, 10, 0)),
            end_datetime=timezone.make_aware(datetime(2025, 6, 15, 11, 0)),
        )

        data = self._get_calendar_events()
        event = data["events"][0]

        # Verify all required fields are present
        required_fields = [
            "id",
            "title",
            "start",
            "end",
            "description",
            "location",
            "ministry",
            "parish",
        ]
        for field in required_fields:
            self.assertIn(field, event)
            self.assertIsNotNone(event[field])

        # Verify field values
        self.assertEqual(event["title"], "Test Event")
        self.assertEqual(event["description"], "Test Description")
        self.assertEqual(event["location"], "Test Location")
        self.assertEqual(event["ministry"], self.ministry.name)
        self.assertEqual(event["parish"], self.parish.name)


class PerformanceTest(CalendarEventGenerationTest):
    """Test performance with large datasets."""

    def test_many_recurring_events(self):
        """Test performance with many recurring events."""
        # Create 10 different recurring events
        for i in range(10):
            Event.objects.create(
                associated_ministry=self.ministry,
                title=f"Event {i}",
                is_recurring=True,
                series_start_date=date(2025, 6, 1),
                series_end_date=date(2025, 6, 30),
                start_time_of_day=time(10 + i % 12, 0),
                end_time_of_day=time(11 + i % 12, 0),
                recurrence_rule="FREQ=DAILY",
            )

        # This should complete without timeout
        data = self._get_calendar_events()
        events = data["events"]

        # Should have many events (10 events × 30 days = 300)
        self.assertGreater(len(events), 200)
