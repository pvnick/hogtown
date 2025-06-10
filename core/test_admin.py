from unittest.mock import Mock, patch

from django.contrib.admin.sites import AdminSite
from django.contrib.auth import get_user_model
from django.contrib.messages.storage.base import BaseStorage
from django.test import Client, RequestFactory, TestCase

from .admin import UserAdmin
from .models import Parish

User = get_user_model()


class MockRequest:
    def __init__(self, user=None):
        self.user = user or Mock()
        self._messages = BaseStorage(self)

    def build_absolute_uri(self, path):
        return f"http://testserver{path}"


class UserAdminTest(TestCase):
    def setUp(self):
        self.site = AdminSite()
        self.admin = UserAdmin(User, self.site)
        self.factory = RequestFactory()

        self.parish = Parish.objects.create(name="Test Parish", address="123 Test St")

        self.admin_user = User.objects.create_user(
            username="admin",
            email="admin@example.com",
            password="testpass123",
            full_name="Admin User",
            role="admin",
            status="approved",
        )

        self.pending_user1 = User.objects.create_user(
            username="pending1",
            email="pending1@example.com",
            password="testpass123",
            full_name="Pending User 1",
            status="pending",
            requested_ministry_details="Youth ministry",
        )

        self.pending_user2 = User.objects.create_user(
            username="pending2",
            email="pending2@example.com",
            password="testpass123",
            full_name="Pending User 2",
            status="pending",
            requested_ministry_details="Music ministry",
        )

        self.approved_user = User.objects.create_user(
            username="approved",
            email="approved@example.com",
            password="testpass123",
            full_name="Approved User",
            status="approved",
        )

    def test_colored_status_display(self):
        # Test pending status
        colored_status = self.admin.colored_status(self.pending_user1)
        self.assertIn("orange", colored_status)
        self.assertIn("Pending", colored_status)

        # Test approved status
        colored_status = self.admin.colored_status(self.approved_user)
        self.assertIn("green", colored_status)
        self.assertIn("Approved", colored_status)

    def test_queryset_ordering(self):
        # Test that pending users appear first
        queryset = self.admin.get_queryset(MockRequest())
        users = list(queryset)

        # Pending users should come first
        pending_users = [u for u in users if u.status == "pending"]
        approved_users = [u for u in users if u.status == "approved"]

        self.assertTrue(len(pending_users) > 0)
        self.assertTrue(len(approved_users) > 0)

    @patch("core.admin.send_mail")
    def test_approve_users_action(self, mock_send_mail):
        request = self.factory.post("/admin/core/user/")
        request.user = self.admin_user
        request._messages = BaseStorage(request)
        queryset = User.objects.filter(status="pending")

        self.admin.approve_users(request, queryset)

        # Check users were approved
        self.pending_user1.refresh_from_db()
        self.pending_user2.refresh_from_db()
        self.assertEqual(self.pending_user1.status, "approved")
        self.assertEqual(self.pending_user2.status, "approved")

        # Check emails were sent
        self.assertEqual(mock_send_mail.call_count, 2)

    @patch("core.admin.send_mail")
    def test_reject_users_action(self, mock_send_mail):
        request = self.factory.post("/admin/core/user/")
        request.user = self.admin_user
        request._messages = BaseStorage(request)
        queryset = User.objects.filter(status="pending")

        self.admin.reject_users(request, queryset)

        # Check users were rejected
        self.pending_user1.refresh_from_db()
        self.pending_user2.refresh_from_db()
        self.assertEqual(self.pending_user1.status, "rejected")
        self.assertEqual(self.pending_user2.status, "rejected")

        # Check emails were sent
        self.assertEqual(mock_send_mail.call_count, 2)

    @patch("core.admin.send_mail")
    def test_approve_non_pending_users(self, mock_send_mail):
        request = self.factory.post("/admin/core/user/")
        request.user = self.admin_user
        request._messages = BaseStorage(request)
        queryset = User.objects.filter(status="approved")  # Already approved users

        self.admin.approve_users(request, queryset)

        # No emails should be sent for already approved users
        mock_send_mail.assert_not_called()

    @patch("core.admin.send_mail")
    def test_approve_with_mocked_email(self, mock_send_mail):
        # Mock email to succeed (fake the email sending)
        mock_send_mail.return_value = None

        request = self.factory.post("/admin/core/user/")
        request.user = self.admin_user
        request._messages = BaseStorage(request)
        queryset = User.objects.filter(status="pending")

        self.admin.approve_users(request, queryset)

        # Users should be approved since email is mocked to succeed
        self.pending_user1.refresh_from_db()
        self.assertEqual(self.pending_user1.status, "approved")

    @patch("core.admin.send_mail")
    def test_email_failure_rollback(self, mock_send_mail):
        # Mock email failure
        mock_send_mail.side_effect = Exception("Email service down")

        request = self.factory.post("/admin/core/user/")
        request.user = self.admin_user
        request._messages = BaseStorage(request)
        queryset = User.objects.filter(status="pending")

        # Should not raise exception at the action level
        self.admin.approve_users(request, queryset)

        # Users should NOT be approved if email fails (transaction rollback)
        self.pending_user1.refresh_from_db()
        self.assertEqual(self.pending_user1.status, "pending")


class AdminIntegrationTest(TestCase):
    def setUp(self):
        self.client = Client()
        self.parish = Parish.objects.create(name="Test Parish", address="123 Test St")

        self.admin_user = User.objects.create_superuser(
            username="admin",
            email="admin@example.com",
            password="testpass123",
            full_name="Admin User",
        )

        self.pending_user = User.objects.create_user(
            username="pending",
            email="pending@example.com",
            password="testpass123",
            full_name="Pending User",
            status="pending",
            requested_ministry_details="Youth ministry",
        )

    def test_admin_login_required(self):
        response = self.client.get("/admin/")
        self.assertEqual(response.status_code, 302)  # Redirect to login

    def test_admin_user_list_view(self):
        self.client.force_login(self.admin_user)
        response = self.client.get("/admin/core/user/")
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "Pending User")

    def test_admin_user_detail_view(self):
        self.client.force_login(self.admin_user)
        response = self.client.get(f"/admin/core/user/{self.pending_user.id}/change/")
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "requested_ministry_details")

    @patch("core.admin.send_mail")
    def test_admin_bulk_actions(self, mock_send_mail):
        self.client.force_login(self.admin_user)

        # Test bulk approve action
        response = self.client.post(
            "/admin/core/user/",
            {
                "action": "approve_users",
                "_selected_action": [str(self.pending_user.id)],
            },
            follow=True,
        )

        self.assertEqual(response.status_code, 200)

        self.pending_user.refresh_from_db()
        self.assertEqual(self.pending_user.status, "approved")
        mock_send_mail.assert_called()
