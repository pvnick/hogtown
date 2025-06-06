from django.test import TestCase, Client
from django.urls import reverse
from django.contrib.auth import authenticate
from .models import User, Parish
from .backends import ApprovedUserBackend


class ApprovedUserBackendTest(TestCase):
    def setUp(self):
        self.parish = Parish.objects.create(name="Test Parish", address="123 Test St")
        self.backend = ApprovedUserBackend()
        
        # Create users with different statuses
        self.pending_user = User.objects.create_user(
            username='pending_user',
            email='pending@example.com',
            password='testpass123',
            full_name='Pending User',
            status='pending'
        )
        
        self.approved_user = User.objects.create_user(
            username='approved_user',
            email='approved@example.com',
            password='testpass123',
            full_name='Approved User',
            status='approved'
        )
        
        self.rejected_user = User.objects.create_user(
            username='rejected_user',
            email='rejected@example.com',
            password='testpass123',
            full_name='Rejected User',
            status='rejected'
        )

    def test_authenticate_approved_user(self):
        user = self.backend.authenticate(
            request=None,
            username='approved_user',
            password='testpass123'
        )
        self.assertEqual(user, self.approved_user)

    def test_authenticate_pending_user_fails(self):
        user = self.backend.authenticate(
            request=None,
            username='pending_user',
            password='testpass123'
        )
        self.assertIsNone(user)

    def test_authenticate_rejected_user_fails(self):
        user = self.backend.authenticate(
            request=None,
            username='rejected_user',
            password='testpass123'
        )
        self.assertIsNone(user)

    def test_authenticate_invalid_credentials(self):
        user = self.backend.authenticate(
            request=None,
            username='approved_user',
            password='wrongpassword'
        )
        self.assertIsNone(user)

    def test_authenticate_nonexistent_user(self):
        user = self.backend.authenticate(
            request=None,
            username='nonexistent',
            password='testpass123'
        )
        self.assertIsNone(user)


class LoginViewTest(TestCase):
    def setUp(self):
        self.client = Client()
        self.parish = Parish.objects.create(name="Test Parish", address="123 Test St")
        
        self.approved_user = User.objects.create_user(
            username='approved_user',
            email='approved@example.com',
            password='testpass123',
            full_name='Approved User',
            status='approved'
        )
        
        self.pending_user = User.objects.create_user(
            username='pending_user',
            email='pending@example.com',
            password='testpass123',
            full_name='Pending User',
            status='pending'
        )

    def test_login_page_loads(self):
        response = self.client.get(reverse('login'))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'Ministry Leader Login')
        self.assertContains(response, 'Register as Ministry Leader')

    def test_approved_user_can_login(self):
        response = self.client.post(reverse('login'), {
            'username': 'approved_user',
            'password': 'testpass123'
        })
        self.assertEqual(response.status_code, 302)  # Redirect after successful login
        self.assertTrue(self.client.session.get('_auth_user_id'))

    def test_pending_user_cannot_login(self):
        response = self.client.post(reverse('login'), {
            'username': 'pending_user',
            'password': 'testpass123'
        })
        self.assertEqual(response.status_code, 200)  # Stays on login page
        self.assertFalse(self.client.session.get('_auth_user_id'))

    def test_login_required_views_redirect(self):
        response = self.client.get(reverse('ministry_portal'))
        self.assertEqual(response.status_code, 302)  # Redirect to login
        self.assertIn('/login/', response.url)

    def test_approved_user_can_access_protected_views(self):
        self.client.login(username='approved_user', password='testpass123')
        response = self.client.get(reverse('ministry_portal'))
        self.assertEqual(response.status_code, 200)

    def test_logout_functionality(self):
        self.client.login(username='approved_user', password='testpass123')
        self.assertTrue(self.client.session.get('_auth_user_id'))
        
        response = self.client.post(reverse('logout'))
        self.assertEqual(response.status_code, 302)  # Redirect after logout
        self.assertFalse(self.client.session.get('_auth_user_id'))