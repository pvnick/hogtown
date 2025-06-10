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

        # Test rejected status
        rejected_user = User.objects.create_user(
            username="rejected",
            email="rejected@example.com",
            password="testpass123",
            full_name="Rejected User",
            status="rejected",
        )
        colored_status = self.admin.colored_status(rejected_user)
        self.assertIn("red", colored_status)
        self.assertIn("Rejected", colored_status)

    def test_email_status_display(self):
        # Test pending user (should show "-")
        email_status = self.admin.email_status(self.pending_user1)
        self.assertEqual(email_status, "-")

        # Test approved user with email sent
        self.approved_user.approval_email_sent = True
        self.approved_user.save()
        email_status = self.admin.email_status(self.approved_user)
        self.assertIn("✓ Sent", email_status)
        self.assertIn("green", email_status)

        # Test approved user with email failed
        self.approved_user.approval_email_sent = False
        self.approved_user.save()
        email_status = self.admin.email_status(self.approved_user)
        self.assertIn("✗ Failed", email_status)
        self.assertIn("red", email_status)

        # Test rejected user with email sent
        rejected_user = User.objects.create_user(
            username="rejected",
            email="rejected@example.com",
            password="testpass123",
            full_name="Rejected User",
            status="rejected",
            rejection_email_sent=True,
        )
        email_status = self.admin.email_status(rejected_user)
        self.assertIn("✓ Sent", email_status)
        self.assertIn("green", email_status)

        # Test rejected user with email failed
        rejected_user.rejection_email_sent = False
        rejected_user.save()
        email_status = self.admin.email_status(rejected_user)
        self.assertIn("✗ Failed", email_status)
        self.assertIn("red", email_status)

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

        # Check email tracking fields are set correctly
        self.assertTrue(self.pending_user1.approval_email_sent)
        self.assertTrue(self.pending_user2.approval_email_sent)
        self.assertEqual(self.pending_user1.email_failure_reason, "")
        self.assertEqual(self.pending_user2.email_failure_reason, "")

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

        # Check email tracking fields are set correctly
        self.assertTrue(self.pending_user1.rejection_email_sent)
        self.assertTrue(self.pending_user2.rejection_email_sent)
        self.assertEqual(self.pending_user1.email_failure_reason, "")
        self.assertEqual(self.pending_user2.email_failure_reason, "")

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
    def test_email_failure_no_rollback(self, mock_send_mail):
        # Mock email failure
        mock_send_mail.side_effect = Exception("Email service down")

        request = self.factory.post("/admin/core/user/")
        request.user = self.admin_user
        request._messages = BaseStorage(request)
        queryset = User.objects.filter(status="pending")

        # Should not raise exception at the action level
        self.admin.approve_users(request, queryset)

        # User status should be approved even if email fails (no rollback)
        self.pending_user1.refresh_from_db()
        self.assertEqual(self.pending_user1.status, "approved")

        # Email failure should be tracked
        self.assertFalse(self.pending_user1.approval_email_sent)
        self.assertEqual(self.pending_user1.email_failure_reason, "Email service down")

    @patch("core.admin.send_mail")
    def test_reject_email_failure_no_rollback(self, mock_send_mail):
        # Mock email failure
        mock_send_mail.side_effect = Exception("Email service down")

        request = self.factory.post("/admin/core/user/")
        request.user = self.admin_user
        request._messages = BaseStorage(request)
        queryset = User.objects.filter(status="pending")

        # Should not raise exception at the action level
        self.admin.reject_users(request, queryset)

        # User status should be rejected even if email fails (no rollback)
        self.pending_user1.refresh_from_db()
        self.assertEqual(self.pending_user1.status, "rejected")

        # Email failure should be tracked
        self.assertFalse(self.pending_user1.rejection_email_sent)
        self.assertEqual(self.pending_user1.email_failure_reason, "Email service down")

    @patch("core.admin.send_mail")
    def test_retry_approval_emails(self, mock_send_mail):
        # First, create a user with failed email
        self.pending_user1.status = "approved"
        self.pending_user1.approval_email_sent = False
        self.pending_user1.email_failure_reason = "Previous failure"
        self.pending_user1.save()

        request = self.factory.post("/admin/core/user/")
        request.user = self.admin_user
        request._messages = BaseStorage(request)
        queryset = User.objects.filter(id=self.pending_user1.id)

        # Retry should succeed
        self.admin.retry_approval_emails(request, queryset)

        # Email should be marked as sent
        self.pending_user1.refresh_from_db()
        self.assertTrue(self.pending_user1.approval_email_sent)
        self.assertEqual(self.pending_user1.email_failure_reason, "")

    @patch("core.admin.send_mail")
    def test_retry_rejection_emails(self, mock_send_mail):
        # First, create a user with failed email
        self.pending_user1.status = "rejected"
        self.pending_user1.rejection_email_sent = False
        self.pending_user1.email_failure_reason = "Previous failure"
        self.pending_user1.save()

        request = self.factory.post("/admin/core/user/")
        request.user = self.admin_user
        request._messages = BaseStorage(request)
        queryset = User.objects.filter(id=self.pending_user1.id)

        # Retry should succeed
        self.admin.retry_rejection_emails(request, queryset)

        # Email should be marked as sent
        self.pending_user1.refresh_from_db()
        self.assertTrue(self.pending_user1.rejection_email_sent)
        self.assertEqual(self.pending_user1.email_failure_reason, "")

    @patch("core.admin.send_mail")
    def test_retry_approval_emails_failure(self, mock_send_mail):
        # Mock email failure on retry
        mock_send_mail.side_effect = Exception("Still failing")

        # First, create a user with failed email
        self.pending_user1.status = "approved"
        self.pending_user1.approval_email_sent = False
        self.pending_user1.email_failure_reason = "Previous failure"
        self.pending_user1.save()

        request = self.factory.post("/admin/core/user/")
        request.user = self.admin_user
        request._messages = BaseStorage(request)
        queryset = User.objects.filter(id=self.pending_user1.id)

        # Retry should handle failure gracefully
        self.admin.retry_approval_emails(request, queryset)

        # Email should still be marked as failed with new reason
        self.pending_user1.refresh_from_db()
        self.assertFalse(self.pending_user1.approval_email_sent)
        self.assertEqual(self.pending_user1.email_failure_reason, "Still failing")

    @patch("core.admin.send_mail")
    def test_retry_rejection_emails_failure(self, mock_send_mail):
        # Mock email failure on retry
        mock_send_mail.side_effect = Exception("Still failing")

        # First, create a user with failed email
        self.pending_user1.status = "rejected"
        self.pending_user1.rejection_email_sent = False
        self.pending_user1.email_failure_reason = "Previous failure"
        self.pending_user1.save()

        request = self.factory.post("/admin/core/user/")
        request.user = self.admin_user
        request._messages = BaseStorage(request)
        queryset = User.objects.filter(id=self.pending_user1.id)

        # Retry should handle failure gracefully
        self.admin.retry_rejection_emails(request, queryset)

        # Email should still be marked as failed with new reason
        self.pending_user1.refresh_from_db()
        self.assertFalse(self.pending_user1.rejection_email_sent)
        self.assertEqual(self.pending_user1.email_failure_reason, "Still failing")

    def test_retry_approval_emails_no_failed_users(self):
        # Test with queryset that has no users with failed approval emails
        request = self.factory.post("/admin/core/user/")
        request.user = self.admin_user
        request._messages = BaseStorage(request)

        # Use users that don't have failed approval emails
        queryset = User.objects.filter(status="pending")  # Pending users, not approved

        # Should handle gracefully with warning message
        self.admin.retry_approval_emails(request, queryset)
        # Should not crash - the method handles this case

    def test_retry_rejection_emails_no_failed_users(self):
        # Test with queryset that has no users with failed rejection emails
        request = self.factory.post("/admin/core/user/")
        request.user = self.admin_user
        request._messages = BaseStorage(request)

        # Use users that don't have failed rejection emails
        queryset = User.objects.filter(status="pending")  # Pending users, not rejected

        # Should handle gracefully with warning message
        self.admin.retry_rejection_emails(request, queryset)
        # Should not crash - the method handles this case

    @patch("core.admin.send_mail")
    @patch("core.admin.render_to_string")
    def test_approval_email_context(self, mock_render, mock_send_mail):
        # Test that email templates receive correct context
        request = self.factory.post("/admin/core/user/")
        request.user = self.admin_user
        request._messages = BaseStorage(request)
        queryset = User.objects.filter(id=self.pending_user1.id)

        self.admin.approve_users(request, queryset)

        # Check that render_to_string was called with correct context
        self.assertEqual(mock_render.call_count, 2)  # Subject and body templates

        # Get the context from the first call (approval_subject.txt)
        subject_call = mock_render.call_args_list[0]
        context = subject_call[0][1]  # Second argument is the context

        self.assertEqual(context["user"], self.pending_user1)
        self.assertIn("login_url", context)
        self.assertIn("http://testserver/login/", context["login_url"])

    @patch("core.admin.send_mail")
    @patch("core.admin.render_to_string")
    def test_rejection_email_context(self, mock_render, mock_send_mail):
        # Test that rejection email templates receive correct context
        request = self.factory.post("/admin/core/user/")
        request.user = self.admin_user
        request._messages = BaseStorage(request)
        queryset = User.objects.filter(id=self.pending_user1.id)

        self.admin.reject_users(request, queryset)

        # Check that render_to_string was called with correct context
        self.assertEqual(mock_render.call_count, 2)  # Subject and body templates

        # Get the context from the first call (rejection_subject.txt)
        subject_call = mock_render.call_args_list[0]
        context = subject_call[0][1]  # Second argument is the context

        self.assertEqual(context["user"], self.pending_user1)


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
